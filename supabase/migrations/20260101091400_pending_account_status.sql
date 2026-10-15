-- ===========================================================================
-- SBTF System — Phase 0.14
-- Pending account status for administrator-created staff accounts.
--
-- A staff account created from the admin console must be APPROVED by an
-- administrator before it can be used. Until then the profile is `pending`:
-- the holder has no usable identity (RLS resolves nothing) and the console
-- refuses to issue a password recovery link.
--
-- Contrast with the other states:
--   active    = may use the system
--   pending   = invited, awaiting administrator approval
--   inactive  = voluntarily disabled
--   suspended = administratively blocked
--
-- `pending` is never hand-assigned from the UI; it is written by the
-- `admin-users` Edge Function (service role) at account creation, and cleared by
-- `rpc_admin_set_account_status` when an administrator approves the account.
-- ===========================================================================

alter type public.account_status add value if not exists 'pending';

comment on type public.account_status is
  'active = may use the system; pending = invited, awaiting administrator approval; '
  'inactive = voluntarily disabled; suspended = administratively blocked.';
