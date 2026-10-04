-- ===========================================================================
-- SBTF System — Phase 0.7
-- Auditing, notification and timeline triggers.
--
-- Division of responsibility (single source of truth per concern):
--   * triggers  → write audit logs, create notifications, extend the timeline
--                 for every table mutation, including mutations performed
--                 outside the API (SQL console, service role, migrations);
--   * RPCs      → validate business rules and guarantee atomicity.
--   * RPCs never write audit rows for the same event a trigger already covers,
--     so the audit trail cannot contain duplicates.
-- ===========================================================================

-- --- franchise_applications: submitted --------------------------------------
create or replace function public.fn_trg_application_created()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_toda  text;
begin
  select name into v_toda from public.todas where id = new.toda_id;

  perform public.fn_add_application_event(new.id, 'created', v_actor, 'Application submitted');

  perform public.fn_log_activity(
    coalesce(v_actor, new.applicant_id),
    case when new.application_type = 'renewal'
         then 'application_renewal_submitted'::public.activity_action
         else 'application_submitted'::public.activity_action end,
    'franchise_application',
    new.id,
    jsonb_build_object(
      'application_number', new.application_number,
      'application_type', new.application_type,
      'toda', v_toda,
      'plate_number', new.plate_number
    )
  );

  perform public.fn_notify_staff_and_admin(
    'New ' || new.application_type || ' franchise application',
    'Application ' || new.application_number || ' was submitted for ' || coalesce(v_toda, 'an unlisted TODA') || '.',
    'application_submitted',
    'franchise_application',
    new.id
  );

  return new;
end;
$$;

drop trigger if exists trg_application_created on public.franchise_applications;
create trigger trg_application_created
  after insert on public.franchise_applications
  for each row execute function public.fn_trg_application_created();

-- --- franchise_applications: approved / rejected -----------------------------
create or replace function public.fn_trg_application_status_changed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
  v_franchise_number text;
  v_note text;
