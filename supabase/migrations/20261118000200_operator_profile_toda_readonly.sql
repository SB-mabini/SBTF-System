-- Operator profile module: the TODA is authoritative, not self-editable.
--
-- Phase 0 granted `authenticated` UPDATE on every descriptive profile column,
-- including `toda_id`. The interface never offered it, but a crafted REST call
-- could still move a driver between associations — which changes franchise
-- jurisdiction, membership and reporting. Narrow the grant so only the fields
-- the profile form owns remain writable; `toda_id` is set at registration and
-- managed through the administrative workflow.
--
-- The administrator policy on `public.profiles` is unchanged: it still decides
-- which rows an administrator may touch, while this grant decides which columns
-- any client may write at all.

revoke update (
  first_name,
  middle_name,
  last_name,
  contact_number,
  address_line,
  barangay_code,
  toda_id,
  email_notifications,
  renewal_reminders
) on table public.profiles from authenticated;

grant update (
  first_name,
  middle_name,
  last_name,
  contact_number,
  address_line,
  barangay_code,
  email_notifications,
  renewal_reminders
) on table public.profiles to authenticated;
