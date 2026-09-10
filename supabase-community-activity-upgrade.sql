-- Kanal üyelerinin aktif Pomodoro ve kronometre durumları.
create table if not exists public.community_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  channel_id uuid not null references public.channels(id) on delete cascade,
  active boolean not null default false,
  mode text check (mode in ('pomodoro','stopwatch')),
  started_at timestamptz,
  ends_at timestamptz,
  duration_seconds integer,
  updated_at timestamptz not null default now()
);
alter table public.community_presence enable row level security;
alter table public.community_presence add column if not exists duration_seconds integer;
drop policy if exists "channel members read presence" on public.community_presence;
drop policy if exists "users manage own presence" on public.community_presence;
create policy "channel members read presence" on public.community_presence for select using (public.is_channel_member(channel_id));
create policy "users manage own presence" on public.community_presence for all using (user_id=auth.uid()) with check (user_id=auth.uid() and public.is_channel_member(channel_id));
