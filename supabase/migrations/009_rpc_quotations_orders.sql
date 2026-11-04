-- =============================================================================
-- 009_rpc_quotations_orders.sql
-- Quotation and order lifecycle. All totals are recomputed server side.
--
-- Money conventions
--   * the database stores numeric(15,2)
--   * the API exchanges integer centavos (*_cents) so no float crosses the
--     wire
--   * discount percentages are percentages (12 = 12%)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Quotation
-- -----------------------------------------------------------------------------
create or replace function public.rpc_save_quotation(
  p_business_id uuid,
  p_quotation_id uuid default null,
  p_customer_id uuid default null,
  p_valid_until date default null,
  p_notes text default null,
  p_discount_type text default 'none',
  p_discount_value numeric default 0,
  p_items jsonb default '[]'::jsonb,
  p_assigned_to uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.quotations%rowtype;
  v_item jsonb;
  v_quantity numeric;
  v_price numeric;
  v_estimated numeric;
  v_line numeric;
  v_subtotal numeric := 0;
  v_estimated_total numeric := 0;
  v_discount_type text := coalesce(p_discount_type, 'none');
  v_discount_value numeric := coalesce(p_discount_value, 0);
  v_discount_amount numeric := 0;
  v_position int := 0;
begin
  perform public.assert_business_role(p_business_id, array['owner', 'staff']);

  if p_customer_id is null then
    raise exception 'Select a customer' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.customers c
    where c.id = p_customer_id and c.business_id = p_business_id
  ) then
    raise exception 'Customer not found' using errcode = 'P0002';
  end if;

  if v_discount_type not in ('none', 'percent', 'amount') then
    raise exception 'Unknown discount type' using errcode = 'P0001';
  end if;

  if v_discount_value < 0 then
    raise exception 'Discount cannot be negative' using errcode = 'P0001';
  end if;

  if v_discount_type = 'percent' and v_discount_value > 100 then
    raise exception 'Discount cannot be more than 100%%' using errcode = 'P0001';
  end if;

  for v_item in select value from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    v_quantity := coalesce((v_item ->> 'quantity')::numeric, 1);
    if v_quantity <= 0 then
      raise exception 'Quantity must be greater than zero' using errcode = 'P0001';
    end if;

    v_price := public.cents_to_numeric(coalesce((v_item ->> 'unit_price_cents')::bigint, 0));
    if v_price < 0 then
      raise exception 'Unit price cannot be negative' using errcode = 'P0001';
    end if;

    v_estimated := public.cents_to_numeric(coalesce((v_item ->> 'estimated_cost_cents')::bigint, 0));

    v_line := round(v_quantity * v_price, 2);
    v_subtotal := v_subtotal + v_line;
    v_estimated_total := v_estimated_total + round(v_quantity * v_estimated, 2);
  end loop;

  if v_discount_type = 'percent' then
    v_discount_amount := round(v_subtotal * v_discount_value / 100, 2);
  elsif v_discount_type = 'amount' then
    v_discount_amount := least(v_discount_value, v_subtotal);
  else
    v_discount_amount := 0;
  end if;

  if p_quotation_id is null then
    insert into public.quotations (
      business_id, customer_id, quotation_no, status, valid_until, notes,
      subtotal, discount_type, discount_value, discount_amount,
      estimated_cost, assigned_to, created_by
    ) values (
      p_business_id,
      p_customer_id,
      public.rpc_next_document_no(p_business_id, 'quotation'),
      'draft',
      p_valid_until,
      nullif(btrim(coalesce(p_notes, '')), ''),
      v_subtotal,
      v_discount_type,
      v_discount_value,
      v_discount_amount,
      v_estimated_total,
      p_assigned_to,
      auth.uid()
    ) returning * into v_row;
  else
    select * into v_row from public.quotations
     where id = p_quotation_id and business_id = p_business_id
     for update;

    if v_row.id is null then
      raise exception 'Quotation not found' using errcode = 'P0002';
    end if;

    if v_row.status not in ('draft', 'sent') then
      raise exception 'This quotation can no longer be edited' using errcode = 'P0001';
    end if;

    update public.quotations
       set customer_id = p_customer_id,
           valid_until = p_valid_until,
           notes = nullif(btrim(coalesce(p_notes, '')), ''),
           subtotal = v_subtotal,
           discount_type = v_discount_type,
           discount_value = v_discount_value,
           discount_amount = v_discount_amount,
           estimated_cost = v_estimated_total,
           assigned_to = p_assigned_to,
           updated_at = now()
     where id = p_quotation_id
     returning * into v_row;
  end if;

  delete from public.quotation_items where quotation_id = v_row.id;

  for v_item in select value from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    v_quantity := coalesce((v_item ->> 'quantity')::numeric, 1);
    v_price := public.cents_to_numeric(coalesce((v_item ->> 'unit_price_cents')::bigint, 0));
    v_estimated := public.cents_to_numeric(coalesce((v_item ->> 'estimated_cost_cents')::bigint, 0));

    insert into public.quotation_items (
      quotation_id, product_id, description, quantity, unit_price, estimated_cost, position
    ) values (
      v_row.id,
      nullif(v_item ->> 'product_id', '')::uuid,
      coalesce(nullif(btrim(coalesce(v_item ->> 'description', '')), ''), 'Item'),
      v_quantity,
      v_price,
      v_estimated,
      coalesce((v_item ->> 'position')::int, v_position)
    );

    v_position := v_position + 1;
  end loop;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (p_business_id, auth.uid(), 'quotation', v_row.id, 'saved', to_jsonb(v_row));

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_set_quotation_status(
  p_quotation_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.quotations%rowtype;
  v_old_status text;
  v_allowed boolean;
begin
  select * into v_row from public.quotations
   where id = p_quotation_id
   for update;

  if v_row.id is null then
    raise exception 'Quotation not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_row.business_id, array['owner', 'staff']);

  if p_status = 'converted' then
    raise exception 'Use rpc_convert_quotation_to_order to convert a quotation' using errcode = 'P0001';
  end if;

  v_allowed := case v_row.status
    when 'draft' then p_status in ('sent', 'cancelled')
    when 'sent' then p_status in ('accepted', 'rejected', 'expired')
    else false
  end;

  if not v_allowed then
    raise exception 'Cannot change a % quotation to %', v_row.status, p_status using errcode = 'P0001';
  end if;

  v_old_status := v_row.status;

  update public.quotations
     set status = p_status,
         updated_at = now()
   where id = p_quotation_id
   returning * into v_row;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, old_data, new_data)
  values (
    v_row.business_id, auth.uid(), 'quotation', v_row.id, 'status_changed',
    jsonb_build_object('status', v_old_status), jsonb_build_object('status', p_status)
  );

  return to_jsonb(v_row);
