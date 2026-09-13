import Link from "next/link";
import { Kartu, Petak, JudulHalaman, Catatan, LencanaRst } from "@/components/ui";
import { Meter } from "@/components/Meter";
import { KomposisiJalur } from "@/components/KomposisiJalur";
import { Tabel, TabelPendamping, type Kolom } from "@/components/Tabel";
import BatangPeringkat from "@/components/charts/BatangPeringkat";
import {
  getDataset, kpiRealisasi, kpiBerjalan, saldoPeriode, rstPeriode, segmenPeriode,
} from "@/lib/data";
import { angka, juta, lembar, persen, rupiah, rupiahPenuh, tanggalPendek } from "@/lib/format";
import { KATEGORI_RST } from "@/lib/format";
import type { Saldo } from "@/lib/types";

export const revalidate = 300;

export default async function Ringkasan() {
  const d = await getDataset();
  const agt = kpiRealisasi(d);
  const sep = kpiBerjalan(d);
  const saldo = saldoPeriode(d);
  const rst = rstPeriode(d);
  const segmen = segmenPeriode(d);
  const efek = d.efektivitas.filter((e) => e.periode_kode === d.meta.periode_berjalan);

  const empatTeratas = saldo.slice(0, 4);
  const nilaiEmpat = empatTeratas.reduce((a, s) => a + s.total_nilai, 0);

  const warnaSegmen: Record<string, string> = {
    BILMAN: "var(--viz-1)",
    AMR: "var(--viz-2)",
    NA: "var(--viz-3)",
  };

  const kolomSaldo: Kolom<Saldo>[] = [
    { kunci: "rank", judul: "#", num: true, lebar: "40px", render: (r) => r.rank_sisa },
    {
      kunci: "petugas", judul: "Petugas",
      render: (r) => (
        <Link href={`/petugas/${r.petugas_kode}`} className="font-semibold underline-offset-2 hover:underline">
          {r.petugas_nama}
        </Link>
      ),
    },
    { kunci: "lembar", judul: "Lembar", num: true, render: (r) => angka(r.total_lembar) },
    {
      kunci: "nilai", judul: "Sisa tunggakan", num: true,
      render: (r) => <span className="font-semibold">{rupiahPenuh(r.total_nilai)}</span>,
    },
    { kunci: "persen", judul: "% unit", num: true, render: (r) => persen(r.persen_unit, 1) },
    { kunci: "kum", judul: "Kumulatif", num: true, render: (r) => persen(r.persen_kumulatif, 1) },
    {
      kunci: "rst", judul: "RST",
      render: (r) => {
        const x = rst.find((v) => v.petugas_kode === r.petugas_kode);
        return (
          <span className="flex items-center gap-2">
            <span className="tabular-nums">{persen(x?.rst)}</span>
            <LencanaRst kategori={x?.kategori ?? "N/A"} />
          </span>
        );
      },
    },
  ];

  return (
    <>
      <JudulHalaman
        judul="Ringkasan Eksekutif"
        keterangan={
          <>
            Sisa tunggakan {agt.periode_nama} dan posisi beban {sep.periode_nama} per{" "}
            {sep.tanggal_data ? tanggalPendek(sep.tanggal_data) : "–"}. Target akhir bulan:{" "}
            <strong>{rupiahPenuh(sep.target_saldo_akhir)}</strong>.
          </>
        }
      />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Petak
          label={`Sisa tunggakan ${agt.periode_nama}`}
          nilai={juta(agt.sisa_nilai)}
          satuan="rupiah"
          nada="buruk"
          catatan={`${lembar(agt.sisa_lembar)} pada ${agt.jumlah_petugas} petugas`}
        />
        <Petak
          label="RST unit"
          nilai={persen(agt.rst_unit)}
          nada={(agt.rst_unit ?? 0) <= agt.rst_target ? "baik" : "peringatan"}
          catatan={`Target ${persen(agt.rst_target)} — efektivitas penagihan harus naik dari ${persen(
            agt.efektivitas_penagihan,
          )} ke ${persen(agt.efektivitas_dibutuhkan)}`}
        />
        <Petak
          label="Harus turun bulan ini"
          nilai={juta(agt.gap_penurunan)}
          satuan="rupiah"
          nada="sorot"
          catatan={`Turun ${persen(agt.persen_penurunan, 1)} agar tembus di bawah ${rupiah(
            sep.target_saldo_akhir,
          )}`}
        />
        <Petak
          label="Konsentrasi masalah"
          nilai={persen(agt.konsentrasi_4_teratas, 1)}
          nada="peringatan"
          catatan={`Dipegang 4 petugas: ${empatTeratas.map((s) => s.petugas_nama).join(", ")}`}
        />
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-3">
        <Kartu
          judul="Jarak ke target akhir bulan"
          keterangan="Garis hitam adalah batas Rp40 juta. Batang merah adalah posisi saat ini."
          className="lg:col-span-1"
        >
          <Meter
            nilai={agt.sisa_nilai ?? 0}
            target={sep.target_saldo_akhir}
            labelNilai={`Posisi ${agt.periode_nama}: ${rupiahPenuh(agt.sisa_nilai)}`}
            labelTarget={rupiahPenuh(sep.target_saldo_akhir)}
            terbalik
          />
          <dl className="mt-4 space-y-2 text-sm">
            {[
              ["Sisa akhir " + agt.periode_nama, rupiahPenuh(agt.sisa_nilai)],
              ["Target akhir " + sep.periode_nama, rupiahPenuh(sep.target_saldo_akhir)],
              ["Harus turun", rupiahPenuh(agt.gap_penurunan)],
              ["Penurunan yang dikejar", persen(agt.persen_penurunan, 1)],
            ].map(([k, v]) => (
              <div key={k} className="flex items-baseline justify-between gap-3 border-b pb-1.5"
                   style={{ borderColor: "var(--line)" }}>
                <dt style={{ color: "var(--ink-2)" }}>{k}</dt>
                <dd className="font-semibold tabular-nums">{v}</dd>
              </div>
            ))}
          </dl>
          <p className="mt-3 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
            Secara persentase ini bukan lompatan besar: efektivitas penagihan hanya perlu naik{" "}
            {persen((agt.efektivitas_dibutuhkan ?? 0) - (agt.efektivitas_penagihan ?? 0), 2)}. Yang
            menentukan bukan volumenya, melainkan ke mana usaha diarahkan.
          </p>
        </Kartu>

        <Kartu
          judul={`Tiga jalur tagihan ${sep.periode_nama}`}
          keterangan="Seluruh beban tagihan ULP, bukan hanya yang ditagih bilman. Dua jalur terbesar justru belum tersentuh rencana aksi."
          className="lg:col-span-2"
        >
          <KomposisiJalur
            bagian={segmen.map((s) => ({
              label: s.segmen === "NA" ? "Belum termapping (#N/A)" : s.nama_segmen,
              nilai: s.nilai,
              persen: s.persen_unit,
              warna: warnaSegmen[s.segmen],
              keterangan:
                s.segmen === "AMR"
                  ? `${angka(s.jumlah_lembar)} rekening · rata-rata ${rupiah(s.rata_rata)}`
                  : `${angka(s.jumlah_lembar)} lembar · ${rupiah(s.nilai)}`,
            }))}
          />
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            <Catatan nada="perhatian">
              <strong>Rp{angka(sep.seg_na / 1e6, 1)} juta di {angka(sep.lembar_na)} lembar #N/A
              belum punya penanggung jawab</strong> — nilainya{" "}
              {angka((sep.seg_na ?? 0) / sep.target_saldo_akhir, 1)}× target akhir bulan. Ini
              pekerjaan meja, bukan pekerjaan lapangan.
            </Catatan>
            <Catatan nada="perhatian">
              <strong>{angka(sep.rek_amr)} rekening AMR memegang {persen(sep.persen_seg_amr, 1)}{" "}
              saldo berjalan</strong> — rata-rata {rupiah(sep.rata_rata_amr)} per rekening, setara{" "}
              {angka((sep.rata_rata_amr ?? 0) / sep.target_saldo_akhir, 2)}× target akhir bulan
              seluruh ULP.
            </Catatan>
          </div>
        </Kartu>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Kartu
          judul={`Klasemen RST ${agt.periode_nama}`}
          keterangan="Sisa tunggakan dibagi beban tagihan. Membandingkan sisa rupiah secara telanjang tidak adil — beban wilayah tiap petugas berbeda sampai 1,9 kali."
        >
          <BatangPeringkat
            data={rst
              .filter((r) => r.rst !== null)
              .map((r) => ({
                label: r.petugas_nama,
                nilai: r.rst as number,
                kelompok: r.kategori,
                keterangan: `${rupiahPenuh(r.sisa_nilai)} dari beban ${rupiah(r.beban_nilai)}`,
              }))}
            format="persen"
            warnaKelompok={Object.fromEntries(
              ["SANGAT_BAIK", "CUKUP", "PERLU_EVALUASI", "PERLU_ATENSI"].map((k) => [
                k, KATEGORI_RST[k].hex,
              ]),
            )}
            labelKelompok={Object.fromEntries(
              Object.entries(KATEGORI_RST).map(([k, v]) => [k, v.label]),
            )}
            lebarLabel={82}
          />
          <p className="mt-2 text-xs" style={{ color: "var(--ink-muted)" }}>
            Garis target unit: {persen(agt.rst_target)}. Beban {agt.periode_nama} belum didata,
            sehingga beban {sep.periode_nama} dipakai sebagai pendekatan luas wilayah kerja.
          </p>
        </Kartu>

        <Kartu
          judul={`Sisa tunggakan per petugas — ${agt.periode_nama}`}
          keterangan={`Empat petugas teratas memegang ${rupiah(nilaiEmpat)} atau ${persen(
            agt.konsentrasi_4_teratas, 1,
          )} dari seluruh masalah. Menyebar pendampingan rata ke ${agt.jumlah_petugas} orang adalah pemborosan.`}
        >
          <Tabel
            kolom={kolomSaldo}
            data={saldo}
            kunciBaris={(r) => r.petugas_kode}
            kaki={
              <tfoot>
                <tr>
                  <td />
                  <td className="font-semibold">TOTAL</td>
                  <td className="num font-semibold">{angka(agt.sisa_lembar)}</td>
                  <td className="num font-semibold">{rupiahPenuh(agt.sisa_nilai)}</td>
                  <td className="num">100,0%</td>
                  <td />
                  <td className="num font-semibold">{persen(agt.rst_unit)}</td>
                </tr>
              </tfoot>
            }
          />
        </Kartu>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Kartu
          judul="Makin dalam tunggakan, makin sulit ditagih"
          keterangan={`Hasil 11 hari pertama ${sep.periode_nama}. Ini temuan terpenting dari keseluruhan analisa.`}
        >
          <div className="grid gap-4 sm:grid-cols-2">
            {efek.map((e) => (
              <div key={e.segmen} className="rounded-lg border p-3" style={{ borderColor: "var(--line)" }}>
                <p className="kartu-judul">
                  {e.segmen === "LEMBAR_1" ? "Pelanggan 1 lembar" : "Pelanggan 2 lembar"}
                </p>
                <p className="angka-hero mt-1" style={{ color: "var(--viz-1)" }}>
                  {persen(e.persen_tertagih, 1)}
                </p>
                <p className="mt-1 text-xs" style={{ color: "var(--ink-muted)" }}>
                  {angka(e.tertagih)} tertagih dari {angka(e.posisi_awal)}; {angka(e.masih_menunggak)}{" "}
                  justru naik satu lembar
                </p>
              </div>
            ))}
          </div>
          <p className="mt-4 text-sm leading-relaxed" style={{ color: "var(--ink-2)" }}>
            Tingkat keberhasilan turun dari {persen(efek[0]?.persen_tertagih, 0)} ke{" "}
            {persen(efek[1]?.persen_tertagih, 0)} begitu pelanggan masuk lembar kedua. Artinya{" "}
            <strong>titik intervensi paling murah ada di lembar pertama, sebelum tanggal 20</strong> —
            bukan di sweeping akhir bulan. Menagih pelanggan 1 lembar cukup dengan pengantaran TUL
            6.01 dan pengingat; menagih pelanggan 3 lembar butuh surat peringatan, kunjungan
            berulang, tim pemutusan, dan berujung PRR.
          </p>
        </Kartu>

        <Kartu
          judul={`Peta risiko ${sep.periode_nama}`}
          keterangan="Pelanggan yang sudah menunggak 2 dan 3 lembar — merekalah yang menentukan apakah saldo tutup di bawah target."
        >
          <div className="grid gap-4 sm:grid-cols-3">
            <Petak label="Pelanggan 2 lembar" nilai={angka(sep.macet_2)} satuan="plg"
                   catatan={rupiahPenuh(sep.macet_nilai_2)} nada="peringatan" />
            <Petak label="Pelanggan 3 lembar" nilai={angka(sep.macet_3)} satuan="plg"
                   catatan={rupiahPenuh(sep.macet_nilai_3)} nada="buruk" />
            <Petak label="Total nilai macet" nilai={juta(sep.macet_nilai)} satuan="rupiah"
                   catatan={`${angka(sep.macet_lembar)} pelanggan berisiko`} nada="buruk" />
          </div>
          <p className="mt-4 text-sm leading-relaxed" style={{ color: "var(--ink-2)" }}>
            Mendahulukan {angka(sep.macet_lembar)} pelanggan ini pada pengantaran hari 14–15
            mencegah {rupiah(sep.macet_nilai_2)} naik ke lembar ketiga — di mana biaya per rupiah
            tertagih bisa 5 sampai 10 kali lipat.
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            <Link href="/tunggakan" className="lencana border-slate-200 bg-slate-100 text-slate-700 hover:underline">
              Lihat peringkat risiko →
            </Link>
            <Link href="/pengantaran" className="lencana border-slate-200 bg-slate-100 text-slate-700 hover:underline">
              Lihat progres pengantaran →
            </Link>
          </div>
        </Kartu>
      </div>
    </>
  );
}
