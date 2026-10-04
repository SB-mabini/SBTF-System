-- ===========================================================================
-- SBTF System — Phase 0.10
-- Row Level Security policies and privilege grants.
--
-- This file is the authoritative description of what each role may do. The
-- front-end performs the same checks for usability only; authorisation is
-- enforced here, in PostgreSQL, for every single request.
--
-- Design rules applied throughout:
--   1. Enable RLS on every table in the public schema.
--   2. Grant the narrowest column set possible; privileged columns (status,
--      role, account_status, verification_*) are simply not updatable by
--      clients — they move only through validated SECURITY DEFINER RPCs.
--   3. Tables that are workflow-managed (applications, records, history,
--      audit logs) are read-only for every client role.
-- ===========================================================================

-- --- enable RLS everywhere ---------------------------------------------------
alter table public.roles                      enable row level security;
alter table public.barangays                  enable row level security;
alter table public.system_settings            enable row level security;
alter table public.todas                      enable row level security;
alter table public.toda_members               enable row level security;
alter table public.profiles                   enable row level security;
alter table public.franchise_applications      enable row level security;
alter table public.franchise_documents         enable row level security;
alter table public.franchise_records           enable row level security;
alter table public.franchise_number_sequences  enable row level security;
alter table public.application_status_history  enable row level security;
alter table public.notifications               enable row level security;
alter table public.activity_logs               enable row level security;
alter table public.ai_request_logs             enable row level security;
alter table public.renewal_reminders_sent      enable row level security;

-- ---------------------------------------------------------------------------
-- Reference tables
-- ---------------------------------------------------------------------------
drop policy if exists "roles: authenticated may read the role catalogue" on public.roles;
create policy "roles: authenticated may read the role catalogue"
  on public.roles for select to authenticated
  using (true);

drop policy if exists "barangays: readable by anyone building an address" on public.barangays;
create policy "barangays: readable by anyone building an address"
  on public.barangays for select to anon, authenticated
  using (true);

-- The accredited TODA list is public information (it appears on application
-- forms and on the certificate).
drop policy if exists "todas: readable by anyone" on public.todas;
create policy "todas: readable by anyone"
  on public.todas for select to anon, authenticated
  using (true);

drop policy if exists "todas: administrators may add a TODA" on public.todas;
create policy "todas: administrators may add a TODA"
  on public.todas for insert to authenticated
  with check (public.is_admin());

drop policy if exists "todas: administrators may update a TODA" on public.todas;
create policy "todas: administrators may update a TODA"
  on public.todas for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "toda_members: staff may read the anonymised roster" on public.toda_members;
create policy "toda_members: staff may read the anonymised roster"
  on public.toda_members for select to authenticated
  using (public.is_staff_or_admin());

drop policy if exists "toda_members: administrators may manage the roster" on public.toda_members;
create policy "toda_members: administrators may manage the roster"
  on public.toda_members for insert to authenticated
  with check (public.is_admin());

drop policy if exists "toda_members: administrators may update the roster" on public.toda_members;
create policy "toda_members: administrators may update the roster"
  on public.toda_members for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- system_settings
-- ---------------------------------------------------------------------------
drop policy if exists "settings: authenticated may read settings" on public.system_settings;
create policy "settings: authenticated may read settings"
  on public.system_settings for select to authenticated
  using (true);

drop policy if exists "settings: administrators may update settings" on public.system_settings;
create policy "settings: administrators may update settings"
  on public.system_settings for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
drop policy if exists "profiles: users may read their own profile" on public.profiles;
create policy "profiles: users may read their own profile"
  on public.profiles for select to authenticated
  using (auth_user_id = auth.uid());

drop policy if exists "profiles: staff and administrators may read all profiles" on public.profiles;
create policy "profiles: staff and administrators may read all profiles"
  on public.profiles for select to authenticated
  using (public.is_staff_or_admin());

drop policy if exists "profiles: users may update their own profile" on public.profiles;
create policy "profiles: users may update their own profile"
  on public.profiles for update to authenticated
  using (auth_user_id = auth.uid() and public.is_active_account())
  with check (auth_user_id = auth.uid() and public.is_active_account());

