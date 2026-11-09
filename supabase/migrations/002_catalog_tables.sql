-- =============================================================================
-- 002_catalog_tables.sql
-- Catalogs: customers, products, materials, expense categories, payment methods.
-- =============================================================================

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  phone text,
  email text,
  address text,
  notes text,
  assigned_to uuid references auth.users (id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists customers_business_id_idx on public.customers (business_id);
create index if not exists customers_business_name_idx on public.customers (business_id, name);
create index if not exists customers_assigned_to_idx on public.customers (business_id, assigned_to);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  description text,
  base_price numeric(15,2) not null default 0 check (base_price >= 0),
  base_price_cents bigint generated always as (round(base_price * 100)::bigint) stored,
  production_cost numeric(15,2) not null default 0 check (production_cost >= 0),
  production_cost_cents bigint generated always as (round(production_cost * 100)::bigint) stored,
  unit text,
  image_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists products_business_id_idx on public.products (business_id);

create table if not exists public.materials (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  unit text,
  default_unit_cost numeric(15,2) not null default 0 check (default_unit_cost >= 0),
  default_unit_cost_cents bigint generated always as (round(default_unit_cost * 100)::bigint) stored,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists materials_business_id_idx on public.materials (business_id);

create table if not exists public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  type text not null default 'operating' check (type in ('operating', 'payroll', 'utilities', 'marketing', 'other')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expense_categories_business_name_unique unique (business_id, name)
);

create index if not exists expense_categories_business_id_idx on public.expense_categories (business_id);

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payment_methods_business_name_unique unique (business_id, name)
);

create index if not exists payment_methods_business_id_idx on public.payment_methods (business_id);

drop trigger if exists trg_customers_updated_at on public.customers;
create trigger trg_customers_updated_at
  before update on public.customers
  for each row execute function public.set_updated_at();

drop trigger if exists trg_products_updated_at on public.products;
create trigger trg_products_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

drop trigger if exists trg_materials_updated_at on public.materials;
create trigger trg_materials_updated_at
  before update on public.materials
  for each row execute function public.set_updated_at();

drop trigger if exists trg_expense_categories_updated_at on public.expense_categories;
create trigger trg_expense_categories_updated_at
  before update on public.expense_categories
  for each row execute function public.set_updated_at();

drop trigger if exists trg_payment_methods_updated_at on public.payment_methods;
create trigger trg_payment_methods_updated_at
  before update on public.payment_methods
  for each row execute function public.set_updated_at();
