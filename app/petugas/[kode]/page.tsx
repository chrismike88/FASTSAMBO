import Link from "next/link";
import { notFound } from "next/navigation";
import { Kartu, Petak, JudulHalaman, Catatan, LencanaRst, LencanaAntar } from "@/components/ui";
import { Meter } from "@/components/Meter";
import { Tabel, type Kolom } from "@/components/Tabel";
import { getDataset, kpiRealisasi, kpiBerjalan } from "@/lib/data";
import { angka, gelombang, juta, persen, rupiah, rupiahPenuh } from "@/lib/format";
import type { Pengantaran } from "@/lib/types";

export const revalidate = 300;

export async function generateStaticParams() {
  const d = await getDataset();
  return d.petugas.map((p) => ({ kode: p.kode }));
}

export async function generateMetadata({ params }: { params: Promise<{ kode: string }> }) {
  const { kode } = await params;
  return { title: `Petugas ${kode}` };
}

export default async function DetailPetugas({ params }: { params: Promise<{ kode: string }> }) {
  const { kode } = await params;
  const d = await getDataset();
  const petugas = d.petugas.find((p) => p.kode === kode);
  if (!petugas) notFound();

  const agt = kpiRealisasi(d);
  const sep = kpiBerjalan(d);
  const saldo = d.saldo.find((s) => s.petugas_kode === kode && s.periode_kode === d.meta.periode_realisasi);
  const beban = d.beban.find((b) => b.petugas_kode === kode && b.periode_kode === d.meta.periode_berjalan);
  const rst = d.rst.find((r) => r.petugas_kode === kode && r.periode_kode === d.meta.periode_realisasi);
  const skor = d.skor.find((s) => s.petugas_kode === kode && s.periode_kode === d.meta.periode_realisasi);
  const target = d.target.find((t) => t.petugas_kode === kode && t.periode_kode === d.meta.periode_berjalan);
  const tertib = d.penertiban.find((t) => t.petugas_kode === kode && t.periode_kode === d.meta.periode_realisasi);
  const progres = d.progres_antar.find((p) => p.petugas_kode === kode);
  const antar = d.pengantaran.filter((a) => a.petugas_kode === kode);

  const kolomAntar: Kolom<Pengantaran>[] = [
    { kunci: "idpel", judul: "IDPEL", render: (a) => <span className="whitespace-nowrap tabular-nums">{a.idpel}</span> },
    {
      kunci: "lembar", judul: "Lembar", num: true,
      render: (a) => (
        <span className={a.jml_lembar >= 3 ? "font-bold text-red-600" : "font-semibold"}>
          {a.jml_lembar}
        </span>
      ),
    },
    { kunci: "nilai", judul: "Nilai tagihan", num: true, render: (a) => rupiahPenuh(a.nilai_tagihan) },
    { kunci: "gelombang", judul: "Gelombang", render: (a) => gelombang(a.gelombang) },
    { kunci: "status", judul: "Status", render: (a) => <LencanaAntar status={a.status_antar} /> },
    { kunci: "tgl", judul: "Tgl antar", render: (a) => a.tgl_antar ?? "–" },
  ];

  return (
    <>
      <div className="mb-2">
        <Link href="/petugas" className="text-xs underline-offset-2 hover:underline"
              style={{ color: "var(--ink-muted)" }}>
          ← Kembali ke klasemen
        </Link>
      </div>
      <JudulHalaman
        judul={petugas.nama}
        keterangan={
          <>
            {petugas.status === "AKTIF"
              ? `Petugas bilman aktif sejak ${petugas.aktif_dari ?? "–"}.`
              : petugas.status === "PERLU_KONFIRMASI"
                ? "Status keaktifan perlu dikonfirmasi ke Nusa Daya."
                : "Sudah tidak aktif."}{" "}
            {petugas.catatan}
          </>
        }
      />

      {!beban && (
        <Catatan nada="perhatian">
          Petugas ini tidak muncul pada data {sep.periode_nama}, sehingga beban kerjanya tidak
          diketahui dan RST-nya tidak dapat dihitung. Pertanggungjawaban wilayahnya perlu
          diperjelas sebelum klasemen bulan ini terbit.
        </Catatan>
      )}

      <div className="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Petak label={`Sisa ${agt.periode_nama}`} nilai={juta(saldo?.total_nilai)} satuan="rupiah"
               nada="buruk"
               catatan={saldo ? `${angka(saldo.total_lembar)} lembar · peringkat ${saldo.rank_sisa} dari ${agt.jumlah_petugas}` : "tidak ada data"} />
        <Petak label={`Beban ${sep.periode_nama}`} nilai={juta(beban?.nilai_total)} satuan="rupiah"
               nada="sorot"
               catatan={beban ? `${angka(beban.total_lembar)} lembar · ${persen(beban.persen_beban_unit, 1)} beban unit` : "tidak ada data"} />
        <Petak label="RST" nilai={persen(rst?.rst)} nada={(rst?.rst ?? 99) <= agt.rst_target ? "baik" : "buruk"}
               catatan={`Target unit ${persen(agt.rst_target)} · peringkat ${rst?.rank_rst ?? "–"}`} />
        <Petak label="Skor kinerja" nilai={angka(skor?.skor_total, 1)}
               nada={(skor?.skor_total ?? 0) >= 75 ? "baik" : (skor?.skor_total ?? 0) >= 50 ? "peringatan" : "buruk"}
               catatan={`Dari bobot ${angka(skor?.bobot_terpakai)} yang datanya tersedia`} />
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Kartu judul={`Target ${sep.periode_nama}`}
               keterangan="Target dialokasikan proporsional terhadap kontribusi masalah, bukan dibagi rata.">
          {target ? (
            <>
              <Meter
                nilai={target.sisa_awal ?? 0}
                target={target.target_sisa}
                labelNilai={`Posisi awal: ${rupiahPenuh(target.sisa_awal)}`}
                labelTarget={`Target ${rupiahPenuh(target.target_sisa)}`}
                terbalik
              />
              <dl className="mt-4 space-y-2 text-sm">
                {[
                  ["Sisa awal bulan", rupiahPenuh(target.sisa_awal)],
                  ["Target sisa akhir bulan", rupiahPenuh(target.target_sisa)],
                  ["Harus turun", rupiahPenuh(target.harus_turun)],
                  ["RST yang dituju", persen(target.rst_target)],
                  ["Jenis target", target.jenis_target === "PERTAHANKAN" ? "Pertahankan" :
                    target.jenis_target === "BARU" ? "Petugas baru" : "Turunkan"],
                ].map(([k, v]) => (
                  <div key={k} className="flex items-baseline justify-between gap-3 border-b pb-1.5"
                       style={{ borderColor: "var(--line)" }}>
                    <dt style={{ color: "var(--ink-2)" }}>{k}</dt>
                    <dd className="font-semibold tabular-nums">{v}</dd>
                  </div>
                ))}
              </dl>
              {target.catatan && (
                <p className="mt-3 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
                  {target.catatan}
                </p>
              )}
            </>
          ) : (
            <p className="text-sm" style={{ color: "var(--ink-muted)" }}>Belum ada target yang ditetapkan.</p>
          )}
        </Kartu>

        <Kartu judul="Rincian komponen penilaian"
               keterangan="Komponen yang datanya belum tersedia dikeluarkan dari perhitungan, dan bobotnya dinormalisasi ulang.">
          <Tabel
            kolom={[
              { kunci: "nama", judul: "Komponen", render: (k) => k.nama },
              { kunci: "bobot", judul: "Bobot", num: true, render: (k) => `${angka(k.bobot)}%` },
              {
                kunci: "nilai", judul: "Capaian", num: true,
                render: (k) => {
                  const v: Record<string, number | null | undefined> = {
                    RST: skor?.rst, ROLLOVER: skor?.rollover, TUL601: skor?.ketepatan_tul,
                    CASHIN: skor?.cash_in_dini, PENERTIBAN: skor?.efektivitas_penertiban,
                  };
                  return persen(v[k.kode]);
                },
              },
              {
                kunci: "target", judul: "Target", num: true,
                render: (k) => `${k.arah === "MINIMUM" ? "≤" : "≥"} ${angka(k.target, k.target % 1 ? 2 : 0)}%`,
              },
              {
                kunci: "skor", judul: "Skor", num: true,
                render: (k) => {
                  const v: Record<string, number | null | undefined> = {
                    RST: skor?.skor_rst, ROLLOVER: skor?.skor_rollover, TUL601: skor?.skor_tul,
                    CASHIN: skor?.skor_cash_in, PENERTIBAN: skor?.skor_penertiban,
                  };
                  return v[k.kode] === null || v[k.kode] === undefined
                    ? <span style={{ color: "var(--ink-muted)" }}>menunggu data</span>
                    : <span className="font-semibold">{angka(v[k.kode], 1)}</span>;
                },
              },
            ]}
            data={d.komponen_skor}
            kunciBaris={(k) => k.kode}
            kaki={
              <tfoot>
                <tr>
                  <td className="font-semibold">SKOR AKHIR</td>
                  <td className="num">{angka(skor?.bobot_terpakai)}%</td>
                  <td colSpan={2} />
                  <td className="num font-bold">{angka(skor?.skor_total, 1)}</td>
                </tr>
              </tfoot>
            }
          />
          <div className="mt-3 flex flex-wrap items-center gap-2 text-xs">
            <LencanaRst kategori={rst?.kategori ?? "N/A"} />
            {tertib && (
              <span style={{ color: "var(--ink-muted)" }}>
                Penertiban {agt.periode_nama}: {angka(tertib.jumlah_pelanggan)} pelanggan ·{" "}
                {rupiahPenuh(tertib.nilai)}
              </span>
            )}
          </div>
        </Kartu>
      </div>

      {progres && progres.total_lembar > 0 && (
        <div className="mt-4">
          <Kartu
            judul={`Daftar prioritas pengantaran TUL 6.01 — ${sep.periode_nama}`}
            keterangan={`${angka(progres.total_lembar)} pelanggan 2 dan 3 lembar di wilayah kerja ${petugas.nama}, senilai ${rupiahPenuh(progres.nilai_total)}. Inilah gelombang pertama yang harus diantar pada hari 14–15.`}
          >
            <div className="mb-4 grid gap-4 sm:grid-cols-3">
              <Petak label="Sudah terantar" nilai={angka(progres.terantar)} satuan="lbr"
                     nada={progres.terantar > 0 ? "baik" : "netral"}
                     catatan={persen(progres.persen_antar, 1) + " dari daftar prioritas"} />
              <Petak label="Belum diantar" nilai={angka(progres.belum)} satuan="lbr" nada="peringatan"
                     catatan={rupiahPenuh(progres.nilai_total - progres.nilai_terantar)} />
              <Petak label="Ditandai suspect" nilai={angka(progres.suspect)} satuan="lbr"
                     nada={progres.suspect > 0 ? "buruk" : "netral"}
                     catatan="Jarak foto FTO melebihi 100 m dari titik pelanggan" />
            </div>
            <Tabel
              kolom={kolomAntar}
              data={antar}
              kunciBaris={(a) => a.idpel}
              tinggiMaks="420px"
            />
            <p className="mt-3 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
              IDPEL berawalan <code>SLOT-</code> adalah kerangka: jumlah barisnya sudah sesuai
              jumlah pelanggan 2 dan 3 lembar yang sebenarnya, tetapi nomor pelanggannya menunggu
              penarikan dari AP2T. Nilai tagihan yang tertera adalah rata-rata per lembar petugas
              ini, bukan nilai per pelanggan.
            </p>
          </Kartu>
        </div>
      )}
    </>
  );
}
