# FASTSAMBO

**Monitoring Performa Bilman, Pengantaran TUL 6.01 & Percepatan Cash-In — ULP Samboja**

Dashboard web untuk memantau kinerja sepuluh petugas bilman ULP Samboja
(UP3 Balikpapan, UID Kalimantan Timur & Kalimantan Utara), melacak pengantaran
invoice TUL 6.01 sampai ke bukti foto FTO, dan mengejar target sisa tunggakan
akhir bulan.

| Lapisan | Teknologi | Berkas |
|---|---|---|
| **Front end** | Next.js 15 (App Router), React 19, Tailwind, Recharts | `app/`, `components/` |
| **Back end / API** | Supabase (PostgreSQL 15+), PostgREST, RPC | `supabase/migrations/` |
| **Basis data** | Skema `bilman` — 21 tabel, 10 view analitik, RLS penuh | [`docs/ERD.md`](docs/ERD.md) |
| **Sumber data** | Lima belas berkas CSV yang bisa disunting di Excel | `data/master/` |

---

## Mulai cepat

```bash
npm install
npm run data      # bangun dataset & seed SQL dari data/master/*.csv
npm run dev       # http://localhost:3000
```

Dashboard **langsung berjalan tanpa Supabase**. Bila variabel lingkungan belum
diisi, angkanya dibaca dari `lib/fallback/dataset.json` yang dibangun dari
`data/master/*.csv`. Lencana di pojok kanan atas menunjukkan sumber yang sedang
dipakai: *Data bawaan* atau *Supabase*.

---

## Isi dashboard

| Halaman | Menjawab |
|---|---|
| **Ringkasan** | Berapa sisa tunggakan, seberapa jauh dari target, dan di mana masalahnya terkonsentrasi |
| **Kinerja Petugas** | Klasemen RST dan skor lima komponen — bukan klasemen rupiah |
| **Tunggakan & Risiko** | Siapa memegang pelanggan 2 dan 3 lembar, serta tiga jalur tagihan ULP |
| **Pengantaran TUL 6.01** | Progres antar per petugas, daftar prioritas, dan aturan bukti lapangan |
| **Percepatan Cash-In** | Target individual, lima aksi berdampak tertinggi, kalender, hambatan |
| **Simulasi Target** | Dengan tingkat penagihan sekian, saldo akhir bulan mendarat di mana |

### Dua hal yang sengaja dibedakan

**Beban bukan prestasi.** Beban tagihan tiap petugas berselisih sampai 1,9 kali
(Rp186 juta sampai Rp349 juta). Memberi label “Kinerja Terbaik” atau “Perlu
Evaluasi” pada grafik beban membuat petugas berwilayah terluas terbaca paling
buruk — padahal justru sebaliknya. Karena itu klasemen di sini memakai **RST
(Rasio Sisa Tunggakan) = sisa ÷ beban**, dan grafik beban diberi judul tegas
sebagai beban kerja.

**Belum diketahui bukan nol.** Periode yang saldonya belum ditutup tampil
sebagai “–”, bukan angka nol; komponen skor yang datanya belum ada dikeluarkan
dari perhitungan dan bobotnya dinormalisasi ulang. Tanpa itu, petugas akan
terlihat bernilai nol hanya karena bulan berjalan belum sampai tanggal
pengantaran.

---

## Data

Seluruh angka masukan ada di **`data/master/`** sebagai CSV biasa yang bisa
dibuka dengan Excel. Satu perintah membangun ulang semua keluaran:

```bash
python3 scripts/build_all.py
```

menghasilkan dua berkas yang dijamin selalu sinkron:

- `lib/fallback/dataset.json` — yang dibaca dashboard bila Supabase belum ada
- `supabase/migrations/20260913000003_seed.sql` — data awal untuk Supabase

> **Sumber angka:** Rekap Saldo Tunggakan ULP Samboja per 31 Agustus 2026 dan
> per 11 September 2026 ([`docs/analisa-bilman-agt-sep-2026.md`](docs/analisa-bilman-agt-sep-2026.md)).
>
> **Yang masih berupa kerangka:** data sumber hanya memuat agregat per petugas,
> bukan rincian per pelanggan. Karena itu 175 baris pengantaran memakai IDPEL
> berawalan `SLOT-`: **jumlah baris per petugas sudah sesuai jumlah pelanggan
> 2 dan 3 lembar yang sebenarnya**, tetapi nomor pelanggan, nama, alamat, dan
> nilai per lembar menunggu penarikan dari AP2T. Rekening AMR (71) dan lembar
> #N/A (29) tersimpan sebagai agregat per segmen, bukan per rekening.

### Satu koreksi terhadap data sumber

Saat data dimasukkan, penjumlahan per petugas tidak cocok dengan baris subtotal
pada materi sumber:

