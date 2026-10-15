-- ===========================================================================
-- SBTF System — Phase 1.1
-- Workflow enumerated types for the staff-driven franchising process
-- (docs/process.md): a processing pipeline (stage) distinct from the decision
-- outcome (status stays pending/approved/rejected), form requests, scheduled
-- appointments/hearings and document release.
--
-- Enum VALUE additions live in this file and are referenced only from later
-- migrations, because a value added by ALTER TYPE ... ADD VALUE may not be used
-- in the same transaction that adds it.
-- ===========================================================================

-- --- processing pipeline ----------------------------------------------------
-- The staff-facing progression of an application. `status` remains the
-- decision outcome (pending/approved/rejected) so analytics, the driver tracker
-- and existing constraints keep working unchanged.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'application_stage') then
    create type public.application_stage as enum (
      'submitted',
      'under_verification',
      'for_compliance',
      'verified',
      'recorded',
      'for_endorsement',
      'for_approval',
      'ready_for_release',
      'released',
      'completed',
      'rejected'
    );
  end if;
end
$$;

comment on type public.application_stage is
  'Processing pipeline shown to staff (docs/process.md). Decision outcome remains application_status.';

-- --- form requests ----------------------------------------------------------
-- A request for an application form issued BEFORE a formal application exists.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'form_request_status') then
    create type public.form_request_status as enum (
      'requested',
      'issued',
      'converted',
      'cancelled'
    );
  end if;
end
$$;

comment on type public.form_request_status is
  'Lifecycle of a pre-application form request: requested → issued → converted (or cancelled).';

-- --- appointments / hearings ------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'appointment_kind') then
    create type public.appointment_kind as enum (
      'evaluation',
      'physical_documents',
      'hearing',
      'release',
      'other'
    );
  end if;
end
$$;

comment on type public.appointment_kind is
  'The kind of in-person appointment scheduled for an application.';

do $$
begin
  if not exists (select 1 from pg_type where typname = 'appointment_status') then
    create type public.appointment_status as enum (
      'scheduled',
      'completed',
      'no_show',
      'rescheduled',
      'cancelled'
    );
  end if;
end
$$;

comment on type public.appointment_status is
  'Outcome state of a scheduled appointment.';

-- --- application timeline events --------------------------------------------
alter type public.application_event add value if not exists 'stage_changed';
alter type public.application_event add value if not exists 'appointment_scheduled';
alter type public.application_event add value if not exists 'appointment_completed';
alter type public.application_event add value if not exists 'endorsement_recorded';
alter type public.application_event add value if not exists 'decision_recorded';
alter type public.application_event add value if not exists 'document_released';

-- --- notifications ----------------------------------------------------------
alter type public.notification_type add value if not exists 'application_stage_changed';
alter type public.notification_type add value if not exists 'form_request_received';
alter type public.notification_type add value if not exists 'form_request_issued';
alter type public.notification_type add value if not exists 'appointment_scheduled';
alter type public.notification_type add value if not exists 'appointment_updated';
alter type public.notification_type add value if not exists 'document_release_ready';

-- --- audit actions ----------------------------------------------------------
alter type public.activity_action add value if not exists 'stage_changed';
alter type public.activity_action add value if not exists 'appointment_scheduled';
alter type public.activity_action add value if not exists 'appointment_updated';
alter type public.activity_action add value if not exists 'form_request_created';
alter type public.activity_action add value if not exists 'form_request_issued';
alter type public.activity_action add value if not exists 'endorsement_recorded';
alter type public.activity_action add value if not exists 'decision_recorded';
alter type public.activity_action add value if not exists 'document_released';

-- --- audit targets ----------------------------------------------------------
alter type public.log_target_type add value if not exists 'form_request';
alter type public.log_target_type add value if not exists 'appointment';
alter type public.log_target_type add value if not exists 'document_release';
