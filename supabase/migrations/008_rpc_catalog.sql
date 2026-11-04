-- =============================================================================
-- 008_rpc_catalog.sql
-- Catalog writes (customers, products, materials, categories, methods).
--
-- Owner and staff may manage the operational catalogs. Accountant and owner
-- may manage expense categories and payment methods.
-- =============================================================================

create or replace function public.rpc_save_customer(
  p_business_id uuid,
  p_customer_id uuid default null,
  p_name text default null,
  p_phone text default null,
  p_email text default null,
  p_address text default null,
  p_notes text default null,
  p_assigned_to uuid default null,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.customers%rowtype;
begin
  perform public.assert_business_role(p_business_id, array['owner', 'staff']);

  if p_name is null or length(btrim(p_name)) = 0 then
    raise exception 'Customer name is required' using errcode = 'P0001';
  end if;

  if p_customer_id is null then
    insert into public.customers (
      business_id, name, phone, email, address, notes, assigned_to, is_active
    ) values (
      p_business_id,
      btrim(p_name),
      nullif(btrim(coalesce(p_phone, '')), ''),
      nullif(btrim(coalesce(p_email, '')), ''),
      nullif(btrim(coalesce(p_address, '')), ''),
      nullif(btrim(coalesce(p_notes, '')), ''),
      p_assigned_to,
      coalesce(p_is_active, true)
    ) returning * into v_row;
  else
    update public.customers
       set name = btrim(p_name),
           phone = nullif(btrim(coalesce(p_phone, '')), ''),
           email = nullif(btrim(coalesce(p_email, '')), ''),
           address = nullif(btrim(coalesce(p_address, '')), ''),
           notes = nullif(btrim(coalesce(p_notes, '')), ''),
           assigned_to = p_assigned_to,
           is_active = coalesce(p_is_active, true),
           updated_at = now()
     where id = p_customer_id
       and business_id = p_business_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'Customer not found' using errcode = 'P0002';
    end if;
  end if;

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_save_product(
  p_business_id uuid,
  p_product_id uuid default null,
  p_name text default null,
  p_description text default null,
  p_base_price_cents bigint default 0,
  p_unit text default null,
  p_image_path text default null,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.products%rowtype;
begin
  perform public.assert_business_role(p_business_id, array['owner', 'staff']);

  if p_name is null or length(btrim(p_name)) = 0 then
    raise exception 'Product name is required' using errcode = 'P0001';
  end if;

  if coalesce(p_base_price_cents, 0) < 0 then
    raise exception 'Price cannot be negative' using errcode = 'P0001';
  end if;

  if p_product_id is null then
    insert into public.products (
      business_id, name, description, base_price, unit, image_path, is_active
    ) values (
      p_business_id,
      btrim(p_name),
      nullif(btrim(coalesce(p_description, '')), ''),
      public.cents_to_numeric(coalesce(p_base_price_cents, 0)),
      nullif(btrim(coalesce(p_unit, '')), ''),
      nullif(btrim(coalesce(p_image_path, '')), ''),
      coalesce(p_is_active, true)
    ) returning * into v_row;
  else
    update public.products
       set name = btrim(p_name),
           description = nullif(btrim(coalesce(p_description, '')), ''),
           base_price = public.cents_to_numeric(coalesce(p_base_price_cents, 0)),
           unit = nullif(btrim(coalesce(p_unit, '')), ''),
           image_path = coalesce(p_image_path, image_path),
           is_active = coalesce(p_is_active, true),
           updated_at = now()
     where id = p_product_id
       and business_id = p_business_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'Product not found' using errcode = 'P0002';
    end if;
  end if;

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_save_material(
  p_business_id uuid,
  p_material_id uuid default null,
  p_name text default null,
  p_unit text default null,
  p_default_unit_cost_cents bigint default 0,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.materials%rowtype;
begin
  perform public.assert_business_role(p_business_id, array['owner', 'staff']);

  if p_name is null or length(btrim(p_name)) = 0 then
    raise exception 'Material name is required' using errcode = 'P0001';
  end if;

  if p_material_id is null then
    insert into public.materials (business_id, name, unit, default_unit_cost, is_active)
    values (
      p_business_id,
      btrim(p_name),
      nullif(btrim(coalesce(p_unit, '')), ''),
      public.cents_to_numeric(coalesce(p_default_unit_cost_cents, 0)),
      coalesce(p_is_active, true)
    ) returning * into v_row;
  else
    update public.materials
       set name = btrim(p_name),
           unit = nullif(btrim(coalesce(p_unit, '')), ''),
           default_unit_cost = public.cents_to_numeric(coalesce(p_default_unit_cost_cents, 0)),
           is_active = coalesce(p_is_active, true),
           updated_at = now()
     where id = p_material_id
       and business_id = p_business_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'Material not found' using errcode = 'P0002';
    end if;
  end if;

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_save_expense_category(
  p_business_id uuid,
  p_category_id uuid default null,
  p_name text default null,
  p_type text default 'operating',
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.expense_categories%rowtype;
begin
  perform public.assert_business_role(p_business_id, array['owner', 'accountant']);

  if p_name is null or length(btrim(p_name)) = 0 then
    raise exception 'Category name is required' using errcode = 'P0001';
  end if;

  if p_type not in ('operating', 'payroll', 'utilities', 'marketing', 'other') then
    raise exception 'Unknown category type' using errcode = 'P0001';
  end if;

  if p_category_id is null then
    insert into public.expense_categories (business_id, name, type, is_active)
    values (p_business_id, btrim(p_name), p_type, coalesce(p_is_active, true))
    returning * into v_row;
  else
    update public.expense_categories
       set name = btrim(p_name),
           type = p_type,
           is_active = coalesce(p_is_active, true),
           updated_at = now()
     where id = p_category_id
       and business_id = p_business_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'Category not found' using errcode = 'P0002';
    end if;
  end if;

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_save_payment_method(
  p_business_id uuid,
  p_method_id uuid default null,
  p_name text default null,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.payment_methods%rowtype;
begin
  perform public.assert_business_role(p_business_id, array['owner']);

  if p_name is null or length(btrim(p_name)) = 0 then
    raise exception 'Payment method name is required' using errcode = 'P0001';
  end if;

  if p_method_id is null then
    insert into public.payment_methods (business_id, name, is_active)
    values (p_business_id, btrim(p_name), coalesce(p_is_active, true))
    returning * into v_row;
  else
    update public.payment_methods
       set name = btrim(p_name),
           is_active = coalesce(p_is_active, true),
           updated_at = now()
     where id = p_method_id
       and business_id = p_business_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'Payment method not found' using errcode = 'P0002';
    end if;
  end if;

  return to_jsonb(v_row);
end;
$$;

-- Team members with their display name, used by the assignment pickers.
create or replace function public.rpc_business_members(p_business_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', m.id,
        'user_id', m.user_id,
        'email', m.email,
        'role', m.role,
        'status', m.status,
        'display_name', coalesce(p.display_name, m.email)
      ) order by m.role, m.email
    ),
    '[]'::jsonb
  )
  from public.business_members m
  left join public.profiles p on p.id = m.user_id
  where m.business_id = p_business_id
    and m.status <> 'inactive'
    and public.is_business_member(p_business_id);
$$;

revoke execute on function public.rpc_save_customer(uuid, uuid, text, text, text, text, text, uuid, boolean) from public, anon;
revoke execute on function public.rpc_save_product(uuid, uuid, text, text, bigint, text, text, boolean) from public, anon;
revoke execute on function public.rpc_save_material(uuid, uuid, text, text, bigint, boolean) from public, anon;
revoke execute on function public.rpc_save_expense_category(uuid, uuid, text, text, boolean) from public, anon;
revoke execute on function public.rpc_save_payment_method(uuid, uuid, text, boolean) from public, anon;
revoke execute on function public.rpc_business_members(uuid) from public, anon;

grant execute on function public.rpc_save_customer(uuid, uuid, text, text, text, text, text, uuid, boolean) to authenticated;
grant execute on function public.rpc_save_product(uuid, uuid, text, text, bigint, text, text, boolean) to authenticated;
grant execute on function public.rpc_save_material(uuid, uuid, text, text, bigint, boolean) to authenticated;
grant execute on function public.rpc_save_expense_category(uuid, uuid, text, text, boolean) to authenticated;
grant execute on function public.rpc_save_payment_method(uuid, uuid, text, boolean) to authenticated;
grant execute on function public.rpc_business_members(uuid) to authenticated;
