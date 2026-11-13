-- ===========================================================================
-- SBTF System — Account purge (part 1 of 2)
--
-- Adds the activity action written by the administrator-only purge RPC.
--
-- This is deliberately a separate migration: PostgreSQL will not let a new
-- enum value be used in the same transaction that adds it, and
-- 20261113000200_admin_purge_account.sql references it at runtime.
-- ===========================================================================

alter type public.activity_action add value if not exists 'user_purged';

comment on type public.activity_action is
  'Actions recorded in the append-only activity log. user_purged records an '
  'administrator permanently erasing an account and its connected data.';
