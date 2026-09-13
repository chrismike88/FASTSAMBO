-- ============================================================================
--  FASTSAMBO — LAPISAN ANALITIK
--  Migrasi 002 : Fungsi bantu + view perhitungan RST, skor kinerja, dan KPI
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Fungsi bantu
-- ---------------------------------------------------------------------------
create or replace function bilman.p(kunci_param text)
returns numeric language sql stable
set search_path = bilman, public as $$
  select nilai from bilman.parameter where kunci = kunci_param;
$$;

create or replace function bilman.nama_bulan(b smallint)
returns text language sql immutable as $$
  select (array['Januari','Februari','Maret','April','Mei','Juni','Juli',
                'Agustus','September','Oktober','November','Desember'])[b];
$$;

-- Kategori RST dibaca dari parameter, bukan dipatok di kode, agar manajer unit
-- dapat menggeser ambang batas lewat satu baris update tanpa migrasi baru.
create or replace function bilman.kategori_rst(rst numeric)
returns bilman.kategori_rst language sql stable
set search_path = bilman, public as $$
  select case
    when rst is null then 'N/A'::bilman.kategori_rst
    when rst <  bilman.p('ambang_rst_sangat_baik') then 'SANGAT_BAIK'::bilman.kategori_rst
    when rst <  bilman.p('ambang_rst_cukup')       then 'CUKUP'::bilman.kategori_rst
    when rst <  bilman.p('ambang_rst_evaluasi')    then 'PERLU_EVALUASI'::bilman.kategori_rst
    else 'PERLU_ATENSI'::bilman.kategori_rst
  end;
$$;

-- Skor 0-100 untuk satu komponen penilaian.
--   arah MINIMUM  : makin kecil makin baik (RST, rollover)
--   arah MAKSIMUM : makin besar makin baik (ketepatan antar, cash-in dini)
create or replace function bilman.skor_komponen(nilai numeric, target numeric, arah text)
returns numeric language sql immutable as $$
  select case
    when nilai is null or target is null or target = 0 then null
    when arah = 'MINIMUM' then
      case when nilai <= 0 then 100 else least(100, round(target / nilai * 100, 1)) end
    else least(100, round(nilai / target * 100, 1))
  end;
$$;

-- ---------------------------------------------------------------------------
-- V1. BEBAN TAGIHAN PER PETUGAS
-- ---------------------------------------------------------------------------
create or replace view bilman.v_beban as
select
  b.id, b.periode_id, pr.kode as periode_kode, b.petugas_id,
  pt.kode as petugas_kode, pt.nama as petugas_nama, pt.status as petugas_status,
  b.total_lembar, b.nilai_total, b.lembar_1, b.nilai_1,
  b.lembar_2, b.nilai_2, b.lembar_3, b.nilai_3,
  b.lembar_macet, b.nilai_macet,
  round(b.nilai_total / nullif(b.total_lembar, 0), 0)              as rata_rata_per_lembar,
  round(100 * b.nilai_total / nullif(sum(b.nilai_total) over (partition by b.periode_id), 0), 2)
                                                                   as persen_beban_unit,
  rank() over (partition by b.periode_id order by b.nilai_total desc) as rank_beban,
  rank() over (partition by b.periode_id order by b.nilai_macet desc) as rank_risiko_nilai,
  rank() over (partition by b.periode_id order by b.lembar_macet desc) as rank_risiko_lembar
from bilman.beban_tagihan b
join bilman.periode pr on pr.id = b.periode_id
join bilman.petugas pt on pt.id = b.petugas_id;
comment on view bilman.v_beban is
  'Beban tagihan bulan berjalan per petugas — BEBAN KERJA, bukan capaian';

