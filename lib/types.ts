/** Bentuk data yang dipakai seluruh dashboard.
 *  Sumbernya bisa Supabase (produksi) atau berkas contoh bawaan (fallback);
 *  keduanya dijamin identik oleh scripts/uji_konsistensi.py. */

export type KategoriRst = "SANGAT_BAIK" | "CUKUP" | "PERLU_EVALUASI" | "PERLU_ATENSI" | "N/A";
export type StatusPetugas = "AKTIF" | "TIDAK_AKTIF" | "PERLU_KONFIRMASI";
export type StatusPeriode = "REALISASI" | "BERJALAN" | "RENCANA";
export type StatusAntar = "BELUM_DIANTAR" | "TERANTAR" | "GAGAL" | "DIBATALKAN";
export type StatusAksi = "RENCANA" | "BERJALAN" | "TERLAMBAT" | "SELESAI" | "BATAL";
export type Prioritas = "SANGAT TINGGI" | "TINGGI" | "SEDANG" | "RUTIN";
export type Segmen = "BILMAN" | "AMR" | "NA";
/** AKTUAL = beban bulan itu sendiri. PROKSI = beban bulan berikutnya dipakai
 *  sebagai pendekatan luas wilayah kerja karena beban bulan itu belum didata. */
export type BasisBeban = "AKTUAL" | "PROKSI" | null;

export interface Unit {
  kode: string;
  nama: string;
  up3: string;
  uid: string;
  jumlah_petugas_bilman: number;
  jumlah_pelanggan_bilman: number;
  jumlah_rekening_amr: number;
}

export interface Periode {
  kode: string;
  nama: string;
  status: StatusPeriode;
  tanggal_data: string | null;
  tahun: number;
  bulan: number;
  keterangan: string | null;
}

export interface Petugas {
  kode: string;
  nama: string;
  status: StatusPetugas;
  aktif_dari: string | null;
  aktif_sampai: string | null;
  catatan: string | null;
}

export interface Kpi {
  periode_kode: string;
  periode_nama: string;
  tahun: number;
  bulan: number;
  status: StatusPeriode;
  tanggal_data: string | null;
  target_saldo_akhir: number;
  sisa_nilai: number | null;
  sisa_lembar: number | null;
  sisa_lembar_2: number | null;
  sisa_nilai_2: number | null;
  jumlah_petugas: number;
  beban_bilman: number;
  lembar_bilman: number;
  basis_beban: BasisBeban;
  macet_2: number | null;
  macet_nilai_2: number | null;
  macet_3: number | null;
  macet_nilai_3: number | null;
  macet_lembar: number;
  macet_nilai: number;
  seg_bilman: number;
  seg_amr: number;
  seg_na: number;
  seg_total: number;
  rek_amr: number;
  lembar_na: number;
  persen_seg_bilman: number | null;
  persen_seg_amr: number | null;
  persen_seg_na: number | null;
  rata_rata_amr: number | null;
  rst_unit: number | null;
  rst_target: number;
  efektivitas_penagihan: number | null;
  efektivitas_dibutuhkan: number;
  konsentrasi_2_teratas: number | null;
  konsentrasi_4_teratas: number | null;
  gap_penurunan: number;
  persen_penurunan: number | null;
}

export interface Saldo {
  periode_kode: string;
  petugas_kode: string;
  petugas_nama: string;
  lembar_1: number;
  nilai_1: number;
  lembar_2: number;
  nilai_2: number;
  total_lembar: number;
  total_nilai: number;
  nilai_unit: number;
  rata_rata_per_lembar: number | null;
  persen_unit: number | null;
  /** Bagian sisa yang tertahan pada pelanggan 2 lembar — komposisi sisa. */
  rollover_persen_lembar: number | null;
  rollover_persen_nilai: number | null;
  rank_sisa: number;
  persen_kumulatif: number | null;
}

export interface Beban {
  periode_kode: string;
  petugas_kode: string;
  petugas_nama: string;
  total_lembar: number;
  nilai_total: number;
  lembar_1: number;
  nilai_1: number;
  lembar_2: number;
  nilai_2: number;
  lembar_3: number;
  nilai_3: number;
  lembar_macet: number;
  nilai_macet: number;
  rata_rata_per_lembar: number | null;
  persen_beban_unit: number | null;
  rank_beban: number;
  rank_risiko_nilai: number;
  rank_risiko_lembar: number;
}

export interface Rst {
  periode_kode: string;
  petugas_kode: string;
  petugas_nama: string;
  sisa_nilai: number;
  sisa_lembar: number;
  beban_nilai: number | null;
  beban_lembar: number | null;
  beban_periode_kode: string | null;
  basis_beban: BasisBeban;
  rst: number | null;
  kategori: KategoriRst;
  rank_rst?: number | null;
}

