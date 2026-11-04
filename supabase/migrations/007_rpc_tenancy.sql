-- =============================================================================
-- 007_rpc_tenancy.sql
-- Tenancy and team management.
--
-- Every function is SECURITY DEFINER and performs its own permission checks,
-- so the client can never widen its own access.
-- =============================================================================

-- Shared guard: membership + optional role check.
create or replace function public.assert_business_role(
  p_business_id uuid,
  p_roles text[] default null
)
returns void
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if p_business_id is null then
    raise exception 'Business is required' using errcode = 'P0001';
  end if;

  if not public.is_business_member(p_business_id) then
    raise exception 'You do not have access to this business' using errcode = '42501';
  end if;

  if p_roles is not null and not public.has_business_role(p_business_id, p_roles) then
    raise exception 'Your role does not allow this action' using errcode = '42501';
  end if;
end;
$$;

-- Memberships of the signed in user, with the business details the app needs.
create or replace function public.rpc_my_memberships()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'business_id', b.id,
        'name', b.name,
        'currency_code', b.currency_code,
        'role', m.role,
        'status', m.status
      ) order by b.name
    ),
    '[]'::jsonb
  )
  from public.business_members m
  join public.businesses b on b.id = m.business_id
  where m.user_id = auth.uid()
    and m.status = 'active';
$$;

