-- ============================================================================
--  FASTSAMBO — MONITORING BILMAN & PERCEPATAN CASH-IN ULP SAMBOJA
--  Target platform : Supabase (PostgreSQL 15+)
--  Migrasi 001     : Tabel master, tabel transaksi, indeks, dan pemicu
-- ============================================================================

create schema if not exists bilman;
comment on schema bilman is
  'Monitoring performa petugas bilman, pengantaran TUL 6.01, dan percepatan cash-in ULP Samboja';

-- ---------------------------------------------------------------------------
-- ENUM
-- ---------------------------------------------------------------------------
do $$ begin create type bilman.status_petugas as enum
  ('AKTIF','TIDAK_AKTIF','PERLU_KONFIRMASI');
exception when duplicate_object then null; end $$;

do $$ begin create type bilman.status_periode as enum
  ('REALISASI','BERJALAN','RENCANA');
exception when duplicate_object then null; end $$;

do $$ begin create type bilman.segmen_tagihan as enum
  ('BILMAN','AMR','NA');
exception when duplicate_object then null; end $$;

-- Kategori penilaian RST. Ambang batasnya tidak dipatok di sini melainkan
-- dibaca dari tabel bilman.parameter agar dapat disetel tanpa migrasi baru.
do $$ begin create type bilman.kategori_rst as enum
  ('SANGAT_BAIK','CUKUP','PERLU_EVALUASI','PERLU_ATENSI','N/A');
exception when duplicate_object then null; end $$;

do $$ begin create type bilman.status_antar as enum
  ('BELUM_DIANTAR','TERANTAR','GAGAL','DIBATALKAN');
exception when duplicate_object then null; end $$;

do $$ begin create type bilman.status_terima as enum
  ('DITERIMA_LANGSUNG','DITITIP','RUMAH_KOSONG','MENOLAK','TIDAK_AMAN');
exception when duplicate_object then null; end $$;

do $$ begin create type bilman.status_aksi as enum
  ('RENCANA','BERJALAN','TERLAMBAT','SELESAI','BATAL');
exception when duplicate_object then null; end $$;

do $$ begin create type bilman.prioritas as enum
  ('SANGAT TINGGI','TINGGI','SEDANG','RUTIN');
exception when duplicate_object then null; end $$;

do $$ begin create type bilman.peran_pengguna as enum
  ('ADMIN','MANAJER','SUPERVISOR','BILMAN','PENGAMAT');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 1. MASTER: UNIT
-- ---------------------------------------------------------------------------
create table if not exists bilman.unit (
  id                      uuid primary key default gen_random_uuid(),
  kode                    text not null unique,
  nama                    text not null,
  up3                     text not null,
  uid                     text not null,
  jumlah_petugas_bilman   integer not null default 0,
  jumlah_pelanggan_bilman integer not null default 0,
  jumlah_rekening_amr     integer not null default 0,
  dibuat_pada             timestamptz not null default now(),
  diubah_pada             timestamptz not null default now()
);
comment on table bilman.unit is 'Master unit layanan pelanggan (ULP)';

-- ---------------------------------------------------------------------------
-- 2. PARAMETER GLOBAL (target, ambang batas, tanggal kunci)
-- ---------------------------------------------------------------------------
create table if not exists bilman.parameter (
  kunci       text primary key,
  nilai       numeric not null,
  satuan      text,
  keterangan  text,
  diubah_pada timestamptz not null default now()
);
comment on table bilman.parameter is
  'Parameter konfigurasi: target saldo akhir bulan, ambang kategori RST, target tiap komponen skor';

-- ---------------------------------------------------------------------------
-- 3. MASTER: PETUGAS BILMAN
-- ---------------------------------------------------------------------------
create table if not exists bilman.petugas (
  id            uuid primary key default gen_random_uuid(),
  unit_id       uuid not null references bilman.unit(id) on delete cascade,
  kode          text not null unique,
  nama          text not null,
  status        bilman.status_petugas not null default 'AKTIF',
  aktif_dari    date,
  aktif_sampai  date,
  catatan       text,
  dibuat_pada   timestamptz not null default now(),
  diubah_pada   timestamptz not null default now()
);
comment on table bilman.petugas is 'Master petugas bilman (vendor Nusa Daya) beserta masa aktifnya';
create index if not exists idx_petugas_unit on bilman.petugas(unit_id);