-- ---------------------------------------------------------------------------
-- V2. SISA TUNGGAKAN PER PETUGAS (+ rollover dan konsentrasi Pareto)
-- ---------------------------------------------------------------------------
create or replace view bilman.v_saldo as
with dasar as (
  select
    s.id, s.periode_id, pr.kode as periode_kode, s.petugas_id,
    pt.kode as petugas_kode, pt.nama as petugas_nama,
    s.lembar_1, s.nilai_1, s.lembar_2, s.nilai_2,
    s.total_lembar, s.total_nilai,
    sum(s.total_nilai) over (partition by s.periode_id) as nilai_unit,
    rank() over (partition by s.periode_id order by s.total_nilai desc) as rank_sisa
  from bilman.saldo_tunggakan s
  join bilman.periode pr on pr.id = s.periode_id
  join bilman.petugas pt on pt.id = s.petugas_id
)
select
  d.*,
  round(d.total_nilai / nullif(d.total_lembar, 0), 0)      as rata_rata_per_lembar,
  round(100 * d.total_nilai / nullif(d.nilai_unit, 0), 2)  as persen_unit,
  -- kumulatif menurun: dasar analisa konsentrasi (aturan Pareto)
  round(100 * sum(d.total_nilai) over (
         partition by d.periode_id order by d.total_nilai desc
         rows between unbounded preceding and current row) / nullif(d.nilai_unit, 0), 2)
                                                           as persen_kumulatif,
  -- rollover: pelanggan yang dibiarkan naik dari 1 lembar ke 2 lembar
  round(100.0 * d.lembar_2 / nullif(d.total_lembar, 0), 2) as rollover_persen_lembar,
  round(100 * d.nilai_2  / nullif(d.total_nilai, 0), 2)    as rollover_persen_nilai
from dasar d;
comment on view bilman.v_saldo is
  'Sisa tunggakan per petugas beserta konsentrasi kumulatif dan rasio rollover';

-- ---------------------------------------------------------------------------
-- V3. RST — RASIO SISA TUNGGAKAN
--     Membandingkan sisa rupiah secara telanjang tidak adil karena beban
--     wilayah tiap petugas berbeda sampai 1,9 kali. RST menyetarakannya.
--
--     Bila beban periode yang sama belum tersedia (lazim pada bulan pertama
--     pendataan), beban periode berikutnya dipakai sebagai PROKSI luas wilayah
--     kerja dan ditandai pada kolom basis_beban supaya tidak terbaca sebagai
--     angka final.
-- ---------------------------------------------------------------------------
create or replace view bilman.v_rst as
select
  s.periode_id,
  s.periode_kode,
  s.petugas_id,
  s.petugas_kode,
  s.petugas_nama,
  s.total_nilai                                       as sisa_nilai,
  s.total_lembar                                      as sisa_lembar,
  coalesce(bs.nilai_total, bn.nilai_total)            as beban_nilai,
  coalesce(bs.total_lembar, bn.total_lembar)          as beban_lembar,
  case when bs.nilai_total is not null then 'AKTUAL'
       when bn.nilai_total is not null then 'PROKSI' end          as basis_beban,
  coalesce(bs.periode_kode, bn.periode_kode)          as beban_periode_kode,
  round(100 * s.total_nilai / nullif(coalesce(bs.nilai_total, bn.nilai_total), 0), 2) as rst,
  bilman.kategori_rst(
    round(100 * s.total_nilai / nullif(coalesce(bs.nilai_total, bn.nilai_total), 0), 2)) as kategori,
  case when coalesce(bs.nilai_total, bn.nilai_total) is not null then
    rank() over (
      partition by s.periode_id
      order by round(100 * s.total_nilai
                     / nullif(coalesce(bs.nilai_total, bn.nilai_total), 0), 2) asc nulls last)
  end as rank_rst
from bilman.v_saldo s
join bilman.periode p on p.id = s.periode_id
left join bilman.v_beban bs on bs.periode_id = s.periode_id and bs.petugas_id = s.petugas_id
left join lateral (
  select b.nilai_total, b.total_lembar, b.periode_kode
  from bilman.v_beban b
  join bilman.periode pb on pb.kode = b.periode_kode
  where b.petugas_id = s.petugas_id
    and (pb.tahun, pb.bulan) > (p.tahun, p.bulan)
  order by pb.tahun, pb.bulan
  limit 1
) bn on bs.nilai_total is null;
comment on view bilman.v_rst is
  'Klasemen yang adil: sisa tunggakan dibagi beban tagihan. Makin kecil makin baik';

