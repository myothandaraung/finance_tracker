-- =============================================================================
-- 011_views_reports.sql
-- Reporting.
--
-- Reports are SECURITY DEFINER functions instead of views: a view owned by
-- the table owner would bypass RLS and expose every business' rows, and
-- `security_invoker` views are not available on every Postgres version.
--
-- Reporting bases
--   cash collected  = successful payments in the period minus refunds
--   revenue         = net sales of orders delivered in the period
--                     (revenue is recognised on delivery)
--   receivables     = outstanding balance of every non cancelled order
-- =============================================================================

-- Per order financial snapshot used by every report.
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
    'outstanding_cents', o.total_amount_cents - (coalesce(p.paid_cents, 0) - coalesce(r.refunded_cents, 0)),
    'estimated_cost_cents', o.estimated_cost_cents,
    'actual_cost_cents', o.actual_cost_cents,
    'profit_cents', o.net_sales_cents - o.actual_cost_cents,
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

-- Everything the order detail screen needs in one round trip.
create or replace function public.rpc_order_financials(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_result jsonb;
begin
  select * into v_order from public.orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_order.business_id);

  select jsonb_build_object(
    'order', to_jsonb(v_order),
    'financials', (
      select f from public.order_financials(v_order.business_id) f
      where f ->> 'order_id' = p_order_id::text
    ),
    'items', coalesce((
      select jsonb_agg(to_jsonb(i) order by i.position)
      from public.order_items i
      where i.order_id = p_order_id
    ), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(to_jsonb(p) order by p.paid_at desc)
      from public.payments p
      where p.order_id = p_order_id
    ), '[]'::jsonb),
    'refunds', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.refunded_at desc)
      from public.refunds r
      where r.order_id = p_order_id
    ), '[]'::jsonb),
    'costs', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.cost_date desc, c.created_at desc)
      from public.order_costs c
      where c.order_id = p_order_id
    ), '[]'::jsonb),
    'history', coalesce((
      select jsonb_agg(to_jsonb(h) order by h.changed_at desc)
      from public.order_status_history h
      where h.order_id = p_order_id
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

-- -----------------------------------------------------------------------------
-- Dashboard
-- -----------------------------------------------------------------------------
create or replace function public.rpc_dashboard_summary(
  p_business_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_from timestamptz := p_from::timestamptz;
  v_to timestamptz := (p_to + 1)::timestamptz;
  v_payments bigint;
  v_refunds bigint;
  v_cash bigint;
  v_revenue bigint;
  v_expenses bigint;
  v_costs bigint;
  v_receivables bigint;
  v_orders int;
  v_delivered int;
  v_open int;
  v_overdue int;
  v_by_category jsonb;
begin
  perform public.assert_business_role(p_business_id);

  select coalesce(sum(amount_cents), 0)::bigint into v_payments
  from public.payments
  where business_id = p_business_id
    and status in ('successful', 'refunded')
    and paid_at >= v_from and paid_at < v_to;

  select coalesce(sum(amount_cents), 0)::bigint into v_refunds
  from public.refunds
  where business_id = p_business_id
    and refunded_at >= v_from and refunded_at < v_to;

  v_cash := v_payments - v_refunds;

  select coalesce(sum((f ->> 'net_sales_cents')::bigint), 0)::bigint into v_revenue
  from public.order_financials(p_business_id) f
  where (f ->> 'delivered_at') is not null
    and (f ->> 'delivered_at')::timestamptz >= v_from
    and (f ->> 'delivered_at')::timestamptz < v_to;

  select coalesce(sum(amount_cents), 0)::bigint into v_expenses
  from public.expenses
  where business_id = p_business_id
    and expense_date >= p_from and expense_date <= p_to;

  select coalesce(sum(amount_cents), 0)::bigint into v_costs
  from public.order_costs
  where business_id = p_business_id
    and cost_date >= p_from and cost_date <= p_to;

  select coalesce(sum(greatest((f ->> 'outstanding_cents')::bigint, 0)), 0)::bigint into v_receivables
  from public.order_financials(p_business_id) f
  where f ->> 'status' <> 'cancelled';

  select count(*)::int into v_orders
  from public.orders
  where business_id = p_business_id
    and created_at >= v_from and created_at < v_to;

  select count(*)::int into v_delivered
  from public.orders
  where business_id = p_business_id
    and delivered_at >= v_from and delivered_at < v_to
    and status in ('delivered', 'closed');

  select count(*)::int into v_open
  from public.orders
  where business_id = p_business_id
    and status in ('draft', 'confirmed', 'in_progress', 'on_hold');

  select count(*)::int into v_overdue
  from public.orders
  where business_id = p_business_id
    and status not in ('cancelled', 'closed', 'delivered')
    and due_date is not null
    and due_date < current_date;

  select coalesce(jsonb_agg(jsonb_build_object(
           'category_id', x.id,
           'name', x.name,
           'amount_cents', x.amount_cents
         ) order by x.amount_cents desc), '[]'::jsonb)
    into v_by_category
  from (
    select c.id,
           coalesce(c.name, 'Uncategorised') as name,
           coalesce(sum(e.amount_cents), 0)::bigint as amount_cents
    from public.expenses e
    left join public.expense_categories c on c.id = e.category_id
    where e.business_id = p_business_id
      and e.expense_date >= p_from and e.expense_date <= p_to
    group by c.id, c.name
  ) x;

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'orders_count', v_orders,
    'orders_delivered', v_delivered,
    'orders_open', v_open,
    'orders_overdue', v_overdue,
    'cash_collected_cents', v_cash,
    'revenue_cents', v_revenue,
    'expenses_cents', v_expenses,
    'production_cost_cents', v_costs,
    'receivables_cents', v_receivables,
    'profit_cents', v_revenue - v_costs,
    'expenses_by_category', v_by_category
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- Sales summary
-- -----------------------------------------------------------------------------
create or replace function public.rpc_sales_summary(
  p_business_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_from timestamptz := p_from::timestamptz;
  v_to timestamptz := (p_to + 1)::timestamptz;
  v_by_month jsonb;
  v_by_status jsonb;
  v_totals jsonb;
begin
  perform public.assert_business_role(p_business_id);

  select coalesce(jsonb_agg(jsonb_build_object(
           'month', to_char(month_start, 'YYYY-MM'),
           'label', to_char(month_start, 'Mon YYYY'),
           'revenue_cents', coalesce(sum((f ->> 'net_sales_cents')::bigint), 0),
           'cash_collected_cents', coalesce(sum(m.cash_cents), 0)
         ) order by month_start), '[]'::jsonb)
    into v_by_month
  from generate_series(date_trunc('month', p_from), date_trunc('month', p_to), interval '1 month') as month_start
  left join lateral (
    select f2 from public.order_financials(p_business_id) f2
    where (f2 ->> 'delivered_at') is not null
      and (f2 ->> 'delivered_at')::timestamptz >= month_start
      and (f2 ->> 'delivered_at')::timestamptz < (month_start + interval '1 month')
  ) f on true
  left join lateral (
    select coalesce(sum(p.amount_cents), 0)::bigint as cash_cents
    from public.payments p
    where p.business_id = p_business_id
      and p.status in ('successful', 'refunded')
      and p.paid_at >= month_start
      and p.paid_at < (month_start + interval '1 month')
  ) m on true
  group by month_start;

  select coalesce(jsonb_agg(jsonb_build_object('status', s.status, 'count', s.count) order by s.status), '[]'::jsonb)
    into v_by_status
  from (
    select o.status, count(*)::int as count
    from public.orders o
    where o.business_id = p_business_id
      and o.created_at >= v_from and o.created_at < v_to
    group by o.status
  ) s;

  select jsonb_build_object(
    'orders_count', coalesce(sum(1), 0),
    'revenue_cents', coalesce(sum((f ->> 'net_sales_cents')::bigint), 0),
    'profit_cents', coalesce(sum((f ->> 'profit_cents')::bigint), 0)
  ) into v_totals
  from public.order_financials(p_business_id) f
  where (f ->> 'delivered_at') is not null
    and (f ->> 'delivered_at')::timestamptz >= v_from
    and (f ->> 'delivered_at')::timestamptz < v_to;

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'totals', v_totals,
    'by_month', v_by_month,
    'by_status', v_by_status
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- Order profitability
-- -----------------------------------------------------------------------------
create or replace function public.rpc_profitability_report(
  p_business_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_from timestamptz := p_from::timestamptz;
  v_to timestamptz := (p_to + 1)::timestamptz;
  v_rows jsonb;
  v_totals jsonb;
begin
  perform public.assert_business_role(p_business_id);

  select coalesce(jsonb_agg(jsonb_build_object(
           'order_id', f ->> 'order_id',
           'order_no', f ->> 'order_no',
           'customer_name', f ->> 'customer_name',
           'status', f ->> 'status',
           'delivered_at', f ->> 'delivered_at',
           'net_sales_cents', (f ->> 'net_sales_cents')::bigint,
           'estimated_cost_cents', (f ->> 'estimated_cost_cents')::bigint,
           'actual_cost_cents', (f ->> 'actual_cost_cents')::bigint,
           'profit_cents', (f ->> 'profit_cents')::bigint,
           'margin_pct', case
             when (f ->> 'net_sales_cents')::bigint = 0 then null
             else round(((f ->> 'profit_cents')::numeric * 100) / (f ->> 'net_sales_cents')::numeric, 1)
           end
         ) order by (f ->> 'delivered_at') desc nulls last), '[]'::jsonb)
    into v_rows
  from public.order_financials(p_business_id) f
  where (f ->> 'delivered_at') is not null
    and (f ->> 'delivered_at')::timestamptz >= v_from
    and (f ->> 'delivered_at')::timestamptz < v_to;

  select jsonb_build_object(
    'revenue_cents', coalesce(sum((f ->> 'net_sales_cents')::bigint), 0),
    'estimated_cost_cents', coalesce(sum((f ->> 'estimated_cost_cents')::bigint), 0),
    'actual_cost_cents', coalesce(sum((f ->> 'actual_cost_cents')::bigint), 0),
    'profit_cents', coalesce(sum((f ->> 'profit_cents')::bigint), 0)
  ) into v_totals
  from public.order_financials(p_business_id) f
  where (f ->> 'delivered_at') is not null
    and (f ->> 'delivered_at')::timestamptz >= v_from
    and (f ->> 'delivered_at')::timestamptz < v_to;

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'totals', v_totals,
    'rows', v_rows
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- Receivables and ageing
-- -----------------------------------------------------------------------------
create or replace function public.rpc_receivables_report(
  p_business_id uuid,
  p_as_of date default current_date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_rows jsonb;
  v_total bigint;
  v_overdue bigint;
begin
  perform public.assert_business_role(p_business_id);

  select coalesce(jsonb_agg(jsonb_build_object(
           'order_id', f ->> 'order_id',
           'order_no', f ->> 'order_no',
           'customer_name', f ->> 'customer_name',
           'status', f ->> 'status',
           'total_cents', (f ->> 'total_cents')::bigint,
           'paid_cents', (f ->> 'paid_cents')::bigint,
           'outstanding_cents', (f ->> 'outstanding_cents')::bigint,
           'due_date', f ->> 'due_date',
           'days_overdue', case
             when (f ->> 'due_date') is null then null
             else greatest(0, (p_as_of - (f ->> 'due_date')::date))
           end,
           'age_bucket', case
             when (f ->> 'due_date') is null then 'no_due_date'
             when p_as_of - (f ->> 'due_date')::date <= 0 then 'current'
             when p_as_of - (f ->> 'due_date')::date <= 30 then '1_30'
             when p_as_of - (f ->> 'due_date')::date <= 60 then '31_60'
             when p_as_of - (f ->> 'due_date')::date <= 90 then '61_90'
             else '90_plus'
           end
         ) order by (f ->> 'due_date') asc nulls last), '[]'::jsonb)
    into v_rows
  from public.order_financials(p_business_id) f
  where f ->> 'status' <> 'cancelled'
    and (f ->> 'outstanding_cents')::bigint > 0;

  select coalesce(sum((f ->> 'outstanding_cents')::bigint), 0)::bigint into v_total
  from public.order_financials(p_business_id) f
  where f ->> 'status' <> 'cancelled'
    and (f ->> 'outstanding_cents')::bigint > 0;

  select coalesce(sum((f ->> 'outstanding_cents')::bigint), 0)::bigint into v_overdue
  from public.order_financials(p_business_id) f
  where f ->> 'status' <> 'cancelled'
    and (f ->> 'outstanding_cents')::bigint > 0
    and (f ->> 'due_date') is not null
    and (f ->> 'due_date')::date < p_as_of;

  return jsonb_build_object(
    'as_of', p_as_of,
    'total_cents', v_total,
    'overdue_cents', v_overdue,
    'rows', v_rows
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- Monthly trends
-- -----------------------------------------------------------------------------
create or replace function public.rpc_monthly_trends(
  p_business_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_rows jsonb;
begin
  perform public.assert_business_role(p_business_id);

  select coalesce(jsonb_agg(jsonb_build_object(
           'month', to_char(m.month_start, 'YYYY-MM'),
           'label', to_char(m.month_start, 'Mon YYYY'),
            'revenue_cents', coalesce(r.revenue_cents, 0),
            'cash_collected_cents', coalesce(c.cash_cents, 0),
            'expenses_cents', coalesce(e.expense_cents, 0),
            'production_cost_cents', coalesce(oc.cost_cents, 0),
            'profit_cents', coalesce(r.revenue_cents, 0) - coalesce(oc.cost_cents, 0)
         ) order by m.month_start), '[]'::jsonb)
    into v_rows
  from generate_series(date_trunc('month', p_from), date_trunc('month', p_to), interval '1 month') as m(month_start)
  left join lateral (
    select coalesce(sum((f ->> 'net_sales_cents')::bigint), 0)::bigint as revenue_cents
    from public.order_financials(p_business_id) f
    where (f ->> 'delivered_at') is not null
      and (f ->> 'delivered_at')::timestamptz >= m.month_start
      and (f ->> 'delivered_at')::timestamptz < (m.month_start + interval '1 month')
  ) r on true
  left join lateral (
    select coalesce(sum(p.amount_cents), 0)::bigint as cash_cents
    from public.payments p
    where p.business_id = p_business_id
      and p.status in ('successful', 'refunded')
      and p.paid_at >= m.month_start
      and p.paid_at < (m.month_start + interval '1 month')
  ) c on true
  left join lateral (
    select coalesce(sum(e.amount_cents), 0)::bigint as expense_cents
    from public.expenses e
    where e.business_id = p_business_id
      and e.expense_date >= m.month_start::date
      and e.expense_date < (m.month_start + interval '1 month')::date
  ) e on true
  left join lateral (
    select coalesce(sum(oc.amount_cents), 0)::bigint as cost_cents
    from public.order_costs oc
    where oc.business_id = p_business_id
      and oc.cost_date >= m.month_start::date
      and oc.cost_date < (m.month_start + interval '1 month')::date
  ) oc on true;

  return jsonb_build_object('from', p_from, 'to', p_to, 'rows', v_rows);
end;
$$;

revoke execute on function public.rpc_order_financials(uuid) from public, anon;
revoke execute on function public.rpc_dashboard_summary(uuid, date, date) from public, anon;
revoke execute on function public.rpc_sales_summary(uuid, date, date) from public, anon;
revoke execute on function public.rpc_profitability_report(uuid, date, date) from public, anon;
revoke execute on function public.rpc_receivables_report(uuid, date) from public, anon;
revoke execute on function public.rpc_monthly_trends(uuid, date, date) from public, anon;

grant execute on function public.rpc_order_financials(uuid) to authenticated;
grant execute on function public.rpc_dashboard_summary(uuid, date, date) to authenticated;
grant execute on function public.rpc_sales_summary(uuid, date, date) to authenticated;
grant execute on function public.rpc_profitability_report(uuid, date, date) to authenticated;
grant execute on function public.rpc_receivables_report(uuid, date) to authenticated;
grant execute on function public.rpc_monthly_trends(uuid, date, date) to authenticated;