-- ---------------------------------------------------------------------------
-- 4. MASTER: PERIODE
-- ---------------------------------------------------------------------------
create table if not exists bilman.periode (
  id                 uuid primary key default gen_random_uuid(),
  unit_id            uuid not null references bilman.unit(id) on delete cascade,
  kode               text not null unique,          -- contoh: 2026-09
  tahun              smallint not null,
  bulan              smallint not null check (bulan between 1 and 12),
  nama               text not null,
  status             bilman.status_periode not null default 'BERJALAN',
  tanggal_data       date,                          -- posisi data terakhir ditarik
  target_saldo_akhir numeric(16,2),
  keterangan         text,
  dibuat_pada        timestamptz not null default now(),
  diubah_pada        timestamptz not null default now(),
  unique (unit_id, tahun, bulan)
);
comment on table bilman.periode is 'Periode bulanan penagihan; target_saldo_akhir adalah batas sisa tunggakan';

-- ---------------------------------------------------------------------------
-- 5. TRANSAKSI: SALDO TUNGGAKAN AKHIR BULAN (per petugas)
-- ---------------------------------------------------------------------------
create table if not exists bilman.saldo_tunggakan (
  id          uuid primary key default gen_random_uuid(),
  periode_id  uuid not null references bilman.periode(id) on delete cascade,
  petugas_id  uuid not null references bilman.petugas(id) on delete cascade,
  lembar_1    integer not null default 0,
  nilai_1     numeric(16,2) not null default 0,
  lembar_2    integer not null default 0,
  nilai_2     numeric(16,2) not null default 0,
  -- kolom turunan disimpan agar kueri dashboard tidak perlu menjumlah ulang
  total_lembar integer generated always as (lembar_1 + lembar_2) stored,
  total_nilai  numeric(16,2) generated always as (nilai_1 + nilai_2) stored,
  dibuat_pada timestamptz not null default now(),
  diubah_pada timestamptz not null default now(),
  unique (periode_id, petugas_id)
);
comment on table bilman.saldo_tunggakan is
  'Sisa tunggakan pada akhir periode, dipecah menurut jumlah lembar yang tertunggak';

-- ---------------------------------------------------------------------------
-- 6. TRANSAKSI: BEBAN TAGIHAN BULAN BERJALAN (per petugas)
--    Ini BEBAN KERJA, bukan prestasi — dipakai sebagai penyebut RST.
-- ---------------------------------------------------------------------------
create table if not exists bilman.beban_tagihan (
  id           uuid primary key default gen_random_uuid(),
  periode_id   uuid not null references bilman.periode(id) on delete cascade,
  petugas_id   uuid not null references bilman.petugas(id) on delete cascade,
  total_lembar integer not null default 0,
  nilai_total  numeric(16,2) not null default 0,
  lembar_1     integer not null default 0,
  lembar_2     integer not null default 0,
  nilai_2      numeric(16,2) not null default 0,
  lembar_3     integer not null default 0,
  nilai_3      numeric(16,2) not null default 0,
  nilai_1      numeric(16,2) generated always as (nilai_total - nilai_2 - nilai_3) stored,
  lembar_macet integer       generated always as (lembar_2 + lembar_3) stored,
  nilai_macet  numeric(16,2) generated always as (nilai_2 + nilai_3) stored,
  dibuat_pada  timestamptz not null default now(),
  diubah_pada  timestamptz not null default now(),
  unique (periode_id, petugas_id)
);
comment on table bilman.beban_tagihan is
  'Beban tagihan bulan berjalan per petugas; lembar 2 dan 3 adalah tunggakan yang menumpuk';

-- ---------------------------------------------------------------------------
-- 7. TRANSAKSI: BEBAN PER SEGMEN (bilman / AMR / belum termapping)
-- ---------------------------------------------------------------------------
create table if not exists bilman.segmen_beban (
  id            uuid primary key default gen_random_uuid(),
  periode_id    uuid not null references bilman.periode(id) on delete cascade,
  segmen        bilman.segmen_tagihan not null,
  nama_segmen   text not null,
  jumlah_lembar integer not null default 0,
  nilai         numeric(16,2) not null default 0,
  lembar_1      integer not null default 0,
  lembar_2      integer not null default 0,
  nilai_2       numeric(16,2) not null default 0,
  keterangan    text,
  unique (periode_id, segmen)
);
comment on table bilman.segmen_beban is
  'Pembagian beban tagihan ULP menjadi tiga jalur: bilman, AMR/pelanggan besar, dan yang belum termapping';

