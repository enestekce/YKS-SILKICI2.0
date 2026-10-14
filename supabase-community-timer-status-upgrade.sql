-- Çalışma topluluğunda duraklatılan sayaçların sürelerini de göstermek için.
-- Supabase SQL Editor'de bir kez çalıştır.
alter table public.community_presence
  add column if not exists state text not null default 'idle'
  check (state in ('idle', 'active', 'paused'));

alter table public.community_presence
  add column if not exists elapsed_seconds integer not null default 0;

update public.community_presence
set state = case when active then 'active' else 'idle' end
where state is null or state = 'idle';
