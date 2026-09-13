import type { Metadata, Viewport } from "next";
import "./globals.css";
import Navigasi from "@/components/Navigasi";
import { getDataset, kpiBerjalan } from "@/lib/data";

export const metadata: Metadata = {
  title: {
    default: "FASTSAMBO — Monitoring Bilman & Cash-In ULP Samboja",
    template: "%s · FASTSAMBO",
  },
  applicationName: "FASTSAMBO",
  description:
    "FASTSAMBO — dashboard monitoring performa petugas bilman, pengantaran invoice TUL 6.01, " +
    "dan percepatan cash-in ULP Samboja: klasemen RST, peta risiko tunggakan, progres " +
    "pengantaran berbukti foto FTO, serta simulasi target akhir bulan.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#0B2E4F" },
    { media: "(prefers-color-scheme: dark)", color: "#0A2135" },
  ],
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const d = await getDataset();
  const berjalan = kpiBerjalan(d);
  return (
    <html lang="id">
      <body className="min-h-screen font-sans antialiased">
        <Navigasi
          unit={d.meta.unit}
          periode={`${berjalan.periode_nama} (per ${berjalan.tanggal_data ?? "–"})`}
          sumber={d.sumber ?? "contoh"}
        />
        <main className="mx-auto w-full max-w-[1500px] px-4 pb-16 pt-6 sm:px-6 lg:px-8">
          {children}
        </main>
        <footer
          className="border-t px-4 py-6 text-center text-xs sm:px-6 lg:px-8"
          style={{ borderColor: "var(--line)", color: "var(--ink-muted)" }}
        >
          {d.meta.unit.nama} · {d.meta.unit.up3} · {d.meta.unit.uid}
          <br className="sm:hidden" />
          <span className="hidden sm:inline"> — </span>
          data {berjalan.periode_nama}, posisi {berjalan.tanggal_data ?? "–"}
        </footer>
      </body>
    </html>
  );
}
