-- ============================================================================
--  FASTSAMBO — KEAMANAN & EKSPOS API
--  Migrasi 003 : Row Level Security, peran, view publik, dan RPC pengantaran
-- ============================================================================

-- ---------------------------------------------------------------------------
-- A. HAK AKSES SCHEMA
-- ---------------------------------------------------------------------------
grant usage on schema bilman to anon, authenticated, service_role;
grant select on all tables in schema bilman to anon, authenticated;

-- Audit log memuat isi baris sebelum dan sesudah perubahan berikut pelakunya.
-- Row Level Security sudah menyembunyikannya dari anon, tetapi haknya dicabut
-- juga agar satu kebijakan keliru di kemudian hari tidak sampai membocorkannya.
revoke select on bilman.audit_log from anon;

-- Riwayat pembayaran memperlihatkan perilaku bayar tiap pelanggan. Row Level
-- Security sudah membatasinya ke pengguna yang login, tetapi RLS menyaring
-- baris secara diam-diam — kueri tetap berhasil dan mengembalikan nol baris.
-- Hak bacanya dicabut juga agar penolakannya tegas di lapisan hak akses tabel.
revoke select on bilman.pembayaran from anon;

-- Pengguna yang sudah login memerlukan hak tulis di TINGKAT TABEL. SIAPA yang
-- benar-benar boleh menulis tetap ditentukan Row Level Security pada bagian E.
-- Tanpa grant ini PostgreSQL menolak lebih dulu di lapisan hak akses tabel,
-- sehingga seluruh kebijakan tulis tidak akan pernah dievaluasi.
grant insert, update, delete on
  bilman.unit, bilman.parameter, bilman.petugas, bilman.periode,
  bilman.saldo_tunggakan, bilman.beban_tagihan, bilman.segmen_beban,
  bilman.penertiban, bilman.target_petugas, bilman.efektivitas_penagihan,
  bilman.pelanggan, bilman.pengantaran_tul601, bilman.pembayaran,
  bilman.aksi, bilman.aksi_langkah, bilman.kalender, bilman.hambatan,
  bilman.komponen_skor, bilman.catatan_perbaikan, bilman.profil
to authenticated;

grant all on all tables in schema bilman to service_role;
grant usage, select on all sequences in schema bilman to authenticated, service_role;
grant execute on all functions in schema bilman to anon, authenticated, service_role;

alter default privileges in schema bilman grant select on tables to anon, authenticated;

-- ---------------------------------------------------------------------------
-- B. FUNGSI BANTU PERAN
-- ---------------------------------------------------------------------------
create or replace function bilman.peran_saya()
returns bilman.peran_pengguna language sql stable security definer
set search_path = bilman, public as $$
  select coalesce((select peran from bilman.profil where id = auth.uid()), 'PENGAMAT');
$$;

-- Petugas bilman yang terikat ke akun yang sedang login (NULL bila bukan bilman)
create or replace function bilman.petugas_saya()
returns uuid language sql stable security definer
set search_path = bilman, public as $$
  select petugas_id from bilman.profil where id = auth.uid();
$$;

create or replace function bilman.boleh_tulis()
returns boolean language sql stable as $$
  select bilman.peran_saya() in ('ADMIN','MANAJER','SUPERVISOR');
$$;

create or replace function bilman.boleh_kelola()
returns boolean language sql stable as $$
  select bilman.peran_saya() in ('ADMIN','MANAJER');
$$;

-- Profil dibuat otomatis saat pengguna baru mendaftar, dengan peran paling
-- rendah. Menaikkan peran adalah tindakan sadar seorang ADMIN, bukan bawaan.
create or replace function bilman.buat_profil_baru()
returns trigger language plpgsql security definer
set search_path = bilman, public as $$
begin
  insert into bilman.profil (id, nama, email, peran)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'nama', split_part(new.email, '@', 1)),
          new.email, 'PENGAMAT')
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists trg_auth_user_baru on auth.users;
create trigger trg_auth_user_baru
  after insert on auth.users
  for each row execute function bilman.buat_profil_baru();

