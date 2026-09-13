import Link from "next/link";
import { Kartu, Petak, JudulHalaman, Catatan } from "@/components/ui";
import { Tabel, TabelPendamping, type Kolom } from "@/components/Tabel";
import BatangPeringkat from "@/components/charts/BatangPeringkat";
import { getDataset, kpiRealisasi, kpiBerjalan, saldoPeriode, bebanPeriode, segmenPeriode } from "@/lib/data";
import { angka, juta, persen, rupiah, rupiahPenuh } from "@/lib/format";
import type { Beban, Saldo, SegmenBeban } from "@/lib/types";

export const revalidate = 300;
export const metadata = { title: "Tunggakan & Risiko" };

export default async function HalamanTunggakan() {
  const d = await getDataset();
  const agt = kpiRealisasi(d);
  const sep = kpiBerjalan(d);
  const saldo = saldoPeriode(d);
  const beban = bebanPeriode(d);
  const segmen = segmenPeriode(d);
  const efek = d.efektivitas.filter((e) => e.periode_kode === d.meta.periode_berjalan);
  const risiko = [...beban].sort((a, b) => a.rank_risiko_lembar - b.rank_risiko_lembar);
  const na = segmen.find((s) => s.segmen === "NA");
  const amr = segmen.find((s) => s.segmen === "AMR");

  const kolomRisiko: Kolom<Beban>[] = [
    { kunci: "rank", judul: "#", num: true, lebar: "40px", render: (b) => b.rank_risiko_lembar },
    {
      kunci: "petugas", judul: "Petugas",
      render: (b) => (
        <Link href={`/petugas/${b.petugas_kode}`} className="font-semibold underline-offset-2 hover:underline">
          {b.petugas_nama}
        </Link>
      ),
    },
    { kunci: "l2", judul: "2 lembar", num: true, render: (b) => angka(b.lembar_2) },
    {
      kunci: "l3", judul: "3 lembar", num: true,
      render: (b) => <span className={b.lembar_3 > 0 ? "font-bold text-red-600" : ""}>{angka(b.lembar_3)}</span>,
    },
    {
      kunci: "total", judul: "Total macet", num: true,
      render: (b) => <span className="font-semibold">{angka(b.lembar_macet)}</span>,
    },
    { kunci: "nilai", judul: "Nilai macet", num: true, render: (b) => rupiahPenuh(b.nilai_macet) },
    {
      kunci: "bagian", judul: "% dari 3 lbr unit", num: true,
      render: (b) => persen((b.lembar_3 / (sep.macet_3 || 1)) * 100, 1),
    },
  ];

  const kolomPareto: Kolom<Saldo>[] = [
    { kunci: "rank", judul: "#", num: true, lebar: "40px", render: (s) => s.rank_sisa },
    { kunci: "petugas", judul: "Petugas", render: (s) => s.petugas_nama },
    { kunci: "l1", judul: "1 lbr", num: true, render: (s) => angka(s.lembar_1) },
    { kunci: "n1", judul: "Rp 1 lbr", num: true, render: (s) => rupiahPenuh(s.nilai_1) },
    { kunci: "l2", judul: "2 lbr", num: true, render: (s) => angka(s.lembar_2) },
    { kunci: "n2", judul: "Rp 2 lbr", num: true, render: (s) => rupiahPenuh(s.nilai_2) },
    {
      kunci: "total", judul: "Total sisa", num: true,
      render: (s) => <span className="font-semibold">{rupiahPenuh(s.total_nilai)}</span>,
    },
    { kunci: "persen", judul: "% unit", num: true, render: (s) => persen(s.persen_unit, 1) },
    {
      kunci: "kum", judul: "Kumulatif", num: true,
      render: (s) => <span className="font-semibold">{persen(s.persen_kumulatif, 1)}</span>,
    },
    { kunci: "rata", judul: "Rata-rata/lbr", num: true, render: (s) => rupiahPenuh(s.rata_rata_per_lembar) },
  ];

  const kolomSegmen: Kolom<SegmenBeban>[] = [
    { kunci: "nama", judul: "Jalur", render: (s) => <span className="font-semibold">{s.nama_segmen}</span> },
    { kunci: "lembar", judul: "Lembar / rekening", num: true, render: (s) => angka(s.jumlah_lembar) },
    { kunci: "nilai", judul: "Nilai", num: true, render: (s) => rupiahPenuh(s.nilai) },
    { kunci: "persen", judul: "% ULP", num: true, render: (s) => persen(s.persen_unit, 1) },
    { kunci: "rata", judul: "Rata-rata", num: true, render: (s) => rupiahPenuh(s.rata_rata) },
    { kunci: "ket", judul: "Keterangan", render: (s) => s.keterangan },
  ];

  return (
    <>
      <JudulHalaman
        judul="Tunggakan & Peringkat Risiko"
        keterangan={`Di mana tunggakan menumpuk, siapa yang memegangnya, dan mana yang paling mahal bila dibiarkan naik satu lembar lagi. Posisi ${sep.periode_nama} per ${sep.tanggal_data ?? "–"}.`}
      />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Petak label="Pelanggan 2 lembar" nilai={angka(sep.macet_2)} satuan="plg" nada="peringatan"
               catatan={`${rupiahPenuh(sep.macet_nilai_2)} — akan naik ke lembar 3 bila tidak ditangani sebelum tanggal 20`} />
        <Petak label="Pelanggan 3 lembar" nilai={angka(sep.macet_3)} satuan="plg" nada="buruk"
               catatan={`${rupiahPenuh(sep.macet_nilai_3)} — kandidat pemutusan permanen`} />
        <Petak label="Total pelanggan berisiko" nilai={angka(sep.macet_lembar)} satuan="plg" nada="buruk"
               catatan={`Senilai ${rupiahPenuh(sep.macet_nilai)} · dibagi ${agt.jumlah_petugas} petugas ≈ ${angka(
                 sep.macet_lembar / agt.jumlah_petugas, 0)} pelanggan per orang`} />
        <Petak label="Lembar tanpa penanggung jawab" nilai={angka(na?.jumlah_lembar)} satuan="lbr" nada="buruk"
               catatan={`${rupiahPenuh(na?.nilai)} — belum ada yang menagihnya`} />
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Kartu
          judul={`Peringkat risiko ${sep.periode_nama}`}
          keterangan="Diurut berdasarkan jumlah pelanggan macet. Perhatikan bahwa urutan berdasarkan NILAI berbeda — dua hal ini menuntut penanganan berbeda."
        >
          <BatangPeringkat
            data={risiko.map((b) => ({
              label: b.petugas_nama,
              nilai: b.lembar_macet,
              kelompok: b.lembar_3 >= 6 ? "banyak3" : b.lembar_3 > 0 ? "ada3" : "tanpa3",
              keterangan: `${angka(b.lembar_2)} pelanggan 2 lembar + ${angka(b.lembar_3)} pelanggan 3 lembar · ${rupiahPenuh(b.nilai_macet)}`,
            }))}
            format="angka"
            warnaKelompok={{ banyak3: "#d03b3b", ada3: "#ec835a", tanpa3: "#fab219" }}
            labelKelompok={{
              banyak3: "≥6 pelanggan 3 lembar",
              ada3: "1–5 pelanggan 3 lembar",
              tanpa3: "tanpa pelanggan 3 lembar",
            }}
            lebarLabel={82}
          />
          <TabelPendamping ringkasan="Lihat angka lengkapnya">
            <Tabel kolom={kolomRisiko} data={risiko} kunciBaris={(b) => b.petugas_kode} />
          </TabelPendamping>
          <p className="mt-3 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
            {risiko[0]?.petugas_nama} memegang {angka(risiko[0]?.lembar_3)} dari{" "}
            {angka(sep.macet_3)} pelanggan 3 lembar se-unit (
            {persen(((risiko[0]?.lembar_3 ?? 0) / (sep.macet_3 || 1)) * 100, 1)}) — kandidat
            pemutusan permanen terbanyak. Sementara nilai macet terbesar dipegang{" "}
            {[...beban].sort((a, b) => b.nilai_macet - a.nilai_macet)[0]?.petugas_nama} sebesar{" "}
            {rupiahPenuh([...beban].sort((a, b) => b.nilai_macet - a.nilai_macet)[0]?.nilai_macet)}.
          </p>
        </Kartu>

        <Kartu
          judul={`Konsentrasi sisa tunggakan ${agt.periode_nama}`}
          keterangan="Bagian tiap petugas terhadap total sisa unit, diurut menurun. Kolom kumulatif menunjukkan seberapa cepat masalah terkumpul di sedikit orang."
        >
          <BatangPeringkat
            data={saldo.map((s) => ({
              label: s.petugas_nama,
              nilai: s.persen_unit ?? 0,
              kelompok: (s.persen_kumulatif ?? 0) <= (agt.konsentrasi_4_teratas ?? 0) ? "inti" : "sisanya",
              keterangan: `${rupiahPenuh(s.total_nilai)} · kumulatif ${persen(s.persen_kumulatif, 1)}`,
            }))}
            format="persen1"
            warnaKelompok={{ inti: "#d03b3b", sisanya: "#2a78d6" }}
            labelKelompok={{
              inti: `4 petugas inti (${persen(agt.konsentrasi_4_teratas, 1)} masalah)`,
              sisanya: "selebihnya",
            }}
            lebarLabel={82}
          />
          <TabelPendamping ringkasan="Lihat rincian per jumlah lembar">
            <Tabel kolom={kolomPareto} data={saldo} kunciBaris={(s) => s.petugas_kode} />
          </TabelPendamping>
          <p className="mt-3 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
            Dua petugas teratas memegang {persen(agt.konsentrasi_2_teratas, 1)} masalah; empat
            teratas {persen(agt.konsentrasi_4_teratas, 1)}. Intervensi yang menyentuh empat orang
            saja sudah menjangkau hampir tiga perempat persoalan unit.
          </p>
        </Kartu>
      </div>

      <div className="mt-4">
        <Kartu
          judul="Efektivitas penagihan antar-lembar"
          keterangan={`Menelusuri apa yang terjadi pada pelanggan yang menunggak di akhir ${agt.periode_nama} setelah 11 hari pertama ${sep.periode_nama}.`}
        >
          <div className="grid gap-4 lg:grid-cols-2">
            {efek.map((e) => {
              const nama = e.segmen === "LEMBAR_1" ? "Pelanggan 1 lembar" : "Pelanggan 2 lembar";
              const naik = e.segmen === "LEMBAR_1" ? "naik jadi 2 lembar" : "naik jadi 3 lembar";
              return (
                <div key={e.segmen} className="rounded-lg border p-4" style={{ borderColor: "var(--line)" }}>
                  <p className="text-sm font-semibold" style={{ color: "var(--ink)" }}>{nama}</p>
                  {/* Dua batang pada satu skala: berapa dari posisi awal yang
                      tertagih, dan berapa yang justru bertambah dalam. */}
                  <div className="mt-3 flex h-7 w-full gap-0.5 overflow-hidden rounded-md">
                    <div className="h-full rounded-l-md" title={`${e.tertagih} tertagih`}
                         style={{ width: `${(e.tertagih / e.posisi_awal) * 100}%`, background: "var(--st-good)" }} />
                    <div className="h-full rounded-r-md" title={`${e.masih_menunggak} ${naik}`}
                         style={{ width: `${(e.masih_menunggak / e.posisi_awal) * 100}%`, background: "var(--st-critical)" }} />
                  </div>
                  <dl className="mt-3 space-y-1.5 text-xs">
                    <div className="flex justify-between gap-3">
                      <dt style={{ color: "var(--ink-2)" }}>Posisi akhir {agt.periode_nama}</dt>
                      <dd className="font-semibold tabular-nums">{angka(e.posisi_awal)} pelanggan</dd>
                    </div>
                    <div className="flex justify-between gap-3">
                      <dt className="flex items-center gap-1.5" style={{ color: "var(--ink-2)" }}>
                        <span className="inline-block h-2 w-2 rounded-sm" style={{ background: "var(--st-good)" }} aria-hidden />
                        Tertagih
                      </dt>
                      <dd className="font-semibold tabular-nums">
                        {angka(e.tertagih)} · {persen(e.persen_tertagih, 1)}
                      </dd>
                    </div>
                    <div className="flex justify-between gap-3">
                      <dt className="flex items-center gap-1.5" style={{ color: "var(--ink-2)" }}>
                        <span className="inline-block h-2 w-2 rounded-sm" style={{ background: "var(--st-critical)" }} aria-hidden />
                        {naik.charAt(0).toUpperCase() + naik.slice(1)}
                      </dt>
                      <dd className="font-semibold tabular-nums">{angka(e.masih_menunggak)}</dd>
                    </div>
                  </dl>
                </div>
              );
            })}
          </div>
          <Catatan>
            Tingkat keberhasilan turun dari {persen(efek[0]?.persen_tertagih, 1)} ke{" "}
            {persen(efek[1]?.persen_tertagih, 1)} begitu pelanggan masuk lembar kedua — selisih{" "}
            {persen((efek[0]?.persen_tertagih ?? 0) - (efek[1]?.persen_tertagih ?? 0), 1)}. Konsekuensi
            operasionalnya jelas: dahulukan pelanggan yang <em>baru</em> menunggak, jangan tunggu
            sampai menumpuk. Biaya per rupiah tertagih pada pelanggan 3 lembar bisa 5 sampai 10 kali
            lipat pelanggan 1 lembar.
          </Catatan>
        </Kartu>
      </div>

      <div className="mt-4">
        <Kartu
          judul="Tiga jalur tagihan — ke mana uang terbesar sebenarnya berada"
          keterangan="Rencana aksi yang hanya menyasar bilman meninggalkan dua jalur bernilai jauh lebih besar tanpa penanganan."
        >
          <Tabel
            kolom={kolomSegmen}
            data={segmen}
            kunciBaris={(s) => s.segmen}
            kaki={
              <tfoot>
                <tr>
                  <td className="font-semibold">TOTAL ULP</td>
                  <td className="num font-semibold">{angka(segmen.reduce((a, s) => a + s.jumlah_lembar, 0))}</td>
                  <td className="num font-semibold">{rupiahPenuh(sep.seg_total)}</td>
                  <td className="num font-semibold">100,0%</td>
                  <td colSpan={2} />
                </tr>
              </tfoot>
            }
          />
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            <Catatan nada="perhatian">
              <strong>#N/A — {angka(na?.jumlah_lembar)} lembar, {rupiahPenuh(na?.nilai)}.</strong>{" "}
              Tidak ada petugas yang bertanggung jawab menagihnya. Nilainya{" "}
              {angka((na?.nilai ?? 0) / sep.target_saldo_akhir, 1)}× target akhir bulan, dan
              menyelesaikannya adalah pekerjaan meja tiga hari: cocokkan koordinat IDPEL dengan
              layer pelanggan termapping, spatial join ke wilayah RBM, terbitkan TO tambahan.
            </Catatan>
            <Catatan nada="perhatian">
              <strong>AMR — {angka(amr?.jumlah_lembar)} rekening, {rupiahPenuh(amr?.nilai)}.</strong>{" "}
              {persen(amr?.persen_unit, 1)} saldo berjalan ULP, rata-rata{" "}
              {rupiahPenuh(amr?.rata_rata)} per rekening. Satu rekening saja setara{" "}
              {angka((amr?.rata_rata ?? 0) / sep.target_saldo_akhir, 2)}× target akhir bulan seluruh
              ULP. Di segmen ini pendekatan relasional jauh lebih efektif daripada surat.
            </Catatan>
          </div>
          <p className="mt-3 text-xs" style={{ color: "var(--ink-muted)" }}>
            {segmen.find((s) => s.segmen === "BILMAN")?.keterangan}
          </p>
        </Kartu>
      </div>
    </>
  );
}
