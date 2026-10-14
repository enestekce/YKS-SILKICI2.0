-- Sohbetlerde herkes yalnızca kendi mesajını düzenleyip silebilsin.
-- Supabase SQL Editor'de bir kez çalıştır.

drop policy if exists "general messages own update" on public.general_messages;
drop policy if exists "general messages own delete" on public.general_messages;
create policy "general messages own update" on public.general_messages
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "general messages own delete" on public.general_messages
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists "direct messages own update" on public.direct_messages;
drop policy if exists "direct messages own delete" on public.direct_messages;
create policy "direct messages own update" on public.direct_messages
  for update to authenticated using (sender_id = auth.uid()) with check (sender_id = auth.uid());
create policy "direct messages own delete" on public.direct_messages
  for delete to authenticated using (sender_id = auth.uid());

drop policy if exists "room messages own update" on public.room_messages;
drop policy if exists "room messages own delete" on public.room_messages;
create policy "room messages own update" on public.room_messages
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "room messages own delete" on public.room_messages
  for delete to authenticated using (user_id = auth.uid());
