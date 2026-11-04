-- =============================================================================
-- 004_money_tables.sql
-- Money events: payments, refunds, production costs and operating expenses.
--
--   order_costs  : costs that belong to one order (materials, labour,
--                   overhead). Always linked to an order.
--   expenses     : general operating expenses. order_id is nullable; when it
--                   is set the expense is attached to an order for reference
--                   but is NOT part of the order production cost, so nothing
--                   is ever counted twice.
-- =============================================================================

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  order_id uuid not null references public.orders (id) on delete cascade,
  customer_id uuid references public.customers (id) on delete set null,
  kind text not null default 'installment' check (kind in ('deposit', 'installment', 'final', 'adjustment')),
  amount numeric(15,2) not null check (amount > 0),
  amount_cents bigint generated always as (round(amount * 100)::bigint) stored,
  method text not null default 'cash',
  reference text,
  receipt_path text,
  paid_at timestamptz not null default now(),
  status text not null default 'successful' check (status in ('successful', 'pending', 'failed', 'void')),
  idempotency_key text not null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payments_business_idempotency_unique unique (business_id, idempotency_key)
);

create index if not exists payments_order_id_idx on public.payments (order_id);
create index if not exists payments_business_paid_at_idx on public.payments (business_id, paid_at);
create index if not exists payments_business_status_idx on public.payments (business_id, status);

create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  order_id uuid not null references public.orders (id) on delete cascade,
  payment_id uuid references public.payments (id) on delete set null,
  amount numeric(15,2) not null check (amount > 0),
  amount_cents bigint generated always as (round(amount * 100)::bigint) stored,
  method text not null default 'cash',
  reason text,
  refunded_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists refunds_order_id_idx on public.refunds (order_id);
create index if not exists refunds_payment_id_idx on public.refunds (payment_id);
create index if not exists refunds_business_refunded_at_idx on public.refunds (business_id, refunded_at);

create table if not exists public.order_costs (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  order_id uuid not null references public.orders (id) on delete cascade,
  cost_type text not null check (cost_type in ('material', 'labor', 'overhead', 'other')),
  material_id uuid references public.materials (id) on delete set null,
  description text not null check (length(btrim(description)) > 0),
  quantity numeric(12,3) not null default 1 check (quantity > 0),
  unit_cost numeric(15,2) not null default 0 check (unit_cost >= 0),
  unit_cost_cents bigint generated always as (round(unit_cost * 100)::bigint) stored,
  amount numeric(15,2) generated always as (round(quantity * unit_cost, 2)) stored,
  amount_cents bigint generated always as (round(quantity * unit_cost * 100)::bigint) stored,
  cost_date date not null default current_date,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists order_costs_order_id_idx on public.order_costs (order_id);
create index if not exists order_costs_business_id_idx on public.order_costs (business_id);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  order_id uuid references public.orders (id) on delete set null,
  category_id uuid references public.expense_categories (id) on delete set null,
  amount numeric(15,2) not null check (amount > 0),
  amount_cents bigint generated always as (round(amount * 100)::bigint) stored,
  description text,
  expense_date date not null default current_date,
  method text not null default 'cash',
  reference text,
  receipt_path text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists expenses_business_date_idx on public.expenses (business_id, expense_date);
create index if not exists expenses_category_id_idx on public.expenses (category_id);
create index if not exists expenses_order_id_idx on public.expenses (order_id);

drop trigger if exists trg_payments_updated_at on public.payments;
create trigger trg_payments_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

drop trigger if exists trg_order_costs_updated_at on public.order_costs;
create trigger trg_order_costs_updated_at
  before update on public.order_costs
  for each row execute function public.set_updated_at();