-- ---------------------------------------------------------------------------
-- 8. TRANSAKSI: TINDAKAN PENERTIBAN (pemutusan / pembongkaran)
-- ---------------------------------------------------------------------------
create table if not exists bilman.penertiban (
  id               uuid primary key default gen_random_uuid(),
  periode_id       uuid not null references bilman.periode(id) on delete cascade,
  petugas_id       uuid not null references bilman.petugas(id) on delete cascade,
  jumlah_pelanggan integer not null default 0,
  nilai            numeric(16,2) not null default 0,
  jumlah_lunas_setelah_peringatan integer not null default 0,
  jumlah_surat_peringatan         integer not null default 0,
  dibuat_pada      timestamptz not null default now(),
  diubah_pada      timestamptz not null default now(),
  unique (periode_id, petugas_id)
);
comment on table bilman.penertiban is
  'Rekap tindakan penertiban per petugas; keberhasilan diukur dari pelunasan setelah surat peringatan';

-- ---------------------------------------------------------------------------
-- 9. TRANSAKSI: TARGET INDIVIDUAL
-- ---------------------------------------------------------------------------
create table if not exists bilman.target_petugas (
  id          uuid primary key default gen_random_uuid(),
  periode_id  uuid not null references bilman.periode(id) on delete cascade,
  petugas_id  uuid not null references bilman.petugas(id) on delete cascade,
  target_sisa numeric(16,2) not null default 0,
  rst_target  numeric(6,3),
  catatan     text,
  dibuat_pada timestamptz not null default now(),
  diubah_pada timestamptz not null default now(),
  unique (periode_id, petugas_id)
);
comment on table bilman.target_petugas is
  'Target sisa tunggakan per petugas, dialokasikan proporsional terhadap kontribusi masalah';

-- ---------------------------------------------------------------------------
-- 10. TRANSAKSI: EFEKTIVITAS PENAGIHAN ANTAR-LEMBAR
-- ---------------------------------------------------------------------------
create table if not exists bilman.efektivitas_penagihan (
  id               uuid primary key default gen_random_uuid(),
  periode_id       uuid not null references bilman.periode(id) on delete cascade,
  segmen           text not null,              -- LEMBAR_1 / LEMBAR_2
  posisi_awal      integer not null default 0,
  masih_menunggak  integer not null default 0,
  tertagih         integer not null default 0,
  keterangan       text,
  unique (periode_id, segmen)
);
comment on table bilman.efektivitas_penagihan is
  'Konversi penagihan: berapa pelanggan tertagih dan berapa yang justru naik lembar';

-- ---------------------------------------------------------------------------
-- 11. MASTER: PELANGGAN
--     Basis pengantaran TUL 6.01. IDPEL adalah kunci relasi ke geodatabase
--     ArcGIS (layer PLGNPASCAPERRBM_ExportFeatures).
-- ---------------------------------------------------------------------------
create table if not exists bilman.pelanggan (
  id             uuid primary key default gen_random_uuid(),
  unit_id        uuid not null references bilman.unit(id) on delete cascade,
  petugas_id     uuid references bilman.petugas(id) on delete set null,
  idpel          text not null unique,
  nama           text,
  alamat         text,
  rbm            text,
  tarif          text,
  daya_va        integer,
  latitude       double precision,
  longitude      double precision,
  termapping     boolean not null default false,
  segmen         bilman.segmen_tagihan not null default 'BILMAN',
  sumber_data    text not null default 'AP2T',
  catatan        text,
  dibuat_pada    timestamptz not null default now(),
  diubah_pada    timestamptz not null default now()
);
comment on table bilman.pelanggan is
  'Master pelanggan pascabayar; petugas_id kosong berarti lembar #N/A yang belum punya penanggung jawab';
comment on column bilman.pelanggan.sumber_data is
  'AP2T untuk data riil, SLOT untuk baris kerangka yang IDPEL-nya masih menunggu penarikan data';
create index if not exists idx_pelanggan_petugas on bilman.pelanggan(petugas_id);
create index if not exists idx_pelanggan_rbm     on bilman.pelanggan(rbm);

