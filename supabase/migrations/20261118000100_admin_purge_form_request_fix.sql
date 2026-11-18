-- ===========================================================================
-- MTOP System — Account purge: fix form-request cleanup order
--
-- Deleting an account whose own form request had been converted into its own
-- application failed with:
--
--   new row for relation "form_requests" violates check constraint
--   "form_requests_converted_consistency"
--
-- The old purge only released OTHER people's form requests before deleting the
-- account's applications. The account's own converted requests were still
-- pointing at those applications, so the `on delete set null` foreign key
-- cleared `converted_application_id` while `status` remained 'converted',
-- tripping the CHECK constraint. The requests were then deleted a few lines
-- later anyway.
--
-- This migration:
--   * deletes the account's own form requests BEFORE its applications, so the
--     foreign key never fires on them;
--   * releases other people's requests into a status that satisfies both the
--     converted and the issued consistency checks. A request can be converted
--     straight from `requested` (rpc_staff_convert_form_request allows it), so
--     falling back to 'issued' unconditionally could violate
--     form_requests_issued_consistency.
-- ===========================================================================

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
  -- Release them before the delete so the foreign key does not blank
  -- converted_application_id while status is still 'converted'. A request can
  -- be converted straight from `requested`, so only restore `issued` when the
  -- request actually carries an issuer.
  update public.form_requests
     set converted_application_id = null,
         status = case
                    when issued_at is not null and issued_by is not null
                      then 'issued'::public.form_request_status
                    else 'requested'::public.form_request_status
                  end
   where converted_application_id = any (v_apps)
     and requested_by <> p_profile_id;

  -- The account's own requests (including converted ones) go away with the
  -- account. Remove them before the applications, otherwise the
  -- converted_application_id foreign key sets the column to null mid-delete
  -- and violates form_requests_converted_consistency.
  delete from public.form_requests where requested_by = p_profile_id;

  delete from public.franchise_applications
   where id = any (v_apps);

  update public.franchise_applications
     set renewal_of_record_id = null
   where renewal_of_record_id = any (v_records);

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

revoke all on function public.rpc_admin_purge_account(uuid, text) from public, anon;
grant execute on function public.rpc_admin_purge_account(uuid, text) to authenticated;
