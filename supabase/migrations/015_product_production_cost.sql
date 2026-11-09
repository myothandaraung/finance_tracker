-- =============================================================================
-- 015_product_production_cost.sql
-- Per-unit production cost on products, with audit history, and reporting that
-- falls back to the product production cost when an order has no cost entries.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. products.production_cost
-- -----------------------------------------------------------------------------
alter table public.products
  add column if not exists production_cost numeric(15,2) not null default 0 check (production_cost >= 0),
  add column if not exists production_cost_cents bigint generated always as (round(production_cost * 100)::bigint) stored;

-- -----------------------------------------------------------------------------
-- 2. product_production_cost_history
-- -----------------------------------------------------------------------------
create table if not exists public.product_production_cost_history (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  old_cost numeric(15,2) not null default 0,
  new_cost numeric(15,2) not null default 0,
  effective_at timestamptz not null default now(),
  changed_by uuid references auth.users (id) on delete set null,
  note text
);

create index if not exists product_production_cost_history_product_id_idx
  on public.product_production_cost_history (product_id, effective_at desc);

drop trigger if exists trg_product_production_cost_history_audit on public.product_production_cost_history;
create trigger trg_product_production_cost_history_audit
  after update or delete on public.product_production_cost_history
  for each row execute function public.log_audit_event();

-- -----------------------------------------------------------------------------
-- 3. rpc_save_product now accepts p_production_cost and records history.
-- -----------------------------------------------------------------------------
create or replace function public.rpc_save_product(
  p_business_id uuid,
  p_product_id uuid default null,
  p_name text default null,
  p_description text default null,
  p_base_price_cents bigint default 0,
  p_unit text default null,
  p_image_path text default null,
  p_is_active boolean default true,
  p_production_cost_cents bigint default 0,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.products%rowtype;
  v_old_cost numeric;
  v_new_cost numeric;
begin
  perform public.assert_business_role(p_business_id, array['owner', 'staff']);

  if p_name is null or length(btrim(p_name)) = 0 then
    raise exception 'Product name is required' using errcode = 'P0001';
  end if;

  if coalesce(p_base_price_cents, 0) < 0 then
    raise exception 'Price cannot be negative' using errcode = 'P0001';
  end if;

  if coalesce(p_production_cost_cents, 0) < 0 then
    raise exception 'Production cost cannot be negative' using errcode = 'P0001';
  end if;

  if p_product_id is null then
    v_new_cost := public.cents_to_numeric(coalesce(p_production_cost_cents, 0));

    insert into public.products (
      business_id, name, description, base_price, production_cost, unit, image_path, is_active
    ) values (
      p_business_id,
      btrim(p_name),
      nullif(btrim(coalesce(p_description, '')), ''),
      public.cents_to_numeric(coalesce(p_base_price_cents, 0)),
      v_new_cost,
      nullif(btrim(coalesce(p_unit, '')), ''),
      nullif(btrim(coalesce(p_image_path, '')), ''),
      coalesce(p_is_active, true)
    ) returning * into v_row;
  else
    select * into v_row from public.products
     where id = p_product_id and business_id = p_business_id
     for update;

    if v_row.id is null then
      raise exception 'Product not found' using errcode = 'P0002';
    end if;

    v_old_cost := v_row.production_cost;
    v_new_cost := public.cents_to_numeric(coalesce(p_production_cost_cents, v_row.production_cost * 100));

    update public.products
       set name = btrim(p_name),
           description = nullif(btrim(coalesce(p_description, '')), ''),
           base_price = public.cents_to_numeric(coalesce(p_base_price_cents, 0)),
           production_cost = v_new_cost,
           unit = nullif(btrim(coalesce(p_unit, '')), ''),
           image_path = coalesce(p_image_path, image_path),
           is_active = coalesce(p_is_active, true),
           updated_at = now()
     where id = p_product_id
       and business_id = p_business_id
     returning * into v_row;

    if v_old_cost is distinct from v_new_cost then
      insert into public.product_production_cost_history (
        business_id, product_id, old_cost, new_cost, changed_by, note
      ) values (
        p_business_id,
        p_product_id,
        coalesce(v_old_cost, 0),
        v_new_cost,
        auth.uid(),
        nullif(btrim(coalesce(p_note, '')), '')
      );
    end if;
  end if;

  return to_jsonb(v_row);
end;
$$;

revoke execute on function public.rpc_save_product(uuid, uuid, text, text, bigint, text, text, boolean) from public, anon;
revoke execute on function public.rpc_save_product(uuid, uuid, text, text, bigint, text, text, boolean, bigint, text) from public, anon;

grant execute on function public.rpc_save_product(uuid, uuid, text, text, bigint, text, text, boolean, bigint, text) to authenticated;