-- =============================================================================
-- 006_rls_policies.sql
-- Row Level Security for every exposed table.
--
-- Reads are granted to active members of the owning business. Writes are NOT
-- granted here: every mutation goes through a SECURITY DEFINER RPC in
-- 007..011 which performs its own membership and role checks. That keeps a
-- single audited write path and removes the risk of a client sending its own
-- totals.
--
-- Membership checks use the SECURITY DEFINER helpers from 001, otherwise the
-- policies on business_members would recurse.
-- =============================================================================

revoke all on all tables in schema public from anon;
grant select on all tables in schema public to authenticated;

-- -----------------------------------------------------------------------------
-- Tenancy
-- -----------------------------------------------------------------------------
alter table public.businesses enable row level security;
alter table public.profiles enable row level security;
alter table public.business_members enable row level security;
alter table public.business_counters enable row level security;
alter table public.audit_events enable row level security;

drop policy if exists "Members can read their businesses" on public.businesses;
create policy "Members can read their businesses" on public.businesses
  for select
  using (public.is_business_member(id));

drop policy if exists "Members can read shared profiles" on public.profiles;
create policy "Members can read shared profiles" on public.profiles
  for select
  using (id = auth.uid() or public.shares_business_with(id));

drop policy if exists "Members can read their business members" on public.business_members;
create policy "Members can read their business members" on public.business_members
  for select
  using (public.is_business_member(business_id));

-- business_counters and audit_events have no read policy on purpose:
-- counters are only read through rpc_next_document_no, audit events are read
-- by the owner through rpc_audit_events.

drop policy if exists "Owners can read audit events" on public.audit_events;
create policy "Owners can read audit events" on public.audit_events
  for select
  using (
    public.is_business_member(business_id)
    and public.has_business_role(business_id, array['owner', 'accountant'])
  );

-- -----------------------------------------------------------------------------
-- Catalogs
-- -----------------------------------------------------------------------------
alter table public.customers enable row level security;
alter table public.products enable row level security;
alter table public.materials enable row level security;
alter table public.expense_categories enable row level security;
alter table public.payment_methods enable row level security;

drop policy if exists "Members can read customers" on public.customers;
create policy "Members can read customers" on public.customers
  for select
  using (public.is_business_member(business_id));

drop policy if exists "Members can read products" on public.products;
create policy "Members can read products" on public.products
  for select
  using (public.is_business_member(business_id));

drop policy if exists "Members can read materials" on public.materials;
create policy "Members can read materials" on public.materials
  for select
  using (public.is_business_member(business_id));

drop policy if exists "Members can read expense categories" on public.expense_categories;
create policy "Members can read expense categories" on public.expense_categories
  for select
  using (public.is_business_member(business_id));

drop policy if exists "Members can read payment methods" on public.payment_methods;
create policy "Members can read payment methods" on public.payment_methods
  for select
  using (public.is_business_member(business_id));

-- -----------------------------------------------------------------------------
-- Quotations
-- -----------------------------------------------------------------------------
alter table public.quotations enable row level security;
alter table public.quotation_items enable row level security;

drop policy if exists "Members can read quotations" on public.quotations;
create policy "Members can read quotations" on public.quotations
  for select
  using (public.is_business_member(business_id));

drop policy if exists "Members can read quotation items" on public.quotation_items;
create policy "Members can read quotation items" on public.quotation_items
  for select
  using (
    exists (
      select 1 from public.quotations q
      where q.id = quotation_items.quotation_id
        and public.is_business_member(q.business_id)
    )
  );

-- -----------------------------------------------------------------------------
-- Orders
-- -----------------------------------------------------------------------------
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;

drop policy if exists "Members can read orders" on public.orders;
create policy "Members can read orders" on public.orders
  for select
  using (public.is_business_member(business_id));

drop policy if exists "Members can read order items" on public.order_items;
create policy "Members can read order items" on public.order_items
  for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and public.is_business_member(o.business_id)
    )
  );

drop policy if exists "Members can read order status history" on public.order_status_history;
create policy "Members can read order status history" on public.order_status_history
  for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_status_history.order_id
        and public.is_business_member(o.business_id)
    )
  );

-- -----------------------------------------------------------------------------
-- Money
-- -----------------------------------------------------------------------------
alter table public.payments enable row level security;
alter table public.refunds enable row level security;
alter table public.order_costs enable row level security;
alter table public.expenses enable row level security;

drop policy if exists "Members can read payments" on public.payments;
create policy "Members can read payments" on public.payments
  for select
  using (public.is_business_member(business_id));

drop policy if exists "Members can read refunds" on public.refunds;
create policy "Members can read refunds" on public.refunds
  for select
  using (public.is_business_member(business_id));

drop policy if exists "Members can read order costs" on public.order_costs;
create policy "Members can read order costs" on public.order_costs
  for select
  using (public.is_business_member(business_id));

drop policy if exists "Members can read expenses" on public.expenses;
create policy "Members can read expenses" on public.expenses
  for select
  using (public.is_business_member(business_id));
