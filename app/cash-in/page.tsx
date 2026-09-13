import Link from "next/link";
import { Kartu, Petak, JudulHalaman, Catatan, LencanaAksi, LencanaPrioritas } from "@/components/ui";
import { Tabel, type Kolom } from "@/components/Tabel";
import BatangGanda from "@/components/charts/BatangGanda";
import { getDataset, kpiRealisasi, kpiBerjalan, targetPeriode } from "@/lib/data";
import { angka, juta, persen, rupiah, rupiahPenuh, tanggalPendek } from "@/lib/format";
import type { Target, Hambatan, CatatanPerbaikan } from "@/lib/types";

export const revalidate = 300;
export const metadata = { title: "Percepatan Cash-In" };

export default async function HalamanCashIn() {
  const d = await getDataset();
  const agt = kpiRealisasi(d);
  const sep = kpiBerjalan(d);
  const target = targetPeriode(d);
  const aksi = d.aksi.filter((a) => a.periode_kode === d.meta.periode_berjalan);

  const totalTarget = target.reduce((a, t) => a + t.target_sisa, 0);
  const sisaAwalBertarget = target.reduce((a, t) => a + (t.sisa_awal ?? 0), 0);
  // Penurunan BERSIH unit, bukan penjumlahan kolom "harus turun". Keduanya
  // berbeda karena sebagian petugas justru diberi ruang: DONNY memegang
  // wilayah yang bulan lalu milik IBO dan mendapat target baru, sementara
  // beberapa petugas sudah berada di bawah targetnya. Penjumlahan kolom
  // mengabaikan ruang itu dan melebih-lebihkan beban yang sebenarnya.
  const penurunanBersih = sisaAwalBertarget - totalTarget;
  const totalTurunKolom = target.reduce((a, t) => a + t.harus_turun, 0);
  const empatTeratas = [...target].sort((a, b) => b.harus_turun - a.harus_turun).slice(0, 4);
  const turunEmpat = empatTeratas.reduce((a, t) => a + t.harus_turun, 0);
  const bantalan = sep.target_saldo_akhir - totalTarget;
  const sisaTanpaTarget = (agt.sisa_nilai ?? 0) - sisaAwalBertarget;

  const kolomTarget: Kolom<Target>[] = [
    {
      kunci: "petugas", judul: "Petugas",
      render: (t) => (
        <Link href={`/petugas/${t.petugas_kode}`} className="font-semibold underline-offset-2 hover:underline">
          {t.petugas_nama}
        </Link>
      ),
    },
    { kunci: "beban", judul: `Beban ${sep.periode_nama}`, num: true, render: (t) => rupiahPenuh(t.beban) },
    { kunci: "awal", judul: `Sisa ${agt.periode_nama}`, num: true, render: (t) => rupiahPenuh(t.sisa_awal) },
    {
      kunci: "target", judul: "Target sisa", num: true,
      render: (t) => <span className="font-semibold">{rupiahPenuh(t.target_sisa)}</span>,
    },
    {
      kunci: "turun", judul: "Harus turun", num: true,
      render: (t) => t.jenis_target === "PERTAHANKAN"
        ? <span style={{ color: "var(--ink-muted)" }}>pertahankan</span>
        : t.jenis_target === "BARU"
          ? <span style={{ color: "var(--ink-muted)" }}>petugas baru</span>
          : <span className="font-semibold text-red-600">{rupiahPenuh(t.harus_turun)}</span>,
    },
    { kunci: "rst", judul: "RST target", num: true, render: (t) => persen(t.rst_target) },
    { kunci: "catatan", judul: "Catatan", render: (t) => t.catatan },
  ];

  const kolomHambatan: Kolom<Hambatan>[] = [
    { kunci: "hambatan", judul: "Hambatan", lebar: "26%",
      render: (h) => <span className="font-semibold">{h.hambatan}</span> },
    { kunci: "mitigasi", judul: "Mitigasi konkret", render: (h) => h.mitigasi },
    { kunci: "pj", judul: "Penanggung jawab", lebar: "18%", render: (h) => h.penanggung_jawab },
  ];

  const kolomCatatan: Kolom<CatatanPerbaikan>[] = [
    { kunci: "no", judul: "#", num: true, lebar: "36px", render: (c) => c.nomor },
    { kunci: "temuan", judul: "Temuan", render: (c) => c.temuan },
    { kunci: "dampak", judul: "Dampak", render: (c) => c.dampak },
    { kunci: "perbaikan", judul: "Perbaikan", render: (c) => c.perbaikan },
  ];

  return (
    <>
      <JudulHalaman
        judul="Strategi Percepatan Cash-In"
        keterangan={`Target ${rupiahPenuh(sep.target_saldo_akhir)} akhir ${sep.periode_nama} dapat dicapai tanpa menambah personel maupun anggaran — dengan menggeser ke mana usaha diarahkan.`}
      />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Petak label="Total target sisa" nilai={juta(totalTarget)} satuan="rupiah" nada="sorot"
               catatan={`Memberi bantalan ${rupiah(bantalan)} terhadap batas ${rupiah(sep.target_saldo_akhir)}`} />
        <Petak label="Penurunan bersih unit" nilai={juta(penurunanBersih)} satuan="rupiah" nada="buruk"
               catatan={`Dari ${rupiahPenuh(sisaAwalBertarget)} sisa milik petugas bertarget`} />
        <Petak label="Dipikul 4 petugas teratas" nilai={persen((turunEmpat / penurunanBersih) * 100, 0)}
               nada="peringatan"
               catatan={`${rupiah(turunEmpat)} dari ${rupiah(penurunanBersih)} — ${empatTeratas.map((t) => t.petugas_nama).join(", ")}`} />
        <Petak label="RST unit yang dituju" nilai={persen(
                 (totalTarget / sep.beban_bilman) * 100)} nada="baik"
               catatan={`Turun dari ${persen(agt.rst_unit)} pada ${agt.periode_nama}`} />
      </div>

      <div className="mt-4">
        <Kartu
          judul={`Target individual ${sep.periode_nama}`}
          keterangan="Dialokasikan sesuai kontribusi masalah, bukan dibagi rata. Kalau dibebankan merata ke sepuluh orang, semua merasa bebannya ringan dan tidak ada yang bergerak."
        >
          <BatangGanda
            data={target.map((t) => ({
              label: t.petugas_nama,
              a: t.sisa_awal ?? 0,
              b: t.target_sisa,
            }))}
            namaA={`Sisa ${agt.periode_nama}`}
            namaB={`Target akhir ${sep.periode_nama}`}
            format="juta1"
          />
          <div className="mt-4">
            <Tabel
              kolom={kolomTarget}
              data={target}
              kunciBaris={(t) => t.petugas_kode}
              kaki={
                <tfoot>
                  <tr>
                    <td className="font-semibold">TOTAL</td>
                    <td className="num font-semibold">{rupiahPenuh(sep.beban_bilman)}</td>
                    <td className="num font-semibold">{rupiahPenuh(sisaAwalBertarget)}</td>
                    <td className="num font-semibold">{rupiahPenuh(totalTarget)}</td>
                    <td className="num font-semibold">{rupiahPenuh(totalTurunKolom)}</td>
                    <td className="num font-semibold">{persen((totalTarget / sep.beban_bilman) * 100)}</td>
                    <td />
                  </tr>
                </tfoot>
              }
            />
          </div>
          <p className="mt-3 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
            Penjumlahan kolom “harus turun” ({rupiahPenuh(totalTurunKolom)}) lebih besar daripada
            penurunan bersih unit ({rupiahPenuh(penurunanBersih)}), karena sebagian petugas justru
            diberi ruang: {target.find((t) => t.jenis_target === "BARU")?.petugas_nama ?? "petugas baru"}{" "}
            memegang wilayah yang bulan lalu ditangani petugas lain dan mendapat target baru{" "}
            {rupiah(target.find((t) => t.jenis_target === "BARU")?.target_sisa)}. Sisa{" "}
            {rupiahPenuh(sisaTanpaTarget)} milik petugas yang tidak lagi muncul pada data{" "}
            {sep.periode_nama} belum punya pemilik target — ini perlu diperjelas lebih dulu.
          </p>
          <p className="mt-3 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
            Petugas dengan RST terendah cukup diminta mempertahankan posisinya — memaksa mereka
            turun lagi dari kisaran 0,3–0,6% hanya membuang tenaga yang lebih berguna di tempat
            lain. Total {rupiah(totalTarget)} memberi bantalan {rupiah(bantalan)} terhadap batas{" "}
            {rupiah(sep.target_saldo_akhir)}.
          </p>
        </Kartu>
      </div>

      <div className="mt-4">
        <h2 className="mb-3 text-base font-semibold" style={{ color: "var(--ink)" }}>
          Lima aksi berdampak tertinggi
        </h2>
        <div className="grid gap-4 lg:grid-cols-2">
          {aksi.map((a) => (
            <Kartu key={a.kode} className="flex flex-col">
              <div className="mb-3 flex flex-wrap items-start justify-between gap-2">
                <div className="min-w-0">
                  <p className="kartu-judul">{a.kode}</p>
                  <h3 className="mt-1 text-[0.95rem] font-semibold" style={{ color: "var(--ink)" }}>
                    {a.judul}
                  </h3>
                </div>
                <LencanaPrioritas prioritas={a.prioritas} />
              </div>
              <div className="mb-3 flex flex-wrap items-baseline gap-x-4 gap-y-1 text-xs">
                <span className="text-sm font-bold" style={{ color: "var(--viz-1)" }}>
                  {a.dampak_nilai > 0 ? rupiahPenuh(a.dampak_nilai) : "Dampak struktural"}
                </span>
                <span style={{ color: "var(--ink-muted)" }}>{a.dampak_label}</span>
              </div>
              <p className="mb-3 text-sm leading-relaxed" style={{ color: "var(--ink-2)" }}>
                {a.ringkasan}
              </p>
              <ul className="mb-3 space-y-1.5 text-xs leading-relaxed" style={{ color: "var(--ink-2)" }}>
                {a.langkah.map((l, i) => (
                  <li key={i} className="flex gap-2">
                    <span className="mt-[0.15rem] shrink-0 font-semibold" style={{ color: "var(--viz-1)" }}>
                      {i + 1}.
                    </span>
                    <span>{l}</span>
                  </li>
                ))}
              </ul>
              <div className="mt-auto flex flex-wrap items-center gap-x-4 gap-y-1 border-t pt-3 text-xs"
                   style={{ borderColor: "var(--line)", color: "var(--ink-muted)" }}>
                <LencanaAksi status={a.status} />
                <span>{a.penanggung_jawab}</span>
                <span className="ml-auto font-semibold">tenggat {tanggalPendek(a.tenggat)}</span>
              </div>
            </Kartu>
          ))}
        </div>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Kartu judul="Hambatan yang sudah teridentifikasi & mitigasinya"
               keterangan="Hambatan yang tidak punya mitigasi konkret hanya menjadi alasan di laporan bulan depan.">
          <Tabel kolom={kolomHambatan} data={d.hambatan} kunciBaris={(h) => h.kode} />
        </Kartu>

        <Kartu judul="Catatan perbaikan materi checkpoint"
               keterangan="Diselesaikan sebelum materi naik ke UP3/UID agar angkanya tidak dipertanyakan.">
          <Tabel kolom={kolomCatatan} data={d.catatan_perbaikan} kunciBaris={(c) => String(c.nomor)} />
          <Catatan nada="perhatian">
            Temuan nomor {d.catatan_perbaikan.length} ditemukan saat data dimasukkan ke basis data
            ini: penjumlahan baris per petugas tidak cocok dengan baris subtotal pada materi sumber.
            Dashboard memakai angka hasil penjumlahan per petugas, dan selisihnya ditelusuri sampai
            ketemu penyebabnya.
          </Catatan>
        </Kartu>
      </div>

      <div className="mt-4">
        <Kartu judul="Tiga pergeseran yang menentukan"
               keterangan="Target dapat dicapai tanpa menambah personel maupun anggaran.">
          <div className="grid gap-4 sm:grid-cols-3">
            {[
              {
                dari: "Mengejar semua orang",
                ke: "Fokus ke 4 petugas",
                isi: `Mereka memegang ${persen(agt.konsentrasi_4_teratas, 1)} masalah, dengan target individual proporsional terhadap beban.`,
              },
              {
                dari: "Sweeping akhir bulan",
                ke: "Intervensi dini di lembar pertama",
                isi: "Data 11 hari pertama membuktikan efektivitas turun dari 35% ke 25% begitu pelanggan masuk lembar kedua.",
              },
              {
                dari: "Fokus tunggal ke bilman",
                ke: "Tiga jalur paralel",
                isi: `Bilman ${rupiah(sep.seg_bilman)}, AMR ${rupiah(sep.seg_amr)}, dan #N/A ${rupiah(sep.seg_na)}. Dua jalur terakhir belum tersentuh rencana aksi.`,
              },
            ].map((g) => (
              <div key={g.ke} className="rounded-lg border p-3" style={{ borderColor: "var(--line)" }}>
                <p className="text-xs line-through" style={{ color: "var(--ink-muted)" }}>{g.dari}</p>
                <p className="mt-1 text-sm font-bold" style={{ color: "var(--ink)" }}>→ {g.ke}</p>
                <p className="mt-2 text-xs leading-relaxed" style={{ color: "var(--ink-2)" }}>{g.isi}</p>
              </div>
            ))}
          </div>
          <Catatan nada="perhatian">
            Yang paling mendesak minggu ini: <strong>{rupiahPenuh(sep.seg_na)} di{" "}
            {angka(sep.lembar_na)} lembar masih tanpa penanggung jawab.</strong> Itu pekerjaan meja
            yang bisa selesai dalam tiga hari, dan nilainya{" "}
            {angka(sep.seg_na / sep.target_saldo_akhir, 1)} kali lipat target akhir bulan.
          </Catatan>
        </Kartu>
      </div>
    </>
  );
}
