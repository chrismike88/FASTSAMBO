#!/usr/bin/env python3
"""Membandingkan hasil view SQL dengan lib/fallback/dataset.json.

Dashboard membaca dari dua sumber: Supabase bila tersedia, dan berkas contoh
bila belum. Keduanya harus menghasilkan angka yang sama persis — kalau tidak,
tampilan akan berubah diam-diam begitu basis data dipasang.

Dipanggil oleh scripts/uji.sh:

    python3 scripts/uji_konsistensi.py <berkas-ekspor-view.json>
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

AKAR = Path(__file__).resolve().parent.parent
FALLBACK = AKAR / "lib" / "fallback" / "dataset.json"

# Nama bagian -> kolom yang menjadi kunci barisnya
KUNCI = {
    "kpi": ("periode_kode",),
    "rst": ("periode_kode", "petugas_kode"),
    "skor": ("periode_kode", "petugas_kode"),
    "saldo": ("periode_kode", "petugas_kode"),
    "beban": ("periode_kode", "petugas_kode"),
    "target": ("periode_kode", "petugas_kode"),
    "efektivitas": ("segmen",),
    "progres_antar": ("petugas_kode",),
}

TOLERANSI = 0.011  # angka dibulatkan 2 desimal di kedua sisi


def sama(a, b) -> bool:
    if a is None and b is None:
        return True
    if a is None or b is None:
        return False
    try:
        return abs(float(a) - float(b)) <= TOLERANSI
    except (TypeError, ValueError):
        return str(a) == str(b)


def main() -> int:
    dari_sql = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    dari_berkas = json.loads(FALLBACK.read_text(encoding="utf-8"))

    galat: list[str] = []
    diperiksa = 0

    for bagian, kunci in KUNCI.items():
        baris_sql = dari_sql.get(bagian) or []
        baris_berkas = dari_berkas.get(bagian) or []
        peta = {tuple(str(r.get(k)) for k in kunci): r for r in baris_berkas}

        if len(baris_sql) != len(baris_berkas):
            galat.append(f"{bagian}: SQL {len(baris_sql)} baris, berkas {len(baris_berkas)} baris")

        for r in baris_sql:
            k = tuple(str(r.get(x)) for x in kunci)
            pasangan = peta.get(k)
            if pasangan is None:
                galat.append(f"{bagian}[{'/'.join(k)}]: ada di SQL, tidak ada di berkas")
                continue
            for kolom, nilai in r.items():
                if kolom in kunci:
                    continue
                lain = pasangan.get(kolom)
                diperiksa += 1
                if not sama(nilai, lain):
                    galat.append(f"{bagian}[{'/'.join(k)}].{kolom}: SQL={nilai!r} berkas={lain!r}")

    if galat:
        print(f"  ✗ {len(galat)} selisih antara view SQL dan berkas contoh:")
        for g in galat[:25]:
            print(f"      {g}")
        if len(galat) > 25:
            print(f"      … dan {len(galat) - 25} lainnya")
        return 1

    print(f"  ✓ {diperiksa} nilai pada {len(KUNCI)} bagian identik antara SQL dan berkas contoh")
    return 0


if __name__ == "__main__":
    sys.exit(main())
