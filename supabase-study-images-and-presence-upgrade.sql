-- YKS Silkici: not/yanlış defteri görsellerini tarayıcı yerine depoda saklar
-- ve üyelerin kısa süreli çevrimiçi durumunu gösterir.
-- Supabase Dashboard > SQL Editor'da bu dosyanın TAMAMINI bir kez çalıştır.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('study-images','study-images',true,10485760,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public=true,file_size_limit=10485760,allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif'];

drop policy if exists "study images own upload" on storage.objects;
drop policy if exists "study images own delete" on storage.objects;
create policy "study images own upload" on storage.objects for insert to authenticated
with check (bucket_id='study-images' and (storage.foldername(name))[2]=auth.uid()::text);
create policy "study images own delete" on storage.objects for delete to authenticated
using (bucket_id='study-images' and (storage.foldername(name))[2]=auth.uid()::text);

create table if not exists public.user_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  last_seen_at timestamptz not null default now()
);
alter table public.user_presence enable row level security;
drop policy if exists "presence readable by signed in users" on public.user_presence;
drop policy if exists "users manage own presence" on public.user_presence;
create policy "presence readable by signed in users" on public.user_presence for select to authenticated using (true);
create policy "users manage own presence" on public.user_presence for all to authenticated
using (user_id=auth.uid()) with check (user_id=auth.uid());
