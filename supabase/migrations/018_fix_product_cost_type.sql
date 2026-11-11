-- Fix product edits failing with:
-- function public.cents_to_numeric(numeric) does not exist (42883).
--
-- Mixing the bigint RPC parameter with the numeric database column inside
-- coalesce promoted the result to numeric. Cast the fallback back to cents.

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
    v_new_cost := public.cents_to_numeric(
      coalesce(p_production_cost_cents, 0)
    );

    insert into public.products (
      business_id, name, description, base_price, production_cost, unit,
      image_path, is_active
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
    select * into v_row
      from public.products
     where id = p_product_id
       and business_id = p_business_id
     for update;

    if v_row.id is null then
      raise exception 'Product not found' using errcode = 'P0002';
    end if;

    v_old_cost := v_row.production_cost;
    v_new_cost := public.cents_to_numeric(
      coalesce(
        p_production_cost_cents,
        round(v_row.production_cost * 100)::bigint
      )
    );

    update public.products
       set name = btrim(p_name),
           description = nullif(btrim(coalesce(p_description, '')), ''),
           base_price = public.cents_to_numeric(
             coalesce(p_base_price_cents, 0)
           ),
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

revoke execute on function public.rpc_save_product(
  uuid, uuid, text, text, bigint, text, text, boolean, bigint, text
) from public, anon;

grant execute on function public.rpc_save_product(
  uuid, uuid, text, text, bigint, text, text, boolean, bigint, text
) to authenticated;