-- ---------------------------------------------------------------------------
-- 12. TRANSAKSI: PENGANTARAN TUL 6.01  ← inti monitoring lapangan
-- ---------------------------------------------------------------------------
create table if not exists bilman.pengantaran_tul601 (
  id               uuid primary key default gen_random_uuid(),
  periode_id       uuid not null references bilman.periode(id) on delete cascade,
  pelanggan_id     uuid not null references bilman.pelanggan(id) on delete cascade,
  petugas_id       uuid references bilman.petugas(id) on delete set null,
  jml_lembar       smallint not null default 1 check (jml_lembar between 1 and 6),
  nilai_tagihan    numeric(16,2) not null default 0,
  prioritas        bilman.prioritas not null default 'RUTIN',
  gelombang        text,                       -- HARI_14_15 / HARI_16_18 / HARI_19_20
  status_antar     bilman.status_antar not null default 'BELUM_DIANTAR',
  status_terima    bilman.status_terima,
  tgl_antar        date,
  jam_antar        time,
  foto_fto_url     text,
  lat_fto          double precision,
  lon_fto          double precision,
  jarak_validasi_m double precision,
  catatan          text,
  dibuat_pada      timestamptz not null default now(),
  diubah_pada      timestamptz not null default now(),
  unique (periode_id, pelanggan_id),
  -- Aturan validasi lapangan: sebuah lembar hanya dihitung terantar bila
  -- disertai bukti foto FTO. Tanpa lampiran, record ditolak di lapisan basis
  -- data — bukan hanya diingatkan di aplikasi.
  constraint terantar_wajib_bukti check (
    status_antar <> 'TERANTAR'
    or (foto_fto_url is not null and tgl_antar is not null and status_terima is not null)
  )
);
comment on table bilman.pengantaran_tul601 is
  'Monitoring pengantaran invoice TUL 6.01 per pelanggan, lengkap dengan bukti foto FTO dan validasi jarak';
create index if not exists idx_antar_periode_petugas
  on bilman.pengantaran_tul601(periode_id, petugas_id);
create index if not exists idx_antar_status on bilman.pengantaran_tul601(status_antar);

-- Kolom turunan "suspect" tidak disimpan sebagai kolom biasa supaya tidak
-- pernah basi: ambang jaraknya dibaca dari parameter lewat view v_pengantaran.

-- ---------------------------------------------------------------------------
-- 13. TRANSAKSI: PEMBAYARAN (cash-in)
-- ---------------------------------------------------------------------------
create table if not exists bilman.pembayaran (
  id             uuid primary key default gen_random_uuid(),
  periode_id     uuid not null references bilman.periode(id) on delete cascade,
  pelanggan_id   uuid not null references bilman.pelanggan(id) on delete cascade,
  petugas_id     uuid references bilman.petugas(id) on delete set null,
  tanggal_bayar  date not null,
  nilai          numeric(16,2) not null default 0,
  jml_lembar     smallint not null default 1,
  kanal          text,                      -- PPOB / bank / mobile / loket
  setelah_peringatan boolean not null default false,
  dibuat_pada    timestamptz not null default now()
);
comment on table bilman.pembayaran is
  'Realisasi cash-in per pelanggan; dipakai menghitung komponen skor Cash-in dini';
create index if not exists idx_bayar_periode on bilman.pembayaran(periode_id, petugas_id);

-- ---------------------------------------------------------------------------
-- 14. RENCANA AKSI + LANGKAHNYA
-- ---------------------------------------------------------------------------
create table if not exists bilman.aksi (
  id                uuid primary key default gen_random_uuid(),
  periode_id        uuid not null references bilman.periode(id) on delete cascade,
  kode              text not null unique,
  judul             text not null,
  dampak_nilai      numeric(16,2) not null default 0,
  dampak_label      text,
  prioritas         bilman.prioritas not null default 'SEDANG',
  penanggung_jawab  text,
  tenggat           date,
  status            bilman.status_aksi not null default 'RENCANA',
  ringkasan         text,
  dibuat_pada       timestamptz not null default now(),
  diubah_pada       timestamptz not null default now()
);
comment on table bilman.aksi is 'Lima aksi berdampak tertinggi untuk percepatan cash-in';

create table if not exists bilman.aksi_langkah (
  id       uuid primary key default gen_random_uuid(),
  aksi_id  uuid not null references bilman.aksi(id) on delete cascade,
  urutan   smallint not null,
  langkah  text not null,
  selesai  boolean not null default false,
  unique (aksi_id, urutan)
);

-- ---------------------------------------------------------------------------
-- 15. KALENDER OPERASIONAL
-- ---------------------------------------------------------------------------
create table if not exists bilman.kalender (
  id               uuid primary key default gen_random_uuid(),
  periode_id       uuid not null references bilman.periode(id) on delete cascade,
  urutan           smallint not null,
  tanggal_mulai    date not null,
  tanggal_selesai  date not null,
  kegiatan         text not null,
  penanggung_jawab text,
  status           bilman.status_aksi not null default 'RENCANA',
  unique (periode_id, urutan),
  check (tanggal_selesai >= tanggal_mulai)
);
comment on table bilman.kalender is 'Kalender operasional penagihan bulan berjalan';