drop policy if exists "profiles: administrators may update any profile" on public.profiles;
create policy "profiles: administrators may update any profile"
  on public.profiles for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- franchise_applications
-- Read-only for clients: submissions go through
-- rpc_driver_submit_application() and decisions through the staff RPCs.
-- ---------------------------------------------------------------------------
drop policy if exists "applications: drivers read their own applications" on public.franchise_applications;
create policy "applications: drivers read their own applications"
  on public.franchise_applications for select to authenticated
  using (applicant_id = public.current_profile_id());

drop policy if exists "applications: staff and administrators read all applications" on public.franchise_applications;
create policy "applications: staff and administrators read all applications"
  on public.franchise_applications for select to authenticated
  using (public.is_staff_or_admin());

-- ---------------------------------------------------------------------------
-- franchise_documents
-- ---------------------------------------------------------------------------
drop policy if exists "documents: drivers read their own application documents" on public.franchise_documents;
create policy "documents: drivers read their own application documents"
  on public.franchise_documents for select to authenticated
  using (
    exists (
      select 1 from public.franchise_applications a
       where a.id = application_id
         and a.applicant_id = public.current_profile_id()
    )
  );

drop policy if exists "documents: staff and administrators read all documents" on public.franchise_documents;
create policy "documents: staff and administrators read all documents"
  on public.franchise_documents for select to authenticated
  using (public.is_staff_or_admin());

-- Replacing a file is the only client write: the documentary record of a
-- submitted application may not be deleted, and verification columns are
-- excluded by the column grants below.
drop policy if exists "documents: drivers may replace a file while pending" on public.franchise_documents;
create policy "documents: drivers may replace a file while pending"
  on public.franchise_documents for update to authenticated
  using (
    exists (
      select 1 from public.franchise_applications a
       where a.id = application_id
         and a.applicant_id = public.current_profile_id()
         and a.status = 'pending'
    )
  )
  with check (
    exists (
      select 1 from public.franchise_applications a
       where a.id = application_id
         and a.applicant_id = public.current_profile_id()
         and a.status = 'pending'
    )
  );

-- ---------------------------------------------------------------------------
-- franchise_records
-- ---------------------------------------------------------------------------
drop policy if exists "records: drivers read their own franchise records" on public.franchise_records;
create policy "records: drivers read their own franchise records"
  on public.franchise_records for select to authenticated
  using (operator_id = public.current_profile_id());

drop policy if exists "records: staff and administrators read all franchise records" on public.franchise_records;
create policy "records: staff and administrators read all franchise records"
  on public.franchise_records for select to authenticated
  using (public.is_staff_or_admin());

-- ---------------------------------------------------------------------------
-- application_status_history — immutable timeline
-- ---------------------------------------------------------------------------
drop policy if exists "history: drivers read their own application timeline" on public.application_status_history;
create policy "history: drivers read their own application timeline"
  on public.application_status_history for select to authenticated
  using (
    exists (
      select 1 from public.franchise_applications a
       where a.id = application_id
         and a.applicant_id = public.current_profile_id()
    )
  );

drop policy if exists "history: staff and administrators read all timelines" on public.application_status_history;
create policy "history: staff and administrators read all timelines"
  on public.application_status_history for select to authenticated
  using (public.is_staff_or_admin());

-- ---------------------------------------------------------------------------
-- notifications — own rows only
-- ---------------------------------------------------------------------------
drop policy if exists "notifications: users read their own notifications" on public.notifications;
create policy "notifications: users read their own notifications"
  on public.notifications for select to authenticated
  using (user_id = public.current_profile_id());

drop policy if exists "notifications: users mark their own notifications" on public.notifications;
create policy "notifications: users mark their own notifications"
  on public.notifications for update to authenticated
  using (user_id = public.current_profile_id())
  with check (user_id = public.current_profile_id());

drop policy if exists "notifications: users delete their own notifications" on public.notifications;
create policy "notifications: users delete their own notifications"
  on public.notifications for delete to authenticated
  using (user_id = public.current_profile_id());

