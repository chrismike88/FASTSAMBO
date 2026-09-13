import { Kartu, Petak, JudulHalaman, Catatan } from "@/components/ui";
import Simulator from "@/components/Simulator";
import { getDataset, kpiRealisasi, kpiBerjalan, saldoPeriode, targetPeriode } from "@/lib/data";
import { angka, juta, persen, rupiah, rupiahPenuh } from "@/lib/format";

export const revalidate = 300;
export const metadata = { title: "Simulasi Target" };

export default async function HalamanSimulasi() {
  const d = await getDataset();
  const agt = kpiRealisasi(d);
  const sep = kpiBerjalan(d);
  const saldo = saldoPeriode(d);
  const target = targetPeriode(d);
  const efek = d.efektivitas.filter((e) => e.periode_kode === d.meta.periode_berjalan);

  return (
    <>
      <JudulHalaman
        judul="Simulasi Target Akhir Bulan"
        keterangan={`Menguji satu pertanyaan: dengan tingkat keberhasilan penagihan sekian, saldo akhir ${sep.periode_nama} mendarat di angka berapa — dan siapa saja yang melesat dari targetnya.`}
      />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Petak label="Titik awal" nilai={juta(agt.sisa_nilai)} satuan="rupiah" nada="buruk"
               catatan={`Sisa akhir ${agt.periode_nama} · RST ${persen(agt.rst_unit)}`} />
        <Petak label="Batas yang harus ditembus" nilai={juta(sep.target_saldo_akhir)} satuan="rupiah"
               nada="sorot" catatan={`RST ${persen(agt.rst_target)}`} />
        <Petak label="Harus turun" nilai={juta(agt.gap_penurunan)} satuan="rupiah" nada="peringatan"
               catatan={persen(agt.persen_penurunan, 1) + " dari posisi sekarang"} />
        <Petak label="Kenaikan efektivitas" nilai={persen(
                 (agt.efektivitas_dibutuhkan ?? 0) - (agt.efektivitas_penagihan ?? 0), 2)}
               nada="baik"
               catatan={`Dari ${persen(agt.efektivitas_penagihan)} ke ${persen(agt.efektivitas_dibutuhkan)}`} />
      </div>

      <div className="mt-4">
        <Kartu
          judul="Geser tingkat keberhasilan penagihan"
          keterangan="Nilai awal kedua penggeser adalah realisasi 11 hari pertama bulan ini. Perhatikan bahwa menaikkan penagihan pelanggan 1 lembar jauh lebih berpengaruh daripada pelanggan 2 lembar — karena di situlah sebagian besar nilainya berada."
        >
          <Simulator
            saldo={saldo}
            target={target}
            efektivitas={efek}
            targetSaldo={sep.target_saldo_akhir}
            bebanUnit={sep.beban_bilman}
            rstTarget={agt.rst_target}
          />
        </Kartu>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Kartu judul="Bagaimana angka ini dihitung"
               keterangan="Modelnya sengaja terbuka agar dapat diperdebatkan, bukan diterima begitu saja.">
          <pre className="gulir-x rounded-lg border p-3 text-xs leading-relaxed"
               style={{ borderColor: "var(--line)", background: "var(--surface-2)", color: "var(--ink-2)" }}>
{`proyeksi sisa akhir bulan (per petugas)
  = nilai sisa 1 lembar × (1 − keberhasilan tagih 1 lembar)
  + nilai sisa 2 lembar × (1 − keberhasilan tagih 2 lembar)

RST unit = total proyeksi ÷ beban tagihan bilman × 100
         = total proyeksi ÷ ${rupiahPenuh(sep.beban_bilman)} × 100`}
          </pre>
          <Catatan>
            Model ini mengabaikan tagihan bulan berjalan yang mungkin ikut menunggak, sehingga
            proyeksinya cenderung optimistis. Ia berguna untuk menimbang <em>seberapa besar</em>{" "}
            usaha yang dibutuhkan, bukan untuk meramal angka persisnya. Begitu realisasi harian
            mulai direkam, proyeksi ini sebaiknya diganti dengan tren yang sebenarnya.
          </Catatan>
        </Kartu>

        <Kartu judul="Aritmatika targetnya"
               keterangan="Kenapa target ini realistis, bukan mustahil.">
          <dl className="space-y-2 text-sm">
            {[
              [`Sisa akhir ${agt.periode_nama}`, rupiahPenuh(agt.sisa_nilai), `RST ${persen(agt.rst_unit)}`],
              [`Target akhir ${sep.periode_nama}`, rupiahPenuh(sep.target_saldo_akhir), `RST ${persen(agt.rst_target)}`],
              ["Harus turun", rupiahPenuh(agt.gap_penurunan), persen(agt.persen_penurunan, 1)],
              ["Efektivitas penagihan sekarang", persen(agt.efektivitas_penagihan), ""],
              ["Efektivitas yang dibutuhkan", persen(agt.efektivitas_dibutuhkan), ""],
              ["Kenaikan yang diperlukan", persen(
                (agt.efektivitas_dibutuhkan ?? 0) - (agt.efektivitas_penagihan ?? 0), 2), "poin persen"],
            ].map(([k, v, ket]) => (
              <div key={k} className="flex items-baseline justify-between gap-3 border-b pb-1.5"
                   style={{ borderColor: "var(--line)" }}>
                <dt style={{ color: "var(--ink-2)" }}>{k}</dt>
                <dd className="text-right">
                  <span className="font-semibold tabular-nums">{v}</span>
                  {ket && <span className="ml-2 text-xs" style={{ color: "var(--ink-muted)" }}>{ket}</span>}
                </dd>
              </div>
            ))}
          </dl>
          <p className="mt-3 text-sm leading-relaxed" style={{ color: "var(--ink-2)" }}>
            Kenaikan efektivitas yang dibutuhkan hanya{" "}
            {persen((agt.efektivitas_dibutuhkan ?? 0) - (agt.efektivitas_penagihan ?? 0), 2)} — ini
            bukan lompatan besar. Yang menentukan bukan volume usaha, melainkan konsentrasinya:{" "}
            {persen(agt.konsentrasi_4_teratas, 1)} masalah dipegang empat orang, dan efektivitas
            penagihan anjlok dari {persen(efek[0]?.persen_tertagih, 0)} ke{" "}
            {persen(efek[1]?.persen_tertagih, 0)} begitu pelanggan melewati satu lembar.
          </p>
        </Kartu>
      </div>
    </>
  );
}
