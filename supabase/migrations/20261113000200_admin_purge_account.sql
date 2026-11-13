-- ===========================================================================
-- SBTF System — Account purge (part 2 of 2)
--
-- Administrator-only permanent deletion of an account and every row connected
-- to it. This is the "delete account" capability requested for the admin
-- console; it is intentionally isolated so it can be removed later.
--
-- Scope
--   * the profile's own applications, documents, records, form requests,
--     notifications, device tokens, agreements, AI briefings and logs;
--   * the Supabase Auth user (identities, sessions and refresh tokens follow);
--   * files are NOT removed here — the `admin-users` Edge Function reads
--     rpc_admin_collect_account_assets() first and deletes the storage objects
--     through the Storage API, then calls the purge RPC.
--
-- Guard rails
--   * caller must be an active administrator (public.is_admin());
--   * cannot purge your own account;
--   * cannot purge the last active administrator;
--   * refuses accounts that acted on OTHER people's records, because the
--     `on delete set null` actions would violate workflow CHECK constraints
--     (e.g. franchise_applications_reviewed_consistency) and falsify the audit
--     trail. Deactivate such accounts instead.
--
-- Everything except the storage files happens in one transaction, including
-- the auth.users deletion, so a failure leaves the database untouched.
-- ===========================================================================