-- ---------------------------------------------------------------------------
-- activity_logs — readable in a strictly scoped way, never writable
-- ---------------------------------------------------------------------------
create or replace function public.fn_can_read_activity_log(
  p_log_user_id uuid,
  p_target_type public.log_target_type,
  p_target_id   uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    public.is_staff_or_admin()
    or p_log_user_id = public.current_profile_id()
    or (
      p_target_type = 'franchise_application'
      and exists (
        select 1 from public.franchise_applications a
         where a.id = p_target_id and a.applicant_id = public.current_profile_id()
      )
    )
    or (
      p_target_type = 'franchise_record'
      and exists (
        select 1 from public.franchise_records r
         where r.id = p_target_id and r.operator_id = public.current_profile_id()
      )
    )
    or (
      p_target_type = 'franchise_document'
      and exists (
        select 1
          from public.franchise_documents d
          join public.franchise_applications a on a.id = d.application_id
         where d.id = p_target_id and a.applicant_id = public.current_profile_id()
      )
    );
$$;

drop policy if exists "activity_logs: scoped read" on public.activity_logs;
create policy "activity_logs: scoped read"
  on public.activity_logs for select to authenticated
  using (public.fn_can_read_activity_log(user_id, target_type, target_id));

comment on policy "activity_logs: scoped read" on public.activity_logs is
  'Administrators and staff read the full trail; drivers see their own actions and events concerning their own records only.';

-- ---------------------------------------------------------------------------
-- ai_request_logs — administrators only
-- ---------------------------------------------------------------------------
drop policy if exists "ai_request_logs: administrators may read" on public.ai_request_logs;
create policy "ai_request_logs: administrators may read"
  on public.ai_request_logs for select to authenticated
  using (public.is_admin());

-- ===========================================================================
-- Privilege grants (defence in depth on top of RLS)
-- ===========================================================================

-- Start from a clean, least-privilege state for the client roles.
revoke all on table public.roles, public.barangays, public.system_settings,
                     public.todas, public.toda_members, public.profiles,
                     public.franchise_applications, public.franchise_documents,
                     public.franchise_records, public.franchise_number_sequences,
                     public.application_status_history, public.notifications,
                     public.activity_logs, public.ai_request_logs,
                     public.renewal_reminders_sent
  from anon, authenticated;

-- Reference data (read-only)
grant select on table public.roles, public.barangays, public.todas to anon, authenticated;
grant select on table public.toda_members, public.system_settings to authenticated;

-- Profile: clients may edit only descriptive columns. role, account_status,
-- status_reason, e-mail identity and audit columns are intentionally omitted —
-- they can only be changed through rpc_admin_set_user_role /
-- rpc_admin_set_account_status.
grant select on table public.profiles to authenticated;
grant update (first_name, middle_name, last_name, contact_number, address_line,
              barangay_code, toda_id, email_notifications, renewal_reminders)
  on table public.profiles to authenticated;

-- Application data (read-only; writes go through RPCs)
grant select on table public.franchise_applications, public.franchise_records,
                     public.application_status_history
  to authenticated;

-- Documents: read + replace the file only
grant select on table public.franchise_documents to authenticated;
grant update (storage_path, file_name, file_size_bytes, mime_type, uploaded_at)
  on table public.franchise_documents to authenticated;

-- Notifications: read, mark as read, delete own
grant select, delete on table public.notifications to authenticated;
grant update (read, read_at) on table public.notifications to authenticated;

-- Audit trail: read only, and only through the scoped RLS policy
grant select on table public.activity_logs, public.ai_request_logs to authenticated;

-- Settings: administrators update the value; the key set is fixed by migration
grant update (value) on table public.system_settings to authenticated;

-- TODA management by administrators (row access is gated by the policies above)
grant insert, update on table public.todas to authenticated;
grant insert, update on table public.toda_members to authenticated;

-- franchise_number_sequences and renewal_reminders_sent stay fully revoked:
-- they are internal bookkeeping tables.

-- --- function execution privileges ------------------------------------------
-- Internal helpers: revoke from every client role. They remain reachable from
-- triggers and from SECURITY DEFINER functions, which run as the owner.
revoke all on function public.fn_log_activity(uuid, public.activity_action, public.log_target_type, uuid, jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.fn_notify(uuid, text, text, public.notification_type, public.log_target_type, uuid) from public, anon, authenticated;
revoke all on function public.fn_notify_staff_and_admin(text, text, public.notification_type, public.log_target_type, uuid) from public, anon, authenticated;
revoke all on function public.fn_add_application_event(uuid, public.application_event, uuid, text) from public, anon, authenticated;
revoke all on function public.fn_next_sequence(text, integer) from public, anon, authenticated;
revoke all on function public.fn_generate_verification_code() from public, anon, authenticated;
revoke all on function public.fn_required_text(jsonb, text, integer, integer) from public, anon, authenticated;
revoke all on function public.fn_optional_text(jsonb, text, integer) from public, anon, authenticated;
revoke all on function public.fn_set_updated_at() from public, anon, authenticated;
revoke all on function public.fn_toda_sync_members_count() from public, anon, authenticated;
revoke all on function public.fn_handle_new_auth_user() from public, anon, authenticated;
revoke all on function public.fn_block_activity_log_mutation() from public, anon, authenticated;
revoke all on function public.fn_block_ai_log_mutation() from public, anon, authenticated;
revoke all on function public.fn_trg_application_created() from public, anon, authenticated;
revoke all on function public.fn_trg_application_status_changed() from public, anon, authenticated;
revoke all on function public.fn_trg_document_written() from public, anon, authenticated;
revoke all on function public.fn_trg_record_created() from public, anon, authenticated;
revoke all on function public.fn_trg_record_updated() from public, anon, authenticated;
revoke all on function public.fn_trg_profile_privilege_change() from public, anon, authenticated;
revoke all on function public.fn_trg_settings_change() from public, anon, authenticated;
revoke all on function public.fn_trg_settings_stamp() from public, anon, authenticated;

-- NOTE: functions referenced inside RLS policies (current_profile_id, is_admin,
-- is_staff, is_staff_or_admin, is_active_account, current_account_state,
-- current_user_role, fn_can_read_activity_log) intentionally keep EXECUTE for
-- anon/authenticated: PostgreSQL evaluates policy expressions with the
-- privileges of the role running the query, so revoking them would make the
-- policies themselves unrunnable. None of them leak information beyond the
-- caller's own authorisation context.
grant execute on function public.fn_can_read_activity_log(uuid, public.log_target_type, uuid) to authenticated;

-- Public API surface (each function re-validates the caller's role internally)
grant execute on function public.rpc_log_activity(public.activity_action, public.log_target_type, uuid, jsonb) to authenticated;
grant execute on function public.rpc_driver_submit_application(jsonb) to authenticated;
grant execute on function public.rpc_staff_start_review(uuid) to authenticated;
grant execute on function public.rpc_staff_verify_document(uuid, public.document_verification_status, text) to authenticated;
grant execute on function public.rpc_staff_approve_application(uuid) to authenticated;
grant execute on function public.rpc_staff_reject_application(uuid, text) to authenticated;
grant execute on function public.rpc_staff_attach_certificate(uuid, text) to authenticated;
grant execute on function public.rpc_staff_archive_franchise_record(uuid, text, boolean) to authenticated;
grant execute on function public.rpc_admin_set_user_role(uuid, public.user_role) to authenticated;
grant execute on function public.rpc_admin_set_account_status(uuid, public.account_status, text) to authenticated;
grant execute on function public.rpc_analytics_overview() to authenticated;
grant execute on function public.rpc_analytics_application_trends(integer) to authenticated;
grant execute on function public.rpc_analytics_by_toda() to authenticated;
grant execute on function public.rpc_analytics_processing_time(integer) to authenticated;
grant execute on function public.rpc_analytics_expiring(integer) to authenticated;
grant execute on function public.rpc_analytics_document_compliance() to authenticated;
grant execute on function public.rpc_analytics_prescriptive() to authenticated;
grant execute on function public.rpc_analytics_ai_context(integer) to authenticated;
grant execute on function public.rpc_analytics_system_health() to authenticated;
grant execute on function public.rpc_verify_certificate(text) to anon, authenticated;

-- Recurring job: server-side only.
revoke all on function public.rpc_generate_renewal_reminders(integer[]) from public, anon, authenticated;
grant execute on function public.rpc_generate_renewal_reminders(integer[]) to service_role;