begin
  -- Only react to real status transitions, including by the service role.
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'approved' then
    select franchise_number into v_franchise_number
      from public.franchise_records where application_id = new.id;

    perform public.fn_add_application_event(new.id, 'approved', coalesce(v_actor, new.reviewed_by), v_franchise_number);
    perform public.fn_log_activity(
      coalesce(v_actor, new.reviewed_by),
      'application_approved',
      'franchise_application',
      new.id,
      jsonb_build_object('application_number', new.application_number, 'franchise_number', v_franchise_number)
    );
    perform public.fn_notify(
      new.applicant_id,
      'Franchise application approved',
      'Your ' || new.application_type || ' franchise application ' || new.application_number ||
      ' has been approved.' || coalesce(' Franchise number: ' || v_franchise_number || '.', ''),
      'application_approved',
      'franchise_application',
      new.id
    );

  elsif new.status = 'rejected' then
    v_note := nullif(btrim(coalesce(new.rejection_reason, '')), '');
    perform public.fn_add_application_event(new.id, 'rejected', coalesce(v_actor, new.reviewed_by), v_note);
    perform public.fn_log_activity(
      coalesce(v_actor, new.reviewed_by),
      'application_rejected',
      'franchise_application',
      new.id,
      jsonb_build_object('application_number', new.application_number, 'reason', v_note)
    );
    perform public.fn_notify(
      new.applicant_id,
      'Franchise application rejected',
      'Your ' || new.application_type || ' franchise application ' || new.application_number ||
      ' was rejected. Reason: ' || coalesce(v_note, 'not specified'),
      'application_rejected',
      'franchise_application',
      new.id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_application_status_changed on public.franchise_applications;
create trigger trg_application_status_changed
  after update on public.franchise_applications
  for each row execute function public.fn_trg_application_status_changed();

-- --- franchise_documents ----------------------------------------------------
create or replace function public.fn_trg_document_written()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor     uuid := public.current_profile_id();
  v_applicant uuid;
  v_app_number text;
  v_label     text;
begin
  select applicant_id, application_number into v_applicant, v_app_number
    from public.franchise_applications where id = new.application_id;

  v_label := replace(new.document_type::text, '_', ' ');

  if tg_op = 'INSERT' then
    perform public.fn_add_application_event(new.application_id, 'document_uploaded', v_actor, v_label);
    perform public.fn_log_activity(
      coalesce(v_actor, v_applicant),
      'document_upload',
      'franchise_document',
      new.id,
      jsonb_build_object('application_number', v_app_number, 'document_type', new.document_type)
    );
    perform public.fn_notify_staff_and_admin(
      'Document uploaded',
      v_label || ' was uploaded for application ' || v_app_number || '.',
      'application_submitted',
      'franchise_document',
      new.id
    );
    return new;
  end if;

  -- UPDATE: a replaced file is recorded before verification transitions.
  if new.storage_path is distinct from old.storage_path then
    perform public.fn_add_application_event(new.application_id, 'document_replaced', v_actor, v_label);
    perform public.fn_log_activity(
      coalesce(v_actor, v_applicant),
      'document_replaced',
      'franchise_document',
      new.id,
      jsonb_build_object('application_number', v_app_number, 'document_type', new.document_type)
    );
  end if;

  if new.verification_status is not distinct from old.verification_status then
    return new;
  end if;

  if new.verification_status = 'pending' then
    perform public.fn_add_application_event(new.application_id, 'document_replaced', v_actor, v_label || ' verification reset');
    return new;
  end if;

  perform public.fn_add_application_event(
    new.application_id,
    case when new.verification_status = 'verified' then 'document_verified' else 'document_rejected' end,
    coalesce(v_actor, new.verified_by),
    v_label
  );
  perform public.fn_log_activity(
    coalesce(v_actor, new.verified_by),
    'document_verification',
    'franchise_document',
    new.id,
    jsonb_build_object(
      'application_number', v_app_number,
      'document_type', new.document_type,
      'verification_status', new.verification_status,
      'remarks', new.remarks
    )
  );
  perform public.fn_notify(
    v_applicant,
    case when new.verification_status = 'verified' then 'Document verified' else 'Document needs attention' end,
    initcap(v_label) ||
    case when new.verification_status = 'verified'
         then ' was verified for application ' || v_app_number || '.'
         else ' was rejected for application ' || v_app_number || '. ' || coalesce('Remarks: ' || new.remarks, 'Please upload a corrected copy.')
    end,
    case when new.verification_status = 'verified'
         then 'document_verified'::public.notification_type
         else 'document_rejected'::public.notification_type end,
    'franchise_application',
    new.application_id
  );

  return new;
end;
$$;

drop trigger if exists trg_document_written on public.franchise_documents;
create trigger trg_document_written
  after insert or update on public.franchise_documents
  for each row execute function public.fn_trg_document_written();

-- --- franchise_records ------------------------------------------------------
create or replace function public.fn_trg_record_created()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
begin
  perform public.fn_log_activity(
    v_actor,
    'record_created',
    'franchise_record',
    new.id,
    jsonb_build_object(
      'franchise_number', new.franchise_number,
      'issued_at', new.issued_at,
      'expires_at', new.expires_at
    )
  );

  perform public.fn_add_application_event(new.application_id, 'certificate_issued', v_actor, new.franchise_number);

  return new;
end;
$$;

drop trigger if exists trg_record_created on public.franchise_records;
create trigger trg_record_created
  after insert on public.franchise_records
  for each row execute function public.fn_trg_record_created();

create or replace function public.fn_trg_record_updated()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
begin
  -- Certificate attachment
  if new.certificate_storage_path is distinct from old.certificate_storage_path
     and new.certificate_storage_path is not null then
    perform public.fn_log_activity(
      v_actor,
      'certificate_generation',
      'franchise_record',
      new.id,
      jsonb_build_object('franchise_number', new.franchise_number, 'storage_path', new.certificate_storage_path)
    );
    perform public.fn_notify(
      new.operator_id,
      'Certificate ready',
      'The franchise certificate for ' || new.franchise_number || ' is now available in your account.',
      'system',
      'franchise_record',
      new.id
    );
  end if;

  -- Archiving
  if new.archived and not old.archived then
    perform public.fn_log_activity(
      v_actor,
      'franchise_archived',
      'franchise_record',
      new.id,
      jsonb_build_object('franchise_number', new.franchise_number, 'reason', new.archive_reason)
    );
    perform public.fn_add_application_event(new.application_id, 'archived', v_actor, new.archive_reason);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_record_updated on public.franchise_records;
create trigger trg_record_updated
  after update on public.franchise_records
  for each row execute function public.fn_trg_record_updated();

-- --- profiles: role / account status changes --------------------------------
create or replace function public.fn_trg_profile_privilege_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := public.current_profile_id();
begin
  if new.role is distinct from old.role then
    perform public.fn_log_activity(
      v_actor, 'role_change', 'profile', new.id,
      jsonb_build_object('from', old.role, 'to', new.role)
    );
    perform public.fn_notify(
      new.id,
      'Account role updated',
      'Your system role was changed from ' || old.role || ' to ' || new.role || '.',
      'account_updated',
      'profile',
      new.id
    );
  end if;

  if new.account_status is distinct from old.account_status then
    perform public.fn_log_activity(
      v_actor,
      case when new.account_status = 'active'
           then 'user_activated'::public.activity_action
           else 'user_deactivated'::public.activity_action end,
      'profile', new.id,
      jsonb_build_object('from', old.account_status, 'to', new.account_status, 'reason', new.status_reason)
    );
    perform public.fn_notify(
      new.id,
      'Account status updated',
      'Your account status is now "' || new.account_status || '".' ||
      coalesce(' Reason: ' || nullif(btrim(coalesce(new.status_reason, '')), '') || '.', ''),
      'account_updated',
      'profile',
      new.id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_profile_privilege_change on public.profiles;
create trigger trg_profile_privilege_change
  after update on public.profiles
  for each row execute function public.fn_trg_profile_privilege_change();

-- --- system_settings --------------------------------------------------------
create or replace function public.fn_trg_settings_stamp()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  new.updated_by := coalesce(public.current_profile_id(), new.updated_by);
  return new;
end;
$$;

drop trigger if exists trg_settings_stamp on public.system_settings;
create trigger trg_settings_stamp
  before update on public.system_settings
  for each row execute function public.fn_trg_settings_stamp();

create or replace function public.fn_trg_settings_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.fn_log_activity(
    coalesce(public.current_profile_id(), new.updated_by),
    'settings_update',
    'system_setting',
    null,
    jsonb_build_object('key', new.key, 'old_value', old.value, 'new_value', new.value)
  );
  return new;
end;
$$;

drop trigger if exists trg_settings_change on public.system_settings;
create trigger trg_settings_change
  after update on public.system_settings
  for each row execute function public.fn_trg_settings_change();
