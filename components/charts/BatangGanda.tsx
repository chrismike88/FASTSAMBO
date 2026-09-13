"use client";

import {
  Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from "recharts";
import { pakaiFormat, type FormatNama } from "@/lib/format";
import { useWarnaViz, gayaSumbu } from "./viz";
import { KotakTooltip } from "./Tooltip";

export interface BarisGanda {
  label: string;
  a: number;
  b: number;
}

/**
 * Dua seri berdampingan pada SATU sumbu — keduanya harus dalam satuan yang
 * sama (di sini sama-sama Rupiah). Perbandingan dua besaran berbeda satuan
 * tidak pernah digambar dengan dua sumbu-y; pisahkan jadi dua grafik.
 */
export default function BatangGanda({
  data,
  namaA,
  namaB,
  format,
  tinggi = 320,
}: {
  data: BarisGanda[];
  namaA: string;
  namaB: string;
  format: FormatNama;
  tinggi?: number;
}) {
  const w = useWarnaViz();
  const gaya = gayaSumbu(w);
  const f = pakaiFormat(format);

  return (
    <div className="gulir-x">
      <div style={{ minWidth: Math.max(420, data.length * 62), height: tinggi }}>
        <ResponsiveContainer>
          <BarChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: 4 }} barGap={2}>
            <CartesianGrid stroke={w.kisi} vertical={false} />
            <XAxis dataKey="label" {...gaya} tick={{ fill: w.tinta2, fontSize: 11 }} interval={0} />
            <YAxis {...gaya} tickFormatter={(v) => f(Number(v))} width={64} />
            <Tooltip
              cursor={{ fill: w.kisi, fillOpacity: 0.45 }}
              content={({ active, payload, label }) => {
                if (!active || !payload?.length) return null;
                const d = payload[0].payload as BarisGanda;
                return (
                  <KotakTooltip
                    judul={String(label)}
                    baris={[
                      { warna: w.seri[0], label: namaA, nilai: f(d.a) },
                      { warna: w.seri[1], label: namaB, nilai: f(d.b) },
                    ]}
                  />
                );
              }}
            />
            <Legend
              wrapperStyle={{ fontSize: 12, color: w.tinta2, paddingTop: 4 }}
              iconType="square"
              iconSize={9}
            />
            <Bar dataKey="a" name={namaA} fill={w.seri[0]} radius={[4, 4, 0, 0]} isAnimationActive={false} />
            <Bar dataKey="b" name={namaB} fill={w.seri[1]} radius={[4, 4, 0, 0]} isAnimationActive={false} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