end;
$$;

-- Accepts a quotation and turns it into a confirmed order in one transaction.
create or replace function public.rpc_convert_quotation_to_order(
  p_quotation_id uuid,
  p_due_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_quote public.quotations%rowtype;
  v_order public.orders%rowtype;
begin
  select * into v_quote from public.quotations
   where id = p_quotation_id
   for update;

  if v_quote.id is null then
    raise exception 'Quotation not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_quote.business_id, array['owner', 'staff']);

  if v_quote.status <> 'accepted' then
    raise exception 'Accept the quotation before converting it' using errcode = 'P0001';
  end if;

  if v_quote.converted_order_id is not null then
    select * into v_order from public.orders where id = v_quote.converted_order_id;
    return to_jsonb(v_order);
  end if;

  insert into public.orders (
    business_id, customer_id, quotation_id, order_no, status,
    subtotal, discount_type, discount_value, discount_amount,
    estimated_cost, notes, due_date,
    confirmed_at, assigned_to, created_by
  ) values (
    v_quote.business_id,
    v_quote.customer_id,
    v_quote.id,
    public.rpc_next_document_no(v_quote.business_id, 'order'),
    'confirmed',
    v_quote.subtotal,
    v_quote.discount_type,
    v_quote.discount_value,
    v_quote.discount_amount,
    v_quote.estimated_cost,
    v_quote.notes,
    p_due_date,
    now(),
    v_quote.assigned_to,
    auth.uid()
  ) returning * into v_order;

  insert into public.order_items (order_id, product_id, description, quantity, unit_price, position)
  select
    v_order.id, qi.product_id, qi.description, qi.quantity, qi.unit_price, qi.position
  from public.quotation_items qi
  where qi.quotation_id = v_quote.id;

  insert into public.order_status_history (order_id, from_status, to_status, note, changed_by)
  values (v_order.id, null, 'confirmed', 'Converted from quotation ' || v_quote.quotation_no, auth.uid());

  update public.quotations
     set status = 'converted',
         converted_order_id = v_order.id,
         updated_at = now()
   where id = v_quote.id;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (v_quote.business_id, auth.uid(), 'order', v_order.id, 'created_from_quotation', to_jsonb(v_order));

  return to_jsonb(v_order);
end;
$$;

-- -----------------------------------------------------------------------------
-- Order
-- -----------------------------------------------------------------------------
create or replace function public.rpc_save_order(
  p_business_id uuid,
  p_order_id uuid default null,
  p_customer_id uuid default null,
  p_due_date date default null,
  p_notes text default null,
  p_discount_type text default 'none',
  p_discount_value numeric default 0,
  p_items jsonb default '[]'::jsonb,
  p_assigned_to uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.orders%rowtype;
  v_item jsonb;
  v_quantity numeric;
  v_price numeric;
  v_estimated numeric;
  v_line numeric;
  v_subtotal numeric := 0;
  v_estimated_total numeric := 0;
  v_discount_type text := coalesce(p_discount_type, 'none');
  v_discount_value numeric := coalesce(p_discount_value, 0);
  v_discount_amount numeric := 0;
  v_position int := 0;
begin
  perform public.assert_business_role(p_business_id, array['owner', 'staff']);

  if p_customer_id is null then
    raise exception 'Select a customer' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.customers c
    where c.id = p_customer_id and c.business_id = p_business_id
  ) then
    raise exception 'Customer not found' using errcode = 'P0002';
  end if;

  if v_discount_type not in ('none', 'percent', 'amount') then
    raise exception 'Unknown discount type' using errcode = 'P0001';
  end if;

  if v_discount_value < 0 then
    raise exception 'Discount cannot be negative' using errcode = 'P0001';
  end if;

  if v_discount_type = 'percent' and v_discount_value > 100 then
    raise exception 'Discount cannot be more than 100%%' using errcode = 'P0001';
  end if;

  for v_item in select value from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    v_quantity := coalesce((v_item ->> 'quantity')::numeric, 1);
    if v_quantity <= 0 then
      raise exception 'Quantity must be greater than zero' using errcode = 'P0001';
    end if;

    v_price := public.cents_to_numeric(coalesce((v_item ->> 'unit_price_cents')::bigint, 0));
    if v_price < 0 then
      raise exception 'Unit price cannot be negative' using errcode = 'P0001';
    end if;

    v_estimated := public.cents_to_numeric(coalesce((v_item ->> 'estimated_cost_cents')::bigint, 0));

    v_line := round(v_quantity * v_price, 2);
    v_subtotal := v_subtotal + v_line;
    v_estimated_total := v_estimated_total + round(v_quantity * v_estimated, 2);
  end loop;

  if v_discount_type = 'percent' then
    v_discount_amount := round(v_subtotal * v_discount_value / 100, 2);
  elsif v_discount_type = 'amount' then
    v_discount_amount := least(v_discount_value, v_subtotal);
  else
    v_discount_amount := 0;
  end if;

  if p_order_id is null then
    insert into public.orders (
      business_id, customer_id, order_no, status,
      subtotal, discount_type, discount_value, discount_amount,
      estimated_cost, notes, due_date, assigned_to, created_by
    ) values (
      p_business_id,
      p_customer_id,
      public.rpc_next_document_no(p_business_id, 'order'),
      'draft',
      v_subtotal,
      v_discount_type,
      v_discount_value,
      v_discount_amount,
      v_estimated_total,
      nullif(btrim(coalesce(p_notes, '')), ''),
      p_due_date,
      p_assigned_to,
      auth.uid()
    ) returning * into v_row;
  else
    select * into v_row from public.orders
     where id = p_order_id and business_id = p_business_id
     for update;

    if v_row.id is null then
      raise exception 'Order not found' using errcode = 'P0002';
    end if;

    if v_row.status not in ('draft', 'confirmed', 'on_hold') then
      raise exception 'Items cannot be edited once production has started' using errcode = 'P0001';
    end if;

    update public.orders
       set customer_id = p_customer_id,
           subtotal = v_subtotal,
           discount_type = v_discount_type,
           discount_value = v_discount_value,
           discount_amount = v_discount_amount,
           estimated_cost = v_estimated_total,
           notes = nullif(btrim(coalesce(p_notes, '')), ''),
           due_date = p_due_date,
           assigned_to = p_assigned_to,
           updated_at = now()
     where id = p_order_id
     returning * into v_row;
  end if;

  delete from public.order_items where order_id = v_row.id;

  for v_item in select value from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    v_quantity := coalesce((v_item ->> 'quantity')::numeric, 1);
    v_price := public.cents_to_numeric(coalesce((v_item ->> 'unit_price_cents')::bigint, 0));
    v_estimated := public.cents_to_numeric(coalesce((v_item ->> 'estimated_cost_cents')::bigint, 0));

    insert into public.order_items (
      order_id, product_id, description, quantity, unit_price, position
    ) values (
      v_row.id,
      nullif(v_item ->> 'product_id', '')::uuid,
      coalesce(nullif(btrim(coalesce(v_item ->> 'description', '')), ''), 'Item'),
      v_quantity,
      v_price,
      coalesce((v_item ->> 'position')::int, v_position)
    );

    v_position := v_position + 1;
  end loop;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (p_business_id, auth.uid(), 'order', v_row.id, 'saved', to_jsonb(v_row));

  return to_jsonb(v_row);
end;
$$;

-- Central status transition gate.
create or replace function public.rpc_update_order_status(
  p_order_id uuid,
  p_to_status text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.orders%rowtype;
  v_old_status text;
  v_allowed boolean;
  v_uncollected numeric;
  v_roles text[];
begin
  select * into v_row from public.orders
   where id = p_order_id
   for update;

  if v_row.id is null then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;

  v_roles := array['owner', 'staff'];
  if p_to_status = 'cancelled' then
    v_roles := array['owner'];
  end if;

  perform public.assert_business_role(v_row.business_id, v_roles);

  if p_to_status not in ('draft', 'confirmed', 'in_progress', 'on_hold', 'completed', 'delivered', 'closed', 'cancelled') then
    raise exception 'Unknown status' using errcode = 'P0001';
  end if;

  v_allowed := case v_row.status
    when 'draft' then p_to_status in ('confirmed', 'cancelled')
    when 'confirmed' then p_to_status in ('in_progress', 'on_hold', 'cancelled')
    when 'in_progress' then p_to_status in ('completed', 'on_hold', 'cancelled')
    when 'on_hold' then p_to_status in ('in_progress', 'confirmed', 'cancelled')
    when 'completed' then p_to_status in ('delivered', 'in_progress')
    when 'delivered' then p_to_status in ('closed', 'cancelled')
    else false
  end;

  if not v_allowed then
    raise exception 'Cannot move an order from % to %', v_row.status, p_to_status using errcode = 'P0001';
  end if;

  if p_to_status = 'cancelled' then
    select coalesce(sum(p.amount), 0) - coalesce(sum(r.refunded), 0)
      into v_uncollected
    from public.payments p
    left join public.refunds r on r.payment_id = p.id
    where p.order_id = p_order_id and p.status = 'successful';

    if coalesce(v_uncollected, 0) > 0 then
      raise exception 'Refund the collected amount before cancelling this order' using errcode = 'P0001';
    end if;
  end if;

  v_old_status := v_row.status;

  update public.orders
     set status = p_to_status,
         confirmed_at = case when p_to_status = 'confirmed' then now() else confirmed_at end,
         delivered_at = case when p_to_status = 'delivered' then now() else delivered_at end,
         closed_at = case when p_to_status = 'closed' then now() else closed_at end,
         cancelled_at = case when p_to_status = 'cancelled' then now() else cancelled_at end,
         updated_at = now()
   where id = p_order_id
   returning * into v_row;

  insert into public.order_status_history (order_id, from_status, to_status, note, changed_by)
  values (p_order_id, v_old_status, p_to_status, nullif(btrim(coalesce(p_note, '')), ''), auth.uid());

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, old_data, new_data)
  values (
    v_row.business_id, auth.uid(), 'order', v_row.id, 'status_changed',
    jsonb_build_object('status', v_old_status), jsonb_build_object('status', p_to_status)
  );

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_assign_order(
  p_order_id uuid,
  p_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.orders%rowtype;
begin
  select * into v_row from public.orders where id = p_order_id for update;
  if v_row.id is null then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_row.business_id, array['owner', 'staff']);

  if p_user_id is not null and not exists (
    select 1 from public.business_members bm
    where bm.business_id = v_row.business_id
      and bm.user_id = p_user_id
      and bm.status = 'active'
  ) then
    raise exception 'That person is not an active member of this business' using errcode = 'P0001';
  end if;

  update public.orders
     set assigned_to = p_user_id,
         updated_at = now()
   where id = p_order_id
   returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

revoke execute on function public.rpc_save_quotation(uuid, uuid, uuid, date, text, text, numeric, jsonb, uuid) from public, anon;
revoke execute on function public.rpc_set_quotation_status(uuid, text) from public, anon;
revoke execute on function public.rpc_convert_quotation_to_order(uuid, date) from public, anon;
revoke execute on function public.rpc_save_order(uuid, uuid, uuid, date, text, text, numeric, jsonb, uuid) from public, anon;
revoke execute on function public.rpc_update_order_status(uuid, text, text) from public, anon;
revoke execute on function public.rpc_assign_order(uuid, uuid) from public, anon;

grant execute on function public.rpc_save_quotation(uuid, uuid, uuid, date, text, text, numeric, jsonb, uuid) to authenticated;
grant execute on function public.rpc_set_quotation_status(uuid, text) to authenticated;
grant execute on function public.rpc_convert_quotation_to_order(uuid, date) to authenticated;
grant execute on function public.rpc_save_order(uuid, uuid, uuid, date, text, text, numeric, jsonb, uuid) to authenticated;
grant execute on function public.rpc_update_order_status(uuid, text, text) to authenticated;
grant execute on function public.rpc_assign_order(uuid, uuid) to authenticated;
