-- YKS Silkici: yalnızca kanal sahibinin kanal silmesine izin verir.
-- Supabase SQL Editor'de bir kez çalıştır.

drop policy if exists "channel owners delete channels" on public.channels;
create policy "channel owners delete channels"
on public.channels for delete to authenticated
using (owner_id = auth.uid());
