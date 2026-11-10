-- =============================================================================
-- 003_sales_tables.sql
-- Quotations and orders.
--
-- Totals are protected by construction:
--   line_total  = generated from quantity * unit_price
--   net_sales   = generated from subtotal - discount_amount
--   total_amount= generated from net_sales   (same as net_sales)
-- so the only values the server has to write are subtotal, discount_amount.
-- =============================================================================

create table if not exists public.quotations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete restrict,
  quotation_no text not null,
  status text not null default 'draft' check (status in ('draft', 'sent', 'accepted', 'rejected', 'expired', 'converted', 'cancelled')),
  valid_until date,
  notes text,
  subtotal numeric(15,2) not null default 0,
  discount_type text not null default 'none' check (discount_type in ('none', 'percent', 'amount')),
  discount_value numeric(15,2) not null default 0 check (discount_value >= 0),
  discount_amount numeric(15,2) not null default 0,
  total_amount numeric(15,2) generated always as (subtotal - discount_amount) stored,
  net_sales numeric(15,2) generated always as (subtotal - discount_amount) stored,
  estimated_cost numeric(15,2) not null default 0,
  assigned_to uuid references auth.users (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  converted_order_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quotations_business_no_unique unique (business_id, quotation_no)
);

create index if not exists quotations_business_id_idx on public.quotations (business_id);
create index if not exists quotations_business_status_idx on public.quotations (business_id, status);
create index if not exists quotations_customer_id_idx on public.quotations (customer_id);

create table if not exists public.quotation_items (
  id uuid primary key default gen_random_uuid(),
  quotation_id uuid not null references public.quotations (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  description text not null check (length(btrim(description)) > 0),
  quantity numeric(12,3) not null default 1 check (quantity > 0),
  unit_price numeric(15,2) not null default 0 check (unit_price >= 0),
  unit_price_cents bigint generated always as (round(unit_price * 100)::bigint) stored,
  estimated_cost numeric(15,2) not null default 0 check (estimated_cost >= 0),
  line_total numeric(15,2) generated always as (round(quantity * unit_price, 2)) stored,
  line_total_cents bigint generated always as (round(quantity * unit_price * 100)::bigint) stored,
  position int not null default 0
);

create index if not exists quotation_items_quotation_id_idx on public.quotation_items (quotation_id);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete restrict,
  quotation_id uuid references public.quotations (id) on delete set null,
  order_no text not null,
  status text not null default 'draft' check (status in ('draft', 'confirmed', 'in_progress', 'on_hold', 'completed', 'delivered', 'closed', 'cancelled')),
  subtotal numeric(15,2) not null default 0,
  discount_type text not null default 'none' check (discount_type in ('none', 'percent', 'amount')),
  discount_value numeric(15,2) not null default 0 check (discount_value >= 0),
  discount_amount numeric(15,2) not null default 0,
  total_amount numeric(15,2) generated always as (subtotal - discount_amount) stored,
  net_sales numeric(15,2) generated always as (subtotal - discount_amount) stored,
  estimated_cost numeric(15,2) not null default 0,
  actual_cost numeric(15,2) not null default 0,
  notes text,
  due_date date,
  confirmed_at timestamptz,
  delivered_at timestamptz,
  closed_at timestamptz,
  cancelled_at timestamptz,
  assigned_to uuid references auth.users (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint orders_business_no_unique unique (business_id, order_no)
);

create index if not exists orders_business_id_idx on public.orders (business_id);
create index if not exists orders_business_status_idx on public.orders (business_id, status);
create index if not exists orders_business_delivered_idx on public.orders (business_id, delivered_at);
create index if not exists orders_business_assigned_idx on public.orders (business_id, assigned_to);
create index if not exists orders_customer_id_idx on public.orders (customer_id);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  description text not null check (length(btrim(description)) > 0),
  quantity numeric(12,3) not null default 1 check (quantity > 0),
  unit_price numeric(15,2) not null default 0 check (unit_price >= 0),
  unit_price_cents bigint generated always as (round(unit_price * 100)::bigint) stored,
  estimated_cost numeric(15,2) not null default 0 check (estimated_cost >= 0),
  estimated_cost_cents bigint generated always as (round(estimated_cost * 100)::bigint) stored,
  line_total numeric(15,2) generated always as (round(quantity * unit_price, 2)) stored,
  line_total_cents bigint generated always as (round(quantity * unit_price * 100)::bigint) stored,
  position int not null default 0
);

create index if not exists order_items_order_id_idx on public.order_items (order_id);

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  from_status text,
  to_status text not null,
  note text,
  changed_by uuid references auth.users (id) on delete set null,
  changed_at timestamptz not null default now()
);

create index if not exists order_status_history_order_id_idx on public.order_status_history (order_id, changed_at desc);

-- Centavos mirrors for the money columns the app reads directly.
alter table public.quotations
  add column if not exists subtotal_cents bigint generated always as (round(subtotal * 100)::bigint) stored,
  add column if not exists discount_amount_cents bigint generated always as (round(discount_amount * 100)::bigint) stored,
  add column if not exists total_amount_cents bigint generated always as (round((subtotal - discount_amount) * 100)::bigint) stored,
  add column if not exists net_sales_cents bigint generated always as (round((subtotal - discount_amount) * 100)::bigint) stored,
  add column if not exists estimated_cost_cents bigint generated always as (round(estimated_cost * 100)::bigint) stored;

alter table public.orders
  add column if not exists subtotal_cents bigint generated always as (round(subtotal * 100)::bigint) stored,
  add column if not exists discount_amount_cents bigint generated always as (round(discount_amount * 100)::bigint) stored,
  add column if not exists total_amount_cents bigint generated always as (round((subtotal - discount_amount) * 100)::bigint) stored,
  add column if not exists net_sales_cents bigint generated always as (round((subtotal - discount_amount) * 100)::bigint) stored,
  add column if not exists estimated_cost_cents bigint generated always as (round(estimated_cost * 100)::bigint) stored,
  add column if not exists actual_cost_cents bigint generated always as (round(actual_cost * 100)::bigint) stored;

-- Centavos mirror for the estimated cost of a quotation line.
alter table public.quotation_items
  add column if not exists estimated_cost_cents bigint generated always as (round(estimated_cost * 100)::bigint) stored;

drop trigger if exists trg_quotations_updated_at on public.quotations;
create trigger trg_quotations_updated_at
  before update on public.quotations
  for each row execute function public.set_updated_at();

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at
  before update on public.orders
  for each row execute function public.set_updated_at();
