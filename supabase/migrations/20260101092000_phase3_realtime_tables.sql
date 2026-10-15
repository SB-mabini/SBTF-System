-- ===========================================================================
-- SBTF System — Phase 3.1
-- Realtime publication for the Phase 1 workflow tables.
--
-- The Phase 0 publication covered the four tables that existed then. Appointments,
-- form requests and document releases now mutate from the staff console, so an
-- open console must receive their change events to stay current without a manual
-- refresh. Subscriptions still honour RLS: an administrator or staff session only
-- receives rows its policies expose.
-- ===========================================================================

do $$
declare
  v_table text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'Publication supabase_realtime not present; skipping realtime setup.';
    return;
  end if;

  foreach v_table in array array[
    'public.application_appointments',
    'public.form_requests',
    'public.document_releases'
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table %s', v_table);
    exception
      when duplicate_object then
        -- Already part of the publication.
        null;
      when undefined_table then
        raise notice 'Table % is missing; skipped from realtime publication.', v_table;
    end;
  end loop;
end
$$;

-- UPDATE payloads carry the identity of the changed row so clients reconcile.
alter table public.application_appointments replica identity default;
alter table public.form_requests replica identity default;
alter table public.document_releases replica identity default;