-- Creates a business and makes the caller its owner.
create or replace function public.rpc_create_business(
  p_name text,
  p_currency_code text default 'PHP'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_business public.businesses%rowtype;
  v_email text;
begin
  if v_user is null then
    raise exception 'You must be signed in' using errcode = '42501';
  end if;

  if p_name is null or length(btrim(p_name)) = 0 then
    raise exception 'Business name is required' using errcode = 'P0001';
  end if;

  select lower(coalesce(email, '')) into v_email from auth.users where id = v_user;

  insert into public.businesses (name, currency_code)
  values (
    btrim(p_name),
    upper(coalesce(p_currency_code, 'PHP'))
  )
  returning * into v_business;

  insert into public.business_members (business_id, user_id, email, role, status, invited_by)
  values (v_business.id, v_user, v_email, 'owner', 'active', v_user);

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (v_business.id, v_user, 'business', v_business.id, 'created', to_jsonb(v_business));

  return jsonb_build_object(
    'business_id', v_business.id,
    'name', v_business.name,
    'currency_code', v_business.currency_code
  );
end;
$$;

-- Owner only: business settings.
create or replace function public.rpc_update_business(
  p_business_id uuid,
  p_name text default null,
  p_currency_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_business public.businesses%rowtype;
begin
  perform public.assert_business_role(p_business_id, array['owner']);

   update public.businesses
      set name = coalesce(nullif(btrim(p_name), ''), name),
          currency_code = coalesce(upper(p_currency_code), currency_code)
    where id = p_business_id
    returning * into v_business;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (p_business_id, auth.uid(), 'business', v_business.id, 'updated', to_jsonb(v_business));

  return to_jsonb(v_business);
end;
$$;

-- Owner only: add or update a team member by email.
create or replace function public.rpc_invite_member(
  p_business_id uuid,
  p_email text,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_member public.business_members%rowtype;
begin
  perform public.assert_business_role(p_business_id, array['owner']);

  if v_email = '' or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Enter a valid email address' using errcode = 'P0001';
  end if;

  if p_role not in ('owner', 'staff', 'accountant') then
    raise exception 'Unknown role' using errcode = 'P0001';
  end if;

  insert into public.business_members (business_id, user_id, email, role, status, invited_by)
  values (p_business_id, null, v_email, p_role, 'invited', auth.uid())
  on conflict (business_id, email) do update
    set role = excluded.role,
        status = case
          when public.business_members.user_id is not null then 'active'
          else 'invited'
        end,
        updated_at = now()
  returning * into v_member;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (p_business_id, auth.uid(), 'business_member', v_member.id, 'invited', to_jsonb(v_member));

  return to_jsonb(v_member);
end;
$$;

-- Owner only: change the role of an existing member.
create or replace function public.rpc_update_member_role(
  p_member_id uuid,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_member public.business_members%rowtype;
begin
  if p_role not in ('owner', 'staff', 'accountant') then
    raise exception 'Unknown role' using errcode = 'P0001';
  end if;

  select * into v_member from public.business_members where id = p_member_id;
  if v_member.id is null then
    raise exception 'Member not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_member.business_id, array['owner']);

  if v_member.user_id = auth.uid() and p_role <> 'owner' then
    raise exception 'You cannot remove your own owner access' using errcode = 'P0001';
  end if;

  update public.business_members
     set role = p_role,
         updated_at = now()
   where id = p_member_id
   returning * into v_member;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (v_member.business_id, auth.uid(), 'business_member', v_member.id, 'role_changed', to_jsonb(v_member));

  return to_jsonb(v_member);
end;
$$;

-- Owner only: deactivate a member.
create or replace function public.rpc_remove_member(p_member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_member public.business_members%rowtype;
begin
  select * into v_member from public.business_members where id = p_member_id;
  if v_member.id is null then
    raise exception 'Member not found' using errcode = 'P0002';
  end if;

  perform public.assert_business_role(v_member.business_id, array['owner']);

  if v_member.user_id = auth.uid() then
    raise exception 'You cannot remove yourself from the business' using errcode = 'P0001';
  end if;

  update public.business_members
     set user_id = null,
         status = 'inactive',
         updated_at = now()
   where id = p_member_id
   returning * into v_member;

  insert into public.audit_events (business_id, actor_id, entity, entity_id, action, new_data)
  values (v_member.business_id, auth.uid(), 'business_member', v_member.id, 'removed', to_jsonb(v_member));

  return to_jsonb(v_member);
end;
$$;

-- Any signed in user: update their own profile.
create or replace function public.rpc_update_profile(
  p_display_name text default null,
  p_phone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in' using errcode = '42501';
  end if;

  update public.profiles
     set display_name = coalesce(nullif(btrim(p_display_name), ''), display_name),
         phone = coalesce(nullif(btrim(p_phone), ''), phone),
         updated_at = now()
   where id = auth.uid()
   returning * into v_profile;

  if v_profile.id is null then
    insert into public.profiles (id, display_name, phone)
    values (auth.uid(), nullif(btrim(p_display_name), ''), nullif(btrim(p_phone), ''))
    returning * into v_profile;
  end if;

  return to_jsonb(v_profile);
end;
$$;

-- Gapless document number per business: ORD-2026-0001 / QUO-2026-0001.
create or replace function public.rpc_next_document_no(
  p_business_id uuid,
  p_kind text
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_next bigint;
  v_prefix text;
begin
  perform public.assert_business_role(p_business_id);

  if p_kind not in ('order', 'quotation') then
    raise exception 'Unknown document kind' using errcode = 'P0001';
  end if;

  insert into public.business_counters as bc (business_id, kind, next_value)
  values (p_business_id, p_kind, 1)
  on conflict (business_id, kind) do update
    set next_value = bc.next_value + 1
  returning bc.next_value into v_next;

  v_prefix := case p_kind
    when 'order' then 'ORD'
    else 'QUO'
  end;

  return v_prefix || '-' || to_char(now(), 'YYYY') || '-' || lpad(v_next::text, 4, '0');
end;
$$;

-- Owner / accountant: recent audit trail.
create or replace function public.rpc_audit_events(
  p_business_id uuid,
  p_entity text default null,
  p_limit int default 100
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    jsonb_agg(e order by e.created_at desc),
    '[]'::jsonb
  )
  from (
    select id, business_id, actor_id, entity, entity_id, action, old_data, new_data, created_at
    from public.audit_events
    where business_id = p_business_id
      and (p_entity is null or entity = p_entity)
    order by created_at desc
    limit greatest(1, least(coalesce(p_limit, 100), 500))
  ) e
  where public.is_business_member(p_business_id)
    and public.has_business_role(p_business_id, array['owner', 'accountant']);
$$;

-- -----------------------------------------------------------------------------
-- Grants: the client may only call these through the authenticated role.
-- -----------------------------------------------------------------------------
revoke execute on function public.rpc_my_memberships() from public, anon;
revoke execute on function public.rpc_create_business(text, text) from public, anon;
revoke execute on function public.rpc_update_business(uuid, text, text) from public, anon;
revoke execute on function public.rpc_invite_member(uuid, text, text) from public, anon;
revoke execute on function public.rpc_update_member_role(uuid, text) from public, anon;
revoke execute on function public.rpc_remove_member(uuid) from public, anon;
revoke execute on function public.rpc_update_profile(text, text) from public, anon;
revoke execute on function public.rpc_next_document_no(uuid, text) from public, anon;
revoke execute on function public.rpc_audit_events(uuid, text, int) from public, anon;

grant execute on function public.rpc_my_memberships() to authenticated;
grant execute on function public.rpc_create_business(text, text) to authenticated;
grant execute on function public.rpc_update_business(uuid, text, text) to authenticated;
grant execute on function public.rpc_invite_member(uuid, text, text) to authenticated;
grant execute on function public.rpc_update_member_role(uuid, text) to authenticated;
grant execute on function public.rpc_remove_member(uuid) to authenticated;
grant execute on function public.rpc_update_profile(text, text) to authenticated;
grant execute on function public.rpc_next_document_no(uuid, text) to authenticated;
grant execute on function public.rpc_audit_events(uuid, text, int) to authenticated;
