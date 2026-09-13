/** Pemformatan angka gaya Indonesia (pemisah ribuan titik, desimal koma). */

const nf = (min: number, max: number) =>
  new Intl.NumberFormat("id-ID", { minimumFractionDigits: min, maximumFractionDigits: max });

export const angka = (v: number | null | undefined, desimal = 0) =>
  v === null || v === undefined || Number.isNaN(v) ? "–" : nf(desimal, desimal).format(v);

export const persen = (v: number | null | undefined, desimal = 2) =>
  v === null || v === undefined || Number.isNaN(v) ? "–" : `${nf(desimal, desimal).format(v)}%`;

export const pp = (v: number | null | undefined, desimal = 2) => {
  if (v === null || v === undefined || Number.isNaN(v)) return "–";
  const t = nf(desimal, desimal).format(Math.abs(v));
  return `${v > 0 ? "+" : v < 0 ? "−" : ""}${t} pp`;
};

/** Rupiah ringkas: 2.434.686.417 -> "Rp 2,43 M" */
export function rupiah(v: number | null | undefined): string {
  if (v === null || v === undefined || Number.isNaN(v)) return "–";
  const abs = Math.abs(v);
  if (abs >= 1e12) return `Rp ${nf(2, 2).format(v / 1e12)} T`;
  if (abs >= 1e9) return `Rp ${nf(2, 2).format(v / 1e9)} M`;
  if (abs >= 1e6) return `Rp ${nf(1, 1).format(v / 1e6)} jt`;
  if (abs >= 1e3) return `Rp ${nf(0, 0).format(v / 1e3)} rb`;
  return `Rp ${nf(0, 0).format(v)}`;
}

export const rupiahPenuh = (v: number | null | undefined) =>
  v === null || v === undefined ? "–" : `Rp ${nf(0, 0).format(v)}`;

export const juta = (v: number | null | undefined, desimal = 1) =>
  v === null || v === undefined ? "–" : `${nf(desimal, desimal).format(v / 1e6)} jt`;

export const lembar = (v: number | null | undefined) =>
  v === null || v === undefined ? "–" : `${nf(0, 0).format(v)} lbr`;

/** "2026-09-14" -> "14 Sep" */
export function tanggalPendek(iso: string | null | undefined): string {
  if (!iso) return "–";
  const d = new Date(`${iso}T00:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return `${d.getDate()} ${["Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
    "Jul", "Ags", "Sep", "Okt", "Nov", "Des"][d.getMonth()]}`;
}

/** Rentang tanggal dalam satu bulan diringkas: "14–15 Sep" */
export function rentangTanggal(mulai: string, selesai: string): string {
  if (mulai === selesai) return tanggalPendek(mulai);
  const a = new Date(`${mulai}T00:00:00`);
  const b = new Date(`${selesai}T00:00:00`);
  if (a.getMonth() === b.getMonth()) return `${a.getDate()}–${tanggalPendek(selesai)}`;
  return `${tanggalPendek(mulai)} – ${tanggalPendek(selesai)}`;
}

/** Kategori RST. Warna selalu didampingi label teks, tidak pernah warna saja. */
export const KATEGORI_RST: Record<
  string,
  { label: string; teks: string; latar: string; garis: string; hex: string }
> = {
  SANGAT_BAIK: {
    label: "Sangat Baik", teks: "text-emerald-700", latar: "bg-emerald-50",
    garis: "border-emerald-200", hex: "#0ca30c",
  },
  CUKUP: {
    label: "Cukup", teks: "text-amber-700", latar: "bg-amber-50",
    garis: "border-amber-200", hex: "#fab219",
  },
  PERLU_EVALUASI: {
    label: "Perlu Evaluasi", teks: "text-orange-700", latar: "bg-orange-50",
    garis: "border-orange-200", hex: "#ec835a",
  },
  PERLU_ATENSI: {
    label: "Perlu Atensi", teks: "text-red-700", latar: "bg-red-50",
    garis: "border-red-200", hex: "#d03b3b",
  },
  "N/A": {
    label: "Data belum ada", teks: "text-slate-600", latar: "bg-slate-50",
    garis: "border-slate-200", hex: "#64748B",
  },
};

export const STATUS_ANTAR: Record<string, { label: string; teks: string; latar: string; garis: string }> = {
  BELUM_DIANTAR: { label: "Belum diantar", teks: "text-slate-700", latar: "bg-slate-100", garis: "border-slate-200" },
  TERANTAR: { label: "Terantar", teks: "text-emerald-700", latar: "bg-emerald-50", garis: "border-emerald-200" },
  GAGAL: { label: "Gagal", teks: "text-red-700", latar: "bg-red-50", garis: "border-red-200" },
  DIBATALKAN: { label: "Dibatalkan", teks: "text-slate-600", latar: "bg-slate-50", garis: "border-slate-200" },
};

/** Gelombang pengantaran — kode basis data diubah menjadi label manusiawi. */
export const GELOMBANG: Record<string, string> = {
  HARI_14_15: "Hari 14–15",
  HARI_16_18: "Hari 16–18",
  HARI_19_20: "Hari 19–20",
};

export const gelombang = (kode: string | null | undefined) =>
  kode ? GELOMBANG[kode] ?? kode.replace(/_/g, " ") : "–";

export const WARNA_PRIORITAS: Record<string, string> = {
  "SANGAT TINGGI": "bg-red-600 text-white",
  TINGGI: "bg-orange-500 text-white",
  SEDANG: "bg-amber-100 text-amber-900",
  RUTIN: "bg-slate-100 text-slate-700",
};

export const STATUS_AKSI: Record<string, { label: string; teks: string; latar: string; garis: string }> = {
  RENCANA: { label: "Rencana", teks: "text-slate-700", latar: "bg-slate-100", garis: "border-slate-200" },
  BERJALAN: { label: "Berjalan", teks: "text-sky-700", latar: "bg-sky-50", garis: "border-sky-200" },
  TERLAMBAT: { label: "Terlambat", teks: "text-amber-700", latar: "bg-amber-50", garis: "border-amber-200" },
  SELESAI: { label: "Selesai", teks: "text-emerald-700", latar: "bg-emerald-50", garis: "border-emerald-200" },
  BATAL: { label: "Batal", teks: "text-slate-600", latar: "bg-slate-50", garis: "border-slate-200" },
};

/** Nama format yang bisa dikirim dari Server Component ke Client Component
 *  (fungsi tidak boleh dilewatkan melintasi batas server/klien). */
export type FormatNama =
  | "angka" | "angka1" | "angka2"
  | "persen" | "persen1"
  | "rupiah" | "rupiahPenuh" | "juta" | "juta1" | "lembar";

export function pakaiFormat(nama: FormatNama): (v: number) => string {
  switch (nama) {
    case "angka1": return (v) => angka(v, 1);
    case "angka2": return (v) => angka(v, 2);
    case "persen": return (v) => persen(v);
    case "persen1": return (v) => persen(v, 1);
    case "rupiah": return (v) => rupiah(v);
    case "rupiahPenuh": return (v) => rupiahPenuh(v);
    case "juta": return (v) => juta(v, 0);
    case "juta1": return (v) => juta(v, 1);
    case "lembar": return (v) => lembar(v);
    default: return (v) => angka(v);
  }
}