-- ---------------------------------------------------------------------------
-- C. AKTIFKAN RLS
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['unit','parameter','petugas','periode','saldo_tunggakan',
                           'beban_tagihan','segmen_beban','penertiban','target_petugas',
                           'efektivitas_penagihan','pelanggan','pengantaran_tul601',
                           'pembayaran','aksi','aksi_langkah','kalender','hambatan',
                           'komponen_skor','catatan_perbaikan','profil','audit_log']
  loop
    execute format('alter table bilman.%I enable row level security;', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- D. KEBIJAKAN BACA
--    Mode bawaan: dashboard bersifat "read-only publik". Isinya angka kinerja
--    unit dan agregat tagihan — tidak memuat identitas pelanggan selain IDPEL
--    kerangka, sehingga situs Vercel dapat tampil tanpa login.
--
--    Untuk mengunci agar wajib login: ganti `to anon, authenticated` menjadi
--    `to authenticated` pada blok di bawah, lalu jalankan ulang migrasi ini.
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['unit','parameter','petugas','periode','saldo_tunggakan',
                           'beban_tagihan','segmen_beban','penertiban','target_petugas',
                           'efektivitas_penagihan','pelanggan','pengantaran_tul601',
                           'aksi','aksi_langkah','kalender','hambatan',
                           'komponen_skor','catatan_perbaikan']
  loop
    execute format('drop policy if exists baca_publik on bilman.%I;', t);
    execute format(
      'create policy baca_publik on bilman.%I for select to anon, authenticated using (true);', t);
  end loop;
end $$;

-- Pembayaran memuat perilaku bayar per pelanggan — hanya untuk yang login.
drop policy if exists baca_pembayaran on bilman.pembayaran;
create policy baca_pembayaran on bilman.pembayaran for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- E. KEBIJAKAN TULIS
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  -- Data operasional bulanan: SUPERVISOR ke atas
  foreach t in array array['saldo_tunggakan','beban_tagihan','segmen_beban','penertiban',
                           'target_petugas','efektivitas_penagihan','pembayaran',
                           'aksi','aksi_langkah','kalender','catatan_perbaikan']
  loop
    execute format('drop policy if exists tulis_operasional on bilman.%I;', t);
    execute format(
      'create policy tulis_operasional on bilman.%I for all to authenticated
       using (bilman.boleh_tulis()) with check (bilman.boleh_tulis());', t);
  end loop;

  -- Data master, parameter, dan bobot penilaian: hanya ADMIN / MANAJER.
  -- Bobot skor ikut dikunci karena mengubahnya berarti mengubah cara orang dinilai.
  foreach t in array array['unit','parameter','petugas','periode','pelanggan',
                           'hambatan','komponen_skor']
  loop
    execute format('drop policy if exists kelola_master on bilman.%I;', t);
    execute format(
      'create policy kelola_master on bilman.%I for all to authenticated
       using (bilman.boleh_kelola()) with check (bilman.boleh_kelola());', t);
  end loop;
end $$;

-- Pengantaran TUL 6.01 — jalur tulis utama di lapangan.
-- Seorang bilman hanya boleh menyentuh barisnya sendiri; ia tidak dapat
-- memindahkan lembar ke petugas lain karena petugas_id dikunci pada WITH CHECK.
drop policy if exists antar_oleh_petugas on bilman.pengantaran_tul601;
create policy antar_oleh_petugas on bilman.pengantaran_tul601 for update to authenticated
  using (petugas_id is not distinct from bilman.petugas_saya())
  with check (petugas_id is not distinct from bilman.petugas_saya());

drop policy if exists antar_oleh_pengawas on bilman.pengantaran_tul601;
create policy antar_oleh_pengawas on bilman.pengantaran_tul601 for all to authenticated
  using (bilman.boleh_tulis()) with check (bilman.boleh_tulis());

-- Profil: setiap orang membaca dan mengubah profilnya sendiri; ADMIN semuanya.
drop policy if exists profil_sendiri on bilman.profil;
create policy profil_sendiri on bilman.profil for select to authenticated
  using (id = auth.uid() or bilman.boleh_kelola());

-- Pengguna tidak dapat menaikkan perannya sendiri: peran pada baris hasil
-- perubahan harus tetap sama dengan peran yang sekarang dipegang.
drop policy if exists profil_ubah_sendiri on bilman.profil;
create policy profil_ubah_sendiri on bilman.profil for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and peran = bilman.peran_saya());

drop policy if exists profil_kelola on bilman.profil;
create policy profil_kelola on bilman.profil for all to authenticated
  using (bilman.boleh_kelola()) with check (bilman.boleh_kelola());

-- Audit log: hanya ADMIN / MANAJER yang boleh membaca, tidak ada yang menulis
-- langsung (pengisiannya lewat pemicu bilman.tulis_audit yang security definer).
drop policy if exists audit_baca on bilman.audit_log;
create policy audit_baca on bilman.audit_log for select to authenticated
  using (bilman.boleh_kelola());

-- ---------------------------------------------------------------------------
-- F. VIEW MENGHORMATI RLS PEMANGGIL
-- ---------------------------------------------------------------------------
do $$
declare v text;
begin
  foreach v in array array['v_beban','v_saldo','v_rst','v_pengantaran','v_progres_antar',
                           'v_cash_in','v_skor_kinerja','v_target','v_kpi_unit','v_efektivitas']
  loop
    execute format('alter view bilman.%I set (security_invoker = on);', v);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- G. EKSPOS KE POSTGREST LEWAT SCHEMA public
--    Supabase secara bawaan hanya mengekspos schema `public` ke REST API.
--    View pembungkus berikut membuat data dapat dibaca lewat
--    supabase.from('fs_kpi_unit') tanpa perlu mengubah setelan Exposed schemas.
-- ---------------------------------------------------------------------------
create or replace view public.fs_kpi_unit      with (security_invoker = on) as select * from bilman.v_kpi_unit;
create or replace view public.fs_saldo         with (security_invoker = on) as select * from bilman.v_saldo;
create or replace view public.fs_beban         with (security_invoker = on) as select * from bilman.v_beban;
create or replace view public.fs_rst           with (security_invoker = on) as select * from bilman.v_rst;
create or replace view public.fs_skor          with (security_invoker = on) as select * from bilman.v_skor_kinerja;
create or replace view public.fs_target        with (security_invoker = on) as select * from bilman.v_target;
create or replace view public.fs_pengantaran   with (security_invoker = on) as select * from bilman.v_pengantaran;
create or replace view public.fs_progres_antar with (security_invoker = on) as select * from bilman.v_progres_antar;
create or replace view public.fs_efektivitas   with (security_invoker = on) as select * from bilman.v_efektivitas;
create or replace view public.fs_segmen        with (security_invoker = on) as select * from bilman.segmen_beban;
create or replace view public.fs_penertiban    with (security_invoker = on) as select * from bilman.penertiban;
create or replace view public.fs_petugas       with (security_invoker = on) as select * from bilman.petugas;
create or replace view public.fs_periode       with (security_invoker = on) as select * from bilman.periode;
create or replace view public.fs_parameter     with (security_invoker = on) as select * from bilman.parameter;
create or replace view public.fs_komponen_skor with (security_invoker = on) as select * from bilman.komponen_skor;
create or replace view public.fs_kalender      with (security_invoker = on) as select * from bilman.kalender;
create or replace view public.fs_hambatan      with (security_invoker = on) as select * from bilman.hambatan;
create or replace view public.fs_catatan       with (security_invoker = on) as select * from bilman.catatan_perbaikan;

create or replace view public.fs_aksi with (security_invoker = on) as
select a.kode, a.judul, a.dampak_nilai, a.dampak_label, a.prioritas,
       a.penanggung_jawab, a.tenggat, a.status, a.ringkasan,
       pr.kode as periode_kode,
       coalesce(
         (select jsonb_agg(jsonb_build_object('urutan', l.urutan, 'langkah', l.langkah,
                                              'selesai', l.selesai) order by l.urutan)
          from bilman.aksi_langkah l where l.aksi_id = a.id), '[]'::jsonb) as langkah
from bilman.aksi a
join bilman.periode pr on pr.id = a.periode_id;

grant select on
  public.fs_kpi_unit, public.fs_saldo, public.fs_beban, public.fs_rst, public.fs_skor,
  public.fs_target, public.fs_pengantaran, public.fs_progres_antar, public.fs_efektivitas,
  public.fs_segmen, public.fs_penertiban, public.fs_petugas, public.fs_periode,
  public.fs_parameter, public.fs_komponen_skor, public.fs_kalender, public.fs_hambatan,
  public.fs_catatan, public.fs_aksi
to anon, authenticated;

-- ---------------------------------------------------------------------------
-- H. RPC: catat pengantaran TUL 6.01 dari lapangan
--    security invoker — seluruh kebijakan RLS di atas tetap berlaku, sehingga
--    seorang bilman tidak bisa mencatatkan lembar milik petugas lain.
-- ---------------------------------------------------------------------------
create or replace function public.fs_catat_pengantaran(
  p_idpel         text,
  p_periode       text,
  p_status_terima text,
  p_foto_url      text,
  p_lat           double precision default null,
  p_lon           double precision default null,
  p_catatan       text default null
) returns jsonb
language plpgsql security invoker
set search_path = bilman, public as $$
declare
  v_periode_id   uuid;
  v_pelanggan_id uuid;
  v_lat          double precision;
  v_lon          double precision;
  v_jarak        double precision;
  v_hasil        jsonb;
begin
  if p_foto_url is null or btrim(p_foto_url) = '' then
    raise exception 'Bukti foto FTO wajib dilampirkan — lembar tanpa foto tidak dihitung terantar';
  end if;

  select id into v_periode_id from bilman.periode where kode = p_periode;
  if v_periode_id is null then
    raise exception 'Periode % tidak ditemukan', p_periode;
  end if;

  select id, latitude, longitude into v_pelanggan_id, v_lat, v_lon
  from bilman.pelanggan where idpel = p_idpel;
  if v_pelanggan_id is null then
    raise exception 'IDPEL % tidak ditemukan', p_idpel;
  end if;

  -- Jarak titik foto ke titik pelanggan termapping, dalam meter. Rumus
  -- haversine dengan jari-jari bumi 6.371.000 m; cukup teliti untuk jarak
  -- ratusan meter dan tidak menuntut ekstensi PostGIS.
  if p_lat is not null and p_lon is not null and v_lat is not null and v_lon is not null then
    v_jarak := 6371000 * 2 * asin(sqrt(
        power(sin(radians(p_lat - v_lat) / 2), 2)
      + cos(radians(v_lat)) * cos(radians(p_lat))
      * power(sin(radians(p_lon - v_lon) / 2), 2)));
  end if;

  update bilman.pengantaran_tul601 set
    status_antar     = 'TERANTAR',
    status_terima    = p_status_terima::bilman.status_terima,
    tgl_antar        = current_date,
    jam_antar        = current_time,
    foto_fto_url     = p_foto_url,
    lat_fto          = p_lat,
    lon_fto          = p_lon,
    jarak_validasi_m = v_jarak,
    catatan          = coalesce(p_catatan, catatan)
  where periode_id = v_periode_id and pelanggan_id = v_pelanggan_id
  returning jsonb_build_object(
    'idpel', p_idpel,
    'periode', p_periode,
    'status_terima', status_terima,
    'tgl_antar', tgl_antar,
    'jarak_validasi_m', round(jarak_validasi_m::numeric, 1),
    'suspect', jarak_validasi_m > bilman.p('jarak_validasi_maks')
  ) into v_hasil;

  if v_hasil is null then
    raise exception 'Lembar untuk IDPEL % pada periode % tidak ada, atau bukan wilayah kerja Anda',
      p_idpel, p_periode;
  end if;

  return v_hasil;
end $$;

grant execute on function public.fs_catat_pengantaran(
  text, text, text, text, double precision, double precision, text) to authenticated;
