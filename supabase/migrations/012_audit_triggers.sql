-- =============================================================================
-- 012_audit_triggers.sql
-- Safety net for the audit trail.
--
-- The RPCs already write an audit_events row for every financial action
-- they perform. These triggers cover the remaining cases (an UPDATE or DELETE
-- that did not come from an RPC, for example a manual fix in the SQL
-- editor) so the trail is never silently incomplete.
-- =============================================================================

create or replace function public.log_audit_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_business_id uuid;
  v_entity_id uuid;
  v_action text;
  v_old jsonb;
  v_new jsonb;
begin
  if tg_op = 'UPDATE' then
    v_business_id := coalesce(new.business_id, old.business_id);
    v_entity_id := new.id;
    v_action := 'updated';
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
  elsif tg_op = 'DELETE' then
    v_business_id := old.business_id;
    v_entity_id := old.id;
    v_action := 'deleted';
    v_old := to_jsonb(old);
    v_new := null;
  else
    v_business_id := new.business_id;
    v_entity_id := new.id;
    v_action := 'created';
    v_old := null;
    v_new := to_jsonb(new);
  end if;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, old_data, new_data)
  values (v_business_id, auth.uid(), tg_table_name, v_entity_id, v_action, v_old, v_new);

  return coalesce(new, old);
end;
$$;

-- Only UPDATE and DELETE are captured: INSERTs are logged by the RPCs that
-- create them, and a second trigger would duplicate those entries.
drop trigger if exists trg_payments_audit on public.payments;
create trigger trg_payments_audit
  after update or delete on public.payments
  for each row execute function public.log_audit_event();

drop trigger if exists trg_refunds_audit on public.refunds;
create trigger trg_refunds_audit
  after update or delete on public.refunds
  for each row execute function public.log_audit_event();

drop trigger if exists trg_expenses_audit on public.expenses;
create trigger trg_expenses_audit
  after update or delete on public.expenses
  for each row execute function public.log_audit_event();

drop trigger if exists trg_order_costs_audit on public.order_costs;
create trigger trg_order_costs_audit
  after update or delete on public.order_costs
  for each row execute function public.log_audit_event();

drop trigger if exists trg_business_members_audit on public.business_members;
create trigger trg_business_members_audit
  after update or delete on public.business_members
  for each row execute function public.log_audit_event();
