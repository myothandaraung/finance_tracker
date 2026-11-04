-- Drop everything in the public schema and recreate it.
-- Run this in the Supabase SQL Editor, then re-run migrations 001..014 in order.
drop schema if exists public cascade;
create schema public;

grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on schema public to postgres, service_role;
alter default privileges in schema public grant all on tables to postgres, service_role;
alter default privileges in schema public grant all on functions to postgres, service_role;
alter default privileges in schema public grant all on sequences to postgres, service_role;

-- Storage buckets are upserted by 013_storage.sql; leave storage alone.
