-- ============================================================================
--  Tiruan minimal lingkungan Supabase untuk menguji Row Level Security
--  pada PostgreSQL biasa (lokal atau CI).
--
--  Supabase menyediakan peran anon/authenticated/service_role, skema auth,
--  dan fungsi auth.uid(). Berkas ini membuat padanannya seperlunya saja.
--
--  CATATAN: tiruan tidak sama persis dengan Supabase. Ia cukup untuk menjaga
--  agar kebijakan RLS tidak rusak tanpa disadari, tetapi pemeriksaan yang
--  menentukan tetaplah menjalankan uji ini pada proyek Supabase sungguhan.
-- ============================================================================

do $$ begin create role anon nologin;          exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
do $$ begin create role service_role nologin bypassrls; exception when duplicate_object then null; end $$;

create schema if not exists auth;

create table if not exists auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text,
  raw_user_meta_data jsonb default '{}'::jsonb
);

-- Supabase mengambil id pengguna dari klaim JWT; di sini dari setelan sesi.
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

grant usage on schema auth to anon, authenticated;
grant select on auth.users to anon, authenticated;
