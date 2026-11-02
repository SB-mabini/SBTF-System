-- Push notification device tokens for mobile app
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_profile_idx on public.device_tokens (profile_id);

alter table public.device_tokens enable row level security;

create policy "device_tokens_insert_own"
  on public.device_tokens for insert
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = profile_id
        and p.auth_user_id = auth.uid()
    )
  );

create policy "device_tokens_update_own"
  on public.device_tokens for update
  using (
    exists (
      select 1 from public.profiles p
      where p.id = profile_id
        and p.auth_user_id = auth.uid()
    )
  );

create policy "device_tokens_delete_own"
  on public.device_tokens for delete
  using (
    exists (
      select 1 from public.profiles p
      where p.id = profile_id
        and p.auth_user_id = auth.uid()
    )
  );
