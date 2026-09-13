import type { ReactNode } from "react";

export interface BagianKomposisi {
  label: string;
  nilai: number;
  persen: number | null;
  warna: string;
  keterangan?: ReactNode;
}

/**
 * Satu batang bertumpuk 100% — untuk pertanyaan "dari seluruh tagihan, berapa
 * bagian tiap jalur". Dibuat dengan HTML biasa, bukan pustaka grafik: bentuknya
 * sederhana, dan tiap segmen bisa diberi celah 2px agar batasnya tegas.
 */
export function KomposisiJalur({ bagian }: { bagian: BagianKomposisi[] }) {
  const total = bagian.reduce((a, b) => a + b.nilai, 0);
  return (
    <div>
      <div className="flex h-8 w-full gap-0.5 overflow-hidden rounded-md">
        {bagian.map((b) => (
          <div
            key={b.label}
            className="h-full first:rounded-l-md last:rounded-r-md"
            style={{ width: `${(b.nilai / total) * 100}%`, background: b.warna, minWidth: 3 }}
            title={`${b.label}: ${b.persen ?? 0}%`}
          />
        ))}
      </div>
      <ul className="mt-3 grid gap-2 sm:grid-cols-3">
        {bagian.map((b) => (
          <li key={b.label} className="min-w-0">
            <p className="flex items-center gap-1.5 text-xs font-semibold" style={{ color: "var(--ink-2)" }}>
              <span
                className="inline-block h-2.5 w-2.5 shrink-0 rounded-sm"
                style={{ background: b.warna }}
                aria-hidden
              />
              <span className="truncate">{b.label}</span>
            </p>
            <p className="mt-0.5 text-sm font-bold tabular-nums" style={{ color: "var(--ink)" }}>
              {b.persen ?? "–"}%
            </p>
            {b.keterangan && (
              <p className="mt-0.5 text-xs leading-snug" style={{ color: "var(--ink-muted)" }}>
                {b.keterangan}
              </p>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
