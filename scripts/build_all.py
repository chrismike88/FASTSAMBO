#!/usr/bin/env python3
"""Bangun seluruh keluaran FASTSAMBO dari satu sumber: data/master/*.csv

Menghasilkan dua berkas yang harus selalu sinkron:

  supabase/migrations/20260913000003_seed.sql  — data awal untuk Supabase
  lib/fallback/dataset.json                    — data yang dipakai dashboard
                                                 bila Supabase belum disetel

Seluruh angka turunan (RST, konsentrasi Pareto, rollover, skor kinerja)
dihitung di sini dengan rumus yang sama persis dengan view SQL pada migrasi
002, sehingga tampilan dashboard tidak berubah saat sumbernya berpindah dari
berkas contoh ke basis data.

    python3 scripts/build_all.py
"""
from __future__ import annotations

import csv
import json
from datetime import date, datetime, timezone
from pathlib import Path

AKAR = Path(__file__).resolve().parent.parent
MASTER = AKAR / "data" / "master"
SEED = AKAR / "supabase" / "migrations" / "20260913000003_seed.sql"
FALLBACK = AKAR / "lib" / "fallback" / "dataset.json"

BULAN = ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli",
         "Agustus", "September", "Oktober", "November", "Desember"]


# --------------------------------------------------------------------------
# Pembacaan CSV
# --------------------------------------------------------------------------
def baca(nama: str) -> list[dict]:
    with (MASTER / f"{nama}.csv").open(encoding="utf-8") as f:
        return [{k: (v.strip() if isinstance(v, str) else v) for k, v in r.items()}
                for r in csv.DictReader(f)]


def angka(v, bawaan=0.0) -> float:
    if v in (None, "", "-"):
        return bawaan
    return float(v)


def bulat(v, bawaan=0) -> int:
    if v in (None, "", "-"):
        return bawaan
    return int(float(v))


def bagi(a, b, faktor=100.0, desimal=2):
    """Pembagian yang aman terhadap penyebut nol — sepadan dengan nullif() di SQL."""
    if not b:
        return None
    return round(a / b * faktor, desimal)


# --------------------------------------------------------------------------
# Perhitungan turunan — cerminan view SQL pada migrasi 002
# --------------------------------------------------------------------------
def kategori_rst(rst, par):
    if rst is None:
        return "N/A"
    if rst < par["ambang_rst_sangat_baik"]:
        return "SANGAT_BAIK"
    if rst < par["ambang_rst_cukup"]:
        return "CUKUP"
    if rst < par["ambang_rst_evaluasi"]:
        return "PERLU_EVALUASI"
    return "PERLU_ATENSI"


def skor_komponen(nilai, target, arah):
    if nilai is None or not target:
        return None
    if arah == "MINIMUM":
        return 100.0 if nilai <= 0 else round(min(100.0, target / nilai * 100), 1)
    return round(min(100.0, nilai / target * 100), 1)