-- ---------------------------------------------------------------------------
-- 16. HAMBATAN & MITIGASI
-- ---------------------------------------------------------------------------
create table if not exists bilman.hambatan (
  id               uuid primary key default gen_random_uuid(),
  kode             text not null unique,
  hambatan         text not null,
  mitigasi         text not null,
  penanggung_jawab text
);

-- ---------------------------------------------------------------------------
-- 17. KOMPONEN SKOR KINERJA (bobot dapat disetel tanpa migrasi)
-- ---------------------------------------------------------------------------
create table if not exists bilman.komponen_skor (
  kode     text primary key,
  nama     text not null,
  bobot    numeric(5,2) not null,
  definisi text,
  target   numeric(10,3),
  arah     text not null default 'MINIMUM' check (arah in ('MINIMUM','MAKSIMUM')),
  urutan   smallint not null default 0
);
comment on table bilman.komponen_skor is
  'Lima komponen penilaian kinerja bilman; arah MINIMUM berarti makin kecil makin baik';

-- ---------------------------------------------------------------------------
-- 18. CATATAN PERBAIKAN MATERI CHECKPOINT
-- ---------------------------------------------------------------------------
create table if not exists bilman.catatan_perbaikan (
  id        uuid primary key default gen_random_uuid(),
  nomor     smallint not null unique,
  temuan    text not null,
  dampak    text,
  perbaikan text,
  status    text not null default 'TERBUKA'
);

-- ---------------------------------------------------------------------------
-- 19. PROFIL PENGGUNA (peran untuk Row Level Security)
-- ---------------------------------------------------------------------------
create table if not exists bilman.profil (
  id          uuid primary key references auth.users(id) on delete cascade,
  nama        text,
  email       text,
  peran       bilman.peran_pengguna not null default 'PENGAMAT',
  petugas_id  uuid references bilman.petugas(id) on delete set null,
  dibuat_pada timestamptz not null default now()
);
comment on table bilman.profil is
  'Peran pengguna aplikasi; petugas_id mengikat akun ke satu petugas bilman';

-- ---------------------------------------------------------------------------
-- 20. AUDIT LOG
-- ---------------------------------------------------------------------------
create table if not exists bilman.audit_log (
  id          bigserial primary key,
  tabel       text not null,
  operasi     text not null,
  baris_id    text,
  oleh        uuid,
  sebelum     jsonb,
  sesudah     jsonb,
  pada        timestamptz not null default now()
);
create index if not exists idx_audit_pada on bilman.audit_log(pada desc);

-- ---------------------------------------------------------------------------
-- PEMICU: stempel waktu perubahan + audit
-- ---------------------------------------------------------------------------
create or replace function bilman.stempel_diubah()
returns trigger language plpgsql as $$
begin
  new.diubah_pada := now();
  return new;
end $$;

create or replace function bilman.tulis_audit()
returns trigger language plpgsql security definer
set search_path = bilman, public as $$
begin
  insert into bilman.audit_log (tabel, operasi, baris_id, oleh, sebelum, sesudah)
  values (
    tg_table_name,
    tg_op,
    coalesce((to_jsonb(new)->>'id'), (to_jsonb(old)->>'id')),
    auth.uid(),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end
  );
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array['unit','parameter','petugas','periode','saldo_tunggakan',
                           'beban_tagihan','penertiban','target_petugas','pelanggan',
                           'pengantaran_tul601','aksi']
  loop
    execute format('drop trigger if exists trg_%1$s_stempel on bilman.%1$I;', t);
    execute format(
      'create trigger trg_%1$s_stempel before update on bilman.%1$I
         for each row execute function bilman.stempel_diubah();', t);
  end loop;

  -- Audit hanya untuk tabel yang isinya jadi dasar penilaian orang.
  foreach t in array array['saldo_tunggakan','beban_tagihan','penertiban',
                           'target_petugas','pengantaran_tul601','pembayaran']
  loop
    execute format('drop trigger if exists trg_%1$s_audit on bilman.%1$I;', t);
    execute format(
      'create trigger trg_%1$s_audit after insert or update or delete on bilman.%1$I
         for each row execute function bilman.tulis_audit();', t);
  end loop;
end $$;
