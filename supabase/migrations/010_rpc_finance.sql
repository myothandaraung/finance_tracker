-- =============================================================================
-- 010_rpc_finance.sql
-- Cash movements, production costs and operating expenses.
--
-- Reliability rules enforced here:
--   * every payment carries an idempotency key; replaying a key returns the
--     existing payment instead of creating a second one
--   * the order row is locked before balances are computed so two devices
--     cannot both spend the same remaining balance
--   * overpayment is rejected unless an owner explicitly allows it
-- =============================================================================

-- Recomputes the production cost of an order from its cost entries.
create or replace function public.refresh_order_actual_cost(p_order_id uuid)
returns numeric
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.orders o
     set actual_cost = coalesce(
           (select sum(c.amount) from public.order_costs c where c.order_id = o.id),
           0
         ),
         updated_at = now()
   where o.id = p_order_id
  returning o.actual_cost;
$$;

-- -----------------------------------------------------------------------------
-- Payments
-- -----------------------------------------------------------------------------
create or replace function public.rpc_record_payment(
  p_order_id uuid,
  p_amount_cents bigint,
  p_kind text default 'installment',
  p_method text default 'cash',
  p_reference text default null,
  p_paid_at timestamptz default now(),
  p_idempotency_key text default null,
  p_receipt_path text default null,
  p_allow_overpayment boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_payment public.payments%rowtype;
  v_total_cents bigint;
  v_paid_cents bigint;
  v_refunded_cents bigint;
  v_outstanding_cents bigint;
  v_existing public.payments%rowtype;
begin
  if p_idempotency_key is null or length(btrim(p_idempotency_key)) = 0 then
    raise exception 'An idempotency key is required' using errcode = 'P0001';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_order.business_id, array['owner', 'accountant']);

  -- Replay of the same submission: return the original payment.
  select * into v_existing
  from public.payments
  where business_id = v_order.business_id
    and idempotency_key = p_idempotency_key;

  if v_existing.id is not null then
    select coalesce(sum(amount_cents), 0)::bigint into v_paid_cents
    from public.payments where order_id = p_order_id and status in ('successful', 'refunded');
    select coalesce(sum(amount_cents), 0)::bigint into v_refunded_cents
    from public.refunds where order_id = p_order_id;

    v_total_cents := public.numeric_to_cents(v_order.total_amount);
    v_outstanding_cents := v_total_cents - (v_paid_cents - v_refunded_cents);

    return jsonb_build_object(
      'payment', to_jsonb(v_existing),
      'outstanding_cents', v_outstanding_cents,
      'duplicate', true
    );
  end if;

  if coalesce(p_amount_cents, 0) <= 0 then
    raise exception 'Enter an amount greater than zero' using errcode = 'P0001';
  end if;

  if p_kind not in ('deposit', 'installment', 'final', 'adjustment') then
    raise exception 'Unknown payment type' using errcode = 'P0001';
  end if;

  v_total_cents := public.numeric_to_cents(v_order.total_amount);
  select coalesce(sum(amount_cents), 0)::bigint into v_paid_cents
  from public.payments where order_id = p_order_id and status in ('successful', 'refunded');
  select coalesce(sum(amount_cents), 0)::bigint into v_refunded_cents
  from public.refunds where order_id = p_order_id;

  v_outstanding_cents := v_total_cents - (v_paid_cents - v_refunded_cents);

  if p_amount_cents > v_outstanding_cents then
    if not coalesce(p_allow_overpayment, false) then
      raise exception 'Amount exceeds the outstanding balance of %',
        (v_outstanding_cents / 100.0)::numeric using errcode = 'P0001';
    end if;
    if not public.has_business_role(v_order.business_id, array['owner']) then
      raise exception 'Only an owner can accept an overpayment' using errcode = '42501';
    end if;
  end if;

  if v_order.status = 'cancelled' then
    raise exception 'This order is cancelled' using errcode = 'P0001';
  end if;

  insert into public.payments (
    business_id, order_id, customer_id, kind, amount, method, reference,
    receipt_path, paid_at, status, idempotency_key, created_by
  ) values (
    v_order.business_id,
    v_order.id,
    v_order.customer_id,
    p_kind,
    public.cents_to_numeric(p_amount_cents),
    coalesce(nullif(btrim(coalesce(p_method, '')), ''), 'cash'),
    nullif(btrim(coalesce(p_reference, '')), ''),
    nullif(btrim(coalesce(p_receipt_path, '')), ''),
    coalesce(p_paid_at, now()),
    'successful',
    btrim(p_idempotency_key),
    auth.uid()
  ) returning * into v_payment;

  v_outstanding_cents := v_outstanding_cents - p_amount_cents;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (v_order.business_id, auth.uid(), 'payment', v_payment.id, 'created', to_jsonb(v_payment));

  return jsonb_build_object(
    'payment', to_jsonb(v_payment),
    'outstanding_cents', v_outstanding_cents,
    'duplicate', false
  );