def bangun():
    unit = baca("unit")[0]
    par = {r["kunci"]: angka(r["nilai"]) for r in baca("parameter")}
    par_baris = baca("parameter")
    petugas = baca("petugas")
    periode = baca("periode")
    saldo_csv = baca("saldo_tunggakan")
    beban_csv = baca("beban_tagihan")
    segmen_csv = baca("segmen_beban")
    tertib_csv = baca("penertiban")
    target_csv = baca("target_petugas")
    efek_csv = baca("efektivitas_penagihan")
    aksi_csv = baca("aksi")
    kalender_csv = baca("kalender")
    hambatan_csv = baca("hambatan")
    komponen_csv = baca("komponen_skor")
    catatan_csv = baca("catatan_perbaikan")

    nama_petugas = {p["kode"]: p["nama"] for p in petugas}
    urut_periode = sorted(periode, key=lambda p: (bulat(p["tahun"]), bulat(p["bulan"])))
    kode_periode = [p["kode"] for p in urut_periode]

    # ---- beban per periode ------------------------------------------------
    beban: list[dict] = []
    for pk in kode_periode:
        baris = [r for r in beban_csv if r["periode"] == pk]
        total_nilai = sum(angka(r["nilai_total"]) for r in baris)
        for r in baris:
            nilai_total = angka(r["nilai_total"])
            nilai_2, nilai_3 = angka(r["nilai_2"]), angka(r["nilai_3"])
            lembar_2, lembar_3 = bulat(r["lembar_2"]), bulat(r["lembar_3"])
            beban.append({
                "periode_kode": pk,
                "petugas_kode": r["petugas"],
                "petugas_nama": nama_petugas.get(r["petugas"], r["petugas"]),
                "total_lembar": bulat(r["total_lembar"]),
                "nilai_total": nilai_total,
                "lembar_1": bulat(r["lembar_1"]),
                "nilai_1": nilai_total - nilai_2 - nilai_3,
                "lembar_2": lembar_2, "nilai_2": nilai_2,
                "lembar_3": lembar_3, "nilai_3": nilai_3,
                "lembar_macet": lembar_2 + lembar_3,
                "nilai_macet": nilai_2 + nilai_3,
                "rata_rata_per_lembar": bagi(nilai_total, bulat(r["total_lembar"]), 1, 0),
                "persen_beban_unit": bagi(nilai_total, total_nilai),
            })
    for pk in kode_periode:
        baris = [b for b in beban if b["periode_kode"] == pk]
        for i, b in enumerate(sorted(baris, key=lambda x: -x["nilai_total"]), 1):
            b["rank_beban"] = i
        for i, b in enumerate(sorted(baris, key=lambda x: -x["nilai_macet"]), 1):
            b["rank_risiko_nilai"] = i
        for i, b in enumerate(sorted(baris, key=lambda x: -x["lembar_macet"]), 1):
            b["rank_risiko_lembar"] = i

    # ---- saldo per periode (+ Pareto & rollover) --------------------------
    saldo: list[dict] = []
    for pk in kode_periode:
        baris = [r for r in saldo_csv if r["periode"] == pk]
        nilai_unit = sum(angka(r["nilai_1"]) + angka(r["nilai_2"]) for r in baris)
        susun = []
        for r in baris:
            n1, n2 = angka(r["nilai_1"]), angka(r["nilai_2"])
            l1, l2 = bulat(r["lembar_1"]), bulat(r["lembar_2"])
            susun.append({
                "periode_kode": pk,
                "petugas_kode": r["petugas"],
                "petugas_nama": nama_petugas.get(r["petugas"], r["petugas"]),
                "lembar_1": l1, "nilai_1": n1, "lembar_2": l2, "nilai_2": n2,
                "total_lembar": l1 + l2, "total_nilai": n1 + n2,
                "nilai_unit": nilai_unit,
                "rata_rata_per_lembar": bagi(n1 + n2, l1 + l2, 1, 0),
                "persen_unit": bagi(n1 + n2, nilai_unit),
                "rollover_persen_lembar": bagi(l2, l1 + l2),
                "rollover_persen_nilai": bagi(n2, n1 + n2),
            })
        susun.sort(key=lambda x: -x["total_nilai"])
        kumulatif = 0.0
        for i, s in enumerate(susun, 1):
            kumulatif += s["total_nilai"]
            s["rank_sisa"] = i
            s["persen_kumulatif"] = bagi(kumulatif, nilai_unit)
        saldo.extend(susun)

    # ---- RST --------------------------------------------------------------
    def beban_untuk(kode_ptg, pk):
        """Beban periode yang sama; bila belum ada, beban periode berikutnya
        dipakai sebagai proksi luas wilayah kerja (ditandai PROKSI)."""
        cocok = [b for b in beban if b["periode_kode"] == pk and b["petugas_kode"] == kode_ptg]
        if cocok:
            return cocok[0], "AKTUAL"
        i = kode_periode.index(pk)
        for pk2 in kode_periode[i + 1:]:
            lanjut = [b for b in beban if b["periode_kode"] == pk2 and b["petugas_kode"] == kode_ptg]
            if lanjut:
                return lanjut[0], "PROKSI"
        return None, None

    rst: list[dict] = []
    for s in saldo:
        b, basis = beban_untuk(s["petugas_kode"], s["periode_kode"])
        nilai = bagi(s["total_nilai"], b["nilai_total"]) if b else None
        rst.append({
            "periode_kode": s["periode_kode"],
            "petugas_kode": s["petugas_kode"],
            "petugas_nama": s["petugas_nama"],
            "sisa_nilai": s["total_nilai"],
            "sisa_lembar": s["total_lembar"],
            "beban_nilai": b["nilai_total"] if b else None,
            "beban_lembar": b["total_lembar"] if b else None,
            "beban_periode_kode": b["periode_kode"] if b else None,
            "basis_beban": basis,
            "rst": nilai,
            "kategori": kategori_rst(nilai, par),
        })
    for pk in kode_periode:
        baris = [r for r in rst if r["periode_kode"] == pk and r["rst"] is not None]
        for i, r in enumerate(sorted(baris, key=lambda x: x["rst"]), 1):
            r["rank_rst"] = i

    # ---- penertiban -------------------------------------------------------
    penertiban = [{
        "periode_kode": r["periode"],
        "petugas_kode": r["petugas"],
        "petugas_nama": nama_petugas.get(r["petugas"], r["petugas"]),
        "jumlah_pelanggan": bulat(r["jumlah_pelanggan"]),
        "nilai": angka(r["nilai"]),
        "rata_rata": bagi(angka(r["nilai"]), bulat(r["jumlah_pelanggan"]), 1, 0),
        "jumlah_surat_peringatan": 0,
        "jumlah_lunas_setelah_peringatan": 0,
    } for r in tertib_csv]

    # ---- pengantaran TUL 6.01 --------------------------------------------
    # Daftar prioritas gelombang pertama: seluruh pelanggan 2 dan 3 lembar.
    # Jumlah per petugas diambil dari beban riil; IDPEL masih berupa kerangka
    # yang menunggu penarikan dari AP2T, karena data sumber hanya agregat.
    pk_jalan = next((p["kode"] for p in urut_periode if p["status"] == "BERJALAN"),
                    kode_periode[-1])
    pelanggan: list[dict] = []
    pengantaran: list[dict] = []
    for b in sorted([x for x in beban if x["periode_kode"] == pk_jalan],
                    key=lambda x: -x["nilai_macet"]):
        for lembar in (3, 2):
            jml = b[f"lembar_{lembar}"]
            nilai = b[f"nilai_{lembar}"]
            if not jml:
                continue
            rata = round(nilai / jml, 2)
            for i in range(1, jml + 1):
                idpel = f"SLOT-{b['petugas_kode']}-{lembar}L-{i:03d}"
                pelanggan.append({
                    "idpel": idpel,
                    "petugas_kode": b["petugas_kode"],
                    "sumber_data": "SLOT",
                    "termapping": False,
                    "catatan": "Kerangka menunggu penarikan IDPEL riil dari AP2T",
                })
                pengantaran.append({
                    "periode_kode": pk_jalan,
                    "idpel": idpel,
                    "petugas_kode": b["petugas_kode"],
                    "petugas_nama": b["petugas_nama"],
                    "jml_lembar": lembar,
                    "nilai_tagihan": rata,
                    "prioritas": "SANGAT TINGGI" if lembar == 3 else "TINGGI",
                    "gelombang": "HARI_14_15",
                    "status_antar": "BELUM_DIANTAR",
                    "status_terima": None,
                    "tgl_antar": None,
                    "catatan": "Nilai adalah rata-rata lembar petugas — perbarui saat IDPEL riil ditarik",
                })

    progres = []
    for b in [x for x in beban if x["periode_kode"] == pk_jalan]:
        milik = [a for a in pengantaran if a["petugas_kode"] == b["petugas_kode"]]
        terantar = [a for a in milik if a["status_antar"] == "TERANTAR"]
        progres.append({
            "periode_kode": pk_jalan,
            "petugas_kode": b["petugas_kode"],
            "petugas_nama": b["petugas_nama"],
            "total_lembar": len(milik),
            "terantar": len(terantar),
            "belum": len(milik) - len(terantar),
            "suspect": 0,
            "nilai_total": round(sum(a["nilai_tagihan"] for a in milik), 2),
            "nilai_terantar": round(sum(a["nilai_tagihan"] for a in terantar), 2),
            "persen_antar": bagi(len(terantar), len(milik), 100, 1) or 0.0,
            "persen_ketepatan": None,
        })

    # ---- skor kinerja -----------------------------------------------------
    komponen = [{
        "kode": r["kode"], "nama": r["nama"], "bobot": angka(r["bobot"]),
        "definisi": r["definisi"], "target": angka(r["target"]), "arah": r["arah"],
    } for r in komponen_csv]
    kmp = {k["kode"]: k for k in komponen}

    skor: list[dict] = []
    for r in rst:
        s = next((x for x in saldo if x["periode_kode"] == r["periode_kode"]
                  and x["petugas_kode"] == r["petugas_kode"]), None)
        pr = next((x for x in progres if x["periode_kode"] == r["periode_kode"]
                   and x["petugas_kode"] == r["petugas_kode"]), None)
        # Rollover diukur terhadap beban, bukan terhadap sisa: penyebutnya
        # adalah seluruh pelanggan yang ditangani petugas pada bulan itu.
        rollover = bagi(s["lembar_2"], r["beban_lembar"]) if s and r["beban_lembar"] else None
        komp = {
            "RST": (r["rst"], "MINIMUM"),
            "ROLLOVER": (rollover, "MINIMUM"),
            "TUL601": (pr["persen_ketepatan"] if pr else None, "MAKSIMUM"),
            "CASHIN": (None, "MAKSIMUM"),
            "PENERTIBAN": (None, "MAKSIMUM"),
        }
        nilai_skor, bobot_pakai, total = {}, 0.0, 0.0
        for kode, (nilai, arah) in komp.items():
            sk = skor_komponen(nilai, kmp[kode]["target"], arah)
            nilai_skor[kode] = sk
            if sk is not None:
                bobot_pakai += kmp[kode]["bobot"]
                total += sk * kmp[kode]["bobot"]
        skor.append({
            "periode_kode": r["periode_kode"],
            "petugas_kode": r["petugas_kode"],
            "petugas_nama": r["petugas_nama"],
            "rst": r["rst"], "kategori": r["kategori"], "basis_beban": r["basis_beban"],
            "sisa_nilai": r["sisa_nilai"], "beban_nilai": r["beban_nilai"],
            "rollover": rollover,
            "ketepatan_tul": komp["TUL601"][0],
            "cash_in_dini": None,
            "efektivitas_penertiban": None,
            "skor_rst": nilai_skor["RST"],
            "skor_rollover": nilai_skor["ROLLOVER"],
            "skor_tul": nilai_skor["TUL601"],
            "skor_cash_in": nilai_skor["CASHIN"],
            "skor_penertiban": nilai_skor["PENERTIBAN"],
            "skor_total": round(total / bobot_pakai, 1) if bobot_pakai else None,
            "bobot_terpakai": bobot_pakai,
        })
    for pk in kode_periode:
        baris = [x for x in skor if x["periode_kode"] == pk and x["skor_total"] is not None]
        for i, x in enumerate(sorted(baris, key=lambda y: -y["skor_total"]), 1):
            x["rank_skor"] = i

    # ---- target -----------------------------------------------------------
    target = []
    for r in target_csv:
        pk = r["periode"]
        i = kode_periode.index(pk)
        sisa_awal = None
        for pk_lalu in reversed(kode_periode[:i]):
            cocok = [s for s in saldo if s["periode_kode"] == pk_lalu
                     and s["petugas_kode"] == r["petugas"]]
            if cocok:
                sisa_awal = cocok[0]["total_nilai"]
                break
        b = next((x for x in beban if x["periode_kode"] == pk
                  and x["petugas_kode"] == r["petugas"]), None)
        tgt = angka(r["target_sisa"])
        target.append({
            "periode_kode": pk,
            "petugas_kode": r["petugas"],
            "petugas_nama": nama_petugas.get(r["petugas"], r["petugas"]),
            "target_sisa": tgt,
            "rst_target": angka(r["rst_target"]) or None,
            "sisa_awal": sisa_awal,
            "beban": b["nilai_total"] if b else None,
            "harus_turun": max((sisa_awal or 0) - tgt, 0) if sisa_awal is not None else 0,
            "jenis_target": ("BARU" if sisa_awal is None
                             else "PERTAHANKAN" if sisa_awal <= tgt else "TURUNKAN"),
            "catatan": r["catatan"],
        })

    # ---- segmen & efektivitas --------------------------------------------
    segmen = [{
        "periode_kode": r["periode"], "segmen": r["segmen"], "nama_segmen": r["nama_segmen"],
        "jumlah_lembar": bulat(r["jumlah_lembar"]), "nilai": angka(r["nilai"]),
        "lembar_1": bulat(r["lembar_1"]), "lembar_2": bulat(r["lembar_2"]),
        "nilai_2": angka(r["nilai_2"]), "keterangan": r["keterangan"],
    } for r in segmen_csv]
    for pk in kode_periode:
        tot = sum(s["nilai"] for s in segmen if s["periode_kode"] == pk)
        for s in [x for x in segmen if x["periode_kode"] == pk]:
            s["persen_unit"] = bagi(s["nilai"], tot, 100, 1)
            s["rata_rata"] = bagi(s["nilai"], s["jumlah_lembar"], 1, 0)

    efektivitas = [{
        "periode_kode": r["periode"], "segmen": r["segmen"],
        "posisi_awal": bulat(r["posisi_awal"]),
        "masih_menunggak": bulat(r["masih_menunggak"]),
        "tertagih": bulat(r["tertagih"]),
        "persen_tertagih": bagi(bulat(r["tertagih"]), bulat(r["posisi_awal"]), 100, 1),
        "keterangan": r["keterangan"],
    } for r in efek_csv]

    # ---- KPI unit per periode --------------------------------------------
    kpi = []
    for p in urut_periode:
        pk = p["kode"]
        s_baris = [x for x in saldo if x["periode_kode"] == pk]
        b_baris = [x for x in beban if x["periode_kode"] == pk]
        g_baris = [x for x in segmen if x["periode_kode"] == pk]
        sisa = sum(x["total_nilai"] for x in s_baris)
        beban_bilman = sum(x["nilai_total"] for x in b_baris)
        lembar_bilman = sum(x["total_lembar"] for x in b_baris)
        # Bila beban periode ini belum didata, beban periode berikutnya dipakai
        # sebagai proksi luas wilayah kerja unit — seluruh petugas, termasuk
        # yang wilayahnya berpindah tangan antar bulan. Menjumlah hanya petugas
        # yang punya saldo akan mengecilkan penyebut dan membuat RST unit
        # terbaca lebih buruk daripada keadaan sebenarnya.
        basis_unit = "AKTUAL"
        if not beban_bilman and s_baris:
            basis_unit = "PROKSI"
            for pk2 in kode_periode[kode_periode.index(pk) + 1:]:
                lanjut = [x for x in beban if x["periode_kode"] == pk2]
                if lanjut:
                    beban_bilman = sum(x["nilai_total"] for x in lanjut)
                    lembar_bilman = sum(x["total_lembar"] for x in lanjut)
                    break
        seg_total = sum(x["nilai"] for x in g_baris)
        amr = next((x for x in g_baris if x["segmen"] == "AMR"), None)
        na = next((x for x in g_baris if x["segmen"] == "NA"), None)
        target_saldo = angka(p["target_saldo_akhir"], par["target_saldo_akhir_bulan"])
        kpi.append({
            "periode_kode": pk, "periode_nama": p["nama"],
            "tahun": bulat(p["tahun"]), "bulan": bulat(p["bulan"]),
            "status": p["status"], "tanggal_data": p["tanggal_data"],
            "target_saldo_akhir": target_saldo,
            # Periode yang saldonya belum ditutup bernilai NULL, bukan nol —
            # "belum diketahui" dan "tidak ada tunggakan" adalah dua hal berbeda.
            "sisa_nilai": sisa if s_baris else None,
            "sisa_lembar": sum(x["total_lembar"] for x in s_baris) if s_baris else None,
            "sisa_lembar_2": sum(x["lembar_2"] for x in s_baris) if s_baris else None,
            "sisa_nilai_2": sum(x["nilai_2"] for x in s_baris) if s_baris else None,
            "jumlah_petugas": len(s_baris) or len(b_baris),
            "beban_bilman": beban_bilman,
            "lembar_bilman": lembar_bilman,
            "basis_beban": basis_unit,
            "macet_2": sum(x["lembar_2"] for x in b_baris) if b_baris else None,
            "macet_nilai_2": sum(x["nilai_2"] for x in b_baris) if b_baris else None,
            "macet_3": sum(x["lembar_3"] for x in b_baris) if b_baris else None,
            "macet_nilai_3": sum(x["nilai_3"] for x in b_baris) if b_baris else None,
            "macet_lembar": sum(x["lembar_macet"] for x in b_baris),
            "macet_nilai": sum(x["nilai_macet"] for x in b_baris),
            "seg_bilman": next((x["nilai"] for x in g_baris if x["segmen"] == "BILMAN"), 0),
            "seg_amr": amr["nilai"] if amr else 0,
            "seg_na": na["nilai"] if na else 0,
            "seg_total": seg_total,
            "rek_amr": amr["jumlah_lembar"] if amr else 0,
            "lembar_na": na["jumlah_lembar"] if na else 0,
            "persen_seg_bilman": bagi(next((x["nilai"] for x in g_baris
                                            if x["segmen"] == "BILMAN"), 0), seg_total, 100, 1),
            "persen_seg_amr": bagi(amr["nilai"] if amr else 0, seg_total, 100, 1),
            "persen_seg_na": bagi(na["nilai"] if na else 0, seg_total, 100, 1),
            "rata_rata_amr": bagi(amr["nilai"], amr["jumlah_lembar"], 1, 0) if amr else None,
            "rst_unit": bagi(sisa, beban_bilman) if s_baris else None,
            "rst_target": par["target_rst_unit"],
            "efektivitas_penagihan": (round(100 - bagi(sisa, beban_bilman), 2)
                                      if beban_bilman and sisa else None),
            "efektivitas_dibutuhkan": round(100 - par["target_rst_unit"], 2),
            "konsentrasi_2_teratas": bagi(sum(x["total_nilai"] for x in s_baris
                                              if x["rank_sisa"] <= 2), sisa, 100, 1),
            "konsentrasi_4_teratas": bagi(sum(x["total_nilai"] for x in s_baris
                                              if x["rank_sisa"] <= 4), sisa, 100, 1),
            "gap_penurunan": max(sisa - target_saldo, 0) if sisa else 0,
            "persen_penurunan": bagi(max(sisa - target_saldo, 0), sisa, 100, 1) if sisa else None,
        })

    # ---- aksi, kalender, hambatan, catatan -------------------------------
    aksi = [{
        "kode": r["kode"], "periode_kode": r["periode"], "judul": r["judul"],
        "dampak_nilai": angka(r["dampak_nilai"]), "dampak_label": r["dampak_label"],
        "prioritas": r["prioritas"], "penanggung_jawab": r["penanggung_jawab"],
        "tenggat": r["tenggat"], "status": r["status"], "ringkasan": r["ringkasan"],
        "langkah": [l.strip() for l in r["langkah"].split("|") if l.strip()],
    } for r in aksi_csv]

    kalender = [{
        "periode_kode": r["periode"], "urutan": bulat(r["urutan"]),
        "tanggal_mulai": r["tanggal_mulai"], "tanggal_selesai": r["tanggal_selesai"],
        "kegiatan": r["kegiatan"], "penanggung_jawab": r["penanggung_jawab"],
        "status": r["status"],
    } for r in kalender_csv]

    dataset = {
        "meta": {
            "unit": {
                "kode": unit["kode"], "nama": unit["nama"],
                "up3": unit["up3"], "uid": unit["uid"],
                "jumlah_petugas_bilman": bulat(unit["jumlah_petugas_bilman"]),
                "jumlah_pelanggan_bilman": bulat(unit["jumlah_pelanggan_bilman"]),
                "jumlah_rekening_amr": bulat(unit["jumlah_rekening_amr"]),
            },
            "parameter": par,
            "parameter_baris": [{"kunci": r["kunci"], "nilai": angka(r["nilai"]),
                                 "satuan": r["satuan"], "keterangan": r["keterangan"]}
                                for r in par_baris],
            "periode": [{"kode": p["kode"], "nama": p["nama"], "status": p["status"],
                         "tanggal_data": p["tanggal_data"], "tahun": bulat(p["tahun"]),
                         "bulan": bulat(p["bulan"]), "keterangan": p["keterangan"]}
                        for p in urut_periode],
            "periode_realisasi": next((p["kode"] for p in urut_periode
                                       if p["status"] == "REALISASI"), kode_periode[0]),
            "periode_berjalan": pk_jalan,
            "bulan_nama": BULAN,
            "dibangun_pada": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        },
        "petugas": [{"kode": p["kode"], "nama": p["nama"], "status": p["status"],
                     "aktif_dari": p["aktif_dari"] or None,
                     "aktif_sampai": p["aktif_sampai"] or None,
                     "catatan": p["catatan"] or None} for p in petugas],
        "kpi": kpi,
        "saldo": saldo,
        "beban": beban,
        "rst": rst,
        "skor": skor,
        "target": target,
        "penertiban": penertiban,
        "segmen": segmen,
        "efektivitas": efektivitas,
        "pengantaran": pengantaran,
        "progres_antar": progres,
        "aksi": aksi,
        "kalender": kalender,
        "hambatan": [{"kode": r["kode"], "hambatan": r["hambatan"], "mitigasi": r["mitigasi"],
                      "penanggung_jawab": r["penanggung_jawab"]} for r in hambatan_csv],
        "komponen_skor": komponen,
        "catatan_perbaikan": [{"nomor": bulat(r["nomor"]), "temuan": r["temuan"],
                               "dampak": r["dampak"], "perbaikan": r["perbaikan"],
                               "status": r["status"]} for r in catatan_csv],
        "pelanggan": pelanggan,
    }
    return dataset


