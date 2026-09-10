-- Üyeler, 6 haneli davet kodu ve dosya yükleme düzeltmesi.
create table if not exists public.community_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  updated_at timestamptz not null default now()
);
alter table public.community_profiles enable row level security;
create policy "community profiles readable" on public.community_profiles for select using (true);
create policy "users manage own community profile" on public.community_profiles for all using (user_id=auth.uid()) with check (user_id=auth.uid());

create or replace function public.generate_invite_code()
returns text language plpgsql security definer set search_path=public as $$
declare candidate text;
begin
  loop
    candidate := lpad(floor(random()*1000000)::text,6,'0');
    exit when not exists(select 1 from public.channels where invite_code=candidate);
  end loop;
  return candidate;
end;
$$;
alter table public.channels alter column invite_code drop default;
do $$
declare item record; next_code text;
begin
  for item in select id from public.channels loop
    next_code := public.generate_invite_code();
    update public.channels set invite_code=next_code where id=item.id;
  end loop;
end;
$$;
alter table public.channels alter column invite_code set default public.generate_invite_code();

create or replace function public.join_channel_by_invite(p_code text)
returns uuid language plpgsql security definer set search_path=public as $$
declare target_id uuid;
begin
  select id into target_id from public.channels where invite_code=trim(p_code);
  if target_id is null then raise exception 'Davet kodu geçersiz.'; end if;
  insert into public.channel_members(channel_id,user_id,role) values(target_id,auth.uid(),'member') on conflict do nothing;
  return target_id;
end;
$$;

drop policy if exists "users request private channel" on public.channel_join_requests;
create policy "users request private channel" on public.channel_join_requests for insert with check (requester_id=auth.uid() and exists(select 1 from public.channels c where c.id=channel_id and c.privacy='private'));
create policy "requester updates own request" on public.channel_join_requests for update using (requester_id=auth.uid()) with check (requester_id=auth.uid());

update storage.buckets set file_size_limit=52428800,
allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif','application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','text/plain']
where id='community-files';
