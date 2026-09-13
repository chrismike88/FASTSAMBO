"use client";

import { useMemo, useState } from "react";
import { angka, persen, rupiah, rupiahPenuh } from "@/lib/format";
import type { Efektivitas, Saldo, Target } from "@/lib/types";

/**
 * Menjawab satu pertanyaan: dengan tingkat keberhasilan penagihan sekian,
 * saldo akhir bulan mendarat di angka berapa — dan apakah lolos target.
 *
 * Modelnya sengaja sederhana dan terbuka, bukan kotak hitam: sisa akhir bulan
 * diperkirakan sebagai sisa awal dikurangi bagian yang tertagih, dengan tingkat
 * keberhasilan yang berbeda untuk pelanggan 1 lembar dan 2 lembar — karena
 * data 11 hari pertama menunjukkan keduanya memang jauh berbeda.
 */
export default function Simulator({
  saldo,
  target,
  efektivitas,
  targetSaldo,
  bebanUnit,
  rstTarget,
}: {
  saldo: Saldo[];
  target: Target[];
  efektivitas: Efektivitas[];
  targetSaldo: number;
  bebanUnit: number;
  rstTarget: number;
}) {
  const dasar1 = efektivitas.find((e) => e.segmen === "LEMBAR_1")?.persen_tertagih ?? 35;
  const dasar2 = efektivitas.find((e) => e.segmen === "LEMBAR_2")?.persen_tertagih ?? 25;

  const [tagih1, setTagih1] = useState(Math.round(dasar1));
  const [tagih2, setTagih2] = useState(Math.round(dasar2));

  const hasil = useMemo(() => {
    const baris = saldo.map((s) => {
      const sisa = s.nilai_1 * (1 - tagih1 / 100) + s.nilai_2 * (1 - tagih2 / 100);
      const t = target.find((x) => x.petugas_kode === s.petugas_kode);
      return {
        kode: s.petugas_kode,
        nama: s.petugas_nama,
        awal: s.total_nilai,
        proyeksi: sisa,
        target: t?.target_sisa ?? null,
        lolos: t ? sisa <= t.target_sisa : null,
      };
    });
    const total = baris.reduce((a, b) => a + b.proyeksi, 0);
    return {
      baris: baris.sort((a, b) => b.proyeksi - a.proyeksi),
      total,
      rst: (total / bebanUnit) * 100,
      lolos: total <= targetSaldo,
      selisih: total - targetSaldo,
    };
  }, [saldo, target, tagih1, tagih2, targetSaldo, bebanUnit]);

  return (
    <div>
      <div className="grid gap-5 sm:grid-cols-2">
        <Geser
          label="Keberhasilan menagih pelanggan 1 lembar"
          nilai={tagih1}
          ubah={setTagih1}
          dasar={dasar1}
          catatan={`Realisasi 11 hari pertama: ${persen(dasar1, 1)}`}
        />
        <Geser
          label="Keberhasilan menagih pelanggan 2 lembar"
          nilai={tagih2}
          ubah={setTagih2}
          dasar={dasar2}
          catatan={`Realisasi 11 hari pertama: ${persen(dasar2, 1)}`}
        />
      </div>

      <div
        className="mt-5 rounded-lg border p-4"
        style={{
          borderColor: hasil.lolos ? "var(--st-good)" : "var(--st-critical)",
          background: "var(--surface-2)",
        }}
      >
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <p className="kartu-judul">Proyeksi sisa akhir bulan</p>
            <p
              className="angka-hero mt-1"
              style={{ color: hasil.lolos ? "var(--st-good)" : "var(--st-critical)" }}
            >
              {rupiah(hasil.total)}
            </p>
            <p className="mt-1 text-xs" style={{ color: "var(--ink-muted)" }}>
              {rupiahPenuh(hasil.total)} · RST {persen(hasil.rst)}
            </p>
          </div>
          <div className="text-right">
            <p className="text-sm font-bold" style={{ color: hasil.lolos ? "var(--st-good)" : "var(--st-critical)" }}>
              {hasil.lolos ? "✓ Target tercapai" : "✕ Target terlampaui"}
            </p>
            <p className="mt-1 text-xs" style={{ color: "var(--ink-2)" }}>
              {hasil.lolos
                ? `Bantalan ${rupiah(Math.abs(hasil.selisih))} di bawah batas`
                : `Kelebihan ${rupiah(hasil.selisih)} dari batas ${rupiah(targetSaldo)}`}
            </p>
            <p className="mt-0.5 text-xs" style={{ color: "var(--ink-muted)" }}>
              RST target unit {persen(rstTarget)}
            </p>
          </div>
        </div>
      </div>

      <div className="gulir-x mt-4 rounded-lg border" style={{ borderColor: "var(--line)" }}>
        <table className="tabel">
          <thead>
            <tr>
              <th>Petugas</th>
              <th className="num">Sisa awal</th>
              <th className="num">Proyeksi akhir</th>
              <th className="num">Target</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {hasil.baris.map((b) => (
              <tr key={b.kode}>
                <td className="font-semibold">{b.nama}</td>
                <td className="num">{rupiahPenuh(b.awal)}</td>
                <td className="num font-semibold">{rupiahPenuh(b.proyeksi)}</td>
                <td className="num">{b.target === null ? "–" : rupiahPenuh(b.target)}</td>
                <td>
                  {b.lolos === null ? (
                    <span style={{ color: "var(--ink-muted)" }}>–</span>
                  ) : b.lolos ? (
                    <span className="lencana border-emerald-200 bg-emerald-50 text-emerald-700">✓ tercapai</span>
                  ) : (
                    <span className="lencana border-red-200 bg-red-50 text-red-700">✕ meleset</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr>
              <td className="font-semibold">TOTAL UNIT</td>
              <td className="num font-semibold">
                {rupiahPenuh(hasil.baris.reduce((a, b) => a + b.awal, 0))}
              </td>
              <td className="num font-semibold">{rupiahPenuh(hasil.total)}</td>
              <td className="num font-semibold">{rupiahPenuh(targetSaldo)}</td>
              <td />
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
  );
}

function Geser({
  label,
  nilai,
  ubah,
  dasar,
  catatan,
}: {
  label: string;
  nilai: number;
  ubah: (n: number) => void;
  dasar: number;
  catatan: string;
}) {
  const id = label.replace(/\s+/g, "-").toLowerCase();
  return (
    <div>
      <div className="flex items-baseline justify-between gap-3">
        <label htmlFor={id} className="text-sm font-medium" style={{ color: "var(--ink-2)" }}>
          {label}
        </label>
        <span className="text-lg font-bold tabular-nums" style={{ color: "var(--viz-1)" }}>
          {persen(nilai, 0)}
        </span>
      </div>
      <input
        id={id}
        type="range"
        min={0}
        max={100}
        step={1}
        value={nilai}
        onChange={(e) => ubah(Number(e.target.value))}
        className="mt-2 w-full accent-[var(--viz-1)]"
      />
      <div className="mt-1 flex items-center justify-between text-xs" style={{ color: "var(--ink-muted)" }}>
        <span>{catatan}</span>
        <button
          type="button"
          onClick={() => ubah(Math.round(dasar))}
          className="underline-offset-2 hover:underline"
        >
          kembalikan
        </button>
      </div>
    </div>
  );
}
