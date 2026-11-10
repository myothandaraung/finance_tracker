-- Fix order cancellation after refund support was introduced.
-- The original RPC referenced a non-existent refunds.refunded column.

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
  v_paid numeric;
  v_refunded numeric;
  v_roles text[];
begin
  select * into v_row
  from public.orders
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

  if p_to_status not in (
    'draft', 'confirmed', 'in_progress', 'on_hold', 'completed', 'delivered',
    'closed', 'cancelled'
  ) then
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
    raise exception 'Cannot move an order from % to %',
      v_row.status, p_to_status using errcode = 'P0001';
  end if;

  if p_to_status = 'cancelled' then
    select coalesce(sum(p.amount), 0)
      into v_paid
    from public.payments p
    where p.order_id = p_order_id
      and p.status in ('successful', 'refunded');

    select coalesce(sum(r.amount), 0)
      into v_refunded
    from public.refunds r
    where r.order_id = p_order_id;

    if v_paid - v_refunded > 0 then
      raise exception 'Refund the collected amount before cancelling this order'
        using errcode = 'P0001';
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

  insert into public.order_status_history (
    order_id, from_status, to_status, note, changed_by
  ) values (
    p_order_id,
    v_old_status,
    p_to_status,
    nullif(btrim(coalesce(p_note, '')), ''),
    auth.uid()
  );

  insert into public.audit_events (
    business_id, actor_id, entity, entity_id, action, old_data, new_data
  ) values (
    v_row.business_id,
    auth.uid(),
    'order',
    v_row.id,
    'status_changed',
    jsonb_build_object('status', v_old_status),
    jsonb_build_object('status', p_to_status)
  );

  return to_jsonb(v_row);
end;
$$;

revoke execute on function public.rpc_update_order_status(uuid, text, text)
  from public, anon;
grant execute on function public.rpc_update_order_status(uuid, text, text)
  to authenticated;
