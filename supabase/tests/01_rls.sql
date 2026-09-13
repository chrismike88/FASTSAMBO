-- ============================================================================
--  UJI ROW LEVEL SECURITY — FASTSAMBO
--
--  Menguji bahwa model keamanan benar-benar berlaku, bukan sekadar terpasang:
--    * pengunjung tanpa login boleh membaca dashboard, tidak boleh menulis
--    * PENGAMAT boleh membaca, tidak boleh menulis apa pun
--    * BILMAN hanya boleh mencatat pengantaran di wilayah kerjanya sendiri
--    * BILMAN tidak dapat memindahkan lembar ke petugas lain
--    * SUPERVISOR boleh mengisi data operasional, tidak boleh ubah data master
--    * tidak seorang pun dapat menaikkan perannya sendiri
--    * bobot penilaian kinerja hanya dapat diubah ADMIN / MANAJER
--    * lembar tanpa bukti foto FTO tidak dapat berstatus terantar
--    * log audit tidak terbaca oleh peran di bawah MANAJER
--
--  Cara menjalankan:  bash scripts/uji.sh
--  Berkas ini gagal dengan galat bila ada satu saja perilaku yang meleset.
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

-- ---------------------------------------------------------------------------
-- Alat bantu
-- ---------------------------------------------------------------------------
-- Penolakan oleh Row Level Security dan penolakan oleh hak akses tabel
-- sama-sama bernomor SQLSTATE 42501, padahal artinya jauh berbeda:
--   DITOLAK_HAK_TABEL — peran memang tidak punya hak sama sekali
--   DITOLAK_RLS       — peran punya hak, tetapi kebijakan RLS menolaknya
-- Membedakan keduanya penting: bila kebijakan tulis tertutup oleh hak tabel
-- yang tidak pernah diberikan, kebijakan itu tidak pernah benar-benar teruji.
create or replace function pg_temp.coba(perintah text)
returns text language plpgsql as $$
begin
  execute perintah;
  return 'BERHASIL';
exception
  when others then
    if sqlerrm ilike '%row-level security%' then return 'DITOLAK_RLS';
    elsif sqlerrm ilike '%permission denied%' then return 'DITOLAK_HAK_TABEL';
    else return 'DITOLAK_' || sqlstate;
    end if;
end $$;

-- Perintah TULIS butuh pembeda tambahan. Kebijakan RLS yang menolak lewat
-- klausa USING tidak menimbulkan galat sama sekali: perintahnya berhasil,
-- hanya saja nol baris tersentuh. Tanpa memeriksa jumlah baris, uji seperti
-- "pengamat tidak boleh mengubah target" akan lolos untuk alasan yang salah.
--   BERHASIL    — ada baris yang benar-benar berubah
--   TANPA_EFEK  — diizinkan menjalankan, tetapi RLS menyaring seluruh barisnya
create or replace function pg_temp.coba_tulis(perintah text)
returns text language plpgsql as $$
declare n bigint;
begin
  execute perintah;
  get diagnostics n = row_count;
  return case when n > 0 then 'BERHASIL' else 'TANPA_EFEK' end;
exception
  when others then
    if sqlerrm ilike '%row-level security%' then return 'DITOLAK_RLS';
    elsif sqlerrm ilike '%permission denied%' then return 'DITOLAK_HAK_TABEL';
    else return 'DITOLAK_' || sqlstate;
    end if;
end $$;

create or replace function pg_temp.harus(nama text, dapat text, harap text)
returns void language plpgsql as $$
begin
  if dapat is distinct from harap then
    raise exception '✗ % — diharapkan "%", ternyata "%"', nama, harap, dapat;
  end if;
  raise notice '  ✓ %', nama;
end $$;

create or replace function pg_temp.harus_angka(nama text, dapat bigint, harap bigint)
returns void language plpgsql as $$
begin
  if dapat is distinct from harap then
    raise exception '✗ % — diharapkan %, ternyata %', nama, harap, dapat;
  end if;
  raise notice '  ✓ % (%)', nama, dapat;
end $$;

create or replace function pg_temp.harus_ada(nama text, dapat bigint)
returns void language plpgsql as $$
begin
  if coalesce(dapat, 0) = 0 then
    raise exception '✗ % — diharapkan ada baris terbaca, ternyata nol', nama;
  end if;
  raise notice '  ✓ % (% baris)', nama, dapat;
end $$;

-- ---------------------------------------------------------------------------
-- Siapkan empat pengguna dengan peran berbeda
-- ---------------------------------------------------------------------------
delete from bilman.profil;
delete from auth.users;
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'pengamat@uji.local'),
  ('22222222-2222-2222-2222-222222222222', 'bilman.reza@uji.local'),
  ('33333333-3333-3333-3333-333333333333', 'supervisor@uji.local'),
  ('44444444-4444-4444-4444-444444444444', 'admin@uji.local');

