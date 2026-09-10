-- YKS Silkici: genel sohbet, arkadaşlık, özel mesaj ve profil fotoğrafları.
-- Supabase Dashboard > SQL Editor'da bu dosyanın TAMAMINI bir kez çalıştır.

alter table public.community_profiles add column if not exists avatar_path text;

create table if not exists public.general_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 700),
  attachment_path text,
  created_at timestamptz not null default now()
);

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(requester_id, recipient_id),
  check (requester_id <> recipient_id)
);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 700),
  attachment_path text,
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create index if not exists general_messages_created_at_idx on public.general_messages(created_at);
create index if not exists friend_requests_recipient_idx on public.friend_requests(recipient_id, status);
create index if not exists direct_messages_pair_idx on public.direct_messages(sender_id, recipient_id, created_at);

alter table public.general_messages enable row level security;
alter table public.friend_requests enable row level security;
alter table public.direct_messages enable row level security;

create or replace function public.are_friends(other_user uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.friend_requests
    where status = 'accepted'
      and ((requester_id = auth.uid() and recipient_id = other_user)
        or (recipient_id = auth.uid() and requester_id = other_user))
  );
$$;

-- İsteklerin tek noktadan yönetilmesi; bekleyen/reddedilen kayıtlar takılmaz.
create or replace function public.send_friend_request(p_recipient uuid)
returns void language plpgsql security definer set search_path = public as $$
declare existing public.friend_requests;
begin
  if auth.uid() is null then raise exception 'Oturum bulunamadı.'; end if;
  if p_recipient = auth.uid() then raise exception 'Kendine arkadaşlık isteği gönderemezsin.'; end if;
  select * into existing from public.friend_requests
    where (requester_id = auth.uid() and recipient_id = p_recipient)
       or (requester_id = p_recipient and recipient_id = auth.uid())
    limit 1;
  if existing.id is null then
    insert into public.friend_requests(requester_id,recipient_id,status) values(auth.uid(),p_recipient,'pending');
  elsif existing.requester_id = auth.uid() and existing.status = 'rejected' then
    update public.friend_requests set status='pending',updated_at=now() where id=existing.id;
  elsif existing.status = 'accepted' then
    raise exception 'Bu kullanıcı zaten arkadaşın.';
  elsif existing.requester_id = p_recipient and existing.status = 'pending' then
    raise exception 'Bu kullanıcı sana zaten arkadaşlık isteği gönderdi.';
  else
    raise exception 'Arkadaşlık isteği zaten bekliyor.';
  end if;
end;
$$;

create or replace function public.answer_friend_request(p_request_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.friend_requests
     set status = case when p_accept then 'accepted' else 'rejected' end,
         updated_at = now()
   where id = p_request_id and recipient_id = auth.uid() and status = 'pending';
  if not found then raise exception 'Bu isteği güncelleme yetkin yok veya istek artık beklemiyor.'; end if;
end;
$$;

create or replace function public.cancel_friend_request(p_request_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.friend_requests
   where id = p_request_id
     and (
       (status = 'pending' and requester_id = auth.uid())
       or (status = 'accepted' and (requester_id = auth.uid() or recipient_id = auth.uid()))
     );
  if not found then raise exception 'Bu isteği iptal etme veya arkadaşlıktan çıkarma yetkin yok.'; end if;
end;
$$;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.answer_friend_request(uuid,boolean) to authenticated;
grant execute on function public.cancel_friend_request(uuid) to authenticated;

drop policy if exists "general messages readable" on public.general_messages;
drop policy if exists "general messages own insert" on public.general_messages;
create policy "general messages readable" on public.general_messages for select to authenticated using (true);
create policy "general messages own insert" on public.general_messages for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "friend requests participants read" on public.friend_requests;
drop policy if exists "friend requests sender insert" on public.friend_requests;
drop policy if exists "friend requests recipient update" on public.friend_requests;
create policy "friend requests participants read" on public.friend_requests for select to authenticated using (requester_id = auth.uid() or recipient_id = auth.uid());
create policy "friend requests sender insert" on public.friend_requests for insert to authenticated with check (requester_id = auth.uid() and requester_id <> recipient_id);
create policy "friend requests recipient update" on public.friend_requests for update to authenticated using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

drop policy if exists "direct messages participants read" on public.direct_messages;
drop policy if exists "direct messages friend insert" on public.direct_messages;
create policy "direct messages participants read" on public.direct_messages for select to authenticated using (sender_id = auth.uid() or recipient_id = auth.uid());
create policy "direct messages friend insert" on public.direct_messages for insert to authenticated with check (sender_id = auth.uid() and public.are_friends(recipient_id));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos','profile-photos',true,2097152,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true, file_size_limit=2097152, allowed_mime_types=array['image/jpeg','image/png','image/webp'];

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('social-files','social-files',true,52428800,null)
on conflict (id) do update set public=true, file_size_limit=52428800, allowed_mime_types=null;

drop policy if exists "profile photos readable" on storage.objects;
drop policy if exists "profile photos own upload" on storage.objects;
drop policy if exists "social files readable" on storage.objects;
drop policy if exists "social files own upload" on storage.objects;
drop policy if exists "social files own update" on storage.objects;
create policy "profile photos readable" on storage.objects for select to authenticated using (bucket_id = 'profile-photos');
create policy "profile photos own upload" on storage.objects for insert to authenticated with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "social files readable" on storage.objects for select to authenticated using (bucket_id = 'social-files');
create policy "social files own upload" on storage.objects for insert to authenticated with check (bucket_id = 'social-files' and (storage.foldername(name))[2] = auth.uid()::text);