-- ---------------------------------------------------------------------------
-- V4. PENGANTARAN TUL 6.01 — baris per pelanggan + penanda suspect
-- ---------------------------------------------------------------------------
create or replace view bilman.v_pengantaran as
select
  a.id, a.periode_id, pr.kode as periode_kode,
  a.pelanggan_id, pl.idpel, pl.nama as pelanggan_nama, pl.alamat, pl.rbm,
  pl.tarif, pl.daya_va, pl.latitude, pl.longitude,
  a.petugas_id, pt.kode as petugas_kode, pt.nama as petugas_nama,
  a.jml_lembar, a.nilai_tagihan, a.prioritas, a.gelombang,
  a.status_antar, a.status_terima, a.tgl_antar, a.jam_antar,
  a.foto_fto_url, a.jarak_validasi_m, a.catatan,
  (a.status_antar = 'TERANTAR' and a.foto_fto_url is not null)          as bukti_valid,
  (a.jarak_validasi_m is not null
   and a.jarak_validasi_m > bilman.p('jarak_validasi_maks'))            as suspect,
  (a.status_antar = 'TERANTAR'
   and extract(day from a.tgl_antar) <= bilman.p('tanggal_batas_antar'))
                                                                       as tepat_waktu
from bilman.pengantaran_tul601 a
join bilman.periode pr   on pr.id = a.periode_id
join bilman.pelanggan pl on pl.id = a.pelanggan_id
left join bilman.petugas pt on pt.id = a.petugas_id;
comment on view bilman.v_pengantaran is
  'Baris pengantaran TUL 6.01; suspect = jarak foto FTO melebihi ambang parameter';

-- ---------------------------------------------------------------------------
-- V5. PROGRES PENGANTARAN PER PETUGAS
-- ---------------------------------------------------------------------------
create or replace view bilman.v_progres_antar as
select
  a.periode_id, a.periode_kode, a.petugas_id, a.petugas_kode, a.petugas_nama,
  count(*)                                                     as total_lembar,
  count(*) filter (where a.status_antar = 'TERANTAR')          as terantar,
  count(*) filter (where a.status_antar = 'BELUM_DIANTAR')     as belum,
  count(*) filter (where a.status_antar = 'GAGAL')             as gagal,
  count(*) filter (where a.bukti_valid)                        as bukti_valid,
  count(*) filter (where a.suspect)                            as suspect,
  count(*) filter (where a.tepat_waktu)                        as tepat_waktu,
  count(*) filter (where a.status_terima = 'RUMAH_KOSONG')     as rumah_kosong,
  count(*) filter (where a.status_terima = 'TIDAK_AMAN')       as tidak_aman,
  sum(a.nilai_tagihan)                                         as nilai_total,
  sum(a.nilai_tagihan) filter (where a.status_antar = 'TERANTAR') as nilai_terantar,
  round(100.0 * count(*) filter (where a.status_antar = 'TERANTAR')
        / nullif(count(*), 0), 1)                              as persen_antar,
  -- Ketepatan TUL 6.01: terantar dengan bukti FTO valid paling lambat tanggal 18
  round(100.0 * count(*) filter (where a.bukti_valid and a.tepat_waktu)
        / nullif(count(*), 0), 1)                              as persen_ketepatan
from bilman.v_pengantaran a
group by a.periode_id, a.periode_kode, a.petugas_id, a.petugas_kode, a.petugas_nama;

-- ---------------------------------------------------------------------------
-- V6. CASH-IN DINI & EFEKTIVITAS PENERTIBAN PER PETUGAS
-- ---------------------------------------------------------------------------
create or replace view bilman.v_cash_in as
select
  b.periode_id, b.periode_kode, b.petugas_id, b.petugas_kode,
  b.total_lembar                                                  as lembar_beban,
  coalesce(k.lembar_lunas, 0)                                     as lembar_lunas,
  coalesce(k.lembar_lunas_dini, 0)                                as lembar_lunas_dini,
  coalesce(k.nilai_lunas, 0)                                      as nilai_lunas,
  round(100.0 * coalesce(k.lembar_lunas_dini, 0)
        / nullif(b.total_lembar, 0), 1)                           as persen_cash_in_dini,
  coalesce(t.jumlah_surat_peringatan, 0)                          as surat_peringatan,
  coalesce(t.jumlah_lunas_setelah_peringatan, 0)                  as lunas_setelah_peringatan,
  round(100.0 * coalesce(t.jumlah_lunas_setelah_peringatan, 0)
        / nullif(t.jumlah_surat_peringatan, 0), 1)                as persen_efektivitas_penertiban
from bilman.v_beban b
left join lateral (
  select
    count(*)                                                  as lembar_lunas,
    count(*) filter (
      where extract(day from p.tanggal_bayar) < bilman.p('tanggal_jatuh_tempo')) as lembar_lunas_dini,
    sum(p.nilai)                                              as nilai_lunas
  from bilman.pembayaran p
  where p.periode_id = b.periode_id and p.petugas_id = b.petugas_id
) k on true
left join bilman.penertiban t
  on t.periode_id = b.periode_id and t.petugas_id = b.petugas_id;