update bilman.profil set peran = 'BILMAN',
       petugas_id = (select id from bilman.petugas where kode = 'REZA')
 where email = 'bilman.reza@uji.local';
update bilman.profil set peran = 'SUPERVISOR' where email = 'supervisor@uji.local';
update bilman.profil set peran = 'ADMIN'      where email = 'admin@uji.local';

\echo ''
\echo 'A. PENGUNJUNG TANPA LOGIN (anon)'
set role anon;
select set_config('request.jwt.claim.sub', '', false);

select pg_temp.harus_ada('anon membaca ringkasan KPI',
  (select count(*) from public.fs_kpi_unit));
select pg_temp.harus_ada('anon membaca klasemen RST',
  (select count(*) from public.fs_rst));
select pg_temp.harus_ada('anon membaca progres pengantaran',
  (select count(*) from public.fs_progres_antar));
select pg_temp.harus('anon TIDAK boleh mengubah saldo',
  pg_temp.coba_tulis('update bilman.saldo_tunggakan set nilai_1 = 0'), 'DITOLAK_HAK_TABEL');
select pg_temp.harus('anon TIDAK boleh mencatat pengantaran',
  pg_temp.coba_tulis($$update bilman.pengantaran_tul601 set status_antar = 'TERANTAR'$$),
  'DITOLAK_HAK_TABEL');
select pg_temp.harus('anon TIDAK boleh membaca log audit',
  pg_temp.coba('select count(*) from bilman.audit_log'), 'DITOLAK_HAK_TABEL');
select pg_temp.harus('anon TIDAK boleh membaca riwayat pembayaran pelanggan',
  pg_temp.coba('select count(*) from bilman.pembayaran'), 'DITOLAK_HAK_TABEL');
reset role;

\echo ''
\echo 'B. PENGAMAT (sudah login, peran terendah)'
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

select pg_temp.harus_ada('pengamat membaca skor kinerja',
  (select count(*) from public.fs_skor));
select pg_temp.harus('pengamat TIDAK boleh mengubah target',
  pg_temp.coba_tulis('update bilman.target_petugas set target_sisa = 0'), 'TANPA_EFEK');
select pg_temp.harus('pengamat TIDAK boleh mengubah bobot penilaian',
  pg_temp.coba_tulis($$update bilman.komponen_skor set bobot = 99 where kode = 'RST'$$),
  'TANPA_EFEK');
-- Untuk pembacaan pun RLS menyaring diam-diam: kuerinya berhasil, isinya
-- kosong. Yang dibuktikan karena itu adalah jumlah baris yang terlihat.
select pg_temp.harus_angka('pengamat tidak melihat satu pun baris log audit',
  (select count(*) from bilman.audit_log), 0);
select pg_temp.harus('pengamat TIDAK dapat menaikkan perannya sendiri',
  pg_temp.coba_tulis($$update bilman.profil set peran = 'ADMIN' where id = auth.uid()$$),
  'DITOLAK_RLS');

-- RLS menyaring baris tanpa menimbulkan galat, jadi yang dibuktikan di sini
-- adalah JUMLAH baris yang terlihat, bukan sekadar kuerinya tidak gagal.
select pg_temp.harus_angka('pengamat hanya melihat profilnya sendiri',
  (select count(*) from bilman.profil), 1);
reset role;

\echo ''
\echo 'C. BILMAN (REZA) — hanya wilayah kerjanya sendiri'
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);

select pg_temp.harus('bilman mencatat pengantaran miliknya sendiri',
  pg_temp.coba($$
    select public.fs_catat_pengantaran(
      (select pl.idpel from bilman.pengantaran_tul601 a
         join bilman.pelanggan pl on pl.id = a.pelanggan_id
         join bilman.petugas pt on pt.id = a.petugas_id
        where pt.kode = 'REZA' limit 1),
      '2026-09', 'DITERIMA_LANGSUNG', 'https://contoh/fto/1.jpg', -1.05, 116.98)$$),
  'BERHASIL');

select pg_temp.harus('bilman TIDAK boleh mencatat lembar petugas lain',
  pg_temp.coba($$
    select public.fs_catat_pengantaran(
      (select pl.idpel from bilman.pengantaran_tul601 a
         join bilman.pelanggan pl on pl.id = a.pelanggan_id
         join bilman.petugas pt on pt.id = a.petugas_id
        where pt.kode = 'RIDA' limit 1),
      '2026-09', 'DITERIMA_LANGSUNG', 'https://contoh/fto/2.jpg')$$),
  'DITOLAK_P0001');

