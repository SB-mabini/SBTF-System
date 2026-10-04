-- ===========================================================================
-- SBTF System — Phase 0.5
-- Notifications, activity logging and AI request logging.
--
-- Activity logs are append-only: they can never be updated or deleted by any
-- client role, and no UPDATE/DELETE policy exists for them at all.
--
-- AI request logs deliberately store no prompt text and no personal data —
-- only hashes, model metadata and timing information.
-- ===========================================================================

-- --- notifications ----------------------------------------------------------
create table if not exists public.notifications (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles (id) on delete cascade,
  title             text not null check (length(btrim(title)) between 1 and 120),
  message           text not null check (length(btrim(message)) between 1 and 1000),
  notification_type public.notification_type not null,
  -- Optional deep-link target so the mobile app can navigate to the record
  target_type       public.log_target_type,
  target_id         uuid,
  read              boolean not null default false,
  read_at           timestamptz,
  created_at        timestamptz not null default now()
);

comment on table public.notifications is
  'In-app notification feed. Created by SECURITY DEFINER functions and triggers; clients may only mark their own notifications as read or delete them.';

create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index if not exists notifications_unread_idx on public.notifications (user_id) where read = false;

-- --- activity_logs ----------------------------------------------------------
create table if not exists public.activity_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.profiles (id) on delete set null,
  action      public.activity_action not null,
  target_type public.log_target_type,
  target_id   uuid,
  metadata    jsonb not null default '{}'::jsonb,
  -- Coarse, non-identifying request context (never the IP address itself).
  context     jsonb not null default '{}'::jsonb,
  "timestamp" timestamptz not null default now()
);

comment on table public.activity_logs is
  'Append-only audit trail. Protected by RLS (SELECT only) and by a trigger that rejects UPDATE/DELETE attempts from any non-owner role.';

create index if not exists activity_logs_user_idx on public.activity_logs (user_id, "timestamp" desc);
create index if not exists activity_logs_action_idx on public.activity_logs (action);
create index if not exists activity_logs_target_idx on public.activity_logs (target_type, target_id);
create index if not exists activity_logs_timestamp_idx on public.activity_logs ("timestamp" desc);

-- Explicit tamper protection: activity logs are immutable once written.
create or replace function public.fn_block_activity_log_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'activity_logs is append-only: % is not permitted', tg_op
    using errcode = 'insufficient_privilege';
end;
$$;

comment on function public.fn_block_activity_log_mutation() is
  'Second line of defence (beyond RLS) making activity_logs immutable.';

drop trigger if exists trg_activity_logs_immutable on public.activity_logs;
create trigger trg_activity_logs_immutable
  before update or delete on public.activity_logs
  for each row execute function public.fn_block_activity_log_mutation();

-- --- ai_request_logs --------------------------------------------------------
create table if not exists public.ai_request_logs (
  id             uuid primary key default gen_random_uuid(),
  requester_id   uuid references public.profiles (id) on delete set null,
  requested_by_role public.user_role,
  purpose        text not null default 'decision_support',
  model          text not null,
  prompt_hash    text not null,
  context_hash   text not null,
  context_summary jsonb not null default '{}'::jsonb,
  status         text not null check (status in ('success', 'error', 'rejected')),
  error_code     text,
  latency_ms     integer check (latency_ms is null or latency_ms >= 0),
  prompt_tokens  integer check (prompt_tokens is null or prompt_tokens >= 0),
  output_tokens  integer check (output_tokens is null or output_tokens >= 0),
  created_at     timestamptz not null default now()
);

comment on table public.ai_request_logs is
  'Audit metadata for AI decision-support calls. No prompt text, no personal data: prompt and context are stored as SHA-256 hashes only, and context_summary holds aggregate counts exclusively.';

create index if not exists ai_request_logs_created_idx on public.ai_request_logs (created_at desc);
create index if not exists ai_request_logs_requester_idx on public.ai_request_logs (requester_id, created_at desc);

create or replace function public.fn_block_ai_log_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'ai_request_logs is append-only: % is not permitted', tg_op
    using errcode = 'insufficient_privilege';
end;
$$;

drop trigger if exists trg_ai_request_logs_immutable on public.ai_request_logs;
create trigger trg_ai_request_logs_immutable
  before update or delete on public.ai_request_logs
  for each row execute function public.fn_block_ai_log_mutation();
