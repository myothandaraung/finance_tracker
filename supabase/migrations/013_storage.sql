-- =============================================================================
-- 013_storage.sql
-- Private storage buckets for receipt images and product photos.
--
-- Object paths always start with the business id:
--   receipts/{business_id}/{order_id}/{file}.jpg
--   product-images/{business_id}/{product_id}/{file}.jpg
-- so a storage policy can be scoped to a business the same way the table
-- policies are.
-- =============================================================================

create or replace function public.storage_business_id(p_path text)
returns uuid
language plpgsql
immutable
as $$
declare
  v_first text;
begin
  v_first := split_part(coalesce(p_path, ''), '/', 1);
  if v_first ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    return v_first::uuid;
  end if;
  return null;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit)
values ('receipts', 'receipts', false, 10485760)
on conflict (id) do update set public = false, file_size_limit = 10485760;

insert into storage.buckets (id, name, public, file_size_limit)
values ('product-images', 'product-images', false, 5242880)
on conflict (id) do update set public = false, file_size_limit = 5242880;

drop policy if exists "Members can read business files" on storage.objects;
create policy "Members can read business files" on storage.objects
  for select
  using (
    bucket_id in ('receipts', 'product-images')
    and public.is_business_member(public.storage_business_id(name))
  );

drop policy if exists "Finance can upload receipts" on storage.objects;
create policy "Finance can upload receipts" on storage.objects
  for insert
  with check (
    bucket_id = 'receipts'
    and public.is_business_member(public.storage_business_id(name))
    and public.has_business_role(public.storage_business_id(name), array['owner', 'accountant'])
  );

drop policy if exists "Staff can upload product images" on storage.objects;
create policy "Staff can upload product images" on storage.objects
  for insert
  with check (
    bucket_id = 'product-images'
    and public.is_business_member(public.storage_business_id(name))
    and public.has_business_role(public.storage_business_id(name), array['owner', 'staff'])
  );

drop policy if exists "Owners can delete business files" on storage.objects;
create policy "Owners can delete business files" on storage.objects
  for delete
  using (
    bucket_id in ('receipts', 'product-images')
    and public.is_business_member(public.storage_business_id(name))
    and public.has_business_role(public.storage_business_id(name), array['owner'])
  );

revoke execute on function public.storage_business_id(text) from public, anon;
grant execute on function public.storage_business_id(text) to authenticated;
