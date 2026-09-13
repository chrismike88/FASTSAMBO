import type { ReactNode } from "react";

/**
 * Meter satu nilai terhadap targetnya. Bukan grafik — hanya satu batang —
 * karena yang perlu dibaca cuma "sudah sejauh mana" dan "berapa lagi".
 * Angkanya selalu dicetak sebagai teks, sehingga tetap terbaca tanpa warna.
 */
export function Meter({
  nilai,
  target,
  maks,
  labelNilai,
  labelTarget,
  terbalik = false,
}: {
  nilai: number;
  target: number;
  maks?: number;
  labelNilai: ReactNode;
  labelTarget: ReactNode;
  /** true bila makin kecil makin baik (sisa tunggakan, RST). */
  terbalik?: boolean;
}) {
  const batas = maks ?? Math.max(nilai, target) * 1.12;
  const persenNilai = Math.min(100, (nilai / batas) * 100);
  const persenTarget = Math.min(100, (target / batas) * 100);
  const tercapai = terbalik ? nilai <= target : nilai >= target;

  return (
    <div>
      <div
        className="relative h-6 w-full overflow-hidden rounded-md"
        style={{ background: "var(--surface-2)", border: "1px solid var(--line)" }}
        role="img"
        aria-label={`${labelNilai} terhadap target ${labelTarget}`}
      >
        <div
          className="h-full rounded-md transition-[width]"
          style={{
            width: `${persenNilai}%`,
            background: tercapai ? "var(--st-good)" : "var(--st-critical)",
          }}
        />
        {/* Garis target berdiri di atas batang, bukan warna kedua, supaya
            posisi "cukup" terbaca persis dan tidak tertukar dengan capaian. */}
        <div
          className="absolute inset-y-0 w-0.5"
          style={{ left: `${persenTarget}%`, background: "var(--ink)" }}
          aria-hidden
        />
      </div>
      <div className="mt-1.5 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-0.5 text-xs">
        <span className="font-semibold" style={{ color: "var(--ink)" }}>
          {labelNilai}
        </span>
        <span style={{ color: "var(--ink-muted)" }}>
          garis target: <span className="font-semibold">{labelTarget}</span>
        </span>
      </div>
    </div>
  );
}
