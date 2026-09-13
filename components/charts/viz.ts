"use client";

import { useEffect, useState } from "react";

export interface WarnaViz {
  seri: [string, string, string];
  kisi: string;
  sumbu: string;
  redup: string;
  permukaan: string;
  tinta: string;
  tinta2: string;
  seq: string[];
}

const BAWAAN: WarnaViz = {
  seri: ["#2a78d6", "#eb6834", "#1baf7a"],
  kisi: "#E1E0D9",
  sumbu: "#C3C2B7",
  redup: "#898781",
  permukaan: "#FFFFFF",
  tinta: "#0B1F33",
  tinta2: "#475569",
  seq: ["#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#104281"],
};

/** Membaca token warna dari CSS agar grafik ikut berubah saat tema diganti. */
export function useWarnaViz(): WarnaViz {
  const [warna, setWarna] = useState<WarnaViz>(BAWAAN);

  useEffect(() => {
    const baca = () => {
      const g = getComputedStyle(document.documentElement);
      const v = (n: string, f: string) => g.getPropertyValue(n).trim() || f;
      setWarna({
        seri: [v("--viz-1", BAWAAN.seri[0]), v("--viz-2", BAWAAN.seri[1]), v("--viz-3", BAWAAN.seri[2])],
        kisi: v("--viz-grid", BAWAAN.kisi),
        sumbu: v("--viz-axis", BAWAAN.sumbu),
        redup: v("--viz-muted", BAWAAN.redup),
        permukaan: v("--surface", BAWAAN.permukaan),
        tinta: v("--ink", BAWAAN.tinta),
        tinta2: v("--ink-2", BAWAAN.tinta2),
        seq: [1, 2, 3, 4, 5, 6].map((i) => v(`--seq-${i}`, BAWAAN.seq[i - 1])),
      });
    };
    baca();
    const mo = new MutationObserver(baca);
    mo.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    mq.addEventListener("change", baca);
    return () => {
      mo.disconnect();
      mq.removeEventListener("change", baca);
    };
  }, []);

  return warna;
}

export const gayaSumbu = (w: WarnaViz) => ({
  tick: { fill: w.redup, fontSize: 11 },
  axisLine: { stroke: w.sumbu },
  tickLine: false as const,
});