-- ---------------------------------------------------------------------------
-- V7. SKOR KINERJA — lima komponen berbobot
--
--     Komponen yang datanya belum tersedia (misalnya pengantaran yang belum
--     dimulai) bernilai NULL dan dikeluarkan dari perhitungan; bobotnya
--     dinormalisasi ulang. Tanpa itu, petugas akan terlihat bernilai nol
--     hanya karena bulan berjalan belum sampai tanggal pengantaran.
-- ---------------------------------------------------------------------------
create or replace view bilman.v_skor_kinerja as
with nilai as (
  select
    r.periode_id, r.periode_kode, r.petugas_id, r.petugas_kode, r.petugas_nama,
    r.rst, r.kategori, r.sisa_nilai, r.beban_nilai, r.basis_beban,
    -- Rollover diukur terhadap SELURUH pelanggan yang ditangani petugas
    -- bulan itu (penyebutnya beban), bukan terhadap sisa tunggakan.
    -- v_saldo.rollover_persen_lembar adalah metrik lain: komposisi sisa.
    round(100.0 * s.lembar_2 / nullif(r.beban_lembar, 0), 2) as rollover,
    pa.persen_ketepatan                     as ketepatan_tul,
    ci.persen_cash_in_dini                  as cash_in_dini,
    ci.persen_efektivitas_penertiban        as efektivitas_penertiban
  from bilman.v_rst r
  left join bilman.v_saldo s
    on s.periode_id = r.periode_id and s.petugas_id = r.petugas_id
  left join bilman.v_progres_antar pa
    on pa.periode_id = r.periode_id and pa.petugas_id = r.petugas_id
  left join bilman.v_cash_in ci
    on ci.periode_id = r.periode_id and ci.petugas_id = r.petugas_id
),
skor as (
  select
    n.*,
    bilman.skor_komponen(n.rst, (select target from bilman.komponen_skor where kode='RST'), 'MINIMUM')
      as skor_rst,
    bilman.skor_komponen(n.rollover, (select target from bilman.komponen_skor where kode='ROLLOVER'), 'MINIMUM')
      as skor_rollover,
    bilman.skor_komponen(n.ketepatan_tul, (select target from bilman.komponen_skor where kode='TUL601'), 'MAKSIMUM')
      as skor_tul,
    bilman.skor_komponen(n.cash_in_dini, (select target from bilman.komponen_skor where kode='CASHIN'), 'MAKSIMUM')
      as skor_cash_in,
    bilman.skor_komponen(n.efektivitas_penertiban, (select target from bilman.komponen_skor where kode='PENERTIBAN'), 'MAKSIMUM')
      as skor_penertiban
  from nilai n
),
bobot as (
  select
    (select bobot from bilman.komponen_skor where kode='RST')        as w_rst,
    (select bobot from bilman.komponen_skor where kode='ROLLOVER')   as w_rollover,
    (select bobot from bilman.komponen_skor where kode='TUL601')     as w_tul,
    (select bobot from bilman.komponen_skor where kode='CASHIN')     as w_cash,
    (select bobot from bilman.komponen_skor where kode='PENERTIBAN') as w_tertib
)
select
  s.periode_id, s.periode_kode, s.petugas_id, s.petugas_kode, s.petugas_nama,
  s.rst, s.kategori, s.sisa_nilai, s.beban_nilai, s.basis_beban,
  s.rollover, s.ketepatan_tul, s.cash_in_dini, s.efektivitas_penertiban,
  s.skor_rst, s.skor_rollover, s.skor_tul, s.skor_cash_in, s.skor_penertiban,
  round(
    ( coalesce(s.skor_rst,0)        * case when s.skor_rst        is null then 0 else b.w_rst      end
    + coalesce(s.skor_rollover,0)   * case when s.skor_rollover   is null then 0 else b.w_rollover end
    + coalesce(s.skor_tul,0)        * case when s.skor_tul        is null then 0 else b.w_tul      end
    + coalesce(s.skor_cash_in,0)    * case when s.skor_cash_in    is null then 0 else b.w_cash     end
    + coalesce(s.skor_penertiban,0) * case when s.skor_penertiban is null then 0 else b.w_tertib   end
    ) / nullif(
      ( case when s.skor_rst        is null then 0 else b.w_rst      end
      + case when s.skor_rollover   is null then 0 else b.w_rollover end
      + case when s.skor_tul        is null then 0 else b.w_tul      end
      + case when s.skor_cash_in    is null then 0 else b.w_cash     end
      + case when s.skor_penertiban is null then 0 else b.w_tertib   end), 0)
  , 1) as skor_total,
  ( case when s.skor_rst        is null then 0 else b.w_rst      end
  + case when s.skor_rollover   is null then 0 else b.w_rollover end
  + case when s.skor_tul        is null then 0 else b.w_tul      end
  + case when s.skor_cash_in    is null then 0 else b.w_cash     end
  + case when s.skor_penertiban is null then 0 else b.w_tertib   end) as bobot_terpakai
