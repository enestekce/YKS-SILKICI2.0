-- Topluluk odaları, davet bağlantısı, katılım isteği ve dosya ekleri yükseltmesi.
alter table public.channels add column if not exists invite_code text unique;
update public.channels set invite_code=encode(gen_random_bytes(9),'hex') where invite_code is null;
alter table public.channels alter column invite_code set default encode(gen_random_bytes(9),'hex');
alter table public.channels alter column invite_code set not null;

create table if not exists public.channel_join_requests (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(), unique(channel_id, requester_id)
);
alter table public.channel_join_requests enable row level security;

create or replace function public.is_channel_owner(target_channel uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select exists(select 1 from public.channels where id=target_channel and owner_id=auth.uid());
$$;
create or replace function public.is_room_member(target_room uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select exists(select 1 from public.study_rooms r where r.id=target_room and public.is_channel_member(r.channel_id));
$$;
create or replace function public.join_channel_by_invite(p_code text)
returns uuid language plpgsql security definer set search_path=public as $$
declare target_id uuid;
begin
  select id into target_id from public.channels where invite_code=p_code and privacy='invite';
  if target_id is null then raise exception 'Davet bağlantısı geçersiz.'; end if;
  insert into public.channel_members(channel_id,user_id,role) values(target_id,auth.uid(),'member') on conflict do nothing;
  return target_id;
end;
$$;
create or replace function public.resolve_join_request(p_request_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path=public as $$
declare request_row public.channel_join_requests;
begin
  select * into request_row from public.channel_join_requests where id=p_request_id;
  if request_row.id is null or not public.is_channel_owner(request_row.channel_id) then raise exception 'Yetkin yok.'; end if;
  if p_approve then
    insert into public.channel_members(channel_id,user_id,role) values(request_row.channel_id,request_row.requester_id,'member') on conflict do nothing;
    update public.channel_join_requests set status='approved' where id=p_request_id;
  else
    update public.channel_join_requests set status='rejected' where id=p_request_id;
  end if;
end;
$$;

drop policy if exists "public channels readable" on public.channels;
create policy "channels discoverable" on public.channels for select using (true);
create policy "room owners delete rooms" on public.study_rooms for delete using (owner_id=auth.uid() or public.is_channel_owner(channel_id));
create policy "requester reads requests" on public.channel_join_requests for select using (requester_id=auth.uid() or public.is_channel_owner(channel_id));
create policy "users request private channel" on public.channel_join_requests for insert with check (requester_id=auth.uid() and exists(select 1 from public.channels c where c.id=channel_id and c.privacy='private'));

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('community-files','community-files',false,52428800,array['image/jpeg','image/png','image/webp','application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do update set file_size_limit=52428800;
drop policy if exists "community members read files" on storage.objects;
drop policy if exists "community members upload files" on storage.objects;
create policy "community members read files" on storage.objects for select to authenticated using (bucket_id='community-files' and public.is_room_member((storage.foldername(name))[1]::uuid));
create policy "community members upload files" on storage.objects for insert to authenticated with check (bucket_id='community-files' and public.is_room_member((storage.foldername(name))[1]::uuid) and (storage.foldername(name))[2]=auth.uid()::text);
