-- ===========================================================================
-- SBTF System — Phase 3.2
-- Saved AI briefings.
--
-- A briefing costs one model call and four to five seconds, but until now it
-- lived only in React state, so a page refresh threw it away. Each staff member
-- and administrator now keeps their most recent briefing for 24 hours, and
-- generating a new one replaces it immediately.
--
-- Reads are protected by RLS: a caller only sees their own row. Every write
-- comes from the ai-decision-support Edge Function with the service role, so
-- the table deliberately has no insert, update or delete policy.
-- ===========================================================================

create table if not exists public.ai_briefings (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references public.profiles (id) on delete cascade,
  payload       jsonb not null,
  model         text not null,
  period_months integer not null check (period_months between 1 and 24),
  generated_at  timestamptz not null default now(),
  expires_at    timestamptz not null,
  created_at    timestamptz not null default now(),
  constraint ai_briefings_requester_key unique (requester_id)
);

comment on table public.ai_briefings is
  'Most recent AI advisory briefing per user, served for 24 hours. Built from aggregated statistics only; written by the ai-decision-support Edge Function.';

comment on column public.ai_briefings.payload is
  'The exact JSON response returned to the browser, so a refresh renders the same briefing without spending another model call.';

create index if not exists ai_briefings_expires_idx on public.ai_briefings (expires_at);

alter table public.ai_briefings enable row level security;

drop policy if exists "ai_briefings: owners read their own" on public.ai_briefings;
create policy "ai_briefings: owners read their own"
  on public.ai_briefings for select to authenticated
  using (requester_id = public.current_profile_id());

revoke all on table public.ai_briefings from public, anon, authenticated;
grant select on table public.ai_briefings to authenticated;
grant all on table public.ai_briefings to service_role;