select pg_temp.harus('lembar tanpa bukti foto FTO ditolak',
  pg_temp.coba($$
    select public.fs_catat_pengantaran(
      (select pl.idpel from bilman.pengantaran_tul601 a
         join bilman.pelanggan pl on pl.id = a.pelanggan_id
         join bilman.petugas pt on pt.id = a.petugas_id
        where pt.kode = 'REZA' limit 1),
      '2026-09', 'DITERIMA_LANGSUNG', '')$$),
  'DITOLAK_P0001');

-- Lembar hanya boleh berpindah petugas lewat keputusan pengawas, bukan oleh
-- petugas yang bersangkutan — kalau tidak, beban kerja bisa dialihkan diam-diam.
select pg_temp.harus('bilman TIDAK boleh memindahkan lembar ke petugas lain',
  pg_temp.coba_tulis($$
    update bilman.pengantaran_tul601
       set petugas_id = (select id from bilman.petugas where kode = 'RIDA')
     where petugas_id = (select id from bilman.petugas where kode = 'REZA')$$),
  'DITOLAK_RLS');

select pg_temp.harus('bilman TIDAK boleh mengubah targetnya sendiri',
  pg_temp.coba_tulis('update bilman.target_petugas set target_sisa = 0'), 'TANPA_EFEK');
reset role;

\echo ''
\echo 'D. SUPERVISOR — data operasional boleh, data master tidak'
set role authenticated;
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);

select pg_temp.harus('supervisor mengisi realisasi penertiban',
  pg_temp.coba_tulis('update bilman.penertiban set jumlah_surat_peringatan = 5'), 'BERHASIL');
select pg_temp.harus('supervisor menetapkan target petugas',
  pg_temp.coba_tulis('update bilman.target_petugas set catatan = $$dievaluasi ulang$$'),
  'BERHASIL');
select pg_temp.harus('supervisor mencatat pengantaran petugas mana pun',
  pg_temp.coba_tulis($$update bilman.pengantaran_tul601 set gelombang = 'HARI_16_18'
                        where jml_lembar = 2$$), 'BERHASIL');
select pg_temp.harus('supervisor TIDAK boleh mengubah data master petugas',
  pg_temp.coba_tulis($$update bilman.petugas set nama = 'X'$$), 'TANPA_EFEK');
select pg_temp.harus('supervisor TIDAK boleh mengubah bobot penilaian',
  pg_temp.coba_tulis($$update bilman.komponen_skor set bobot = 99 where kode = 'RST'$$),
  'TANPA_EFEK');
select pg_temp.harus_angka('supervisor tidak melihat satu pun baris log audit',
  (select count(*) from bilman.audit_log), 0);
reset role;

\echo ''
\echo 'E. ADMIN — boleh mengelola, dan perubahannya tercatat'
set role authenticated;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);

select pg_temp.harus('admin mengubah parameter target',
  pg_temp.coba_tulis($$update bilman.parameter set nilai = 40000000
                        where kunci = 'target_saldo_akhir_bulan'$$), 'BERHASIL');
select pg_temp.harus('admin mengubah status petugas',
  pg_temp.coba_tulis($$update bilman.petugas set catatan = 'dikonfirmasi ke Nusa Daya'
                        where kode = 'IBO'$$), 'BERHASIL');
select pg_temp.harus_ada('admin membaca log audit',
  (select count(*) from bilman.audit_log));
reset role;

\echo ''
\echo 'F. JEJAK AUDIT'
do $$
declare n bigint;
begin
  select count(*) into n from bilman.audit_log
   where tabel = 'pengantaran_tul601' and operasi = 'UPDATE';
  if n = 0 then
    raise exception '✗ Perubahan pengantaran tidak tercatat di log audit';
  end if;
  raise notice '  ✓ perubahan pengantaran tercatat di log audit (% baris)', n;
end $$;

do $$
declare n bigint;
begin
  select count(*) into n from bilman.audit_log
   where tabel = 'pengantaran_tul601' and oleh is not null;
  if n = 0 then
    raise exception '✗ Log audit tidak mencatat siapa yang mengubah';
  end if;
  raise notice '  ✓ log audit mencatat pelaku perubahan (% baris)', n;
end $$;

\echo ''
\echo 'G. ATURAN INTEGRITAS DATA'
select pg_temp.harus('status TERANTAR tanpa foto FTO ditolak basis data',
  pg_temp.coba_tulis($$update bilman.pengantaran_tul601
                          set status_antar = 'TERANTAR', foto_fto_url = null
                        where true$$), 'DITOLAK_23514');

\echo ''
\echo '✓ Seluruh uji Row Level Security lulus'
