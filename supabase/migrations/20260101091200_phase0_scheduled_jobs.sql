-- ===========================================================================
-- SBTF System — Phase 0.13
-- Scheduled renewal reminders (90 / 60 / 30 days before expiry).
--
-- Implemented as a server-side scheduled database job, not as a client action:
-- the reminder routine only READs franchise records and only INSERTs
-- notifications. It never approves, renews, expires or otherwise modifies a
-- franchise record.
--
-- An equivalent Supabase Edge Function (supabase/functions/renewal-reminders)
-- is provided for deployments that prefer Edge scheduling; both paths call the
-- same rpc_generate_renewal_reminders() routine and are idempotent.
-- ===========================================================================

do $$
begin
  begin
    create extension if not exists pg_cron;
  exception
    when insufficient_privilege then
      raise notice 'pg_cron could not be enabled by this role; enable it from the Supabase dashboard and re-run the schedule block below.';
    when others then
      raise notice 'pg_cron unavailable (%); scheduled reminders will rely on the Edge Function instead.', sqlerrm;
  end;

  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'sbtf-renewal-reminders') then
      perform cron.unschedule('sbtf-renewal-reminders');
    end if;

    -- Daily at 01:15 server time.
    perform cron.schedule(
      'sbtf-renewal-reminders',
      '15 1 * * *',
      $cron$select public.rpc_generate_renewal_reminders(array[90, 60, 30])$cron$
    );

    raise notice 'Scheduled job sbtf-renewal-reminders created (daily 01:15).';
  else
    raise notice 'Scheduled job skipped: pg_cron is not enabled on this database.';
  end if;
end
$$;
