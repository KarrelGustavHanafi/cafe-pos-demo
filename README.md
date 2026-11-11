# CAFFE POS

> Sistem Kasir & Manajemen Kafe Modern (Point of Sale) untuk bisnis F&B Indonesia.

---

## 1. Ikhtisar Produk

CAFFE POS adalah sistem kasir dan manajemen operasional kafe terpadu yang dirancang dengan antarmuka cepat, touch-friendly, dan responsif (desktop, tablet, mobile web). Sistem ini memisahkan operasional harian kasir dari modul manajerial pemilik ke dalam dua peran utama:

- **Role CASHIER**: Pemesanan cepat, manajemen nomor meja visual, kalkulasi keranjang otomatis, pembayaran Tunai & simulasi QRIS, validasi shift, serta cetak struk (preview/browser).
- **Role OWNER**: Dashboard analitik real-time, manajemen menu & resep berjenjang (multi-tier recipe), pelacakan inventaris bahan baku (FIFO/deduction), riwayat shift, rekonsiliasi kas, dan pengaturan bisnis.

---

## 2. Struktur Monorepo Proyek

| Folder / Modul | Deskripsi | Status |
|---|---|---|
| `lib/` | Aplikasi utama Flutter (Web, Desktop, Mobile) | Aktif (72 file, ~22k LOC, 31 file test) |
| `api-worker/` | Cloudflare Workers API backend (TypeScript) | Terverifikasi via Vitest (76 tests pass) |
| `telegram-worker/` | Cloudflare Workers relay untuk notifikasi transaksi ke Telegram Bot | Tracked, 2 route endpoints |
| `promo/` | Remotion (React + TypeScript) generator video promosi 9:16 & 16:9 | Aktif (output MP4 via ffmpeg/Chromium) |
| `docs/` | Dokumentasi audit, diagram spesifikasi, dan master roadmap | Lengkap (docs/feature-audit & docs/architecture) |

---

## 3. Quick Start

### Frontend (Flutter App)
```bash
# Pastikan Flutter SDK ^3.13.3 terpasang
flutter pub get

# Jalankan aplikasi (mode Chrome Web)
flutter run -d chrome

# Jalankan unit & widget test
flutter test
```

### Backend Workers (`api-worker/` & `telegram-worker/`)
```bash
cd api-worker
npm install
npm run typecheck
npm test

# Jalankan lokal dev server
npm run dev
```

### Promo Video Generator (`promo/`)
```bash
cd promo
npm install
npm run build
npm run render:landscape
```

---

## 4. Status Kesiapan Sistem

- **Demo & Presentasi**: **LAYAK**. Alur kasir, kalkulasi keranjang, inventaris bahan baku, dan navigasi multi-viewport terverifikasi berjalan tanpa runtime exception.
- **Produksi**: **BELUM LAYAK**. Autentikasi dan otorisasi masih berskala client-side simulasi; sinkronisasi ke backend database permanen (PostgreSQL/D1) masih dalam tahap integrasi roadmap.

---

## 5. Dokumentasi Terkait

- [PRD.md](PRD.md) — Product Requirements Document & spesifikasi fitur.
- [TECHSTACK.md](TECHSTACK.md) — Arsitektur teknologi dan dependensi.
- [STYLEGUIDE.md](STYLEGUIDE.md) — Konvensi kode, arsitektur folder, dan design tokens.
- [SECURITY.md](SECURITY.md) — Analisis risiko keamanan, threat model, dan pedoman.
- [TASK.md](TASK.md) — Actionable checklist dan prioritas roadmap pengembangan.
- [SKILLS.md](SKILLS.md) — Standard operating procedure dan keahlian teknis pemeliharaan.

