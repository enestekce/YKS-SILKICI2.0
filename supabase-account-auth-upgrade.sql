-- YKS Silkici kalıcı kullanıcı adı / şifre ve bulut veri altyapısı.
-- Supabase SQL Editor'da TAMAMINI bir kez çalıştır.
-- Kullanıcılar e-posta vermeden kullanıcı adı + şifre + kurtarma kodu kullanır.

create extension if not exists pgcrypto schema extensions;

create table if not exists public.yks_accounts (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  username text not null,
  username_key text generated always as (lower(username)) stored unique,
  password_hash text not null,
  recovery_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.yks_account_data (
  account_id uuid primary key references public.yks_accounts(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.yks_account_sessions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.yks_accounts(id) on delete cascade,
  token_hash text not null,
  expires_at timestamptz not null default now() + interval '180 days',
  created_at timestamptz not null default now()
);
create index if not exists yks_account_sessions_account_idx on public.yks_account_sessions(account_id);

alter table public.yks_accounts enable row level security;
alter table public.yks_account_data enable row level security;
alter table public.yks_account_sessions enable row level security;

create or replace function public.yks_new_session(p_account_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare v_token text;
begin
  v_token := encode(extensions.gen_random_bytes(32),'hex');
  delete from public.yks_account_sessions where expires_at < now();
  insert into public.yks_account_sessions(account_id,token_hash) values(p_account_id,extensions.crypt(v_token,extensions.gen_salt('bf')));
  return v_token;
end; $$;

create or replace function public.yks_session_account(p_token text)
returns uuid language sql security definer set search_path=public stable as $$
  select account_id from public.yks_account_sessions
  where expires_at > now() and extensions.crypt(p_token,token_hash)=token_hash
  order by created_at desc limit 1;
$$;

create or replace function public.yks_register_account(p_name text,p_username text,p_password text,p_recovery text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_token text; v_name text:=trim(p_name); v_username text:=trim(p_username);
begin
  if char_length(v_name)<1 or char_length(v_name)>80 then raise exception 'Ad 1-80 karakter olmalı.'; end if;
  if v_username !~ '^[A-Za-z0-9_.-]{3,30}$' then raise exception 'Kullanıcı adı 3-30 karakter olmalı.'; end if;
  if char_length(p_password)<6 then raise exception 'Şifre en az 6 karakter olmalı.'; end if;
  if char_length(p_recovery)<6 then raise exception 'Kurtarma kodu en az 6 karakter olmalı.'; end if;
  insert into public.yks_accounts(name,username,password_hash,recovery_hash)
    values(v_name,v_username,extensions.crypt(p_password,extensions.gen_salt('bf')),extensions.crypt(p_recovery,extensions.gen_salt('bf')))
    returning id into v_id;
  insert into public.yks_account_data(account_id) values(v_id);
  v_token:=public.yks_new_session(v_id);
  return jsonb_build_object('account_id',v_id,'name',v_name,'username',v_username,'token',v_token,'data','{}'::jsonb);
exception when unique_violation then raise exception 'Bu kullanıcı adı zaten alınmış.';
end; $$;

create or replace function public.yks_login_account(p_username text,p_password text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.yks_accounts; v_token text; v_data jsonb;
begin
  select * into a from public.yks_accounts where username_key=lower(trim(p_username)) limit 1;
  if a.id is null or extensions.crypt(p_password,a.password_hash)<>a.password_hash then raise exception 'Kullanıcı adı veya şifre hatalı.'; end if;
  select data into v_data from public.yks_account_data where account_id=a.id;
  v_token:=public.yks_new_session(a.id);
  return jsonb_build_object('account_id',a.id,'name',a.name,'username',a.username,'token',v_token,'data',coalesce(v_data,'{}'::jsonb));
end; $$;

create or replace function public.yks_save_account_data(p_token text,p_data jsonb)
returns void language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  v_id:=public.yks_session_account(p_token);
  if v_id is null then raise exception 'Oturumun sona ermiş. Tekrar giriş yap.'; end if;
  if p_data is null or jsonb_typeof(p_data)<>'object' then raise exception 'Geçersiz veri.'; end if;
  insert into public.yks_account_data(account_id,data,updated_at) values(v_id,p_data,now())
  on conflict(account_id) do update set data=excluded.data,updated_at=now();
end; $$;

create or replace function public.yks_reset_account_password(p_username text,p_recovery text,p_password text)
returns void language plpgsql security definer set search_path=public as $$
declare a public.yks_accounts;
begin
  if char_length(p_password)<6 then raise exception 'Şifre en az 6 karakter olmalı.'; end if;
  select * into a from public.yks_accounts where username_key=lower(trim(p_username)) limit 1;
  if a.id is null or extensions.crypt(p_recovery,a.recovery_hash)<>a.recovery_hash then raise exception 'Kullanıcı adı veya kurtarma kodu hatalı.'; end if;
  update public.yks_accounts set password_hash=extensions.crypt(p_password,extensions.gen_salt('bf')),updated_at=now() where id=a.id;
end; $$;

grant execute on function public.yks_register_account(text,text,text,text) to anon,authenticated;
grant execute on function public.yks_login_account(text,text) to anon,authenticated;
grant execute on function public.yks_save_account_data(text,jsonb) to anon,authenticated;
grant execute on function public.yks_reset_account_password(text,text,text) to anon,authenticated;