end;
$$;

create or replace function public.rpc_record_refund(
  p_payment_id uuid,
  p_amount_cents bigint,
  p_reason text default null,
  p_method text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_payment public.payments%rowtype;
  v_refund public.refunds%rowtype;
  v_refunded_cents bigint;
  v_outstanding_cents bigint;
  v_paid_cents bigint;
  v_total_cents bigint;
begin
  select * into v_payment from public.payments where id = p_payment_id for update;
  if v_payment.id is null then
    raise exception 'Payment not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_payment.business_id, array['owner', 'accountant']);

  if v_payment.status <> 'successful' then
    raise exception 'Only a successful payment can be refunded' using errcode = 'P0001';
  end if;

  if coalesce(p_amount_cents, 0) <= 0 then
    raise exception 'Enter an amount greater than zero' using errcode = 'P0001';
  end if;

  select coalesce(sum(amount_cents), 0)::bigint into v_refunded_cents
  from public.refunds where payment_id = p_payment_id;

  if p_amount_cents > v_payment.amount_cents - v_refunded_cents then
    raise exception 'Refund cannot be more than the amount that is still refundable' using errcode = 'P0001';
  end if;

  insert into public.refunds (
    business_id, order_id, payment_id, amount, method, reason, refunded_at, created_by
  ) values (
    v_payment.business_id,
    v_payment.order_id,
    v_payment.id,
    public.cents_to_numeric(p_amount_cents),
    coalesce(nullif(btrim(coalesce(p_method, '')), ''), v_payment.method),
    nullif(btrim(coalesce(p_reason, '')), ''),
    now(),
    auth.uid()
  ) returning * into v_refund;

  if v_refunded_cents + p_amount_cents = v_payment.amount_cents then
    update public.payments set status = 'refunded', updated_at = now() where id = p_payment_id;
  end if;

  select coalesce(sum(amount_cents), 0)::bigint into v_paid_cents
  from public.payments where order_id = v_payment.order_id and status in ('successful', 'refunded');
  select coalesce(sum(amount_cents), 0)::bigint into v_refunded_cents
  from public.refunds where order_id = v_payment.order_id;
  select total_amount_cents into v_total_cents from public.orders where id = v_payment.order_id;

  v_outstanding_cents := v_total_cents - (v_paid_cents - v_refunded_cents);

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (v_payment.business_id, auth.uid(), 'refund', v_refund.id, 'created', to_jsonb(v_refund));

  return jsonb_build_object(
    'refund', to_jsonb(v_refund),
    'outstanding_cents', v_outstanding_cents
  );
end;
$$;

create or replace function public.rpc_void_payment(
  p_payment_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_payment public.payments%rowtype;
begin
  select * into v_payment from public.payments where id = p_payment_id for update;
  if v_payment.id is null then
    raise exception 'Payment not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_payment.business_id, array['owner']);

  if v_payment.status = 'void' then
    raise exception 'This payment is already void' using errcode = 'P0001';
  end if;

  update public.payments
     set status = 'void',
         reference = coalesce(reference || ' | voided: ', reference) ||
                    coalesce(nullif(btrim(coalesce(p_reason, '')), ''), 'no reason given'),
         updated_at = now()
   where id = p_payment_id
   returning * into v_payment;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, old_data, new_data)
  values (
    v_payment.business_id, auth.uid(), 'payment', v_payment.id, 'voided',
    jsonb_build_object('status', 'successful'), to_jsonb(v_payment)
  );

  return to_jsonb(v_payment);
end;
$$;

-- -----------------------------------------------------------------------------
-- Production costs
-- -----------------------------------------------------------------------------
create or replace function public.rpc_add_order_cost(
  p_order_id uuid,
  p_cost_type text,
  p_description text,
  p_quantity numeric default 1,
  p_unit_cost_cents bigint default 0,
  p_material_id uuid default null,
  p_cost_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_cost public.order_costs%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_order.business_id, array['owner', 'staff']);

  if p_cost_type not in ('material', 'labor', 'overhead', 'other') then
    raise exception 'Unknown cost type' using errcode = 'P0001';
  end if;

  if p_description is null or length(btrim(p_description)) = 0 then
    raise exception 'Describe the cost' using errcode = 'P0001';
  end if;

  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'Quantity must be greater than zero' using errcode = 'P0001';
  end if;

  if coalesce(p_unit_cost_cents, 0) < 0 then
    raise exception 'Cost cannot be negative' using errcode = 'P0001';
  end if;

  insert into public.order_costs (
    business_id, order_id, cost_type, material_id, description,
    quantity, unit_cost, cost_date, created_by
  ) values (
    v_order.business_id,
    v_order.id,
    p_cost_type,
    p_material_id,
    btrim(p_description),
    coalesce(p_quantity, 1),
    public.cents_to_numeric(coalesce(p_unit_cost_cents, 0)),
    coalesce(p_cost_date, current_date),
    auth.uid()
  ) returning * into v_cost;

  perform public.refresh_order_actual_cost(v_order.id);

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (v_order.business_id, auth.uid(), 'order_cost', v_cost.id, 'created', to_jsonb(v_cost));

  return to_jsonb(v_cost);
end;
$$;

create or replace function public.rpc_delete_order_cost(p_cost_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cost public.order_costs%rowtype;
begin
  select * into v_cost from public.order_costs where id = p_cost_id for update;
  if v_cost.id is null then
    raise exception 'Cost entry not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_cost.business_id, array['owner', 'staff']);

  delete from public.order_costs where id = p_cost_id;

  perform public.refresh_order_actual_cost(v_cost.order_id);

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, old_data)
  values (v_cost.business_id, auth.uid(), 'order_cost', v_cost.id, 'deleted', to_jsonb(v_cost));

  return jsonb_build_object('deleted', true, 'order_id', v_cost.order_id);
end;
$$;

-- -----------------------------------------------------------------------------
-- Operating expenses
-- -----------------------------------------------------------------------------
create or replace function public.rpc_record_expense(
  p_business_id uuid,
  p_amount_cents bigint,
  p_description text default null,
  p_category_id uuid default null,
  p_expense_date date default current_date,
  p_method text default 'cash',
  p_reference text default null,
  p_receipt_path text default null,
  p_order_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_expense public.expenses%rowtype;
begin
  perform public.assert_business_role(p_business_id, array['owner', 'accountant']);

  if coalesce(p_amount_cents, 0) <= 0 then
    raise exception 'Enter an amount greater than zero' using errcode = 'P0001';
  end if;

  if p_order_id is not null and not exists (
    select 1 from public.orders o
    where o.id = p_order_id and o.business_id = p_business_id
  ) then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;

  insert into public.expenses (
    business_id, order_id, category_id, amount, description,
    expense_date, method, reference, receipt_path, created_by
  ) values (
    p_business_id,
    p_order_id,
    p_category_id,
    public.cents_to_numeric(p_amount_cents),
    nullif(btrim(coalesce(p_description, '')), ''),
    coalesce(p_expense_date, current_date),
    coalesce(nullif(btrim(coalesce(p_method, '')), ''), 'cash'),
    nullif(btrim(coalesce(p_reference, '')), ''),
    nullif(btrim(coalesce(p_receipt_path, '')), ''),
    auth.uid()
  ) returning * into v_expense;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (p_business_id, auth.uid(), 'expense', v_expense.id, 'created', to_jsonb(v_expense));

  return to_jsonb(v_expense);
end;
$$;

create or replace function public.rpc_delete_expense(p_expense_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_expense public.expenses%rowtype;
begin
  select * into v_expense from public.expenses where id = p_expense_id for update;
  if v_expense.id is null then
    raise exception 'Expense not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_expense.business_id, array['owner']);

  delete from public.expenses where id = p_expense_id;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, old_data)
  values (v_expense.business_id, auth.uid(), 'expense', v_expense.id, 'deleted', to_jsonb(v_expense));

  return jsonb_build_object('deleted', true);
end;
$$;

revoke execute on function public.rpc_record_payment(uuid, bigint, text, text, text, timestamptz, text, text, boolean) from public, anon;
revoke execute on function public.rpc_record_refund(uuid, bigint, text, text) from public, anon;
revoke execute on function public.rpc_void_payment(uuid, text) from public, anon;
revoke execute on function public.rpc_add_order_cost(uuid, text, text, numeric, bigint, uuid, date) from public, anon;
revoke execute on function public.rpc_delete_order_cost(uuid) from public, anon;
revoke execute on function public.rpc_record_expense(uuid, bigint, text, uuid, date, text, text, text, uuid) from public, anon;
revoke execute on function public.rpc_delete_expense(uuid) from public, anon;

grant execute on function public.rpc_record_payment(uuid, bigint, text, text, text, timestamptz, text, text, boolean) to authenticated;
grant execute on function public.rpc_record_refund(uuid, bigint, text, text) to authenticated;
grant execute on function public.rpc_void_payment(uuid, text) to authenticated;
grant execute on function public.rpc_add_order_cost(uuid, text, text, numeric, bigint, uuid, date) to authenticated;
grant execute on function public.rpc_delete_order_cost(uuid) to authenticated;
grant execute on function public.rpc_record_expense(uuid, bigint, text, uuid, date, text, text, text, uuid) to authenticated;
grant execute on function public.rpc_delete_expense(uuid) to authenticated;