export interface Skor {
  periode_kode: string;
  petugas_kode: string;
  petugas_nama: string;
  rst: number | null;
  kategori: KategoriRst;
  basis_beban: BasisBeban;
  sisa_nilai: number;
  beban_nilai: number | null;
  /** Pelanggan naik dari 1 ke 2 lembar dibagi SELURUH pelanggan yang ditangani. */
  rollover: number | null;
  ketepatan_tul: number | null;
  cash_in_dini: number | null;
  efektivitas_penertiban: number | null;
  skor_rst: number | null;
  skor_rollover: number | null;
  skor_tul: number | null;
  skor_cash_in: number | null;
  skor_penertiban: number | null;
  skor_total: number | null;
  /** Bobot komponen yang datanya sudah tersedia; skor dinormalisasi atasnya. */
  bobot_terpakai: number;
  rank_skor?: number | null;
}

export interface Target {
  periode_kode: string;
  petugas_kode: string;
  petugas_nama: string;
  target_sisa: number;
  rst_target: number | null;
  sisa_awal: number | null;
  beban: number | null;
  harus_turun: number;
  jenis_target: "TURUNKAN" | "PERTAHANKAN" | "BARU";
  catatan: string | null;
}

export interface Penertiban {
  periode_kode: string;
  petugas_kode: string;
  petugas_nama: string;
  jumlah_pelanggan: number;
  nilai: number;
  rata_rata: number | null;
  jumlah_surat_peringatan: number;
  jumlah_lunas_setelah_peringatan: number;
}

export interface SegmenBeban {
  periode_kode: string;
  segmen: Segmen;
  nama_segmen: string;
  jumlah_lembar: number;
  nilai: number;
  lembar_1: number;
  lembar_2: number;
  nilai_2: number;
  keterangan: string | null;
  persen_unit: number | null;
  rata_rata: number | null;
}

export interface Efektivitas {
  periode_kode: string;
  segmen: string;
  posisi_awal: number;
  masih_menunggak: number;
  tertagih: number;
  persen_tertagih: number | null;
  keterangan: string | null;
}

export interface Pengantaran {
  periode_kode: string;
  idpel: string;
  petugas_kode: string;
  petugas_nama: string;
  jml_lembar: number;
  nilai_tagihan: number;
  prioritas: Prioritas;
  gelombang: string | null;
  status_antar: StatusAntar;
  status_terima: string | null;
  tgl_antar: string | null;
  catatan: string | null;
}

export interface ProgresAntar {
  periode_kode: string;
  petugas_kode: string;
  petugas_nama: string;
  total_lembar: number;
  terantar: number;
  belum: number;
  suspect: number;
  nilai_total: number;
  nilai_terantar: number;
  persen_antar: number;
  persen_ketepatan: number | null;
}

export interface Aksi {
  kode: string;
  periode_kode: string;
  judul: string;
  dampak_nilai: number;
  dampak_label: string | null;
  prioritas: Prioritas;
  penanggung_jawab: string | null;
  tenggat: string | null;
  status: StatusAksi;
  ringkasan: string | null;
  langkah: string[];
}

export interface Kalender {
  periode_kode: string;
  urutan: number;
  tanggal_mulai: string;
  tanggal_selesai: string;
  kegiatan: string;
  penanggung_jawab: string | null;
  status: StatusAksi;
}

export interface Hambatan {
  kode: string;
  hambatan: string;
  mitigasi: string;
  penanggung_jawab: string | null;
}

export interface KomponenSkor {
  kode: string;
  nama: string;
  bobot: number;
  definisi: string | null;
  target: number;
  arah: "MINIMUM" | "MAKSIMUM";
}

export interface CatatanPerbaikan {
  nomor: number;
  temuan: string;
  dampak: string | null;
  perbaikan: string | null;
  status: string;
}

export interface Meta {
  unit: Unit;
  parameter: Record<string, number>;
  parameter_baris: { kunci: string; nilai: number; satuan: string | null; keterangan: string | null }[];
  periode: Periode[];
  periode_realisasi: string;
  periode_berjalan: string;
  bulan_nama: string[];
  dibangun_pada: string;
}

export interface Dataset {
  meta: Meta;
  petugas: Petugas[];
  kpi: Kpi[];
  saldo: Saldo[];
  beban: Beban[];
  rst: Rst[];
  skor: Skor[];
  target: Target[];
  penertiban: Penertiban[];
  segmen: SegmenBeban[];
  efektivitas: Efektivitas[];
  pengantaran: Pengantaran[];
  progres_antar: ProgresAntar[];
  aksi: Aksi[];
  kalender: Kalender[];
  hambatan: Hambatan[];
  komponen_skor: KomponenSkor[];
  catatan_perbaikan: CatatanPerbaikan[];
  pelanggan: { idpel: string; petugas_kode: string; sumber_data: string; termapping: boolean; catatan: string | null }[];
  /** Diisi lib/data.ts: dari mana angka pada halaman ini benar-benar dibaca. */
  sumber?: "supabase" | "contoh";
}