from skor s cross join bobot b;
comment on view bilman.v_skor_kinerja is
  'Skor kinerja bilman 5 komponen; bobot dinormalisasi atas komponen yang datanya tersedia';

-- ---------------------------------------------------------------------------
-- V8. TARGET VS REALISASI PER PETUGAS
-- ---------------------------------------------------------------------------
create or replace view bilman.v_target as
select
  t.periode_id, pr.kode as periode_kode, t.petugas_id,
  pt.kode as petugas_kode, pt.nama as petugas_nama,
  t.target_sisa, t.rst_target, t.catatan,
  sa.total_nilai                                   as sisa_awal,
  b.nilai_total                                    as beban,
  greatest(coalesce(sa.total_nilai, 0) - t.target_sisa, 0) as harus_turun,
  case when sa.total_nilai is null then 'BARU'
       when sa.total_nilai <= t.target_sisa then 'PERTAHANKAN'
       else 'TURUNKAN' end                         as jenis_target
from bilman.target_petugas t
join bilman.periode pr  on pr.id = t.periode_id
join bilman.petugas pt  on pt.id = t.petugas_id
left join bilman.v_beban b on b.periode_id = t.periode_id and b.petugas_id = t.petugas_id
left join lateral (
  -- sisa awal = saldo penutup periode sebelumnya
  select s.total_nilai
  from bilman.saldo_tunggakan s
  join bilman.periode ps on ps.id = s.periode_id
  where s.petugas_id = t.petugas_id
    and (ps.tahun, ps.bulan) < (pr.tahun, pr.bulan)
  order by ps.tahun desc, ps.bulan desc
  limit 1
) sa on true;

