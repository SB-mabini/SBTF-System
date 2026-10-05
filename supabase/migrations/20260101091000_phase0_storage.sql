-- ===========================================================================
-- SBTF System — Phase 0.11
-- Supabase Storage: private buckets and access policies.
--
-- Both buckets are PRIVATE. Files are never exposed through a public URL:
-- the web application requests short-lived signed URLs through the Supabase
-- client (authorised by the storage policies below) and the mobile application
-- does the same.
--
-- Folder conventions
--   franchise-documents : {profile_id}/{application_id}/{document_type}-{epoch}.{ext}
--   certificates        : {profile_id}/{franchise_number}.pdf
--
-- Folder segment 1 is always the owning profile id, which is what the policies
-- below use to authorise access.
-- ===========================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'franchise-documents',
  'franchise-documents',
  false,
  10485760,
  array['application/pdf', 'image/jpeg', 'image/png']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'certificates',
  'certificates',
  false,
  5242880,
  array['application/pdf']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- --- franchise-documents ----------------------------------------------------
drop policy if exists "documents bucket: owner or franchising staff may read" on storage.objects;
create policy "documents bucket: owner or franchising staff may read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'franchise-documents'
    and (
      public.is_staff_or_admin()
      or (storage.foldername(name))[1] = public.current_profile_id()::text
    )
  );

drop policy if exists "documents bucket: owners may upload to their own folder" on storage.objects;
create policy "documents bucket: owners may upload to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'franchise-documents'
    and public.current_profile_id() is not null
    and (storage.foldername(name))[1] = public.current_profile_id()::text
  );

drop policy if exists "documents bucket: owners may replace a file in their own folder" on storage.objects;
create policy "documents bucket: owners may replace a file in their own folder"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'franchise-documents'
    and (storage.foldername(name))[1] = public.current_profile_id()::text
  )
  with check (
    bucket_id = 'franchise-documents'
    and (storage.foldername(name))[1] = public.current_profile_id()::text
  );

drop policy if exists "documents bucket: owners may delete their own unlinked uploads" on storage.objects;
create policy "documents bucket: owners may delete their own unlinked uploads"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'franchise-documents'
    and (storage.foldername(name))[1] = public.current_profile_id()::text
  );

-- --- certificates -----------------------------------------------------------
drop policy if exists "certificates bucket: operator or franchising staff may read" on storage.objects;
create policy "certificates bucket: operator or franchising staff may read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'certificates'
    and (
      public.is_staff_or_admin()
      or (storage.foldername(name))[1] = public.current_profile_id()::text
    )
  );

drop policy if exists "certificates bucket: franchising staff may publish a certificate" on storage.objects;
create policy "certificates bucket: franchising staff may publish a certificate"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'certificates' and public.is_staff_or_admin());

drop policy if exists "certificates bucket: franchising staff may replace a certificate" on storage.objects;
create policy "certificates bucket: franchising staff may replace a certificate"
  on storage.objects for update to authenticated
  using (bucket_id = 'certificates' and public.is_staff_or_admin())
  with check (bucket_id = 'certificates' and public.is_staff_or_admin());

-- Drivers never delete certificates: only the office may withdraw one, and it
-- happens through the archiving workflow (which preserves the audit trail).
