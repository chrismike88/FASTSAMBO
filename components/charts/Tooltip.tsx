"use client";

import type { ReactNode } from "react";

export interface BarisTooltip {
  warna: string;
  label: string;
  nilai: ReactNode;
}

export function KotakTooltip({
  judul,
  baris,
  catatan,
}: {
  judul: ReactNode;
  baris: BarisTooltip[];
  catatan?: ReactNode;
}) {
  return (
    <div
      className="rounded-lg border px-3 py-2 text-xs shadow-lg"
      style={{
        background: "var(--surface)",
        borderColor: "var(--line-strong)",
        color: "var(--ink)",
        minWidth: 168,
      }}
    >
      <p className="mb-1.5 font-semibold">{judul}</p>
      <ul className="space-y-1">
        {baris.map((b, i) => (
          <li key={i} className="flex items-center justify-between gap-4">
            <span className="flex items-center gap-1.5" style={{ color: "var(--ink-2)" }}>
              <span
                className="inline-block h-2 w-2 shrink-0 rounded-sm"
                style={{ background: b.warna }}
                aria-hidden
              />
              {b.label}
            </span>
            <span className="font-semibold tabular-nums">{b.nilai}</span>
          </li>
        ))}
      </ul>
      {catatan && (
        <p className="mt-1.5 border-t pt-1.5" style={{ borderColor: "var(--line)", color: "var(--ink-muted)" }}>
          {catatan}
        </p>
      )}
    </div>
  );
}
