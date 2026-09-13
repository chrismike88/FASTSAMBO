import Link from "next/link";
import { Kartu, Petak, JudulHalaman, Catatan, LencanaRst } from "@/components/ui";
import { Tabel, TabelPendamping, type Kolom } from "@/components/Tabel";
import BatangPeringkat from "@/components/charts/BatangPeringkat";
import {
  getDataset, kpiRealisasi, kpiBerjalan, skorPeriode, bebanPeriode, rstPeriode,
} from "@/lib/data";
import { angka, juta, persen, rupiah, rupiahPenuh, KATEGORI_RST } from "@/lib/format";
import type { Skor, Beban, KomponenSkor } from "@/lib/types";

export const revalidate = 300;
export const metadata = { title: "Kinerja Petugas" };

export default async function HalamanPetugas() {
  const d = await getDataset();
  const agt = kpiRealisasi(d);
  const sep = kpiBerjalan(d);
  const skor = skorPeriode(d);
  const beban = bebanPeriode(d);
  const rst = rstPeriode(d);
  const tertib = d.penertiban.filter((p) => p.periode_kode === d.meta.periode_realisasi);

  const terbaik = skor.filter((s) => s.skor_total !== null);
  const nolPenertiban = tertib.filter((t) => t.jumlah_pelanggan === 0);
  const bobotTersedia = terbaik[0]?.bobot_terpakai ?? 0;
  const bobotPenuh = d.komponen_skor.reduce((a, k) => a + k.bobot, 0);

  const kolomSkor: Kolom<Skor>[] = [
    {
      kunci: "petugas", judul: "Petugas",
      render: (r) => (
        <Link href={`/petugas/${r.petugas_kode}`} className="font-semibold underline-offset-2 hover:underline">
          {r.petugas_nama}
        </Link>
      ),
    },
    { kunci: "sisa", judul: "Sisa", num: true, render: (r) => rupiahPenuh(r.sisa_nilai) },
    { kunci: "beban", judul: "Beban", num: true, render: (r) => rupiah(r.beban_nilai) },
    { kunci: "rst", judul: "RST", num: true, render: (r) => persen(r.rst) },
    { kunci: "rollover", judul: "Rollover", num: true, render: (r) => persen(r.rollover) },
    { kunci: "skor_rst", judul: "Skor RST", num: true, render: (r) => angka(r.skor_rst, 1) },
    { kunci: "skor_ro", judul: "Skor rollover", num: true, render: (r) => angka(r.skor_rollover, 1) },
    {
      kunci: "total", judul: "Skor akhir", num: true,
      render: (r) => <span className="font-bold">{r.skor_total === null ? "–" : angka(r.skor_total, 1)}</span>,
    },
    { kunci: "kat", judul: "Kategori", render: (r) => <LencanaRst kategori={r.kategori} /> },
  ];

  const kolomBeban: Kolom<Beban>[] = [
    { kunci: "rank", judul: "#", num: true, lebar: "40px", render: (r) => r.rank_beban },
    { kunci: "petugas", judul: "Petugas", render: (r) => r.petugas_nama },
    { kunci: "lembar", judul: "Lembar", num: true, render: (r) => angka(r.total_lembar) },
    {
      kunci: "nilai", judul: "Beban tagihan", num: true,
      render: (r) => <span className="font-semibold">{rupiahPenuh(r.nilai_total)}</span>,
    },
    { kunci: "persen", judul: "% unit", num: true, render: (r) => persen(r.persen_beban_unit, 1) },
    { kunci: "rata", judul: "Rata-rata/lembar", num: true, render: (r) => rupiahPenuh(r.rata_rata_per_lembar) },
  ];

  const kolomKomponen: Kolom<KomponenSkor>[] = [
    { kunci: "nama", judul: "Komponen", render: (k) => <span className="font-semibold">{k.nama}</span> },
    { kunci: "bobot", judul: "Bobot", num: true, render: (k) => `${angka(k.bobot)}%` },
    { kunci: "def", judul: "Definisi", render: (k) => k.definisi },
    {
      kunci: "target", judul: "Target", num: true,
      render: (k) => `${k.arah === "MINIMUM" ? "≤" : "≥"} ${angka(k.target, k.target % 1 ? 2 : 0)}%`,
    },
    {
      kunci: "siap", judul: "Data tersedia",
      render: (k) => {
        const adaData = ["RST", "ROLLOVER"].includes(k.kode);
        return (
          <span className={`lencana ${adaData
            ? "border-emerald-200 bg-emerald-50 text-emerald-700"
            : "border-slate-200 bg-slate-100 text-slate-700"}`}>
            {adaData ? "✓ dihitung" : "menunggu input"}
          </span>
        );
      },
    },
  ];

  return (
    <>
      <JudulHalaman
        judul="Kinerja Petugas Bilman"
        keterangan={`Klasemen berdasarkan RST dan skor lima komponen, bukan nilai rupiah absolut — karena beban wilayah tiap petugas tidak sama. Periode penilaian: ${agt.periode_nama}.`}
      />

      <Catatan nada="perhatian">
        <strong>Grafik beban bukan grafik prestasi.</strong> Beban tagihan {sep.periode_nama}{" "}
        berkisar {rupiah(Math.min(...beban.map((b) => b.nilai_total)))} sampai{" "}
        {rupiah(Math.max(...beban.map((b) => b.nilai_total)))} — selisihnya{" "}
        {angka(Math.max(...beban.map((b) => b.nilai_total)) / Math.min(...beban.map((b) => b.nilai_total)), 1)}{" "}
        kali. Memberi label “Kinerja Terbaik” atau “Perlu Evaluasi” pada grafik beban akan membuat
        petugas dengan wilayah terluas terbaca paling buruk, padahal justru sebaliknya.
      </Catatan>

      <div className="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Petak label="Skor tertinggi" nilai={terbaik[0]?.petugas_nama ?? "–"} nada="baik"
               catatan={`Skor ${angka(terbaik[0]?.skor_total, 1)} — RST ${persen(terbaik[0]?.rst)}`} />
        <Petak label="Perlu atensi" nilai={terbaik[terbaik.length - 1]?.petugas_nama ?? "–"} nada="buruk"
               catatan={`Skor ${angka(terbaik[terbaik.length - 1]?.skor_total, 1)} — RST ${persen(
                 terbaik[terbaik.length - 1]?.rst)}`} />
        <Petak label="Nol rollover" nilai={angka(terbaik.filter((s) => s.rollover === 0).length)} satuan="petugas"
               nada="baik"
               catatan={terbaik.filter((s) => s.rollover === 0).map((s) => s.petugas_nama).join(", ") || "–"} />
        <Petak label="Nol eksekusi pemutusan" nilai={angka(nolPenertiban.length)} satuan="petugas"
               nada="peringatan"
               catatan={nolPenertiban.map((t) => t.petugas_nama).join(", ")} />
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Kartu
          judul={`Skor kinerja ${agt.periode_nama}`}
          keterangan={`Bobot ${angka(bobotTersedia)} dari ${angka(bobotPenuh)} sudah dapat dihitung; tiga komponen sisanya menunggu data pengantaran dan pembayaran. Skor dinormalisasi atas komponen yang datanya ada, sehingga tidak ada petugas yang tampak nol hanya karena bulan berjalan belum sampai tanggal pengantaran.`}
        >
          <BatangPeringkat
            data={terbaik.map((s) => ({
              label: s.petugas_nama,
              nilai: s.skor_total as number,
              kelompok: s.kategori,
              keterangan: `RST ${persen(s.rst)} · rollover ${persen(s.rollover)}`,
            }))}
            format="angka1"
            warnaKelompok={Object.fromEntries(
              ["SANGAT_BAIK", "CUKUP", "PERLU_EVALUASI", "PERLU_ATENSI"].map((k) => [k, KATEGORI_RST[k].hex]),
            )}
            labelKelompok={Object.fromEntries(Object.entries(KATEGORI_RST).map(([k, v]) => [k, v.label]))}
            lebarLabel={82}
          />
          <TabelPendamping ringkasan="Lihat rincian tiap komponen">
            <Tabel
              kolom={kolomSkor}
              data={skor}
              kunciBaris={(r) => r.petugas_kode}
            />
          </TabelPendamping>
        </Kartu>

        <Kartu
          judul={`Beban kerja ${sep.periode_nama}`}
          keterangan="Luas wilayah kerja tiap petugas — dipakai sebagai penyebut RST, bukan sebagai ukuran prestasi."
        >
          <BatangPeringkat
            data={beban.map((b) => ({
              label: b.petugas_nama,
              nilai: b.nilai_total,
              keterangan: `${angka(b.total_lembar)} lembar · rata-rata ${rupiah(b.rata_rata_per_lembar)}`,
            }))}
            format="juta1"
            lebarLabel={82}
          />
          <TabelPendamping>
            <Tabel kolom={kolomBeban} data={beban} kunciBaris={(r) => r.petugas_kode} />
          </TabelPendamping>
        </Kartu>
      </div>

      <div className="mt-4">
        <Kartu
          judul="Susunan penilaian kinerja"
          keterangan="Menggantikan klasemen rupiah. Petugas dengan skor terendah tiga bulan berturut-turut baru diusulkan evaluasi — bukan berdasarkan nilai rupiah absolut, karena beban wilayah tidak sama."
        >
          <Tabel kolom={kolomKomponen} data={d.komponen_skor} kunciBaris={(k) => k.kode} />
          <p className="mt-3 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
            Skor ditampilkan di papan klasemen ruang briefing, diperbarui harian, dan menjadi dasar
            evaluasi bulanan bersama Nusa Daya. Tiga komponen yang masih menunggu input akan
            otomatis ikut terhitung begitu pengantaran TUL 6.01 dan pembayaran mulai direkam —
            bobotnya menyesuaikan sendiri tanpa perlu mengubah rumus.
          </p>
        </Kartu>
      </div>

      <div className="mt-4">
        <Kartu
          judul={`Tindakan penertiban ${agt.periode_nama}`}
          keterangan="Keberhasilan diukur dari pelanggan yang melunasi setelah surat peringatan, bukan dari jumlah pembongkaran. Pembongkaran yang tidak diikuti pelunasan hanya berpindah menjadi PRR."
        >
          <Tabel
            kolom={[
              { kunci: "petugas", judul: "Petugas", render: (t) => t.petugas_nama },
              { kunci: "jml", judul: "Pelanggan diputus/bongkar", num: true, render: (t) => angka(t.jumlah_pelanggan) },
              { kunci: "nilai", judul: "Nilai", num: true, render: (t) => rupiahPenuh(t.nilai) },
              { kunci: "rata", judul: "Rata-rata", num: true, render: (t) => rupiahPenuh(t.rata_rata) },
              {
                kunci: "rst", judul: "RST petugas", num: true,
                render: (t) => persen(rst.find((r) => r.petugas_kode === t.petugas_kode)?.rst),
              },
              {
                kunci: "wajib", judul: "Kewajiban bulan ini",
                render: (t) => {
                  const r = rst.find((x) => x.petugas_kode === t.petugas_kode)?.rst ?? 0;
                  return r > 2 ? (
                    <span className="lencana border-amber-200 bg-amber-50 text-amber-700">
                      wajib ≥1 eksekusi
                    </span>
                  ) : (
                    <span style={{ color: "var(--ink-muted)" }}>–</span>
                  );
                },
              },
            ]}
            data={[...tertib].sort((a, b) => b.jumlah_pelanggan - a.jumlah_pelanggan)}
            kunciBaris={(t) => t.petugas_kode}
            kaki={
              <tfoot>
                <tr>
                  <td className="font-semibold">TOTAL</td>
                  <td className="num font-semibold">{angka(tertib.reduce((a, t) => a + t.jumlah_pelanggan, 0))}</td>
                  <td className="num font-semibold">{rupiahPenuh(tertib.reduce((a, t) => a + t.nilai, 0))}</td>
                  <td className="num font-semibold">
                    {rupiahPenuh(
                      tertib.reduce((a, t) => a + t.nilai, 0) /
                        Math.max(1, tertib.reduce((a, t) => a + t.jumlah_pelanggan, 0)),
                    )}
                  </td>
                  <td colSpan={2} />
                </tr>
              </tfoot>
            }
          />
          <p className="mt-3 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
            Rata-rata nilai per pelanggan yang diputus menunjukkan mayoritas target penertiban
            adalah rumah tangga kecil. Di segmen ini biaya-manfaat pemutusan tipis — pendekatan
            persuasif tetap lebih efisien, dan opsi cicilan sebaiknya ditawarkan lebih dulu.
          </p>
        </Kartu>
      </div>
    </>
  );
}
