-- ===========================================================================
-- SBTF System — Phase 0.1
-- Extensions and enumerated domain types
-- Municipality of Mabini, Batangas
--
-- Idempotent-by-design: safe to re-run against a database where a previous
-- partial apply happened.
-- ===========================================================================

-- --- Extensions -------------------------------------------------------------
-- pgcrypto: gen_random_uuid(), digest() and HMAC helpers used for hashing
--   anonymised AI request metadata.
create extension if not exists pgcrypto with schema extensions;

-- --- Enum types -------------------------------------------------------------
-- Exactly three roles exist in this system (specification §5).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type public.user_role as enum ('administrator', 'staff', 'driver');
  end if;
end
$$;

-- Account lifecycle. "inactive" = temporarily disabled, "suspended" =
-- disciplinary lock. Both are enforced by Row Level Security, never by UI only.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'account_status') then
    create type public.account_status as enum ('active', 'inactive', 'suspended');
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'application_type') then
    create type public.application_type as enum ('new', 'renewal');
  end if;
end
$$;

-- The specification fixes exactly three application statuses.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'application_status') then
    create type public.application_status as enum ('pending', 'approved', 'rejected');
  end if;
end
$$;

-- Four required documentary requirements for a tricycle franchise.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'document_type') then
    create type public.document_type as enum (
      'member_association_certificate',
      'or_cr',
      'cedula',
      'barangay_clearance'
    );
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'document_verification_status') then
    create type public.document_verification_status as enum ('pending', 'verified', 'rejected');
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'notification_type') then
    create type public.notification_type as enum (
      'application_submitted',
      'application_approved',
      'application_rejected',
      'document_verified',
      'document_rejected',
      'renewal_reminder',
      'application_under_review',
      'account_updated',
      'system'
    );
  end if;
end
$$;

-- Every auditable event type required by specification §6.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'activity_action') then
    create type public.activity_action as enum (
      'login',
      'logout',
      'registration',
      'profile_update',
      'notification_preferences_update',
      'application_submitted',
      'application_renewal_submitted',
      'document_upload',
      'document_replaced',
      'document_verification',
      'review_started',
      'application_approved',
      'application_rejected',
      'record_created',
      'record_update',
      'franchise_archived',
      'certificate_generation',
      'role_change',
      'user_activated',
      'user_deactivated',
      'user_created',
      'settings_update',
      'ai_request',
      'renewal_reminder_sent',
      'security_event'
    );
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'log_target_type') then
    create type public.log_target_type as enum (
      'profile',
      'franchise_application',
      'franchise_document',
      'franchise_record',
      'system_setting',
      'toda',
      'system'
    );
  end if;
end
$$;

-- Timeline events shown in the driver application tracker (specification §3.8).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'application_event') then
    create type public.application_event as enum (
      'created',
      'document_uploaded',
      'document_replaced',
      'document_verified',
      'document_rejected',
      'review_started',
      'approved',
      'rejected',
      'certificate_issued',
      'archived'
    );
  end if;
end
$$;

-- Certificate verification outcome (QR scanning, specification §3.12).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'certificate_verification_status') then
    create type public.certificate_verification_status as enum ('valid', 'expired', 'archived', 'not_found');
  end if;
end
$$;

comment on type public.user_role is 'Exactly three system roles: administrator, staff, driver.';
comment on type public.application_status is 'Pending / Approved / Rejected as fixed by the system specification.';
