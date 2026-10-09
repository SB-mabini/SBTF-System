-- ===========================================================================
-- SBTF System — Phase 0.14
-- Driver document replacement
-- Municipality of Mabini, Batangas
--
-- Closes the last mobile-blocking gap in the workflow surface: when staff
-- reject a document, the driver had no way to upload a corrected copy.
--
-- No audit code lives in this function on purpose: fn_trg_document_written
-- (20260101090600) already recognises exactly this change — a replaced
-- storage_path plus a verification reset to pending — and writes the
-- "document_replaced" activity-log row and both application-timeline events.
--
-- Idempotent-by-design: safe to re-run.
-- ===========================================================================
create or replace function public.rpc_driver_replace_document(
  p_document_id     uuid,
  p_storage_path    text,
  p_file_name       text default null,
  p_file_size_bytes integer default null,
  p_mime_type       text default null
)
returns public.franchise_documents
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_role  public.user_role;
  v_doc   public.franchise_documents;
  v_app   public.franchise_applications;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  v_role := public.current_user_role();
  if v_role <> 'driver' then
    raise exception 'Only driver/operator accounts may replace application documents'
      using errcode = '42501';
  end if;
  select * into v_doc from public.franchise_documents where id = p_document_id for update;
  if not found then
    raise exception 'Document not found' using errcode = 'P0002';
  end if;
  select * into v_app from public.franchise_applications where id = v_doc.application_id;
  if v_app.applicant_id <> v_actor then
    raise exception 'You can only replace documents on your own application'
      using errcode = '42501';
  end if;
  if v_app.status <> 'pending' then
    raise exception 'Documents of a % application can no longer be replaced', v_app.status
      using errcode = 'P0001';
  end if;
  -- A document staff already verified is part of the reviewed record and is
  -- immutable; only pending or rejected copies may be replaced.
  if v_doc.verification_status = 'verified' then
    raise exception 'A verified document can no longer be replaced'
      using errcode = 'P0001';
  end if;
  -- The corrected file must already live in the caller's own storage folder,
  -- exactly as rpc_driver_submit_application requires for the initial upload.
  if p_storage_path is null or p_storage_path not like v_actor::text || '/%' then
    raise exception 'Document files must be uploaded to your own storage folder'
      using errcode = '42501';
  end if;
  if p_mime_type is not null
     and p_mime_type not in ('application/pdf', 'image/jpeg', 'image/png') then
    raise exception 'Documents must be PDF, JPEG or PNG files' using errcode = 'P0001';
  end if;
  if p_file_size_bytes is not null and p_file_size_bytes > 10485760 then
    raise exception 'Each document must not exceed 10 MB' using errcode = 'P0001';
  end if;
  update public.franchise_documents
     set storage_path        = p_storage_path,
         file_name           = coalesce(left(nullif(btrim(p_file_name), ''), 200), file_name),
         file_size_bytes     = coalesce(p_file_size_bytes, file_size_bytes),
         mime_type           = coalesce(p_mime_type, mime_type),
         verification_status = 'pending',
         verified_by         = null,
         verified_at         = null,
         remarks             = null,
         uploaded_at         = now()
   where id = p_document_id
  returning * into v_doc;
  return v_doc;
end;
$$;
comment on function public.rpc_driver_replace_document(uuid, text, text, integer, text) is
  'Driver/operator replaces one document on their own pending application — typically a rejected copy. The replacement resets verification to pending; the trg_document_written trigger writes the audit trail and timeline.';
-- Public API surface (the function re-validates the caller's role internally).
grant execute on function public.rpc_driver_replace_document(uuid, text, text, integer, text) to authenticated;
