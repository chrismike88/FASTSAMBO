-- Mengekspor isi view utama sebagai satu objek JSON, untuk dibandingkan
-- dengan lib/fallback/dataset.json oleh scripts/uji_konsistensi.py.
\pset tuples_only on
\pset format unaligned
select jsonb_pretty(jsonb_build_object(
  'kpi', (select jsonb_agg(to_jsonb(t) order by t.periode_kode)
            from (select periode_kode, sisa_nilai, sisa_lembar, beban_bilman, basis_beban,
                         rst_unit, rst_target, gap_penurunan, persen_penurunan,
                         konsentrasi_2_teratas, konsentrasi_4_teratas,
                         macet_2, macet_3, macet_lembar, macet_nilai,
                         persen_seg_bilman, persen_seg_amr, persen_seg_na, rata_rata_amr
                    from bilman.v_kpi_unit) t),
  'rst', (select jsonb_agg(to_jsonb(t) order by t.periode_kode, t.petugas_kode)
            from (select periode_kode, petugas_kode, sisa_nilai, beban_nilai, basis_beban,
                         rst, kategori, rank_rst from bilman.v_rst) t),
  'skor', (select jsonb_agg(to_jsonb(t) order by t.periode_kode, t.petugas_kode)
            from (select periode_kode, petugas_kode, rst, rollover, skor_rst, skor_rollover,
                         skor_total, bobot_terpakai from bilman.v_skor_kinerja) t),
  'saldo', (select jsonb_agg(to_jsonb(t) order by t.periode_kode, t.petugas_kode)
            from (select periode_kode, petugas_kode, total_lembar, total_nilai, persen_unit,
                         persen_kumulatif, rank_sisa, rata_rata_per_lembar,
                         rollover_persen_lembar, rollover_persen_nilai from bilman.v_saldo) t),
  'beban', (select jsonb_agg(to_jsonb(t) order by t.periode_kode, t.petugas_kode)
            from (select periode_kode, petugas_kode, total_lembar, nilai_total, nilai_1,
                         lembar_macet, nilai_macet, rata_rata_per_lembar, persen_beban_unit,
                         rank_beban, rank_risiko_lembar, rank_risiko_nilai from bilman.v_beban) t),
  'target', (select jsonb_agg(to_jsonb(t) order by t.periode_kode, t.petugas_kode)
            from (select periode_kode, petugas_kode, target_sisa, rst_target, sisa_awal,
                         harus_turun, jenis_target from bilman.v_target) t),
  'efektivitas', (select jsonb_agg(to_jsonb(t) order by t.segmen)
            from (select periode_kode, segmen, posisi_awal, masih_menunggak, tertagih,
                         persen_tertagih from bilman.v_efektivitas) t),
  'progres_antar', (select jsonb_agg(to_jsonb(t) order by t.petugas_kode)
            from (select periode_kode, petugas_kode, total_lembar, terantar, belum,
                         nilai_total, persen_antar from bilman.v_progres_antar) t)
));
