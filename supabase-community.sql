-- YKS Silkici canlı topluluk altyapısı. Supabase SQL Editor'de tek sefer çalıştır.
create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 3 and 60), description text default '',
  privacy text not null default 'public' check (privacy in ('public','invite','private')),
  created_at timestamptz not null default now()
);
create table if not exists public.channel_members (
  channel_id uuid references public.channels(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade, role text not null default 'member' check (role in ('owner','moderator','member')),
  joined_at timestamptz not null default now(), primary key(channel_id,user_id)
);
create table if not exists public.study_rooms (
  id uuid primary key default gen_random_uuid(), channel_id uuid not null references public.channels(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade, name text not null check (char_length(name) between 3 and 60),
  description text default '', created_at timestamptz not null default now()
);
create table if not exists public.room_messages (
  id uuid primary key default gen_random_uuid(), room_id uuid not null references public.study_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade, body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
alter table public.channels enable row level security;
alter table public.channel_members enable row level security;
alter table public.study_rooms enable row level security;
alter table public.room_messages enable row level security;
create policy "public channels readable" on public.channels for select using (privacy='public' or owner_id=auth.uid() or exists(select 1 from public.channel_members m where m.channel_id=id and m.user_id=auth.uid()));
create policy "users create channels" on public.channels for insert with check (owner_id=auth.uid());
create policy "members read membership" on public.channel_members for select using (user_id=auth.uid() or exists(select 1 from public.channel_members m where m.channel_id=channel_id and m.user_id=auth.uid()));
create policy "channel owners manage members" on public.channel_members for all using (exists(select 1 from public.channels c where c.id=channel_id and c.owner_id=auth.uid()));
create policy "members read rooms" on public.study_rooms for select using (exists(select 1 from public.channel_members m where m.channel_id=study_rooms.channel_id and m.user_id=auth.uid()));
create policy "members create rooms" on public.study_rooms for insert with check (owner_id=auth.uid() and exists(select 1 from public.channel_members m where m.channel_id=channel_id and m.user_id=auth.uid()));
create policy "members read messages" on public.room_messages for select using (exists(select 1 from public.study_rooms r join public.channel_members m on m.channel_id=r.channel_id where r.id=room_id and m.user_id=auth.uid()));
create policy "members send messages" on public.room_messages for insert with check (user_id=auth.uid() and exists(select 1 from public.study_rooms r join public.channel_members m on m.channel_id=r.channel_id where r.id=room_id and m.user_id=auth.uid()));
alter publication supabase_realtime add table public.room_messages;

-- Üyelik denetimlerinde döngü oluşmaması için güvenli yardımcı fonksiyon.
create or replace function public.is_channel_member(target_channel uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists(select 1 from public.channel_members where channel_id=target_channel and user_id=auth.uid());
$$;
drop policy if exists "public channels readable" on public.channels;
drop policy if exists "members read membership" on public.channel_members;
drop policy if exists "channel owners manage members" on public.channel_members;
drop policy if exists "members read rooms" on public.study_rooms;
drop policy if exists "members create rooms" on public.study_rooms;
drop policy if exists "members read messages" on public.room_messages;
drop policy if exists "members send messages" on public.room_messages;
create policy "public channels readable" on public.channels for select using (privacy='public' or owner_id=auth.uid() or public.is_channel_member(id));
create policy "members read membership" on public.channel_members for select using (user_id=auth.uid() or public.is_channel_member(channel_id));
create policy "channel owners manage members" on public.channel_members for all using (exists(select 1 from public.channels c where c.id=channel_id and c.owner_id=auth.uid()));
create policy "members read rooms" on public.study_rooms for select using (public.is_channel_member(channel_id));
create policy "members create rooms" on public.study_rooms for insert with check (owner_id=auth.uid() and public.is_channel_member(channel_id));
create policy "members read messages" on public.room_messages for select using (exists(select 1 from public.study_rooms r where r.id=room_id and public.is_channel_member(r.channel_id)));
create policy "members send messages" on public.room_messages for insert with check (user_id=auth.uid() and exists(select 1 from public.study_rooms r where r.id=room_id and public.is_channel_member(r.channel_id)));

create or replace function public.add_channel_owner()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.channel_members(channel_id,user_id,role) values(new.id,new.owner_id,'owner') on conflict do nothing;
  return new;
end;
$$;
drop trigger if exists add_channel_owner_membership on public.channels;
create trigger add_channel_owner_membership after insert on public.channels for each row execute function public.add_channel_owner();
create policy "public channel join" on public.channel_members for insert with check (user_id=auth.uid() and exists(select 1 from public.channels c where c.id=channel_id and c.privacy='public'));
