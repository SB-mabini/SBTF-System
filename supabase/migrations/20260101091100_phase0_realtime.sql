-- ===========================================================================
-- SBTF System — Phase 0.12
-- Supabase Realtime publication.
--
-- Realtime applies the same Row Level Security policies as normal queries, so
-- a driver only ever receives change events for rows their policies expose.
--
--   Driver submits application  → staff dashboard updates live
--   Staff approves / rejects    → driver mobile app updates live
--   New notification            → driver badge updates live
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
    'public.franchise_applications',
    'public.franchise_documents',
    'public.franchise_records',
    'public.notifications'
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

-- UPDATE payloads must carry the identity of the changed row for the clients to
-- reconcile their state (default already includes the primary key, this makes
-- the intent explicit for the tables whose status changes are user-facing).
alter table public.franchise_applications replica identity default;
alter table public.franchise_records replica identity default;
alter table public.notifications replica identity default;
