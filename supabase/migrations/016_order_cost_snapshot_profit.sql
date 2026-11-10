-- Use the production cost captured on the order as the historical fallback.
-- Catalog cost changes must never rewrite profit for an existing order.

alter table public.order_items
  add column if not exists estimated_cost numeric(15,2) not null default 0
    check (estimated_cost >= 0),
  add column if not exists estimated_cost_cents bigint generated always as
    (round(estimated_cost * 100)::bigint) stored;

-- Populate the per-line snapshot for orders created by older app versions.
update public.order_items oi
set estimated_cost = coalesce(p.production_cost, 0)
from public.products p
where p.id = oi.product_id
  and oi.estimated_cost = 0
  and p.production_cost > 0;

-- rpc_save_order and quotation conversion recreate order items. Seed their
-- snapshot from the quotation line when available, otherwise from the current
-- catalog cost. The app then applies any explicit per-order override.
create or replace function public.set_order_item_estimated_cost()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cost numeric;
begin
  if new.estimated_cost <> 0 then
    return new;
  end if;

  select qi.estimated_cost into v_cost
  from public.orders o
  join public.quotation_items qi
    on qi.quotation_id = o.quotation_id and qi.position = new.position
  where o.id = new.order_id;

  if v_cost is null and new.product_id is not null then
    select p.production_cost into v_cost
    from public.products p
    where p.id = new.product_id;
  end if;

  new.estimated_cost := coalesce(v_cost, 0);
  return new;
end;
$$;

drop trigger if exists trg_order_item_estimated_cost on public.order_items;
create trigger trg_order_item_estimated_cost
  before insert on public.order_items
  for each row execute function public.set_order_item_estimated_cost();

-- Older app versions did not copy the catalog production cost into an order.
-- Take a one-time snapshot for those orders during this migration. Future
-- catalog edits cannot affect this stored value.
update public.orders o
set estimated_cost = snapshot.total_cost,
    updated_at = now()
from (
  select oi.order_id,
         coalesce(sum(round(oi.quantity * coalesce(p.production_cost, 0), 2)), 0)
           as total_cost
  from public.order_items oi
  left join public.products p on p.id = oi.product_id
  group by oi.order_id
) snapshot
where o.id = snapshot.order_id
  and o.estimated_cost = 0
  and snapshot.total_cost > 0;

-- rpc_save_order owns the header transaction. This companion RPC persists the
-- editable per-line cost snapshot after the header/items have been saved.
create or replace function public.rpc_set_order_item_estimated_costs(
  p_order_id uuid,
  p_items jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_item jsonb;
  v_cost numeric;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_order.business_id, array['owner', 'staff']);

  for v_item in
    select value from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    v_cost := public.cents_to_numeric(
      coalesce((v_item ->> 'estimated_cost_cents')::bigint, 0)
    );
    if v_cost < 0 then
      raise exception 'Production cost cannot be negative' using errcode = 'P0001';
    end if;

    update public.order_items
       set estimated_cost = v_cost
     where order_id = p_order_id
       and position = coalesce((v_item ->> 'position')::int, 0);
  end loop;

  return to_jsonb(v_order);
end;
$$;

revoke execute on function public.rpc_set_order_item_estimated_costs(uuid, jsonb)
  from public, anon;
grant execute on function public.rpc_set_order_item_estimated_costs(uuid, jsonb)
  to authenticated;

create or replace function public.order_financials(p_business_id uuid)
returns setof jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with paid as (
    select p.order_id as pay_order_id, sum(p.amount_cents)::bigint as paid_cents
    from public.payments p
    where p.business_id = p_business_id
      and p.status in ('successful', 'refunded')
    group by p.order_id
  ),
  refunded as (
    select r.order_id as ref_order_id, sum(r.amount_cents)::bigint as refunded_cents
    from public.refunds r
    where r.business_id = p_business_id
    group by r.order_id
  )
  select jsonb_build_object(
    'order_id', o.id,
    'order_no', o.order_no,
    'status', o.status,
    'customer_id', o.customer_id,
    'customer_name', c.name,
    'assigned_to', o.assigned_to,
    'total_cents', o.total_amount_cents,
    'subtotal_cents', o.subtotal_cents,
    'discount_amount_cents', o.discount_amount_cents,
    'net_sales_cents', o.net_sales_cents,
    'paid_cents', coalesce(p.paid_cents, 0),
    'refunded_cents', coalesce(r.refunded_cents, 0),
    'outstanding_cents', o.total_amount_cents -
      (coalesce(p.paid_cents, 0) - coalesce(r.refunded_cents, 0)),
    'estimated_cost_cents', o.estimated_cost_cents,
    'actual_cost_cents', o.actual_cost_cents,
    'estimated_production_cost_cents',
      case when o.actual_cost_cents > 0 then o.actual_cost_cents
           else o.estimated_cost_cents end,
    'production_cost_source',
      case when o.actual_cost_cents > 0 then 'actual'
           when o.estimated_cost_cents > 0 then 'order_snapshot'
           else 'none' end,
    'profit_cents',
      o.net_sales_cents - case when o.actual_cost_cents > 0
                               then o.actual_cost_cents
                               else o.estimated_cost_cents end,
    -- Retained for compatibility with existing app/report models.
    'profit_cents_estimated',
      o.net_sales_cents - case when o.actual_cost_cents > 0
                               then o.actual_cost_cents
                               else o.estimated_cost_cents end,
    'due_date', o.due_date,
    'delivered_at', o.delivered_at,
    'created_at', o.created_at
  )
  from public.orders o
  join public.customers c on c.id = o.customer_id
  left join paid p on p.pay_order_id = o.id
  left join refunded r on r.ref_order_id = o.id
  where o.business_id = p_business_id;
$$;

revoke execute on function public.order_financials(uuid) from public, anon;
grant execute on function public.order_financials(uuid) to authenticated;
