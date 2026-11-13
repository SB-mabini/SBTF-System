-- ===========================================================================
-- Fix: let drivers read announcements addressed to them
--
-- RLS policy expressions run with the caller's privileges. The driver policy
-- previously called fn_announcement_recipients(uuid), but EXECUTE on that
-- helper is intentionally revoked from authenticated users (it returns the
-- full recipient list). The result was "permission denied for function
-- fn_announcement_recipients" / HTTP 401 for every driver query.
--
-- Expose a boolean predicate instead. It reveals only whether the current
-- caller is addressed by the announcement, never the recipient list.
-- ===========================================================================

create or replace function public.fn_is_announcement_recipient(p_announcement_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.fn_announcement_recipients(p_announcement_id) r
     where r.profile_id = public.current_profile_id()
  );
$$;

comment on function public.fn_is_announcement_recipient(uuid) is
  'True when the current user is an addressed recipient of the announcement. Safe for RLS policies.';

revoke all on function public.fn_is_announcement_recipient(uuid)
  from public, anon, authenticated;
grant execute on function public.fn_is_announcement_recipient(uuid) to authenticated;

drop policy if exists "announcements: drivers read addressed published rows" on public.announcements;
create policy "announcements: drivers read addressed published rows"
  on public.announcements for select to authenticated
  using (
    status = 'published'
    and public.fn_is_announcement_recipient(id)
  );