| | Subtotal materi | Penjumlahan per petugas | Selisih |
|---|---:|---:|---:|
| Pelanggan 2 lembar | 137 lembar | **136 lembar** | 1 lembar |
| Nilai 2 lembar | Rp72.691.919 | **Rp71.452.860** | Rp1.239.059 |

Selisihnya persis sama dengan lembar 2 pada baris #N/A (Rp1.239.059) — subtotal
bilman ikut menghitung satu lembar yang justru belum punya penanggung jawab.
Dashboard memakai angka hasil penjumlahan per petugas, dan temuan ini tercatat
sebagai catatan perbaikan nomor 6 pada halaman Percepatan Cash-In. Akibat
praktisnya: pelanggan berisiko yang benar-benar punya petugas ada **175**, bukan
176; satu sisanya baru bisa ditagih setelah pembersihan #N/A selesai.

---

## Memasang basis data ke Supabase

```bash
PGURL='postgresql://postgres.<ref>:<sandi>@<host>:5432/postgres' \
  bash scripts/pasang_supabase.sh
```

`PGURL` diambil dari **Dashboard Supabase → Project Settings → Database →
Connection string → URI** (pakai sandi basis data, bukan kunci API). Skrip
menjalankan keempat migrasi berurutan lalu menampilkan ringkasan KPI sebagai
pemeriksaan. Aman dijalankan berulang.

Setelah itu, isi variabel lingkungan (lihat `.env.example`) dengan **Project
URL** dan **anon key**, lalu deploy ulang. Tidak perlu mengubah setelan
*Exposed schemas*: view pembungkus `public.fs_*` sudah menyediakan jalurnya.

### Model keamanan

- Dashboard bersifat **baca-publik**: isinya angka kinerja unit dan agregat
  tagihan, sehingga situs dapat dibuka tanpa login. Untuk menguncinya, ganti
  `to anon, authenticated` menjadi `to authenticated` pada bagian D migrasi 003.
- **Riwayat pembayaran dan log audit** tidak terbaca pengunjung anonim — hak
  bacanya dicabut di tingkat tabel, bukan hanya disaring RLS.
- **Petugas bilman** hanya dapat mencatat pengantaran di wilayah kerjanya
  sendiri, dan tidak dapat memindahkan lembar ke petugas lain.
- **Bobot penilaian kinerja** hanya dapat diubah ADMIN/MANAJER — mengubahnya
  berarti mengubah cara orang dinilai.
- **Tidak seorang pun dapat menaikkan perannya sendiri.**
- Sebuah lembar **tidak dapat berstatus terantar tanpa foto FTO** — ditegakkan
  `check constraint`, bukan sekadar validasi di aplikasi.

---

## Hosting di Vercel

1. Import repositori ini di Vercel (framework terdeteksi otomatis: Next.js).
2. Isi dua variabel lingkungan dari `.env.example` — atau lewati dulu, situs
   tetap tampil memakai data bawaan.
3. Deploy. `vercel.json` sudah menyetel region `sin1` (Singapura, terdekat dari
   Kalimantan Timur) dan header keamanan dasar.

---

## Uji

```bash
npm run uji     # atau: bash scripts/uji.sh
```

Menjalankan PostgreSQL sementara, memasang keempat migrasi, lalu membuktikan
dua hal:

1. **Konsistensi** — setiap nilai pada view SQL identik dengan
   `lib/fallback/dataset.json`, sehingga tampilan tidak berubah diam-diam saat
   sumber datanya berpindah dari berkas ke basis data.
2. **Keamanan** — 30 perilaku Row Level Security diperiksa satu per satu untuk
   lima peran.

Ujinya membedakan penolakan yang benar-benar terjadi dari penolakan semu: RLS
menyaring baris **tanpa menimbulkan galat**, sehingga `update` yang diblokir
tetap “berhasil” dengan nol baris. Uji di sini memeriksa jumlah baris yang
tersentuh, bukan sekadar apakah perintahnya gagal.

---

## Struktur

```
app/                    halaman dashboard (Server Components)
components/             kartu, tabel, grafik, simulator
lib/
  data.ts               baca Supabase, jatuh ke data bawaan bila gagal
  types.ts              bentuk data yang dipakai seluruh dashboard
  format.ts             pemformatan angka gaya Indonesia
  fallback/dataset.json dibangkitkan — jangan disunting langsung
data/master/*.csv       SUMBER SEBENARNYA — sunting di sini
scripts/
  build_all.py          CSV  →  dataset.json + seed.sql
  uji.sh                migrasi + uji konsistensi + uji RLS
  pasang_supabase.sh    pasang skema & data ke proyek Supabase
supabase/
  migrations/           skema, view analitik, RLS & API, seed
  tests/                tiruan auth Supabase, uji RLS, ekspor view
docs/ERD.md             peta relasi & alasan bentuk basis datanya
```
