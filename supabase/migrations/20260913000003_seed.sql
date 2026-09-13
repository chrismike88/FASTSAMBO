-- ==========================================================================
--  FASTSAMBO — DATA AWAL (SEED)
--  Migrasi 004 : DIBANGKITKAN OTOMATIS oleh scripts/build_all.py
--  Jangan disunting langsung — ubah data/master/*.csv lalu jalankan ulang.
--
--  Sumber angka: Rekap Saldo Tunggakan ULP Samboja per 31 Agustus 2026
--  dan per 11 September 2026.
--
--  Baris pelanggan berawalan 'SLOT-' adalah KERANGKA, bukan pelanggan riil:
--  data sumber hanya memuat agregat per petugas, sehingga IDPEL, nama, dan
--  alamatnya masih menunggu penarikan dari AP2T. Jumlah kerangka per petugas
--  sudah sesuai jumlah pelanggan 2 dan 3 lembar yang sebenarnya.
-- ==========================================================================

begin;

-- Bersihkan data lama agar seed dapat dijalankan berulang
truncate table bilman.pengantaran_tul601, bilman.pembayaran, bilman.aksi_langkah,
               bilman.kalender, bilman.saldo_tunggakan, bilman.beban_tagihan,
               bilman.segmen_beban, bilman.penertiban, bilman.target_petugas,
               bilman.efektivitas_penagihan restart identity cascade;
delete from bilman.aksi;
delete from bilman.pelanggan;
delete from bilman.petugas;
delete from bilman.periode;
delete from bilman.catatan_perbaikan;
delete from bilman.hambatan;
delete from bilman.komponen_skor;
delete from bilman.parameter;
delete from bilman.unit;

-- 1. UNIT
insert into bilman.unit (kode, nama, up3, uid, jumlah_petugas_bilman,
                         jumlah_pelanggan_bilman, jumlah_rekening_amr) values
  ('ULP-SBJ', 'ULP Samboja', 'UP3 Balikpapan', 'UID Kalimantan Timur & Kalimantan Utara',
   10, 5743, 71);

-- 2. PARAMETER
insert into bilman.parameter (kunci, nilai, satuan, keterangan) values
  ('target_saldo_akhir_bulan', 40000000.0, 'Rp', 'Batas maksimum sisa tunggakan akhir September 2026'),
  ('target_rst_unit', 1.64, '%', 'RST unit yang dibutuhkan agar saldo tembus di bawah Rp40 juta'),
  ('tanggal_dtsen', 13.0, 'tanggal', 'Tanggal DTSen terbit — pengantaran TUL 6.01 dimulai sesudahnya'),
  ('tanggal_jatuh_tempo', 20.0, 'tanggal', 'Jatuh tempo pembayaran rekening listrik'),
  ('tanggal_batas_antar', 18.0, 'tanggal', 'Batas akhir pengantaran TUL 6.01 agar dihitung tepat waktu'),
  ('ambang_rst_sangat_baik', 1.64, '%', 'RST di bawah nilai ini dinilai Sangat Baik'),
  ('ambang_rst_cukup', 3.0, '%', 'RST di bawah nilai ini dinilai Cukup'),
  ('ambang_rst_evaluasi', 4.2, '%', 'RST di bawah nilai ini dinilai Perlu Evaluasi; di atasnya Perlu Atensi'),
  ('target_rollover', 1.5, '%', 'Batas maksimum pelanggan naik dari 1 ke 2 lembar'),
  ('target_ketepatan_tul', 95.0, '%', 'Invoice TUL 6.01 terantar dengan bukti FTO valid paling lambat tanggal 18'),
  ('target_cash_in_dini', 85.0, '%', 'Lembar lunas sebelum tanggal 20'),
  ('target_efektivitas_penertiban', 50.0, '%', 'Pelanggan melunasi setelah menerima surat peringatan'),
  ('jarak_validasi_maks', 100.0, 'meter', 'Jarak titik foto FTO ke titik pelanggan termapping sebelum ditandai suspect'),
  ('minimal_penertiban_bulanan', 1.0, 'pelanggan', 'Kewajiban eksekusi pemutusan per bulan bagi petugas dengan RST di atas 2 persen');

-- 3. PETUGAS BILMAN
insert into bilman.petugas (unit_id, kode, nama, status, aktif_dari, aktif_sampai, catatan)
select u.id, x.kode, x.nama, x.status::bilman.status_petugas, x.dari::date, x.sampai::date, x.catatan
from bilman.unit u, (values
  ('AHMAD', 'AHMAD', 'AKTIF', '2026-08-01', null, 'Nol pelanggan rollover pada Agustus — praktik kerjanya dijadikan standar unit'),
  ('FADLI', 'FADLI', 'AKTIF', '2026-08-01', null, 'Nol pelanggan rollover dengan beban terbesar kedua se-ULP'),
  ('SAPRI', 'SAPRI', 'AKTIF', '2026-08-01', null, 'Rata-rata nilai bongkar tertinggi — indikasi menyasar pelanggan daya besar'),
  ('ADE', 'ADE', 'AKTIF', '2026-08-01', null, null),
  ('ZAINI', 'ZAINI', 'AKTIF', '2026-08-01', null, 'Nol eksekusi pemutusan pada Agustus padahal sisa tunggakan besar'),
  ('RIKO', 'RIKO', 'AKTIF', '2026-08-01', null, 'Nol eksekusi pemutusan pada Agustus padahal sisa tunggakan besar'),
  ('RIDO', 'RIDO', 'AKTIF', '2026-08-01', null, null),
  ('RIDA', 'RIDA', 'AKTIF', '2026-08-01', null, 'Memegang 12 dari 39 pelanggan 3 lembar — kandidat pemutusan permanen terbanyak'),
  ('REZA', 'REZA', 'AKTIF', '2026-08-01', null, 'Nilai macet terbesar September (Rp23'),
  ('IBO', 'IBO', 'PERLU_KONFIRMASI', '2026-08-01', '2026-08-31', 'Tidak muncul pada data 11 September — konfirmasi ke Nusa Daya: mutasi / pengunduran diri / salah entri'),
  ('DONNY', 'DONNY', 'AKTIF', '2026-09-01', null, 'Petugas baru pada data September; belum memiliki baseline Agustus')
) as x(kode, nama, status, dari, sampai, catatan) where u.kode = 'ULP-SBJ';

-- 4. PERIODE
insert into bilman.periode (unit_id, kode, tahun, bulan, nama, status, tanggal_data,
                            target_saldo_akhir, keterangan)
select u.id, x.kode, x.tahun::smallint, x.bulan::smallint, x.nama,
       x.status::bilman.status_periode, x.tgl::date, x.target::numeric, x.ket
from bilman.unit u, (values
  ('2026-08', 2026, 8, 'Agustus 2026', 'REALISASI', '2026-08-31', null, 'Rekap saldo tunggakan per 31 Agustus 2026'),
  ('2026-09', 2026, 9, 'September 2026', 'BERJALAN', '2026-09-11', 40000000.0, 'Posisi per 11 September 2026 — bulan berjalan')
) as x(kode, tahun, bulan, nama, status, tgl, target, ket) where u.kode = 'ULP-SBJ';

-- 5. SALDO TUNGGAKAN AKHIR BULAN
insert into bilman.saldo_tunggakan (periode_id, petugas_id, lembar_1, nilai_1, lembar_2, nilai_2)
select pr.id, pt.id, x.lembar_1::int, x.nilai_1::numeric, x.lembar_2::int, x.nilai_2::numeric
from bilman.periode pr join (values
  ('2026-08', 'REZA', 35, 12017191.0, 11, 3336409.0),
  ('2026-08', 'RIDA', 44, 8117029.0, 15, 5076759.0),
  ('2026-08', 'RIDO', 20, 6645002.0, 6, 1899539.0),
  ('2026-08', 'RIKO', 35, 6036402.0, 6, 1465841.0),
  ('2026-08', 'ZAINI', 24, 4769735.0, 5, 1623082.0),
  ('2026-08', 'ADE', 26, 4344794.0, 5, 1043955.0),
  ('2026-08', 'SAPRI', 8, 1339926.0, 1, 262288.0),
  ('2026-08', 'IBO', 6, 1299076.0, 3, 256530.0),
  ('2026-08', 'FADLI', 7, 1055285.0, 0, 0.0),
  ('2026-08', 'AHMAD', 6, 910577.0, 0, 0.0)
) as x(periode, petugas, lembar_1, nilai_1, lembar_2, nilai_2) on x.periode = pr.kode
join bilman.petugas pt on pt.kode = x.petugas;

-- 6. BEBAN TAGIHAN BULAN BERJALAN
insert into bilman.beban_tagihan (periode_id, petugas_id, total_lembar, nilai_total, lembar_1, lembar_2, nilai_2, lembar_3, nilai_3)
select pr.id, pt.id, x.total_lembar::int, x.nilai_total::numeric, x.lembar_1::int, x.lembar_2::int, x.nilai_2::numeric, x.lembar_3::int, x.nilai_3::numeric
from bilman.periode pr join (values
  ('2026-09', 'REZA', 718, 349156312.0, 685, 25, 19525492.0, 8, 4135826.0),
  ('2026-09', 'FADLI', 624, 324821335.0, 622, 2, 1145388.0, 0, 0.0),
  ('2026-09', 'SAPRI', 589, 257477005.0, 582, 6, 1782745.0, 1, 342056.0),
  ('2026-09', 'RIDA', 599, 246297180.0, 554, 33, 14500710.0, 12, 6583096.0),
  ('2026-09', 'ZAINI', 436, 239882312.0, 416, 16, 7679637.0, 4, 2587870.0),
  ('2026-09', 'AHMAD', 554, 221495566.0, 550, 4, 901904.0, 0, 0.0),
  ('2026-09', 'RIDO', 490, 213752116.0, 477, 9, 7442672.0, 4, 1403322.0),
  ('2026-09', 'RIKO', 661, 207669681.0, 631, 24, 9333506.0, 6, 2380916.0),
  ('2026-09', 'ADE', 538, 188332413.0, 520, 15, 7355564.0, 3, 927451.0),
  ('2026-09', 'DONNY', 534, 185802497.0, 531, 2, 1785242.0, 1, 16335.0)
) as x(periode, petugas, total_lembar, nilai_total, lembar_1, lembar_2, nilai_2, lembar_3, nilai_3) on x.periode = pr.kode
join bilman.petugas pt on pt.kode = x.petugas;

-- 7. TINDAKAN PENERTIBAN
insert into bilman.penertiban (periode_id, petugas_id, jumlah_pelanggan, nilai)
select pr.id, pt.id, x.jumlah_pelanggan::int, x.nilai::numeric
from bilman.periode pr join (values
  ('2026-08', 'RIDO', 6, 1126632.0),
  ('2026-08', 'REZA', 4, 1353926.0),
  ('2026-08', 'AHMAD', 3, 766308.0),
  ('2026-08', 'SAPRI', 2, 1852085.0),
  ('2026-08', 'ADE', 2, 107078.0),
  ('2026-08', 'RIDA', 1, 152559.0),
  ('2026-08', 'IBO', 1, 10890.0),
  ('2026-08', 'FADLI', 0, 0.0),
  ('2026-08', 'RIKO', 0, 0.0),
  ('2026-08', 'ZAINI', 0, 0.0)
) as x(periode, petugas, jumlah_pelanggan, nilai) on x.periode = pr.kode
join bilman.petugas pt on pt.kode = x.petugas;

-- 8. TARGET INDIVIDUAL
insert into bilman.target_petugas (periode_id, petugas_id, target_sisa, rst_target, catatan)
select pr.id, pt.id, x.target_sisa::numeric, x.rst_target::numeric, x.catatan
from bilman.periode pr join (values
  ('2026-09', 'REZA', 8000000.0, 2.29, 'Penurunan terbesar — bersama RIDA menyumbang 59 persen dari total penurunan unit'),
  ('2026-09', 'RIDA', 7000000.0, 2.84, 'Prioritas utama; RST tertinggi se-ULP pada Agustus'),
  ('2026-09', 'RIDO', 5000000.0, 2.34, null),
  ('2026-09', 'RIKO', 5000000.0, 2.41, 'Wajib minimal 1 eksekusi pemutusan bulan ini'),
  ('2026-09', 'ZAINI', 3900000.0, 1.63, 'Wajib minimal 1 eksekusi pemutusan bulan ini'),
  ('2026-09', 'ADE', 3100000.0, 1.65, null),
  ('2026-09', 'DONNY', 3000000.0, 1.61, 'Petugas baru — target ditetapkan setara rata-rata unit'),
  ('2026-09', 'SAPRI', 1600000.0, 0.62, 'Cukup dipertahankan'),
  ('2026-09', 'FADLI', 1100000.0, 0.34, 'Cukup dipertahankan'),
  ('2026-09', 'AHMAD', 900000.0, 0.41, 'Cukup dipertahankan')
) as x(periode, petugas, target_sisa, rst_target, catatan) on x.periode = pr.kode
join bilman.petugas pt on pt.kode = x.petugas;

-- 9. BEBAN PER SEGMEN
insert into bilman.segmen_beban (periode_id, segmen, nama_segmen, jumlah_lembar,
                                 nilai, lembar_1, lembar_2, nilai_2, keterangan)
select pr.id, x.segmen::bilman.segmen_tagihan, x.nama, x.lembar::int, x.nilai::numeric,
       x.l1::int, x.l2::int, x.n2::numeric, x.ket
from bilman.periode pr join (values
  ('2026-09', 'BILMAN', 'Tagihan yang ditagih petugas bilman', 5743, 2434686417.0, 5568, 136, 71452860.0, 'Tanggung jawab 10 petugas bilman. Angka 2 lembar dikoreksi dari 137/Rp72.691.919 menjadi 136/Rp71.452.860 — subtotal pada materi sumber ikut menghitung 1 lembar milik #N/A senilai Rp1.239.059'),
  ('2026-09', 'AMR', 'AMR / Pelanggan Besar', 71, 3207529965.0, 71, 0, 0.0, 'Rata-rata Rp45.2 juta per rekening — ditangani Tim Pelayanan Pelanggan Besar UP3 Balikpapan'),
  ('2026-09', 'NA', 'Belum termapping (#N/A)', 29, 104740050.0, 28, 1, 1239059.0, 'Belum memiliki petugas penanggung jawab — perlu spatial join ke wilayah kerja RBM')
) as x(periode, segmen, nama, lembar, nilai, l1, l2, n2, ket) on x.periode = pr.kode;

-- 10. EFEKTIVITAS PENAGIHAN ANTAR-LEMBAR
insert into bilman.efektivitas_penagihan (periode_id, segmen, posisi_awal,
                                          masih_menunggak, tertagih, keterangan)
select pr.id, x.segmen, x.awal::int, x.menunggak::int, x.tertagih::int, x.ket
from bilman.periode pr join (values
  ('2026-09', 'LEMBAR_1', 211, 137, 74, 'Pelanggan 1 lembar per 31 Agustus yang naik menjadi 2 lembar per 11 September'),
  ('2026-09', 'LEMBAR_2', 52, 39, 13, 'Pelanggan 2 lembar per 31 Agustus yang naik menjadi 3 lembar per 11 September')
) as x(periode, segmen, awal, menunggak, tertagih, ket) on x.periode = pr.kode;

-- 11. KOMPONEN SKOR KINERJA
insert into bilman.komponen_skor (kode, nama, bobot, definisi, target, arah, urutan) values
  ('RST', 'RST (Rasio Sisa Tunggakan)', 40.0, 'Sisa tunggakan akhir bulan dibagi beban tagihan bulan tersebut', 1.64, 'MINIMUM', 1),
  ('ROLLOVER', 'Rollover rate', 20.0, 'Jumlah pelanggan naik dari 1 ke 2 lembar dibagi total pelanggan', 1.5, 'MINIMUM', 2),
  ('TUL601', 'Ketepatan TUL 6.01', 20.0, 'Persentase invoice terantar dengan bukti FTO valid paling lambat tanggal 18', 95.0, 'MAKSIMUM', 3),
  ('CASHIN', 'Cash-in dini', 10.0, 'Persentase lembar lunas sebelum tanggal 20', 85.0, 'MAKSIMUM', 4),
  ('PENERTIBAN', 'Efektivitas penertiban', 10.0, 'Persentase pelanggan melunasi setelah surat peringatan', 50.0, 'MAKSIMUM', 5);

-- 12. RENCANA AKSI
insert into bilman.aksi (periode_id, kode, judul, dampak_nilai, dampak_label, prioritas,
                         penanggung_jawab, tenggat, status, ringkasan)
select pr.id, x.kode, x.judul, x.dampak::numeric, x.label, x.prioritas::bilman.prioritas,
       x.pj, x.tenggat::date, x.status::bilman.status_aksi, x.ringkasan
from bilman.periode pr join (values
  ('2026-09', 'AKSI-1', 'Bersihkan #N/A dalam 3 hari kerja', 104740050.0, 'hingga Rp104.7 juta', 'SANGAT TINGGI', 'Manajer ULP + admin GIS', '2026-09-16', 'RENCANA', 'Rp104.740.050 di 29 lembar saat ini tidak ada yang bertanggung jawab menagihnya — nilainya 2,6 kali target akhir bulan. Ini pekerjaan meja, bukan pekerjaan lapangan.'),
  ('2026-09', 'AKSI-2', 'Buka jalur terpisah untuk 71 rekening AMR', 3207529965.0, 'Rp3.21 miliar', 'SANGAT TINGGI', 'Manajer ULP', '2026-09-15', 'RENCANA', '55,8 persen saldo berjalan ULP ada di sini dengan rata-rata Rp45,2 juta per rekening — satu rekening setara 1,13 kali target akhir bulan seluruh ULP. Seluruh rencana aksi September saat ini 100 persen fokus ke bilman.'),
  ('2026-09', 'AKSI-3', 'Geser prioritas pengantaran TUL 6.01 dari rute ke risiko', 72691919.0, 'mencegah Rp72.7 juta naik ke lembar 3', 'TINGGI', '10 petugas bilman', '2026-09-20', 'RENCANA', 'Pengantaran dimulai tanggal 14 setelah DTSen dan disusun per rute geografis, sedangkan jatuh tempo tanggal 20 — pelanggan yang diantar terakhir hanya punya 2 sampai 3 hari.'),
  ('2026-09', 'AKSI-4', 'Tutup celah eksekusi pemutusan', 13895060.0, 'Rp13.9 juta di RIKO + ZAINI', 'TINGGI', 'Tim penertiban + bilman', '2026-09-25', 'RENCANA', 'RIKO (Rp7,50 juta) dan ZAINI (Rp6,39 juta) nol pemutusan di Agustus. Keduanya punya 30 dan 20 pelanggan macet di September.'),
  ('2026-09', 'AKSI-5', 'Replikasi metode AHMAD & FADLI', 0.0, 'dampak struktural', 'SEDANG', 'Manajer ULP + Nusa Daya', '2026-09-30', 'RENCANA', 'Keduanya menutup Agustus dengan nol pelanggan rollover — FADLI bahkan dengan beban terbesar kedua se-ULP.')
) as x(periode, kode, judul, dampak, label, prioritas, pj, tenggat, status, ringkasan)
  on x.periode = pr.kode;

insert into bilman.aksi_langkah (aksi_id, urutan, langkah)
select a.id, x.urutan::smallint, x.langkah
from bilman.aksi a join (values
  ('AKSI-1', 1, 'Tarik 29 IDPEL tersebut dan cocokkan koordinatnya dengan layer PLGNPASCAPERRBM_ExportFeatures (10.115 pelanggan sudah termapping)'),
  ('AKSI-1', 2, 'Spatial join ke wilayah kerja RBM untuk menentukan petugas penanggung jawab'),
  ('AKSI-1', 3, 'Perbaiki field BILLMAN di geodatabase agar tidak terulang bulan depan'),
  ('AKSI-1', 4, 'Terbitkan TO tambahan ke petugas terkait pada hari yang sama'),
  ('AKSI-2', 1, 'Susun daftar 71 rekening urut nilai dan tandai yang jatuh tempo dekat'),
  ('AKSI-2', 2, 'Ajukan surat resmi ke Tim Pelayanan Pelanggan Besar UP3 Balikpapan dengan tenggat respons'),
  ('AKSI-2', 3, 'Manajer ULP melakukan courtesy call langsung ke 10 rekening teratas'),
  ('AKSI-2', 4, 'Masukkan ke laporan checkpoint sebagai baris terpisah agar kinerja bilman tidak tertutup angka AMR'),
  ('AKSI-3', 1, 'Hari 14-15: antar dulu 175 pelanggan berisiko (136 pelanggan 2 lembar + 39 pelanggan 3 lembar), dibagi 10 petugas sekitar 18 pelanggan per orang. Satu lembar 2 lembar lagi ada di baris #N/A dan baru bisa diantar setelah AKSI-1 selesai'),
  ('AKSI-3', 2, 'Hari 16-18: pelanggan 1 lembar dengan nilai besar dan daya besar'),
  ('AKSI-3', 3, 'Hari 19-20: sisanya'),
  ('AKSI-3', 4, 'Rasionalnya 5.568 pelanggan 1 lembar mayoritas memang bayar tepat waktu; yang butuh tenggang justru 175 orang yang sudah menunggak'),
  ('AKSI-4', 1, 'Wajibkan minimal 1 eksekusi pemutusan per petugas per bulan bagi yang RST di atas 2 persen'),
  ('AKSI-4', 2, 'Surat peringatan ke 39 pelanggan 3 lembar terbit paling lambat tanggal 16'),
  ('AKSI-4', 3, 'Pemutusan sementara 136 pelanggan 2 lembar pada tanggal 20-21'),
  ('AKSI-4', 4, 'Pemutusan permanen 39 pelanggan 3 lembar pada tanggal 22-25 — RIDA sendiri memegang 12 di antaranya'),
  ('AKSI-4', 5, 'Ukur keberhasilan dari pelanggan yang melunasi setelah surat peringatan, bukan dari jumlah pembongkaran'),
  ('AKSI-5', 1, 'Alokasikan 20 menit briefing Selasa untuk keduanya memaparkan cara kerja: urutan kunjungan, cara menghadapi rumah kosong, cara mengingatkan menjelang tanggal 20'),
  ('AKSI-5', 2, 'Tuangkan menjadi SOP satu halaman dan bagikan ke 10 petugas'),
  ('AKSI-5', 3, 'Untuk REZA dan RIDA pertimbangkan pendampingan langsung: ikut satu hari penuh bersama FADLI di lapangan')
) as x(kode, urutan, langkah) on x.kode = a.kode;

-- 13. KALENDER OPERASIONAL
insert into bilman.kalender (periode_id, urutan, tanggal_mulai, tanggal_selesai,
                             kegiatan, penanggung_jawab, status)
select pr.id, x.urutan::smallint, x.mulai::date, x.selesai::date, x.kegiatan, x.pj,
       x.status::bilman.status_aksi
from bilman.periode pr join (values
  ('2026-09', 1, '2026-09-14', '2026-09-16', 'Bersihkan 29 lembar #N/A, terbitkan TO tambahan', 'Manajer ULP + admin GIS', 'RENCANA'),
  ('2026-09', 2, '2026-09-14', '2026-09-15', 'Antar TUL 6.01 ke 175 pelanggan berisiko (136 pelanggan 2 lembar + 39 pelanggan 3 lembar), wajib bukti FTO', '10 petugas bilman', 'RENCANA'),
  ('2026-09', 3, '2026-09-15', '2026-09-15', 'Surat resmi ke Tim Pelanggan Besar UP3 untuk 71 rekening AMR', 'Manajer ULP', 'RENCANA'),
  ('2026-09', 4, '2026-09-16', '2026-09-16', 'Surat peringatan ke 39 pelanggan 3 lembar', 'Admin + bilman', 'RENCANA'),
  ('2026-09', 5, '2026-09-16', '2026-09-18', 'Antar TUL 6.01 pelanggan 1 lembar nilai besar / daya besar', '10 petugas bilman', 'RENCANA'),
  ('2026-09', 6, '2026-09-17', '2026-09-19', 'Reminder WA blast + telepon ke yang belum bayar', 'Admin ULP', 'RENCANA'),
  ('2026-09', 7, '2026-09-19', '2026-09-20', 'Antar TUL 6.01 sisa pelanggan', '10 petugas bilman', 'RENCANA'),
  ('2026-09', 8, '2026-09-20', '2026-09-21', 'Pemutusan sementara 136 pelanggan 2 lembar bilman', 'Tim penertiban', 'RENCANA'),
  ('2026-09', 9, '2026-09-22', '2026-09-25', 'Pemutusan permanen 39 pelanggan 3 lembar', 'Tim penertiban', 'RENCANA'),
  ('2026-09', 10, '2026-09-25', '2026-09-30', 'Sweeping masif pelanggan belum bayar, prioritas nilai besar', 'Seluruh petugas + supervisor', 'RENCANA'),
  ('2026-09', 11, '2026-09-15', '2026-09-29', 'Briefing evaluasi RST + update klasemen setiap Selasa 08.00', 'Manajer ULP + Nusa Daya', 'BERJALAN')
) as x(periode, urutan, mulai, selesai, kegiatan, pj, status) on x.periode = pr.kode;

-- 14. HAMBATAN & MITIGASI
insert into bilman.hambatan (kode, hambatan, mitigasi, penanggung_jawab) values
  ('H1', 'Program DTSEN menyita fokus petugas', 'Ajukan ke Nusa Daya agar penugasan DTSEN tidak beririsan dengan tanggal 14-25. Kalau tidak bisa, minta tambahan personel sementara untuk 2 minggu kritis.', 'Manajer ULP'),
  ('H2', 'MLS defisit 400 MW / pemadaman bergilir', 'Overlay jadwal pemadaman ke peta ArcGIS. Hindari penagihan dan pemutusan di zona yang sedang padam — sensitivitas sosialnya tinggi dan tingkat keberhasilannya rendah. Geser kunjungan ke H+1 setelah zona normal.', 'Supervisor + admin GIS'),
  ('H3', 'Pelanggan nelayan sulit ditemui', 'Kelompokkan pelanggan nelayan dalam layer tersendiri, jadwalkan kunjungan sore atau malam saat pulang melaut. Tawarkan reminder WhatsApp dan link bayar sebagai substitusi kunjungan fisik.', 'Bilman wilayah pesisir'),
  ('H4', 'Rumah kosong / anjing galak', 'Wajibkan pencatatan status kunjungan di Field Maps (Diterima / Dititip / Rumah Kosong / Tidak Aman). Status Rumah Kosong dua kali atau lebih dieskalasi ke penelusuran nomor telepon pemilik. Status Tidak Aman dikunjungi berdua, tidak sendirian.', 'Seluruh bilman'),
  ('H5', 'Sensitivitas sosial penagihan', 'Pertahankan prinsip persuasif: rata-rata pelanggan diputus hanya Rp282.604 — mayoritas rumah tangga kecil. Tawarkan opsi cicilan atau keringanan sebelum pemutusan.', 'Manajer ULP');

-- 15. CATATAN PERBAIKAN MATERI CHECKPOINT
insert into bilman.catatan_perbaikan (nomor, temuan, dampak, perbaikan, status) values
  (1, 'Slide Klasemen September menampilkan beban kerja (Rp185-349 juta) tapi diberi label Kinerja Terbaik / Perlu Evaluasi', 'Salah baca fatal — FADLI dan SAPRI terlihat buruk padahal terbaik', 'Ganti ke grafik RST, atau beri judul tegas Beban Kerja tanpa label kinerja', 'TERBUKA'),
  (2, 'Urutan batang pada grafik September tidak konsisten dengan nilainya (ZAINI 239,88 di bawah RIKO 207,66)', 'Kredibilitas data', 'Urutkan ulang secara descending', 'TERBUKA'),
  (3, 'Jumlah pelanggan 3 lembar: slide Rencana Aksi menyebut 39, slide Strategi menyebut 56', 'Angka target tidak sinkron', 'Gunakan 39 sesuai tabel 11 September', 'TERBUKA'),
  (4, 'Sisa Agustus: slide eksekutif Rp61,5 juta sedangkan grafik roadmap Rp61,8 juta', 'Selisih Rp300 ribu', 'Samakan ke Rp61.499.420', 'TERBUKA'),
  (5, 'IBO masuk klasemen September padahal tidak ada di data', 'Pertanggungjawaban wilayah tidak jelas', 'Konfirmasi status ke Nusa Daya, perbarui daftar petugas', 'TERBUKA'),
  (6, 'Subtotal bilman untuk pelanggan 2 lembar tertulis 137 lembar / Rp72.691.919, sedangkan penjumlahan baris per petugas menghasilkan 136 lembar / Rp71.452.860', 'Selisihnya persis 1 lembar senilai Rp1.239.059 — yaitu lembar 2 pada baris #N/A yang belum punya penanggung jawab, sehingga jumlah pelanggan berisiko terbaca 176 padahal yang punya petugas hanya 175', 'Pisahkan baris #N/A dari subtotal bilman. Gunakan 136 lembar untuk beban bilman dan tuntaskan 1 lembar sisanya lewat AKSI-1', 'TERBUKA');

-- 16. PELANGGAN — kerangka gelombang prioritas (lihat catatan di kepala berkas)
insert into bilman.pelanggan (unit_id, petugas_id, idpel, termapping, sumber_data, catatan)
select u.id, pt.id, x.idpel, false, x.sumber, x.catatan
from bilman.unit u join (values
  ('SLOT-REZA-3L-001', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-3L-002', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-3L-003', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-3L-004', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-3L-005', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-3L-006', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-3L-007', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-3L-008', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-001', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-002', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-003', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-004', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-005', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-006', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-007', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-008', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-009', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-010', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-011', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-012', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-013', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-014', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-015', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-016', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-017', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-018', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-019', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-020', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-021', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-022', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-023', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-024', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-REZA-2L-025', 'REZA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-001', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-002', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-003', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-004', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-005', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-006', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-007', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-008', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-009', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-010', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-011', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-3L-012', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-001', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-002', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-003', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-004', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-005', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-006', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-007', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-008', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-009', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-010', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-011', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-012', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-013', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-014', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-015', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-016', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-017', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-018', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-019', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-020', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-021', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-022', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-023', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-024', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-025', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-026', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-027', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-028', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-029', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-030', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-031', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-032', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDA-2L-033', 'RIDA', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-3L-001', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-3L-002', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-3L-003', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-3L-004', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-3L-005', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-3L-006', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-001', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-002', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-003', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-004', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-005', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-006', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-007', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-008', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-009', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-010', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-011', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-012', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-013', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-014', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-015', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-016', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-017', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-018', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-019', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-020', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-021', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-022', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-023', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIKO-2L-024', 'RIKO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-3L-001', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-3L-002', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-3L-003', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-3L-004', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-001', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-002', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-003', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-004', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-005', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-006', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-007', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-008', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-009', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-010', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-011', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-012', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-013', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-014', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-015', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ZAINI-2L-016', 'ZAINI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-3L-001', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-3L-002', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-3L-003', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-3L-004', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-2L-001', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-2L-002', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-2L-003', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-2L-004', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-2L-005', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-2L-006', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-2L-007', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-2L-008', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-RIDO-2L-009', 'RIDO', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-3L-001', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-3L-002', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-3L-003', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-001', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-002', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-003', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-004', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-005', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-006', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-007', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-008', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-009', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-010', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-011', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-012', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-013', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-014', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-ADE-2L-015', 'ADE', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-SAPRI-3L-001', 'SAPRI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-SAPRI-2L-001', 'SAPRI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-SAPRI-2L-002', 'SAPRI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-SAPRI-2L-003', 'SAPRI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-SAPRI-2L-004', 'SAPRI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-SAPRI-2L-005', 'SAPRI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-SAPRI-2L-006', 'SAPRI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-DONNY-3L-001', 'DONNY', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-DONNY-2L-001', 'DONNY', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-DONNY-2L-002', 'DONNY', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-FADLI-2L-001', 'FADLI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-FADLI-2L-002', 'FADLI', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-AHMAD-2L-001', 'AHMAD', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-AHMAD-2L-002', 'AHMAD', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-AHMAD-2L-003', 'AHMAD', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T'),
  ('SLOT-AHMAD-2L-004', 'AHMAD', 'SLOT', 'Kerangka menunggu penarikan IDPEL riil dari AP2T')
) as x(idpel, petugas, sumber, catatan) on true
join bilman.petugas pt on pt.kode = x.petugas
where u.kode = 'ULP-SBJ';

-- 17. PENGANTARAN TUL 6.01 — gelombang prioritas hari 14-15
insert into bilman.pengantaran_tul601 (periode_id, pelanggan_id, petugas_id, jml_lembar,
                                       nilai_tagihan, prioritas, gelombang, status_antar, catatan)
select pr.id, pl.id, pt.id, x.lembar::smallint, x.nilai::numeric,
       x.prioritas::bilman.prioritas, x.gelombang, x.status::bilman.status_antar, x.catatan
from bilman.periode pr join (values
  ('2026-09', 'SLOT-REZA-3L-001', 'REZA', 3, 516978.25, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-3L-002', 'REZA', 3, 516978.25, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-3L-003', 'REZA', 3, 516978.25, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-3L-004', 'REZA', 3, 516978.25, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-3L-005', 'REZA', 3, 516978.25, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-3L-006', 'REZA', 3, 516978.25, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-3L-007', 'REZA', 3, 516978.25, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-3L-008', 'REZA', 3, 516978.25, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-001', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-002', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-003', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-004', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-005', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-006', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-007', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-008', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-009', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-010', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-011', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-012', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-013', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-014', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-015', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-016', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-017', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-018', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-019', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-020', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-021', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-022', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-023', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-024', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-REZA-2L-025', 'REZA', 2, 781019.68, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-001', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-002', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-003', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-004', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-005', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-006', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-007', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-008', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-009', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-010', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-011', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-3L-012', 'RIDA', 3, 548591.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-001', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-002', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-003', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-004', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-005', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-006', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-007', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-008', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-009', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-010', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-011', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-012', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-013', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-014', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-015', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-016', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-017', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-018', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-019', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-020', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-021', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-022', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-023', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-024', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-025', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-026', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-027', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-028', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-029', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-030', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-031', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-032', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDA-2L-033', 'RIDA', 2, 439415.45, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-3L-001', 'RIKO', 3, 396819.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-3L-002', 'RIKO', 3, 396819.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-3L-003', 'RIKO', 3, 396819.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-3L-004', 'RIKO', 3, 396819.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-3L-005', 'RIKO', 3, 396819.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-3L-006', 'RIKO', 3, 396819.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-001', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-002', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-003', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-004', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-005', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-006', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-007', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-008', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-009', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-010', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-011', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-012', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-013', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-014', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-015', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-016', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-017', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-018', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-019', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-020', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-021', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-022', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-023', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIKO-2L-024', 'RIKO', 2, 388896.08, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-3L-001', 'ZAINI', 3, 646967.5, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-3L-002', 'ZAINI', 3, 646967.5, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-3L-003', 'ZAINI', 3, 646967.5, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-3L-004', 'ZAINI', 3, 646967.5, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-001', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-002', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-003', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-004', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-005', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-006', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-007', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-008', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-009', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-010', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-011', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-012', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-013', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-014', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-015', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ZAINI-2L-016', 'ZAINI', 2, 479977.31, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-3L-001', 'RIDO', 3, 350830.5, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-3L-002', 'RIDO', 3, 350830.5, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-3L-003', 'RIDO', 3, 350830.5, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-3L-004', 'RIDO', 3, 350830.5, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-2L-001', 'RIDO', 2, 826963.56, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-2L-002', 'RIDO', 2, 826963.56, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-2L-003', 'RIDO', 2, 826963.56, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-2L-004', 'RIDO', 2, 826963.56, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-2L-005', 'RIDO', 2, 826963.56, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-2L-006', 'RIDO', 2, 826963.56, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-2L-007', 'RIDO', 2, 826963.56, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-2L-008', 'RIDO', 2, 826963.56, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-RIDO-2L-009', 'RIDO', 2, 826963.56, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-3L-001', 'ADE', 3, 309150.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-3L-002', 'ADE', 3, 309150.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-3L-003', 'ADE', 3, 309150.33, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-001', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-002', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-003', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-004', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-005', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-006', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-007', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-008', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-009', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-010', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-011', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-012', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-013', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-014', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-ADE-2L-015', 'ADE', 2, 490370.93, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-SAPRI-3L-001', 'SAPRI', 3, 342056.0, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-SAPRI-2L-001', 'SAPRI', 2, 297124.17, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-SAPRI-2L-002', 'SAPRI', 2, 297124.17, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-SAPRI-2L-003', 'SAPRI', 2, 297124.17, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-SAPRI-2L-004', 'SAPRI', 2, 297124.17, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-SAPRI-2L-005', 'SAPRI', 2, 297124.17, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-SAPRI-2L-006', 'SAPRI', 2, 297124.17, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-DONNY-3L-001', 'DONNY', 3, 16335.0, 'SANGAT TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-DONNY-2L-001', 'DONNY', 2, 892621.0, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-DONNY-2L-002', 'DONNY', 2, 892621.0, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-FADLI-2L-001', 'FADLI', 2, 572694.0, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-FADLI-2L-002', 'FADLI', 2, 572694.0, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-AHMAD-2L-001', 'AHMAD', 2, 225476.0, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-AHMAD-2L-002', 'AHMAD', 2, 225476.0, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-AHMAD-2L-003', 'AHMAD', 2, 225476.0, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik'),
  ('2026-09', 'SLOT-AHMAD-2L-004', 'AHMAD', 2, 225476.0, 'TINGGI', 'HARI_14_15', 'BELUM_DIANTAR', 'Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik')
) as x(periode, idpel, petugas, lembar, nilai, prioritas, gelombang, status, catatan)
  on x.periode = pr.kode
join bilman.pelanggan pl on pl.idpel = x.idpel
join bilman.petugas pt   on pt.kode  = x.petugas;

commit;
