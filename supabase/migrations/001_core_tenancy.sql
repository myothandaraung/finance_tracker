-- =============================================================================
-- 001_core_tenancy.sql
-- Tenancy, identity and shared helpers for MTO Finance.
--
-- Design rules used across every migration:
--   * every business scoped table carries business_id + an index on it
--   * money is stored as numeric(15,2) and mirrored by a generated
--     *_cents bigint column so the API never has to ship a float
--   * membership checks go through SECURITY DEFINER helper functions to
--     avoid infinite recursion inside RLS policies
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- updated_at maintenance
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Core tables
-- -----------------------------------------------------------------------------
create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) > 0),
  currency_code char(3) not null default 'PHP',
  overhead_rate numeric(7,4) not null default 0 check (overhead_rate >= 0 and overhead_rate <= 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  display_name text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A member row is created as an invitation (user_id is null) and is linked
-- to the auth user by the on_auth_user_created trigger.
create table if not exists public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  user_id uuid references auth.users (id) on delete cascade,
  email text not null,
  role text not null check (role in ('owner', 'staff', 'accountant')),
  status text not null default 'invited' check (status in ('invited', 'active', 'inactive')),
  invited_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_members_email_unique unique (business_id, email)
);

create unique index if not exists business_members_business_user_unique
  on public.business_members (business_id, user_id)
  where user_id is not null;

create index if not exists business_members_user_id_idx
  on public.business_members (user_id);
create index if not exists business_members_business_id_idx
  on public.business_members (business_id);

-- Gapless per business document counters (ORD-2026-0001, QUO-2026-0001).
create table if not exists public.business_counters (
  business_id uuid not null references public.businesses (id) on delete cascade,
  kind text not null check (kind in ('order', 'quotation')),
  next_value bigint not null default 1,
  primary key (business_id, kind)
);

-- Append only audit trail for financial and lifecycle changes.
create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses (id) on delete cascade,
  actor_id uuid references auth.users (id) on delete set null,
  entity text not null,
  entity_id uuid,
  action text not null,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_events_business_id_idx on public.audit_events (business_id);
create index if not exists audit_events_entity_idx on public.audit_events (entity, entity_id);
create index if not exists audit_events_created_at_idx on public.audit_events (created_at desc);

drop trigger if exists trg_businesses_updated_at on public.businesses;
create trigger trg_businesses_updated_at
  before update on public.businesses
  for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_business_members_updated_at on public.business_members;
create trigger trg_business_members_updated_at
  before update on public.business_members
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Membership helpers (SECURITY DEFINER so RLS on business_members never
-- recurses into the policies that call them)
-- -----------------------------------------------------------------------------
create or replace function public.is_business_member(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.business_members bm
    where bm.business_id = p_business_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
  );
$$;

create or replace function public.member_role(p_business_id uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select bm.role
  from public.business_members bm
  where bm.business_id = p_business_id
    and bm.user_id = auth.uid()
    and bm.status = 'active'
  limit 1;
$$;

create or replace function public.has_business_role(p_business_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.member_role(p_business_id) = any (p_roles), false);
$$;

-- True when the caller and the given user share at least one business.
create or replace function public.shares_business_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.business_members a
    join public.business_members b on b.business_id = a.business_id
    where a.user_id = auth.uid()
      and a.status = 'active'
      and b.user_id = p_user_id
      and b.status = 'active'
  );
$$;

-- -----------------------------------------------------------------------------
-- Money helpers
-- -----------------------------------------------------------------------------
create or replace function public.cents_to_numeric(p_cents bigint)
returns numeric
language sql
immutable
as $$
  select p_cents::numeric / 100;
$$;

create or replace function public.numeric_to_cents(p_value numeric)
returns bigint
language sql
immutable
as $$
  select round(p_value * 100)::bigint;
$$;
