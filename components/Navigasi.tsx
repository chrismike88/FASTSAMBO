"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

const TAUTAN = [
  { href: "/", label: "Ringkasan" },
  { href: "/petugas", label: "Kinerja Petugas" },
  { href: "/tunggakan", label: "Tunggakan & Risiko" },
  { href: "/pengantaran", label: "Pengantaran TUL 6.01" },
  { href: "/cash-in", label: "Percepatan Cash-In" },
  { href: "/simulasi", label: "Simulasi Target" },
];

export default function Navigasi({
  unit,
  periode,
  sumber,
}: {
  unit: { nama: string; up3: string; kode: string };
  periode: string;
  sumber: "supabase" | "contoh";
}) {
  const path = usePathname();
  const [tema, setTema] = useState<"terang" | "gelap" | null>(null);

  useEffect(() => {
    const simpan = window.localStorage.getItem("tema-fastsambo");
    if (simpan === "terang" || simpan === "gelap") {
      setTema(simpan);
      document.documentElement.dataset.theme = simpan === "gelap" ? "dark" : "light";
    }
  }, []);

  function gantiTema() {
    const baru = (document.documentElement.dataset.theme === "dark" ? "terang" : "gelap") as
      | "terang"
      | "gelap";
    setTema(baru);
    document.documentElement.dataset.theme = baru === "gelap" ? "dark" : "light";
    try {
      window.localStorage.setItem("tema-fastsambo", baru);
    } catch {
      /* penyimpanan diblokir — abaikan, tema tetap berlaku untuk sesi ini */
    }
  }

  return (
    <header style={{ background: "var(--brand)", color: "var(--on-brand)" }}>
      <div className="mx-auto flex w-full max-w-[1500px] flex-wrap items-center gap-x-6 gap-y-3 px-4 py-3 sm:px-6 lg:px-8">
        <div className="flex min-w-0 items-center gap-3">
          <span
            className="grid h-9 w-9 shrink-0 place-items-center rounded-lg text-sm font-bold"
            style={{ background: "var(--viz-1)" }}
            aria-hidden
          >
            FS
          </span>
          <div className="min-w-0">
            <p className="truncate text-sm font-bold leading-tight tracking-wide">
              FASTSAMBO
              <span className="ml-2 text-xs font-normal opacity-60">
                Monitoring Bilman &amp; Cash-In
              </span>
            </p>
            <p className="truncate text-xs leading-tight opacity-70">
              {unit.nama} · {unit.up3} · data {periode}
            </p>
          </div>
        </div>

        <nav className="order-3 -mx-1 flex w-full gap-1 overflow-x-auto pb-1 lg:order-2 lg:mx-0 lg:w-auto lg:flex-1 lg:overflow-visible lg:pb-0">
          {TAUTAN.map((t) => {
            const aktif = t.href === "/" ? path === "/" : path.startsWith(t.href);
            return (
              <Link
                key={t.href}
                href={t.href}
                aria-current={aktif ? "page" : undefined}
                className={`whitespace-nowrap rounded-lg px-3 py-1.5 text-[0.8125rem] font-medium transition ${
                  aktif ? "bg-white/15 text-white" : "text-white/70 hover:bg-white/10 hover:text-white"
                }`}
              >
                {t.label}
              </Link>
            );
          })}
        </nav>

        <div className="order-2 ml-auto flex items-center gap-2 lg:order-3">
          <span
            className="hidden rounded-md px-2 py-1 text-[0.68rem] font-semibold sm:inline"
            style={{
              background: sumber === "supabase" ? "rgba(12,163,12,.18)" : "rgba(250,178,25,.18)",
              color: sumber === "supabase" ? "#7BE87B" : "#FFD98A",
            }}
            title={
              sumber === "supabase"
                ? "Angka dibaca langsung dari basis data Supabase"
                : "Supabase belum disetel — dashboard menampilkan data bawaan dari data/master/*.csv"
            }
          >
            {sumber === "supabase" ? "● Supabase" : "● Data bawaan"}
          </span>
          <button
            type="button"
            onClick={gantiTema}
            className="rounded-lg px-2.5 py-1.5 text-xs font-medium text-white/80 transition hover:bg-white/10 hover:text-white"
            aria-label="Ganti tema terang/gelap"
          >
            {tema === "gelap" ? "☀ Terang" : "☾ Gelap"}
          </button>
        </div>
      </div>
    </header>
  );
}