-- ---------------------------------------------------------------------------
-- V9. KPI UNIT — satu baris ringkasan eksekutif per periode
-- ---------------------------------------------------------------------------
create or replace view bilman.v_kpi_unit as
with s as (
  select periode_id,
         sum(total_nilai)  as sisa_nilai,
         sum(total_lembar) as sisa_lembar,
         count(*)          as jumlah_petugas,
         sum(lembar_2)     as sisa_lembar_2,
         sum(nilai_2)      as sisa_nilai_2
  from bilman.v_saldo group by periode_id
),
b as (
  select periode_id,
         sum(nilai_total)  as beban_bilman,
         sum(total_lembar) as lembar_bilman,
         sum(lembar_2)     as macet_2,
         sum(nilai_2)      as macet_nilai_2,
         sum(lembar_3)     as macet_3,
         sum(nilai_3)      as macet_nilai_3
  from bilman.v_beban group by periode_id
),
-- Penyebut RST unit. Bila beban periode ini belum didata, beban periode
-- berikutnya dipakai sebagai proksi luas wilayah kerja SELURUH unit — bukan
-- hanya petugas yang punya saldo. Menjumlah sebagian petugas saja akan
-- mengecilkan penyebut dan membuat RST unit terbaca lebih buruk dari keadaannya.
bp as (
  select pr.id as periode_id,
         coalesce(bb.beban_bilman,  prox.beban_bilman)  as beban_bilman,
         coalesce(bb.lembar_bilman, prox.lembar_bilman) as lembar_bilman,
         case when bb.beban_bilman is not null then 'AKTUAL' else 'PROKSI' end as basis_beban
  from bilman.periode pr
  left join b bb on bb.periode_id = pr.id
  left join lateral (
    select b2.beban_bilman, b2.lembar_bilman
    from b b2
    join bilman.periode p2 on p2.id = b2.periode_id
    where (p2.tahun, p2.bulan) > (pr.tahun, pr.bulan)
    order by p2.tahun, p2.bulan
    limit 1
  ) prox on bb.beban_bilman is null
),
g as (
  select periode_id,
         sum(nilai) filter (where segmen = 'BILMAN') as seg_bilman,
         sum(nilai) filter (where segmen = 'AMR')    as seg_amr,
         sum(nilai) filter (where segmen = 'NA')     as seg_na,
         sum(jumlah_lembar) filter (where segmen = 'AMR') as rek_amr,
         sum(jumlah_lembar) filter (where segmen = 'NA')  as lembar_na,
         sum(nilai)                                  as seg_total
  from bilman.segmen_beban group by periode_id
),
-- konsentrasi: berapa bagian masalah dipegang petugas teratas
k as (
  select periode_id,
         sum(total_nilai) filter (where rank_sisa <= 2) as sisa_2_teratas,
         sum(total_nilai) filter (where rank_sisa <= 4) as sisa_4_teratas
  from bilman.v_saldo group by periode_id
)
select
  pr.id as periode_id, pr.kode as periode_kode, pr.nama as periode_nama,
  pr.tahun, pr.bulan, pr.status, pr.tanggal_data, pr.target_saldo_akhir,
  u.kode as unit_kode, u.nama as unit_nama, u.up3, u.uid,
  s.sisa_nilai, s.sisa_lembar, s.jumlah_petugas, s.sisa_lembar_2, s.sisa_nilai_2,
  bp.beban_bilman, bp.lembar_bilman, bp.basis_beban,
  b.macet_2, b.macet_nilai_2, b.macet_3, b.macet_nilai_3,
  (coalesce(b.macet_2,0) + coalesce(b.macet_3,0))             as macet_lembar,
  (coalesce(b.macet_nilai_2,0) + coalesce(b.macet_nilai_3,0)) as macet_nilai,
  g.seg_bilman, g.seg_amr, g.seg_na, g.seg_total, g.rek_amr, g.lembar_na,
  round(100 * g.seg_bilman / nullif(g.seg_total,0), 1) as persen_seg_bilman,
  round(100 * g.seg_amr    / nullif(g.seg_total,0), 1) as persen_seg_amr,
  round(100 * g.seg_na     / nullif(g.seg_total,0), 1) as persen_seg_na,
  round(g.seg_amr / nullif(g.rek_amr,0), 0)            as rata_rata_amr,
  round(100 * s.sisa_nilai / nullif(bp.beban_bilman, 0), 2)      as rst_unit,
  bilman.p('target_rst_unit')                                    as rst_target,
  round(100 - 100 * s.sisa_nilai / nullif(bp.beban_bilman, 0), 2) as efektivitas_penagihan,
  round(100 - bilman.p('target_rst_unit'), 2)                     as efektivitas_dibutuhkan,
  round(100 * k.sisa_2_teratas / nullif(s.sisa_nilai,0), 1)   as konsentrasi_2_teratas,
  round(100 * k.sisa_4_teratas / nullif(s.sisa_nilai,0), 1)   as konsentrasi_4_teratas,
  greatest(s.sisa_nilai - coalesce(pr.target_saldo_akhir, bilman.p('target_saldo_akhir_bulan')), 0)
                                                              as gap_penurunan,
  round(100 * greatest(s.sisa_nilai
       - coalesce(pr.target_saldo_akhir, bilman.p('target_saldo_akhir_bulan')), 0)
       / nullif(s.sisa_nilai, 0), 1)                          as persen_penurunan
from bilman.periode pr
join bilman.unit u on u.id = pr.unit_id
left join s  on s.periode_id  = pr.id
left join b  on b.periode_id  = pr.id
left join bp on bp.periode_id = pr.id
left join g  on g.periode_id  = pr.id
left join k  on k.periode_id  = pr.id;
comment on view bilman.v_kpi_unit is
  'Ringkasan eksekutif per periode: sisa, beban tiga jalur, RST unit, konsentrasi, dan gap ke target';

-- ---------------------------------------------------------------------------
-- V10. EFEKTIVITAS PENAGIHAN ANTAR-LEMBAR (dengan persentase)
-- ---------------------------------------------------------------------------
create or replace view bilman.v_efektivitas as
select
  e.periode_id, pr.kode as periode_kode, e.segmen,
  e.posisi_awal, e.masih_menunggak, e.tertagih, e.keterangan,
  round(100.0 * e.tertagih / nullif(e.posisi_awal, 0), 1) as persen_tertagih
from bilman.efektivitas_penagihan e
join bilman.periode pr on pr.id = e.periode_id;
