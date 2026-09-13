import type { ReactNode } from "react";
import { KATEGORI_RST, STATUS_ANTAR, STATUS_AKSI, WARNA_PRIORITAS } from "@/lib/format";

export function Kartu({
  judul,
  keterangan,
  aksi,
  children,
  className = "",
}: {
  judul?: string;
  keterangan?: ReactNode;
  aksi?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`kartu p-4 sm:p-5 ${className}`}>
      {(judul || aksi) && (
        <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            {judul && (
              <h2 className="text-[0.95rem] font-semibold" style={{ color: "var(--ink)" }}>
                {judul}
              </h2>
            )}
            {keterangan && (
              <p className="mt-0.5 text-xs leading-relaxed" style={{ color: "var(--ink-muted)" }}>
                {keterangan}
              </p>
            )}
          </div>
          {aksi}
        </div>
      )}
      {children}
    </section>
  );
}

export function Petak({
  label,
  nilai,
  satuan,
  catatan,
  nada = "netral",
}: {
  label: string;
  nilai: string;
  satuan?: string;
  catatan?: ReactNode;
  nada?: "netral" | "baik" | "peringatan" | "buruk" | "sorot";
}) {
  const warna: Record<string, string> = {
    netral: "var(--ink)",
    baik: "var(--st-good)",
    peringatan: "var(--st-warning)",
    buruk: "var(--st-critical)",
    sorot: "var(--viz-1)",
  };
  return (
    <div className="kartu flex flex-col justify-between p-4">
      <p className="kartu-judul">{label}</p>
      <p className="angka-hero mt-2" style={{ color: warna[nada] }}>
        {nilai}
        {satuan && (
          <span className="ml-1 text-base font-semibold" style={{ color: "var(--ink-2)" }}>
            {satuan}
          </span>
        )}
      </p>
      {catatan && (
        <p className="mt-2 text-xs leading-snug" style={{ color: "var(--ink-muted)" }}>
          {catatan}
        </p>
      )}
    </div>
  );
}

const IKON_RST: Record<string, string> = {
  SANGAT_BAIK: "✓",
  CUKUP: "◐",
  PERLU_EVALUASI: "▲",
  PERLU_ATENSI: "✕",
  "N/A": "–",
};

/** Lencana kategori RST: warna SELALU disertai ikon dan teks, tidak pernah
 *  warna saja — agar tetap terbaca saat dicetak hitam-putih atau oleh pembaca
 *  yang sulit membedakan warna. */
export function LencanaRst({ kategori }: { kategori: string }) {
  const k = KATEGORI_RST[kategori] ?? KATEGORI_RST["N/A"];
  return (
    <span className={`lencana ${k.latar} ${k.teks} ${k.garis}`}>
      <span aria-hidden>{IKON_RST[kategori] ?? "–"}</span>
      {k.label}
    </span>
  );
}

export function LencanaAntar({ status }: { status: string }) {
  const s = STATUS_ANTAR[status] ?? STATUS_ANTAR.BELUM_DIANTAR;
  return <span className={`lencana ${s.latar} ${s.teks} ${s.garis}`}>{s.label}</span>;
}

export function LencanaAksi({ status }: { status: string }) {
  const s = STATUS_AKSI[status] ?? STATUS_AKSI.RENCANA;
  return <span className={`lencana ${s.latar} ${s.teks} ${s.garis}`}>{s.label}</span>;
}

export function LencanaPrioritas({ prioritas }: { prioritas: string }) {
  return (
    <span className={`lencana ${WARNA_PRIORITAS[prioritas] ?? WARNA_PRIORITAS.RUTIN}`}>
      {prioritas}
    </span>
  );
}

export function JudulHalaman({
  judul,
  keterangan,
}: {
  judul: string;
  keterangan?: ReactNode;
}) {
  return (
    <div className="mb-5">
      <h1 className="text-xl font-bold tracking-tight sm:text-2xl" style={{ color: "var(--ink)" }}>
        {judul}
      </h1>
      {keterangan && (
        <p className="mt-1 max-w-3xl text-sm leading-relaxed" style={{ color: "var(--ink-2)" }}>
          {keterangan}
        </p>
      )}
    </div>
  );
}

export function Catatan({ children, nada = "netral" }: { children: ReactNode; nada?: "netral" | "perhatian" }) {
  return (
    <p
      className="rounded-lg border px-3 py-2 text-xs leading-relaxed"
      style={{
        borderColor: nada === "perhatian" ? "var(--st-warning)" : "var(--line)",
        background: "var(--surface-2)",
        color: "var(--ink-2)",
      }}
    >
      {children}
    </p>
  );
}

/** Pemisah kecil untuk memberi napas antar blok dalam satu kartu. */
export function Baris({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`grid gap-4 ${className}`}>{children}</div>;
}
