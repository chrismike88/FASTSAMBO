import { cache } from "react";
import contoh from "@/lib/fallback/dataset.json";
import { getSupabase, supabaseAktif } from "@/lib/supabase";
import type { Dataset } from "@/lib/types";

/** Dataset contoh yang selalu tersedia — dipakai bila Supabase belum disetel
 *  atau sedang tidak dapat dihubungi, sehingga dashboard tidak pernah kosong.
 *  Isinya dibangkitkan dari data/master/*.csv oleh scripts/build_all.py. */
export const datasetContoh = contoh as unknown as Dataset;

export const revalidate = 300; // detik

/** PostgREST mengirim kolom `numeric` sebagai STRING supaya presisinya tidak
 *  hilang. Tanpa dikembalikan ke number, seluruh grafik dan perhitungan akan
 *  memperlakukannya sebagai teks — "10" akan terurut sebelum "9".
 *  Tanggal ("2026-09-11") dan kode ("2026-09", "SLOT-REZA-3L-001") tidak cocok
 *  dengan pola ini sehingga tetap berupa teks. */
const POLA_ANGKA = /^-?\d+(\.\d+)?$/;

function keAngka<T>(baris: unknown[]): T[] {
  return (baris as Record<string, unknown>[]).map((r) => {
    const hasil: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(r)) {
      hasil[k] = typeof v === "string" && POLA_ANGKA.test(v) ? Number(v) : v;
    }
    return hasil as T;
  });
}

/** Satu tabel/view yang perlu ditarik, dipetakan ke bagian dataset. */
const SUMBER = [
  ["kpi", "fs_kpi_unit", "periode_kode"],
  ["saldo", "fs_saldo", "periode_kode,rank_sisa"],
  ["beban", "fs_beban", "periode_kode,rank_beban"],
  ["rst", "fs_rst", "periode_kode,sisa_nilai.desc"],
  ["skor", "fs_skor", "periode_kode,petugas_kode"],
  ["target", "fs_target", "periode_kode,target_sisa.desc"],
  ["penertiban", "fs_penertiban", null],
  ["segmen", "fs_segmen", "periode_kode"],
  ["efektivitas", "fs_efektivitas", "segmen"],
  ["pengantaran", "fs_pengantaran", "periode_kode,idpel"],
  ["progres_antar", "fs_progres_antar", "petugas_kode"],
  ["aksi", "fs_aksi", "kode"],
  ["kalender", "fs_kalender", "urutan"],
  ["hambatan", "fs_hambatan", "kode"],
  ["komponen_skor", "fs_komponen_skor", "urutan"],
  ["catatan_perbaikan", "fs_catatan", "nomor"],
  ["petugas", "fs_petugas", "kode"],
] as const;

/** Membaca seluruh dashboard dari Supabase. Mengembalikan null bila Supabase
 *  belum disetel, atau bila satu saja kueri gagal — dalam hal itu pemanggil
 *  memakai data contoh, bukan menampilkan halaman setengah terisi. */
async function dariSupabase(): Promise<Dataset | null> {
  const sb = getSupabase();
  if (!sb) return null;

  try {
    const hasil = await Promise.all(
      SUMBER.map(async ([, view, urut]) => {
        let kueri = sb.from(view).select("*");
        if (urut) {
          for (const bagian of urut.split(",")) {
            const [kolom, arah] = bagian.split(".");
            kueri = kueri.order(kolom, { ascending: arah !== "desc" });
          }
        }
        const { data, error } = await kueri;
        if (error) throw new Error(`${view}: ${error.message}`);
        return data ?? [];
      }),
    );

    const bagian: Record<string, unknown[]> = {};
    SUMBER.forEach(([nama], i) => {
      bagian[nama] = keAngka(hasil[i]);
    });

    // Tanpa periode dan tanpa KPI tidak ada yang bisa ditampilkan — perlakukan
    // basis data yang masih kosong sama seperti Supabase yang belum disetel.
    if (!bagian.kpi.length) return null;

    // Bagian meta tetap dari berkas contoh: isinya identitas unit dan daftar
    // periode yang tidak berubah tiap bulan. Yang diperbarui adalah angkanya.
    return {
      ...datasetContoh,
      ...(bagian as unknown as Omit<Dataset, "meta" | "pelanggan" | "sumber">),
      meta: datasetContoh.meta,
      pelanggan: datasetContoh.pelanggan,
      sumber: "supabase",
    };
  } catch (e) {
    // Dashboard tidak boleh ikut mati bila basis data sedang tidak terjangkau.
    console.error("[fastsambo] gagal membaca Supabase, memakai data contoh:", e);
    return null;
  }
}

/** Dipanggil banyak komponen dalam satu permintaan; cache() menjaga agar
 *  Supabase hanya ditanya sekali per render. */
export const getDataset = cache(async (): Promise<Dataset> => {
  if (supabaseAktif) {
    const dari = await dariSupabase();
    if (dari) return dari;
  }
  return { ...datasetContoh, sumber: "contoh" };
});

// ---------------------------------------------------------------------------
// Pembantu pemilihan data — dipakai halaman agar tidak mengulang filter
// ---------------------------------------------------------------------------
export const kpiPeriode = (d: Dataset, kode: string) =>
  d.kpi.find((k) => k.periode_kode === kode);

export const kpiRealisasi = (d: Dataset) => kpiPeriode(d, d.meta.periode_realisasi)!;
export const kpiBerjalan = (d: Dataset) => kpiPeriode(d, d.meta.periode_berjalan)!;

export const saldoPeriode = (d: Dataset, kode = d.meta.periode_realisasi) =>
  d.saldo.filter((s) => s.periode_kode === kode).sort((a, b) => a.rank_sisa - b.rank_sisa);

export const bebanPeriode = (d: Dataset, kode = d.meta.periode_berjalan) =>
  d.beban.filter((b) => b.periode_kode === kode).sort((a, b) => a.rank_beban - b.rank_beban);

export const rstPeriode = (d: Dataset, kode = d.meta.periode_realisasi) =>
  d.rst
    .filter((r) => r.periode_kode === kode)
    .sort((a, b) => (a.rst ?? Infinity) - (b.rst ?? Infinity));

export const skorPeriode = (d: Dataset, kode = d.meta.periode_realisasi) =>
  d.skor
    .filter((s) => s.periode_kode === kode)
    .sort((a, b) => (b.skor_total ?? -1) - (a.skor_total ?? -1));

export const targetPeriode = (d: Dataset, kode = d.meta.periode_berjalan) =>
  d.target.filter((t) => t.periode_kode === kode).sort((a, b) => b.target_sisa - a.target_sisa);

export const segmenPeriode = (d: Dataset, kode = d.meta.periode_berjalan) =>
  d.segmen.filter((s) => s.periode_kode === kode).sort((a, b) => b.nilai - a.nilai);

export const petugasAktif = (d: Dataset) => d.petugas.filter((p) => p.status === "AKTIF");
