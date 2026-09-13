import Link from "next/link";
import { Kartu, Petak, JudulHalaman, Catatan, LencanaAntar, LencanaPrioritas } from "@/components/ui";
import { Meter } from "@/components/Meter";
import { Tabel, TabelPendamping, type Kolom } from "@/components/Tabel";
import BatangPeringkat from "@/components/charts/BatangPeringkat";
import { getDataset, kpiBerjalan } from "@/lib/data";
import { angka, juta, persen, rupiah, rupiahPenuh, rentangTanggal, gelombang } from "@/lib/format";
import type { Pengantaran, ProgresAntar, Kalender } from "@/lib/types";

export const revalidate = 300;
export const metadata = { title: "Pengantaran TUL 6.01" };

export default async function HalamanPengantaran() {
  const d = await getDataset();
  const sep = kpiBerjalan(d);
  const antar = d.pengantaran.filter((a) => a.periode_kode === d.meta.periode_berjalan);
  const progres = [...d.progres_antar]
    .filter((p) => p.periode_kode === d.meta.periode_berjalan)
    .sort((a, b) => b.total_lembar - a.total_lembar);
  const kalender = d.kalender
    .filter((k) => k.periode_kode === d.meta.periode_berjalan)
    .sort((a, b) => a.urutan - b.urutan);

  const total = antar.length;
  const terantar = antar.filter((a) => a.status_antar === "TERANTAR").length;
  const tigaLembar = antar.filter((a) => a.jml_lembar >= 3);
  const nilaiTotal = antar.reduce((a, x) => a + x.nilai_tagihan, 0);
  const jatuhTempo = d.meta.parameter.tanggal_jatuh_tempo;
  const batasAntar = d.meta.parameter.tanggal_batas_antar;
  const jarakMaks = d.meta.parameter.jarak_validasi_maks;

  const kolomProgres: Kolom<ProgresAntar>[] = [
    {
      kunci: "petugas", judul: "Petugas",
      render: (p) => (
        <Link href={`/petugas/${p.petugas_kode}`} className="font-semibold underline-offset-2 hover:underline">
          {p.petugas_nama}
        </Link>
      ),
    },
    { kunci: "total", judul: "Daftar prioritas", num: true, render: (p) => angka(p.total_lembar) },
    { kunci: "terantar", judul: "Terantar", num: true, render: (p) => angka(p.terantar) },
    {
      kunci: "belum", judul: "Belum", num: true,
      render: (p) => <span className={p.belum > 0 ? "font-semibold text-amber-700" : ""}>{angka(p.belum)}</span>,
    },
    { kunci: "persen", judul: "% antar", num: true, render: (p) => persen(p.persen_antar, 1) },
    { kunci: "nilai", judul: "Nilai ditangani", num: true, render: (p) => rupiahPenuh(p.nilai_total) },
    {
      kunci: "suspect", judul: "Suspect", num: true,
      render: (p) => (p.suspect > 0
        ? <span className="font-semibold text-red-600">{angka(p.suspect)}</span>
        : <span style={{ color: "var(--ink-muted)" }}>0</span>),
    },
    {
      kunci: "ketepatan", judul: `Ketepatan (≤ tgl ${angka(batasAntar)})`, num: true,
      render: (p) => p.persen_ketepatan === null
        ? <span style={{ color: "var(--ink-muted)" }}>belum mulai</span>
        : persen(p.persen_ketepatan, 1),
    },
  ];

  const kolomAntar: Kolom<Pengantaran>[] = [
    { kunci: "idpel", judul: "IDPEL", render: (a) => <span className="whitespace-nowrap tabular-nums">{a.idpel}</span> },
    { kunci: "petugas", judul: "Petugas", render: (a) => a.petugas_nama },
    {
      kunci: "lembar", judul: "Lembar", num: true,
      render: (a) => (
        <span className={a.jml_lembar >= 3 ? "font-bold text-red-600" : "font-semibold"}>{a.jml_lembar}</span>
      ),
    },
    { kunci: "nilai", judul: "Nilai tagihan", num: true, render: (a) => rupiahPenuh(a.nilai_tagihan) },
    { kunci: "prioritas", judul: "Prioritas", render: (a) => <LencanaPrioritas prioritas={a.prioritas} /> },
    { kunci: "gelombang", judul: "Gelombang", render: (a) => gelombang(a.gelombang) },
    { kunci: "status", judul: "Status", render: (a) => <LencanaAntar status={a.status_antar} /> },
  ];

  const kolomKalender: Kolom<Kalender>[] = [
    { kunci: "tgl", judul: "Tanggal", lebar: "110px",
      render: (k) => <span className="font-semibold tabular-nums">{rentangTanggal(k.tanggal_mulai, k.tanggal_selesai)}</span> },
    { kunci: "kegiatan", judul: "Kegiatan", render: (k) => k.kegiatan },
    { kunci: "pj", judul: "Penanggung jawab", render: (k) => k.penanggung_jawab },
  ];

  return (
    <>
      <JudulHalaman
        judul="Monitoring Pengantaran TUL 6.01"
        keterangan={`Urutan pengantaran disusun berdasarkan risiko, bukan rute geografis. Jatuh tempo tanggal ${angka(jatuhTempo)}; pelanggan yang diantar terakhir hanya punya 2 sampai 3 hari untuk membayar.`}
      />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Petak label="Daftar prioritas gelombang I" nilai={angka(total)} satuan="lbr" nada="sorot"
               catatan={`Seluruh pelanggan 2 dan 3 lembar · ${rupiahPenuh(nilaiTotal)}`} />
        <Petak label="Sudah terantar" nilai={persen(total ? (terantar / total) * 100 : 0, 1)}
               nada={terantar > 0 ? "baik" : "netral"}
               catatan={`${angka(terantar)} dari ${angka(total)} lembar, dengan bukti foto FTO`} />
        <Petak label="Pelanggan 3 lembar" nilai={angka(tigaLembar.length)} satuan="plg" nada="buruk"
               catatan={`Surat peringatan paling lambat tanggal 16 · ${rupiahPenuh(
                 tigaLembar.reduce((a, x) => a + x.nilai_tagihan, 0))}`} />
        <Petak label="Beban per petugas" nilai={angka(total / Math.max(1, progres.length), 0)} satuan="plg"
               catatan={`Dibagi ${progres.length} petugas — selesai dalam 2 hari kerja`} />
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-3">
        <Kartu judul="Progres pengantaran unit" className="lg:col-span-1"
               keterangan={`Target ketepatan: ${persen(d.meta.parameter.target_ketepatan_tul, 0)} terantar dengan bukti FTO valid paling lambat tanggal ${angka(batasAntar)}.`}>
          <Meter
            nilai={total ? (terantar / total) * 100 : 0}
            target={d.meta.parameter.target_ketepatan_tul}
            maks={100}
            labelNilai={`${persen(total ? (terantar / total) * 100 : 0, 1)} terantar`}
            labelTarget={persen(d.meta.parameter.target_ketepatan_tul, 0)}
          />
          <dl className="mt-4 space-y-2 text-sm">
            {[
              ["Daftar prioritas", `${angka(total)} lembar`],
              ["Terantar dengan bukti", `${angka(terantar)} lembar`],
              ["Belum diantar", `${angka(total - terantar)} lembar`],
              ["Nilai yang dikejar", rupiahPenuh(nilaiTotal)],
            ].map(([k, v]) => (
              <div key={k} className="flex items-baseline justify-between gap-3 border-b pb-1.5"
                   style={{ borderColor: "var(--line)" }}>
                <dt style={{ color: "var(--ink-2)" }}>{k}</dt>
                <dd className="font-semibold tabular-nums">{v}</dd>
              </div>
            ))}
          </dl>
          <Catatan>
            Sebuah lembar hanya dihitung terantar bila disertai <strong>foto FTO</strong>. Aturan
            ini ditegakkan di basis data, bukan sekadar diingatkan di aplikasi — baris tanpa
            lampiran ditolak. Bila jarak titik foto ke titik pelanggan termapping melebihi{" "}
            {angka(jarakMaks)} m, baris ditandai <em>suspect</em> dan masuk daftar verifikasi
            supervisor.
          </Catatan>
        </Kartu>

        <Kartu judul="Progres per petugas" className="lg:col-span-2"
               keterangan="Jumlah pelanggan berisiko yang menjadi tanggung jawab tiap petugas pada gelombang pertama.">
          <BatangPeringkat
            data={progres.map((p) => ({
              label: p.petugas_nama,
              nilai: p.total_lembar,
              kelompok: p.belum === p.total_lembar ? "belum" : p.belum > 0 ? "sebagian" : "tuntas",
              keterangan: `${angka(p.terantar)} terantar, ${angka(p.belum)} belum · ${rupiahPenuh(p.nilai_total)}`,
            }))}
            format="angka"
            warnaKelompok={{ belum: "#fab219", sebagian: "#2a78d6", tuntas: "#0ca30c" }}
            labelKelompok={{ belum: "belum mulai", sebagian: "sebagian terantar", tuntas: "tuntas" }}
            lebarLabel={82}
          />
          <TabelPendamping ringkasan="Lihat angka progres lengkap">
            <Tabel kolom={kolomProgres} data={progres} kunciBaris={(p) => p.petugas_kode} />
          </TabelPendamping>
        </Kartu>
      </div>

      <div className="mt-4">
        <Kartu
          judul={`Urutan pengantaran ${sep.periode_nama}`}
          keterangan="Mendahulukan risiko, bukan rute. Pelanggan 1 lembar mayoritas memang bayar tepat waktu; yang butuh waktu tenggang justru yang sudah menunggak."
        >
          <ol className="space-y-3">
            {[
              {
                judul: `Hari 14–15 · ${angka(total)} pelanggan berisiko`,
                isi: `Seluruh pelanggan 2 dan 3 lembar, dibagi ${progres.length} petugas — sekitar ${angka(
                  total / Math.max(1, progres.length), 0)} pelanggan per orang, selesai dalam dua hari. Mencegah ${rupiah(
                  sep.macet_nilai_2)} naik ke lembar ketiga.`,
                warna: "var(--st-critical)",
              },
              {
                judul: "Hari 16–18 · pelanggan 1 lembar nilai besar dan daya besar",
                isi: "Nilai tagihan besar ditangani lebih dulu agar punya waktu tenggang cukup sebelum jatuh tempo.",
                warna: "var(--st-warning)",
              },
              {
                judul: `Hari 19–20 · sisa pelanggan`,
                isi: `${angka(sep.lembar_bilman - total)} lembar sisanya, mayoritas pelanggan 1 lembar yang selama ini bayar tepat waktu.`,
                warna: "var(--viz-1)",
              },
            ].map((g, i) => (
              <li key={i} className="flex gap-3 rounded-lg border p-3" style={{ borderColor: "var(--line)" }}>
                <span className="mt-1 h-full w-1 shrink-0 rounded-full" style={{ background: g.warna }} aria-hidden />
                <div className="min-w-0">
                  <p className="text-sm font-semibold" style={{ color: "var(--ink)" }}>{g.judul}</p>
                  <p className="mt-0.5 text-xs leading-relaxed" style={{ color: "var(--ink-2)" }}>{g.isi}</p>
                </div>
              </li>
            ))}
          </ol>
        </Kartu>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Kartu judul={`Kalender operasional ${sep.periode_nama}`}
               keterangan="Rangkaian kegiatan penagihan bulan berjalan beserta penanggung jawabnya.">
          <Tabel kolom={kolomKalender} data={kalender} kunciBaris={(k) => String(k.urutan)} />
        </Kartu>

        <Kartu
          judul="Daftar lembar prioritas"
          keterangan={`${angka(total)} lembar yang harus diantar lebih dulu. IDPEL berawalan SLOT- adalah kerangka yang menunggu penarikan nomor pelanggan riil dari AP2T.`}
        >
          <Tabel kolom={kolomAntar} data={antar} kunciBaris={(a) => a.idpel} tinggiMaks="460px" />
          <p className="mt-3 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
            Jumlah baris per petugas sudah sesuai jumlah pelanggan 2 dan 3 lembar yang sebenarnya
            pada data {sep.tanggal_data}. Nilai yang tertera adalah rata-rata per lembar petugas
            bersangkutan; nilai per pelanggan akan menyusul bersama IDPEL riil.
          </p>
        </Kartu>
      </div>

      <div className="mt-4">
        <Kartu judul="Field Maps — apa yang wajib dicatat di lapangan"
               keterangan="Struktur ini sudah tersedia di basis data sebagai tabel pengantaran_tul601, siap dihubungkan dengan layer ArcGIS.">
          <div className="gulir-x">
            <table className="tabel">
              <thead>
                <tr>
                  <th>Isian</th><th>Bentuk</th><th>Aturan</th>
                </tr>
              </thead>
              <tbody>
                {[
                  ["Status terima", "Pilihan", "Diterima Langsung / Dititip / Rumah Kosong / Menolak / Tidak Aman"],
                  ["Foto FTO", "Lampiran", "Wajib. Tanpa lampiran, lembar tidak dihitung terantar"],
                  ["Koordinat foto", "Otomatis", `Jarak > ${angka(jarakMaks)} m dari titik pelanggan ditandai suspect`],
                  ["Tanggal & jam antar", "Otomatis", `Dihitung tepat waktu bila ≤ tanggal ${angka(batasAntar)}`],
                  ["Rumah kosong berulang", "Turunan", "Dua kali berturut-turut otomatis masuk daftar eskalasi"],
                  ["Tidak aman", "Turunan", "Kunjungan berikutnya dijadwalkan berdua, tidak sendirian"],
                ].map(([a, b, c]) => (
                  <tr key={a}>
                    <td className="font-semibold">{a}</td>
                    <td>{b}</td>
                    <td>{c}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Kartu>
      </div>
    </>
  );
}