-- --- storage asset discovery -------------------------------------------------
-- Returns the private-bucket objects owned by the profile. The Edge Function
-- removes them through the Storage API before calling the purge RPC.
create or replace function public.rpc_admin_collect_account_assets(
  p_profile_id uuid
)
returns table (bucket_id text, path text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  if p_profile_id is null then
    raise exception 'A profile id is required' using errcode = 'P0001';
  end if;

  return query
    select 'franchise-documents'::text, d.storage_path
      from public.franchise_documents d
      join public.franchise_applications a on a.id = d.application_id
     where a.applicant_id = p_profile_id
    union
    select 'franchise-documents', fr.or_cr_storage_path
      from public.form_requests fr
     where fr.requested_by = p_profile_id
       and fr.or_cr_storage_path is not null
    union
    select 'franchise-documents', fr.signature_storage_path
      from public.form_requests fr
     where fr.requested_by = p_profile_id
       and fr.signature_storage_path is not null
    union
    select 'franchise-documents', a.applicant_signature_storage_path
      from public.franchise_applications a
     where a.applicant_id = p_profile_id
       and a.applicant_signature_storage_path is not null
    union
    select 'certificates', r.certificate_storage_path
      from public.franchise_records r
     where r.operator_id = p_profile_id
       and r.certificate_storage_path is not null;
end;
$$;

comment on function public.rpc_admin_collect_account_assets(uuid) is
  'Administrator-only. Lists the private-bucket storage objects owned by a profile so the admin-users Edge Function can delete them before purging the account.';

-- --- shared guard ------------------------------------------------------------
-- Internal helper: the Edge Function calls rpc_admin_purge_check() before it
-- touches storage, and rpc_admin_purge_account() calls it again inside the
-- deleting transaction. Keeping the rules in one place stops the two paths
-- drifting apart.
create or replace function public.fn_admin_purge_guard(
  p_profile_id uuid
)
returns public.profiles
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor        uuid := public.current_profile_id();
  v_target       public.profiles;
  v_admins       integer;
  v_foreign_refs integer;
begin
  if not public.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  if p_profile_id is null then
    raise exception 'A profile id is required' using errcode = 'P0001';
  end if;

  if p_profile_id = v_actor then
    raise exception 'Administrators cannot delete their own account' using errcode = '42501';
  end if;

  select * into v_target
    from public.profiles
   where id = p_profile_id
   for update;

  if not found then
    raise exception 'User not found' using errcode = 'P0002';
  end if;

  -- Never leave the system without an active administrator.
  if v_target.role = 'administrator' and v_target.account_status = 'active' then
    select count(*) into v_admins
      from public.profiles
     where role = 'administrator' and account_status = 'active';

    if v_admins <= 1 then
      raise exception 'The last active administrator cannot be deleted' using errcode = 'P0001';
    end if;
  end if;

  -- Refuse accounts that acted on other people's records. Nulling those
  -- references would violate workflow consistency checks and rewrite history.
  select
      (select count(*)
         from public.franchise_applications a
        where a.applicant_id <> p_profile_id
          and (a.reviewed_by = p_profile_id
               or a.review_started_by = p_profile_id
               or a.assigned_staff_id = p_profile_id
               or a.endorsed_by = p_profile_id))
    + (select count(*)
         from public.franchise_documents d
         join public.franchise_applications a on a.id = d.application_id
        where d.verified_by = p_profile_id
          and a.applicant_id <> p_profile_id)
    + (select count(*)
         from public.franchise_records r
        where r.archived_by = p_profile_id
          and r.operator_id <> p_profile_id)
    + (select count(*)
         from public.document_releases dr
         join public.franchise_applications a on a.id = dr.application_id
        where dr.released_by = p_profile_id
          and a.applicant_id <> p_profile_id)
    + (select count(*)
         from public.application_appointments ap
         join public.franchise_applications a on a.id = ap.application_id
        where ap.scheduled_by = p_profile_id
          and a.applicant_id <> p_profile_id)
    + (select count(*)
         from public.form_requests fr
        where fr.requested_by <> p_profile_id
          and (fr.issued_by = p_profile_id
               or fr.reviewed_by = p_profile_id
               or fr.printed_by = p_profile_id))
    into v_foreign_refs;

  if v_foreign_refs > 0 then
    raise exception
      'This account has acted on other people''s records (% references). Deactivate it instead.',
      v_foreign_refs
      using errcode = 'P0001';
  end if;

  return v_target;
end;
$$;

comment on function public.fn_admin_purge_guard(uuid) is
  'Internal guard shared by rpc_admin_purge_check() and rpc_admin_purge_account(). Not callable by clients.';

-- --- preflight ---------------------------------------------------------------
-- The Edge Function calls this BEFORE removing storage objects, so a refused
-- purge never loses files. The purge RPC re-runs the guard in its transaction.
create or replace function public.rpc_admin_purge_check(
  p_profile_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_target public.profiles;
begin
  v_target := public.fn_admin_purge_guard(p_profile_id);

  return jsonb_build_object(
    'can_purge', true,
    'profile_id', v_target.id,
    'role', v_target.role,
    'account_status', v_target.account_status
  );
end;
$$;

comment on function public.rpc_admin_purge_check(uuid) is
  'Administrator-only preflight for account deletion. Raises the same errors as rpc_admin_purge_account(), without deleting anything.';

-- --- permanent purge ---------------------------------------------------------
create or replace function public.rpc_admin_purge_account(
  p_profile_id uuid,
  p_reason     text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor   uuid := public.current_profile_id();
  v_target  public.profiles;
  v_apps    uuid[];
  v_records uuid[];
  v_reason  text;
begin
  v_target := public.fn_admin_purge_guard(p_profile_id);

  v_reason := btrim(coalesce(p_reason, ''));
  if length(v_reason) < 5 then
    raise exception 'A reason of at least 5 characters is required' using errcode = 'P0001';
  end if;

  -- --- identify the account's own franchise data ---------------------------
  select coalesce(array_agg(a.id), '{}')
    into v_apps
    from public.franchise_applications a
   where a.applicant_id = p_profile_id;

  select coalesce(array_agg(r.id), '{}')
    into v_records
    from public.franchise_records r
   where r.operator_id = p_profile_id
      or r.application_id = any (v_apps);

  -- --- children first (the restricting foreign keys) -----------------------
  delete from public.document_releases
   where application_id = any (v_apps)
      or record_id = any (v_records);

  delete from public.renewal_reminders_sent
   where record_id = any (v_records);

  delete from public.franchise_records
   where id = any (v_records);

  -- Other people's form requests may point at an application being removed.
  -- Put them back to `issued` so form_requests_converted_consistency holds.
  update public.form_requests
     set converted_application_id = null,
         status = 'issued'
   where converted_application_id = any (v_apps)
     and requested_by <> p_profile_id;

  delete from public.franchise_applications
   where id = any (v_apps);

  update public.franchise_applications
     set renewal_of_record_id = null
   where renewal_of_record_id = any (v_records);

  delete from public.form_requests where requested_by = p_profile_id;

  -- --- profile-scoped rows that cascade anyway -----------------------------
  delete from public.notifications        where user_id = p_profile_id;
  delete from public.device_tokens        where profile_id = p_profile_id;
  delete from public.ai_briefings         where requester_id = p_profile_id;
  delete from public.user_agreements      where profile_id = p_profile_id;
  delete from public.announcement_targets where profile_id = p_profile_id;

  -- The roster entry is anonymised, not personal data; keep it and unlink it.
  update public.toda_members
     set profile_id = null
   where profile_id = p_profile_id;

  -- --- append-only logs ----------------------------------------------------
  -- A deliberate, transaction-scoped bypass so the account's footprint is
  -- actually erased. The triggers are re-enabled immediately; if anything
  -- below raises, the transaction (including the disable) rolls back.
  alter table public.activity_logs   disable trigger trg_activity_logs_immutable;
  alter table public.ai_request_logs disable trigger trg_ai_request_logs_immutable;

  delete from public.ai_request_logs where requester_id = p_profile_id;

  delete from public.activity_logs
   where user_id = p_profile_id
      or (target_type = 'profile' and target_id = p_profile_id)
      or metadata ->> 'email' = v_target.email;

  alter table public.activity_logs   enable trigger trg_activity_logs_immutable;
  alter table public.ai_request_logs enable trigger trg_ai_request_logs_immutable;

  -- --- Supabase Auth, then the profile ------------------------------------
  if v_target.auth_user_id is not null then
    delete from auth.users where id = v_target.auth_user_id;
  end if;

  delete from public.profiles where id = p_profile_id;

  -- One accountability entry: who purged, why, and how much was removed.
  -- No name, email or other PII is retained in the metadata.
  insert into public.activity_logs (user_id, action, target_type, target_id, metadata)
  values (
    v_actor,
    'user_purged',
    'system',
    null,
    jsonb_build_object(
      'purged_profile_id', p_profile_id,
      'reason', v_reason,
      'applications', cardinality(v_apps),
      'records', cardinality(v_records)
    )
  );

  return jsonb_build_object(
    'profile_id', p_profile_id,
    'applications', cardinality(v_apps),
    'records', cardinality(v_records),
    'reason', v_reason
  );
end;
$$;

comment on function public.rpc_admin_purge_account(uuid, text) is
  'Administrator-only permanent purge of a profile, its connected franchise data, logs and Supabase Auth user. Refuses accounts that acted on other people''s records, your own account, and the last active administrator.';

revoke all on function public.fn_admin_purge_guard(uuid) from public, anon, authenticated;
revoke all on function public.rpc_admin_collect_account_assets(uuid) from public, anon;
revoke all on function public.rpc_admin_purge_check(uuid) from public, anon;
revoke all on function public.rpc_admin_purge_account(uuid, text) from public, anon;
grant execute on function public.rpc_admin_collect_account_assets(uuid) to authenticated;
grant execute on function public.rpc_admin_purge_check(uuid) to authenticated;
grant execute on function public.rpc_admin_purge_account(uuid, text) to authenticated;
