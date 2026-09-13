#!/usr/bin/env bash
# ============================================================================
#  Memasang seluruh skema dan data awal FASTSAMBO ke proyek Supabase.
#
#      PGURL='postgresql://postgres.<ref>:<sandi>@<host>:5432/postgres' \
#        bash scripts/pasang_supabase.sh
#
#  PGURL diambil dari Dashboard Supabase > Project Settings > Database >
#  Connection string > URI. Gunakan sandi basis data, BUKAN kunci API.
#
#  Aman dijalankan berulang: migrasi memakai "create ... if not exists" dan
#  seed membersihkan datanya sendiri lebih dulu di dalam satu transaksi.
# ============================================================================
set -euo pipefail

AKAR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${PGURL:-}" ]]; then
  echo "✗ Setel PGURL lebih dulu. Contoh:"
  echo "  PGURL='postgresql://postgres.abcd:sandi@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres' \\"
  echo "    bash scripts/pasang_supabase.sh"
  exit 1
fi

command -v psql >/dev/null || { echo "✗ psql tidak ditemukan. Pasang paket postgresql-client."; exit 1; }

echo "▶ Memeriksa sambungan"
psql "$PGURL" -q -t -A -c "select 'terhubung ke ' || current_database();" || {
  echo "✗ Tidak dapat menyambung. Periksa PGURL dan izin jaringan proyek Supabase."
  exit 1
}

for f in "$AKAR"/supabase/migrations/*.sql; do
  echo "▶ $(basename "$f")"
  PGOPTIONS='-c client_min_messages=warning' \
    psql "$PGURL" -q -v ON_ERROR_STOP=1 -f "$f"
done

echo "▶ Memeriksa hasil"
psql "$PGURL" -q -c "
  select periode_kode, sisa_nilai::bigint as sisa, beban_bilman::bigint as beban,
         rst_unit, gap_penurunan::bigint as gap
    from bilman.v_kpi_unit order by periode_kode;"

echo ""
echo "✓ Selesai. Langkah berikutnya:"
echo "  1. Salin Project URL dan anon key ke variabel lingkungan Vercel"
echo "     (NEXT_PUBLIC_SUPABASE_URL dan NEXT_PUBLIC_SUPABASE_ANON_KEY)"
echo "  2. Deploy ulang. Lencana di pojok kanan atas akan berubah"
echo "     dari 'Data bawaan' menjadi 'Supabase'."
