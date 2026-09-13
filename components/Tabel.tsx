import type { ReactNode } from "react";

export interface Kolom<T> {
  kunci: string;
  judul: string;
  /** Perataan kanan untuk angka. */
  num?: boolean;
  lebar?: string;
  render: (baris: T) => ReactNode;
}

export function Tabel<T>({
  kolom,
  data,
  kunciBaris,
  tinggiMaks,
  kaki,
}: {
  kolom: Kolom<T>[];
  data: T[];
  kunciBaris: (baris: T, i: number) => string;
  tinggiMaks?: string;
  kaki?: ReactNode;
}) {
  return (
    <div className="gulir-x rounded-lg border" style={{ borderColor: "var(--line)", maxHeight: tinggiMaks }}>
      <table className="tabel">
        <thead>
          <tr>
            {kolom.map((k) => (
              <th key={k.kunci} className={k.num ? "num" : undefined} style={{ width: k.lebar }}>
                {k.judul}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.map((baris, i) => (
            <tr key={kunciBaris(baris, i)}>
              {kolom.map((k) => (
                <td key={k.kunci} className={k.num ? "num" : undefined}>
                  {k.render(baris)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
        {kaki}
      </table>
    </div>
  );
}

/** Pasangan tabel untuk sebuah grafik — setiap nilai tetap terbaca tanpa warna. */
export function TabelPendamping({
  ringkasan = "Lihat angkanya dalam tabel",
  children,
}: {
  ringkasan?: string;
  children: ReactNode;
}) {
  return (
    <details className="mt-3 group">
      <summary
        className="cursor-pointer select-none text-xs font-medium underline-offset-2 hover:underline"
        style={{ color: "var(--ink-2)" }}
      >
        {ringkasan}
      </summary>
      <div className="mt-2">{children}</div>
    </details>
  );
}
