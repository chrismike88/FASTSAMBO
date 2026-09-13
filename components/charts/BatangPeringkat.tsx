"use client";

import {
  Bar, BarChart, Cell, LabelList,
  ResponsiveContainer, Tooltip, XAxis, YAxis,
} from "recharts";
import { pakaiFormat, type FormatNama } from "@/lib/format";
import { useWarnaViz, gayaSumbu } from "./viz";
import { KotakTooltip } from "./Tooltip";

export interface BarisBatang {
  label: string;
  nilai: number;
  kelompok?: string;
  keterangan?: string;
}

/**
 * Batang horizontal terurut. Label nilai dicetak langsung di ujung batang
 * sehingga sumbu numerik tidak diperlukan (dan tidak ditampilkan).
 */
export default function BatangPeringkat({
  data,
  format,
  kelompokWarna,
  warnaKelompok,
  labelKelompok,
  tinggiBaris = 30,
  lebarLabel = 190,
}: {
  data: BarisBatang[];
  format: FormatNama;
  /** Peta kelompok -> indeks slot warna (0..2). Bila kosong, satu warna untuk semua. */
  kelompokWarna?: Record<string, number>;
  /** Warna eksplisit per kelompok, untuk palet status (baik/waspada/kritis)
   *  yang bukan bagian dari tiga slot warna kategorikal. */
  warnaKelompok?: Record<string, string>;
  /** Label legenda yang lebih enak dibaca daripada kode kelompoknya. */
  labelKelompok?: Record<string, string>;
  tinggiBaris?: number;
  lebarLabel?: number;
}) {
  const w = useWarnaViz();
  const gaya = gayaSumbu(w);
  const formatNilai = pakaiFormat(format);
  const kelompok = warnaKelompok
    ? Object.keys(warnaKelompok)
    : kelompokWarna
      ? Object.keys(kelompokWarna)
      : [];
  const warnaUntuk = (k?: string) =>
    (k && warnaKelompok?.[k]) ?? w.seri[(k && kelompokWarna ? kelompokWarna[k] : 0) ?? 0];
  const tinggi = Math.max(150, data.length * tinggiBaris + 16);
  const maks = Math.max(...data.map((d) => d.nilai));

  return (
    <div>
      {kelompok.length > 1 && (
        <ul className="mb-2 flex flex-wrap gap-x-4 gap-y-1 text-xs" style={{ color: "var(--ink-2)" }}>
          {kelompok.map((kk) => (
            <li key={kk} className="flex items-center gap-1.5">
              <span
                className="inline-block h-2.5 w-2.5 rounded-sm"
                style={{ background: warnaUntuk(kk) }}
                aria-hidden
              />
              {labelKelompok?.[kk] ?? kk}
            </li>
          ))}
        </ul>
      )}
      <div className="gulir-x">
        <div style={{ minWidth: lebarLabel + 300, height: tinggi }}>
      <ResponsiveContainer>
        <BarChart
          data={data}
          layout="vertical"
          margin={{ top: 4, right: 78, bottom: 0, left: 4 }}
          barCategoryGap="22%"
        >
          <XAxis type="number" hide domain={[0, maks * 1.12]} />
          <YAxis
            type="category"
            dataKey="label"
            width={lebarLabel}
            interval={0}
            {...gaya}
            tick={{ fill: w.tinta2, fontSize: 11 }}
          />
          <Tooltip
            cursor={{ fill: w.kisi, fillOpacity: 0.45 }}
            content={({ active, payload }) => {
              if (!active || !payload?.length) return null;
              const d = payload[0].payload as BarisBatang;
              return (
                <KotakTooltip
                  judul={d.label}
                  baris={[{
                    warna: warnaUntuk(d.kelompok),
                    label: (d.kelompok && labelKelompok?.[d.kelompok]) ?? d.kelompok ?? "Nilai",
                    nilai: formatNilai(d.nilai),
                  }]}
                  catatan={d.keterangan}
                />
              );
            }}
          />
          <Bar dataKey="nilai" radius={[0, 4, 4, 0]} isAnimationActive={false}>
            {data.map((d, i) => (
              <Cell key={i} fill={warnaUntuk(d.kelompok)} />
            ))}
            <LabelList
              dataKey="nilai"
              position="right"
              formatter={(v: unknown) => formatNilai(Number(v))}
              style={{ fill: w.tinta2, fontSize: 11, fontWeight: 600 }}
            />
          </Bar>
        </BarChart>
      </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}
