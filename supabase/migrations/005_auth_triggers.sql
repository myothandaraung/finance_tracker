-- =============================================================================
-- 005_auth_triggers.sql
-- Keeps profiles and business memberships in sync with Supabase Auth.
--
-- Sign up flow:
--   1. the user signs up with an email
--   2. on_auth_user_created creates the profile row
--   3. any invitation created by an owner for that email is activated and
--      linked to the new user id
-- =============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), '')
    )
  )
  on conflict (id) do update
    set email = excluded.email,
        display_name = coalesce(public.profiles.display_name, excluded.display_name);

  update public.business_members
     set user_id = new.id,
         status = 'active',
         updated_at = now()
   where lower(email) = lower(coalesce(new.email, ''))
     and user_id is null
     and status = 'invited';

  return new;
end;
$$;

create or replace function public.handle_user_email_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.email is not distinct from old.email then
    return new;
  end if;

  update public.profiles
     set email = new.email
   where id = new.id;

  update public.business_members
     set email = new.email,
         updated_at = now()
   where user_id = new.id;

  update public.business_members
     set user_id = new.id,
         status = 'active',
         updated_at = now()
   where lower(email) = lower(coalesce(new.email, ''))
     and user_id is null
     and status = 'invited';

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

drop trigger if exists on_auth_user_email_updated on auth.users;
create trigger on_auth_user_email_updated
  after update of email on auth.users
  for each row execute function public.handle_user_email_update();
