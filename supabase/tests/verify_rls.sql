-- =============================================================================
-- tests/verify_rls.sql
-- Run this in the Supabase Dashboard -> SQL Editor after applying the
-- migrations and the seed. It prints PASS / FAIL lines and never changes
-- data (every check runs inside a transaction that is rolled back).
--
-- The checks impersonate an authenticated user by switching the role and
-- setting the JWT claims, which is exactly what PostgREST does.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tenant isolation: a member of business A cannot read business B rows
--   users: owner A  11111111-1111-4111-8111-111111111111
--          staff A  22222222-2222-4222-8222-222222222222
--          acc. A   33333333-3333-4333-8333-333333333333
--          owner B  44444444-4444-4444-8444-444444444444
-- -----------------------------------------------------------------------------
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';

  select case when count(*) = 0
    then raise notice 'PASS: owner A sees no rows of business B'
    else raise exception 'FAIL: owner A can read % rows of business B', count(*)
  end
  from public.customers
  where business_id = 'aaaaaaaa-0000-4000-8000-000000000002';

  select case when count(*) > 0
    then raise notice 'PASS: owner A sees % rows of business A', count(*)
    else raise exception 'FAIL: owner A cannot read their own business'
  end
  from public.customers
  where business_id = 'aaaaaaaa-0000-4000-8000-000000000001';
rollback;

-- -----------------------------------------------------------------------------
-- 2. Staff can read the business but must not record a payment
-- -----------------------------------------------------------------------------
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}';

  select case when count(*) > 0
    then raise notice 'PASS: staff can read customers'
    else raise exception 'FAIL: staff cannot read customers'
  end
  from public.customers;

  do $$
  begin
    insert into public.payments (
      business_id, order_id, kind, amount, method, idempotency_key
    ) values (
      'aaaaaaaa-0000-4000-8000-000000000001',
      'o0000000-0000-4000-8000-000000000001',
      'installment', 100, 'cash', 'verify-rls-should-not-exist'
    );
    raise exception 'FAIL: staff was able to insert a payment directly';
  exception when insufficient_privilege then
    raise notice 'PASS: staff cannot insert payments directly (RLS)';
  end $$;
rollback;

-- -----------------------------------------------------------------------------
-- 3. Accountant can read money but must not change quotations
-- -----------------------------------------------------------------------------
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';

  select case when count(*) > 0
    then raise notice 'PASS: accountant can read payments'
    else raise exception 'FAIL: accountant cannot read payments'
  end
  from public.payments;

  do $$
  begin
    update public.quotations set notes = 'tampered' where id = 'q0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL: accountant was able to update a quotation';
  exception when insufficient_privilege then
    raise notice 'PASS: accountant cannot update quotations (RLS)';
  end $$;

  do $$
  begin
    update public.orders set status = 'closed' where id = 'o0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL: accountant was able to change an order status';
  exception when insufficient_privilege then
    raise notice 'PASS: accountant cannot change order status (RLS)';
  end $$;
rollback;

-- -----------------------------------------------------------------------------
-- 4. The anon role has no table privileges at all
-- -----------------------------------------------------------------------------
begin;
  set local role anon;
  select case when count(*) = 0
    then raise notice 'PASS: anon sees no rows'
    else raise exception 'FAIL: anon can read % rows', count(*)
  end
  from public.customers;
rollback;

-- -----------------------------------------------------------------------------
-- 5. Balance reconciliation
--    outstanding must equal total - (paid - refunded) for every order
-- -----------------------------------------------------------------------------
select case when count(*) = 0
  then raise notice 'PASS: outstanding balance reconciles for every order'
  else raise exception 'FAIL: % orders do not reconcile', count(*)
end
from (
  select o.id,
         o.total_amount_cents - (coalesce(p.paid_cents, 0) - coalesce(r.refunded_cents, 0)) as expected,
         coalesce(f.outstanding_cents, 0) as actual
  from public.orders o
  left join (
    select order_id, sum(amount_cents)::bigint as paid_cents
    from public.payments where status in ('successful', 'refunded') group by order_id
  ) p on p.order_id = o.id
  left join (
    select order_id, sum(amount_cents)::bigint as refunded_cents
    from public.refunds group by order_id
  ) r on r.order_id = o.id
  left join public.order_financials(o.business_id) f on f ->> 'order_id' = o.id::text
) x
where x.expected <> x.actual;

-- -----------------------------------------------------------------------------
-- 6. Production cost reconciliation
-- -----------------------------------------------------------------------------
select case when count(*) = 0
  then raise notice 'PASS: actual cost matches the cost entries'
  else raise exception 'FAIL: % orders have a stale actual cost', count(*)
end
from public.orders o
where o.actual_cost <> coalesce((select sum(c.amount) from public.order_costs c where c.order_id = o.id), 0);