# --------------------------------------------------------------------------
# Penulisan SQL
# --------------------------------------------------------------------------
def q(v) -> str:
    """Literal SQL yang aman: NULL, angka, atau teks dengan kutip yang digandakan."""
    if v is None or v == "":
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"


def tulis_seed(d: dict) -> None:
    u = d["meta"]["unit"]
    b: list[str] = []
    t = b.append

    t("-- ==========================================================================")
    t("--  FASTSAMBO — DATA AWAL (SEED)")
    t("--  Migrasi 004 : DIBANGKITKAN OTOMATIS oleh scripts/build_all.py")
    t("--  Jangan disunting langsung — ubah data/master/*.csv lalu jalankan ulang.")
    t("--")
    t("--  Sumber angka: Rekap Saldo Tunggakan ULP Samboja per 31 Agustus 2026")
    t("--  dan per 11 September 2026.")
    t("--")
    t("--  Baris pelanggan berawalan 'SLOT-' adalah KERANGKA, bukan pelanggan riil:")
    t("--  data sumber hanya memuat agregat per petugas, sehingga IDPEL, nama, dan")
    t("--  alamatnya masih menunggu penarikan dari AP2T. Jumlah kerangka per petugas")
    t("--  sudah sesuai jumlah pelanggan 2 dan 3 lembar yang sebenarnya.")
    t("-- ==========================================================================")
    t("")
    t("begin;")
    t("")
    t("-- Bersihkan data lama agar seed dapat dijalankan berulang")
    t("truncate table bilman.pengantaran_tul601, bilman.pembayaran, bilman.aksi_langkah,")
    t("               bilman.kalender, bilman.saldo_tunggakan, bilman.beban_tagihan,")
    t("               bilman.segmen_beban, bilman.penertiban, bilman.target_petugas,")
    t("               bilman.efektivitas_penagihan restart identity cascade;")
    t("delete from bilman.aksi;")
    t("delete from bilman.pelanggan;")
    t("delete from bilman.petugas;")
    t("delete from bilman.periode;")
    t("delete from bilman.catatan_perbaikan;")
    t("delete from bilman.hambatan;")
    t("delete from bilman.komponen_skor;")
    t("delete from bilman.parameter;")
    t("delete from bilman.unit;")
    t("")

    t("-- 1. UNIT")
    t("insert into bilman.unit (kode, nama, up3, uid, jumlah_petugas_bilman,")
    t("                         jumlah_pelanggan_bilman, jumlah_rekening_amr) values")
    t(f"  ({q(u['kode'])}, {q(u['nama'])}, {q(u['up3'])}, {q(u['uid'])},")
    t(f"   {u['jumlah_petugas_bilman']}, {u['jumlah_pelanggan_bilman']}, {u['jumlah_rekening_amr']});")
    t("")

    t("-- 2. PARAMETER")
    t("insert into bilman.parameter (kunci, nilai, satuan, keterangan) values")
    t(",\n".join(f"  ({q(p['kunci'])}, {p['nilai']}, {q(p['satuan'])}, {q(p['keterangan'])})"
                 for p in d["meta"]["parameter_baris"]) + ";")
    t("")

    t("-- 3. PETUGAS BILMAN")
    t("insert into bilman.petugas (unit_id, kode, nama, status, aktif_dari, aktif_sampai, catatan)")
    t("select u.id, x.kode, x.nama, x.status::bilman.status_petugas, x.dari::date, x.sampai::date, x.catatan")
    t("from bilman.unit u, (values")
    t(",\n".join(f"  ({q(p['kode'])}, {q(p['nama'])}, {q(p['status'])}, {q(p['aktif_dari'])},"
                 f" {q(p['aktif_sampai'])}, {q(p['catatan'])})" for p in d["petugas"]))
    t(f") as x(kode, nama, status, dari, sampai, catatan) where u.kode = {q(u['kode'])};")
    t("")

    t("-- 4. PERIODE")
    t("insert into bilman.periode (unit_id, kode, tahun, bulan, nama, status, tanggal_data,")
    t("                            target_saldo_akhir, keterangan)")
    t("select u.id, x.kode, x.tahun::smallint, x.bulan::smallint, x.nama,")
    t("       x.status::bilman.status_periode, x.tgl::date, x.target::numeric, x.ket")
    t("from bilman.unit u, (values")
    baris = []
    for p in d["meta"]["periode"]:
        k = next(k for k in d["kpi"] if k["periode_kode"] == p["kode"])
        tgt = k["target_saldo_akhir"] if p["status"] != "REALISASI" else None
        baris.append(f"  ({q(p['kode'])}, {p['tahun']}, {p['bulan']}, {q(p['nama'])},"
                     f" {q(p['status'])}, {q(p['tanggal_data'])}, {q(tgt)}, {q(p['keterangan'])})")
    t(",\n".join(baris))
    t(f") as x(kode, tahun, bulan, nama, status, tgl, target, ket) where u.kode = {q(u['kode'])};")
    t("")

    def per_petugas(judul, tabel, kolom, baris_data, konversi):
        t(f"-- {judul}")
        t(f"insert into bilman.{tabel} (periode_id, petugas_id, {', '.join(kolom)})")
        t(f"select pr.id, pt.id, {', '.join(konversi)}")
        t("from bilman.periode pr join (values")
        t(",\n".join(baris_data))
        t(f") as x(periode, petugas, {', '.join(kolom)}) on x.periode = pr.kode")
        t("join bilman.petugas pt on pt.kode = x.petugas;")
        t("")

    per_petugas(
        "5. SALDO TUNGGAKAN AKHIR BULAN", "saldo_tunggakan",
        ["lembar_1", "nilai_1", "lembar_2", "nilai_2"],
        [f"  ({q(s['periode_kode'])}, {q(s['petugas_kode'])}, {s['lembar_1']}, {s['nilai_1']},"
         f" {s['lembar_2']}, {s['nilai_2']})" for s in d["saldo"]],
        ["x.lembar_1::int", "x.nilai_1::numeric", "x.lembar_2::int", "x.nilai_2::numeric"])

    per_petugas(
        "6. BEBAN TAGIHAN BULAN BERJALAN", "beban_tagihan",
        ["total_lembar", "nilai_total", "lembar_1", "lembar_2", "nilai_2", "lembar_3", "nilai_3"],
        [f"  ({q(b['periode_kode'])}, {q(b['petugas_kode'])}, {b['total_lembar']}, {b['nilai_total']},"
         f" {b['lembar_1']}, {b['lembar_2']}, {b['nilai_2']}, {b['lembar_3']}, {b['nilai_3']})"
         for b in d["beban"]],
        ["x.total_lembar::int", "x.nilai_total::numeric", "x.lembar_1::int", "x.lembar_2::int",
         "x.nilai_2::numeric", "x.lembar_3::int", "x.nilai_3::numeric"])

    per_petugas(
        "7. TINDAKAN PENERTIBAN", "penertiban",
        ["jumlah_pelanggan", "nilai"],
        [f"  ({q(p['periode_kode'])}, {q(p['petugas_kode'])}, {p['jumlah_pelanggan']}, {p['nilai']})"
         for p in d["penertiban"]],
        ["x.jumlah_pelanggan::int", "x.nilai::numeric"])

    per_petugas(
        "8. TARGET INDIVIDUAL", "target_petugas",
        ["target_sisa", "rst_target", "catatan"],
        [f"  ({q(t_['periode_kode'])}, {q(t_['petugas_kode'])}, {t_['target_sisa']},"
         f" {q(t_['rst_target'])}, {q(t_['catatan'])})" for t_ in d["target"]],
        ["x.target_sisa::numeric", "x.rst_target::numeric", "x.catatan"])

    t("-- 9. BEBAN PER SEGMEN")
    t("insert into bilman.segmen_beban (periode_id, segmen, nama_segmen, jumlah_lembar,")
    t("                                 nilai, lembar_1, lembar_2, nilai_2, keterangan)")
    t("select pr.id, x.segmen::bilman.segmen_tagihan, x.nama, x.lembar::int, x.nilai::numeric,")
    t("       x.l1::int, x.l2::int, x.n2::numeric, x.ket")
    t("from bilman.periode pr join (values")
    t(",\n".join(f"  ({q(s['periode_kode'])}, {q(s['segmen'])}, {q(s['nama_segmen'])},"
                 f" {s['jumlah_lembar']}, {s['nilai']}, {s['lembar_1']}, {s['lembar_2']},"
                 f" {s['nilai_2']}, {q(s['keterangan'])})" for s in d["segmen"]))
    t(") as x(periode, segmen, nama, lembar, nilai, l1, l2, n2, ket) on x.periode = pr.kode;")
    t("")

    t("-- 10. EFEKTIVITAS PENAGIHAN ANTAR-LEMBAR")
    t("insert into bilman.efektivitas_penagihan (periode_id, segmen, posisi_awal,")
    t("                                          masih_menunggak, tertagih, keterangan)")
    t("select pr.id, x.segmen, x.awal::int, x.menunggak::int, x.tertagih::int, x.ket")
    t("from bilman.periode pr join (values")
    t(",\n".join(f"  ({q(e['periode_kode'])}, {q(e['segmen'])}, {e['posisi_awal']},"
                 f" {e['masih_menunggak']}, {e['tertagih']}, {q(e['keterangan'])})"
                 for e in d["efektivitas"]))
    t(") as x(periode, segmen, awal, menunggak, tertagih, ket) on x.periode = pr.kode;")
    t("")

    t("-- 11. KOMPONEN SKOR KINERJA")
    t("insert into bilman.komponen_skor (kode, nama, bobot, definisi, target, arah, urutan) values")
    t(",\n".join(f"  ({q(k['kode'])}, {q(k['nama'])}, {k['bobot']}, {q(k['definisi'])},"
                 f" {k['target']}, {q(k['arah'])}, {i})"
                 for i, k in enumerate(d["komponen_skor"], 1)) + ";")
    t("")

    t("-- 12. RENCANA AKSI")
    t("insert into bilman.aksi (periode_id, kode, judul, dampak_nilai, dampak_label, prioritas,")
    t("                         penanggung_jawab, tenggat, status, ringkasan)")
    t("select pr.id, x.kode, x.judul, x.dampak::numeric, x.label, x.prioritas::bilman.prioritas,")
    t("       x.pj, x.tenggat::date, x.status::bilman.status_aksi, x.ringkasan")
    t("from bilman.periode pr join (values")
    t(",\n".join(f"  ({q(a['periode_kode'])}, {q(a['kode'])}, {q(a['judul'])}, {a['dampak_nilai']},"
                 f" {q(a['dampak_label'])}, {q(a['prioritas'])}, {q(a['penanggung_jawab'])},"
                 f" {q(a['tenggat'])}, {q(a['status'])}, {q(a['ringkasan'])})" for a in d["aksi"]))
    t(") as x(periode, kode, judul, dampak, label, prioritas, pj, tenggat, status, ringkasan)")
    t("  on x.periode = pr.kode;")
    t("")

    t("insert into bilman.aksi_langkah (aksi_id, urutan, langkah)")
    t("select a.id, x.urutan::smallint, x.langkah")
    t("from bilman.aksi a join (values")
    t(",\n".join(f"  ({q(a['kode'])}, {i}, {q(l)})"
                 for a in d["aksi"] for i, l in enumerate(a["langkah"], 1)))
    t(") as x(kode, urutan, langkah) on x.kode = a.kode;")
    t("")

    t("-- 13. KALENDER OPERASIONAL")
    t("insert into bilman.kalender (periode_id, urutan, tanggal_mulai, tanggal_selesai,")
    t("                             kegiatan, penanggung_jawab, status)")
    t("select pr.id, x.urutan::smallint, x.mulai::date, x.selesai::date, x.kegiatan, x.pj,")
    t("       x.status::bilman.status_aksi")
    t("from bilman.periode pr join (values")
    t(",\n".join(f"  ({q(k['periode_kode'])}, {k['urutan']}, {q(k['tanggal_mulai'])},"
                 f" {q(k['tanggal_selesai'])}, {q(k['kegiatan'])}, {q(k['penanggung_jawab'])},"
                 f" {q(k['status'])})" for k in d["kalender"]))
    t(") as x(periode, urutan, mulai, selesai, kegiatan, pj, status) on x.periode = pr.kode;")
    t("")

    t("-- 14. HAMBATAN & MITIGASI")
    t("insert into bilman.hambatan (kode, hambatan, mitigasi, penanggung_jawab) values")
    t(",\n".join(f"  ({q(h['kode'])}, {q(h['hambatan'])}, {q(h['mitigasi'])},"
                 f" {q(h['penanggung_jawab'])})" for h in d["hambatan"]) + ";")
    t("")

    t("-- 15. CATATAN PERBAIKAN MATERI CHECKPOINT")
    t("insert into bilman.catatan_perbaikan (nomor, temuan, dampak, perbaikan, status) values")
    t(",\n".join(f"  ({c['nomor']}, {q(c['temuan'])}, {q(c['dampak'])}, {q(c['perbaikan'])},"
                 f" {q(c['status'])})" for c in d["catatan_perbaikan"]) + ";")
    t("")

    t("-- 16. PELANGGAN — kerangka gelombang prioritas (lihat catatan di kepala berkas)")
    t("insert into bilman.pelanggan (unit_id, petugas_id, idpel, termapping, sumber_data, catatan)")
    t("select u.id, pt.id, x.idpel, false, x.sumber, x.catatan")
    t("from bilman.unit u join (values")
    t(",\n".join(f"  ({q(p['idpel'])}, {q(p['petugas_kode'])}, {q(p['sumber_data'])},"
                 f" {q(p['catatan'])})" for p in d["pelanggan"]))
    t(") as x(idpel, petugas, sumber, catatan) on true")
    t("join bilman.petugas pt on pt.kode = x.petugas")
    t(f"where u.kode = {q(u['kode'])};")
    t("")

    t("-- 17. PENGANTARAN TUL 6.01 — gelombang prioritas hari 14-15")
    t("insert into bilman.pengantaran_tul601 (periode_id, pelanggan_id, petugas_id, jml_lembar,")
    t("                                       nilai_tagihan, prioritas, gelombang, status_antar, catatan)")
    t("select pr.id, pl.id, pt.id, x.lembar::smallint, x.nilai::numeric,")
    t("       x.prioritas::bilman.prioritas, x.gelombang, x.status::bilman.status_antar, x.catatan")
    t("from bilman.periode pr join (values")
    t(",\n".join(f"  ({q(a['periode_kode'])}, {q(a['idpel'])}, {q(a['petugas_kode'])},"
                 f" {a['jml_lembar']}, {a['nilai_tagihan']}, {q(a['prioritas'])},"
                 f" {q(a['gelombang'])}, {q(a['status_antar'])}, {q(a['catatan'])})"
                 for a in d["pengantaran"]))
    t(") as x(periode, idpel, petugas, lembar, nilai, prioritas, gelombang, status, catatan)")
    t("  on x.periode = pr.kode")
    t("join bilman.pelanggan pl on pl.idpel = x.idpel")
    t("join bilman.petugas pt   on pt.kode  = x.petugas;")
    t("")
    t("commit;")
    t("")

    SEED.write_text("\n".join(b), encoding="utf-8")


def main() -> None:
    d = bangun()
    FALLBACK.parent.mkdir(parents=True, exist_ok=True)
    FALLBACK.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
    tulis_seed(d)

    k_agt = next(k for k in d["kpi"] if k["periode_kode"] == d["meta"]["periode_realisasi"])
    k_sep = next(k for k in d["kpi"] if k["periode_kode"] == d["meta"]["periode_berjalan"])
    print(f"✓ {FALLBACK.relative_to(AKAR)}  ({FALLBACK.stat().st_size / 1024:.0f} KB)")
    print(f"✓ {SEED.relative_to(AKAR)}  ({SEED.stat().st_size / 1024:.0f} KB)")
    print(f"  sisa {k_agt['periode_nama']}   : Rp{k_agt['sisa_nilai']:,.0f}"
          f" — {k_agt['sisa_lembar']} lembar — RST {k_agt['rst_unit']}%")
    print(f"  beban {k_sep['periode_nama']}  : Rp{k_sep['beban_bilman']:,.0f}"
          f" — {k_sep['lembar_bilman']} lembar")
    print(f"  lembar prioritas antar : {len(d['pengantaran'])}")


if __name__ == "__main__":
    main()
