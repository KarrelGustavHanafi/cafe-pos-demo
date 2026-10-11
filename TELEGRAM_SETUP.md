# Telegram Integration Setup Guide

## Overview

CAFFE POS Web mendukung 3 mode integrasi Telegram untuk mengirim notifikasi otomatis:
- **SIMULATION** (Mock) - Mode demo tanpa koneksi Telegram sungguhan
- **DIRECT BOT API** - Koneksi langsung ke Telegram Bot API (untuk testing/sandbox)
- **RELAY WEBHOOK** - Koneksi via Secure Relay Webhook (Cloudflare Worker) untuk production

---

## Mode Integrasi

### 1. SIMULATION (Mock Mode)

**Status Badge:** `SIMULATION` (warna ungu)

**Deskripsi:**
- Mode default untuk demo dan development
- Tidak mengirim pesan ke Telegram
- Simulasi sukses tanpa network call
- Bot token tidak diperlukan

**Konfigurasi:**
- Toggle Telegram: ON
- Bot Username: `@CaffePosBot` (opsional)
- Chat ID: `-1002938472910` (opsional)
- Mode Integrasi: `Simulasi Mock`
- Bot Token: Tidak perlu diisi

**Catatan:**
- Pesan tidak benar-benar dikirim ke Telegram
- UI menampilkan status "SIMULATION"
- Cocok untuk demo tanpa koneksi internet

---

### 2. DIRECT BOT API (Sandbox/Test Mode)

**Status Badge:** `CONNECTED` (hijau) atau `DISCONNECTED` (merah)

**Deskripsi:**
- Koneksi langsung dari Flutter Web ke Telegram Bot API
- Bot token disimpan di browser local storage
- **Hanya untuk testing/sandbox** - tidak disarankan untuk production
- Bot token berpotensi terekspos di browser client

**Prasyarat:**
1. Buat Telegram Bot via [@BotFather](https://t.me/botfather)
2. Dapatkan bot token format: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`
3. Dapatkan Chat ID target (personal atau group)

**Cara Mendapatkan Chat ID:**
- **Personal Chat:** Kirim pesan ke bot, lalu akses `https://api.telegram.org/bot<TOKEN>/getUpdates`
- **Group Chat:** Tambahkan bot ke group, bot harus memiliki permission kirim pesan
- Chat ID group format: `-1001234567890`

**Konfigurasi:**
- Toggle Telegram: ON
- Bot Username: `@YourBotName`
- Chat ID: `-1001234567890` (atau personal chat ID)
- Mode Integrasi: `Direct Bot API (Test Only)`
- Bot Token: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

**CORS Note:**
Flutter Web dapat langsung memanggil Telegram Bot API karena Telegram mendukung CORS untuk public endpoints.

**Pengujian:**
1. Buka Settings → Integrasi → Telegram
2. Pilih mode "Direct Bot API (Test Only)"
3. Isi bot token dan chat ID
4. Klik "Uji Koneksi Telegram"
5. Jika sukses, badge berubah menjadi "CONNECTED"
6. Klik "Kirim Pesan Uji Coba"
7. Cek Telegram - pesan test harus muncul

**Notifikasi yang akan dikirim:**
- ✅ Transaksi berhasil (order paid)
- ✅ Pengurangan stok bahan/material
- ✅ Low stock alert
- ✅ Shift opened
- ✅ Shift closed

**Keamanan:**
⚠️ Bot token disimpan di browser local storage. Jika user clear browser data, konfigurasi hilang. Jangan gunakan token production untuk mode ini.

---

### 3. RELAY WEBHOOK (Production Mode)

**Status Badge:** `CONNECTED` (hijau) atau `DISCONNECTED` (merah)

**Deskripsi:**
- Koneksi via Secure Relay Webhook (Cloudflare Worker atau backend lain)
- Bot token disimpan di server (worker), bukan di browser
- Lebih aman untuk production
- Flutter Web tidak menyimpan token

**Prasyarat:**
1. Deploy Cloudflare Worker atau backend relay
2. Worker harus memiliki endpoint:
   - `POST /telegram/send` - Kirim pesan
   - `POST /telegram/test` - Uji koneksi
3. Worker menyimpan bot token di environment variable
4. Worker memiliki permission CORS untuk domain Flutter Web

**Format Endpoint Relay:**
- Base URL: `https://relay.yourdomain.com`
- Send endpoint: `https://relay.yourdomain.com/telegram/send`
- Test endpoint: `https://relay.yourdomain.com/telegram/test`

**Payload ke Relay:**

**Send Request:**
```json
{
  "chatId": "-1001234567890",
  "message": "🧾 TRANSAKSI BARU\n..."
}
```

**Send Response (Success):**
```json
{
  "ok": true,
  "message": "Laporan sukses diteruskan",
  "messageId": 12345
}
```

**Send Response (Error):**
```json
{
  "ok": false,
  "error": "Telegram API timeout"
}
```

**Test Request:**
```json
{
  "chatId": "-1001234567890"
}
```

**Test Response (Success):**
```json
{
  "ok": true,
  "message": "Koneksi Telegram via Secure Relay berhasil",
  "messageId": 12345
}
```

**Konfigurasi:**
- Toggle Telegram: ON
- Bot Username: `@YourBotName`
- Chat ID: `-1001234567890`
- Mode Integrasi: `Secure Relay Webhook`
- Endpoint Relay Webhook URL: `https://relay.yourdomain.com`
- Bot Token: Tidak perlu diisi (disimpan di worker)

**Pengujian:**
1. Buka Settings → Integrasi → Telegram
2. Pilih mode "Secure Relay Webhook"
3. Isi endpoint relay URL
4. Klik "Uji Koneksi Telegram"
5. Jika relay online dan bot valid, badge "CONNECTED"
6. Klik "Kirim Pesan Uji Coba"
7. Cek Telegram - pesan test harus muncul

**Keamanan:**
✅ Bot token tidak disimpan di browser client
✅ Token disimpan di environment variable worker
✅ Flutter Web hanya mengirim chat ID dan message ke relay

---

## Deploy Cloudflare Worker (Relay Mode)

> Worker yang benar-benar digunakan aplikasi ini sudah ada di `telegram-worker/`.
> Salin `telegram-worker/.dev.vars.example` menjadi `.dev.vars` hanya untuk
> pengembangan lokal. Untuk deployment, selalu pakai **Worker Secrets**.

### 1. Siapkan secret (JANGAN pernah menulis token di wrangler.toml)

```bash
cd telegram-worker
npm install

# Bot token dari @BotFather - akan disimpan oleh Cloudflare, tidak ke disk
npx wrangler secret put TELEGRAM_BOT_TOKEN

# Shared secret client -> worker. Generate nilai acak yang kuat:
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
npx wrangler secret put TELEGRAM_RELAY_SECRET

# Allowlist chat ID Owner (pisahkan dengan koma bila lebih dari satu)
npx wrangler secret put AUTHORIZED_CHAT_IDS
```

> **Jangan pernah** menaruh `TELEGRAM_BOT_TOKEN` di `[vars]` pada
> `wrangler.toml`. Berkas itu **di-commit ke Git**; token di sana bocor ke riwayat
> repository selamanya dan harus dirotasi.

### 2. Deploy

```bash
npx wrangler deploy
```

Sebelum produksi, aktifkan dua pengaman di `telegram-worker/wrangler.toml` agar Worker
tidak dapat diakses lewat subdomain `*.workers.dev`:

```toml
workers_dev = false
routes = [{ pattern = "telegram-relay.yourdomain.com/*", zone_name = "yourdomain.com" }]
```

### 3. Hubungkan Owner di aplikasi

1. Di Telegram, buka `@userinfobot` (atau `@getidsbot`) dan tekan Start.
2. Salin chat ID yang tertera (format `-100...` untuk grup/saluran).
3. Pastikan nilai tersebut sudah terdaftar di `AUTHORIZED_CHAT_IDS` Worker.
4. Di CAFFE POS: Owner > **Pengaturan Kafe** > **Integrasi Telegram**.
5. Pilih mode **Relay Webhook**.
6. Isi **Endpoint Relay Webhook URL** (mis. `https://telegram-relay.yourdomain.com`).
7. Isi **Relay Secret** dengan nilai yang sama seperti `TELEGRAM_RELAY_SECRET`.
8. Isi **Chat ID** dengan chat ID Owner pada langkah 2.
9. Klik **Simpan**, lalu tekan **Uji Koneksi Telegram**.

### 4. Aturan keamanan yang berlaku

| Kontrol | Penjelasan |
|---|---|
| `X-Relay-Secret` | Wajib pada setiap request. Dibandingkan constant-time. |
| `AUTHORIZED_CHAT_IDS` | Chat ID **hanya** boleh salah satu nilai ini. Client tidak bisa memperluasnya. |
| Rate limit | 60 request/menit per caller (best-effort per isolate). |
| Batas ukuran | Body >16 KiB atau pesan >4096 karakter ditolak. |
| `Idempotency-Key` | Header opsional; kunci yang sama tidak mengirim dua kali (best-effort). |
| Error | Balasan generik. Detail internal Telegram tidak pernah dikembalikan. |

> **CORS bukan autentikasi.** Aturan CORS hanya ditegakkan browser dan mudah
> dilewati oleh `curl` atau skrip apa pun. Yang melindungi Worker adalah
> `X-Relay-Secret` + allowlist chat ID.

---

## Notifikasi Otomatis yang Tersedia

### 1. Transaksi Berhasil
Dipicu saat pembayaran berhasil (Order status = paid)
- Order number
- Kasir
- Meja (jika dine-in)
- Items dengan modifiers
- Metode pembayaran
- Total

### 2. Pengurangan Stok
Dipicu bersamaan dengan transaksi berhasil
- Order number
- List bahan/material yang berkurang

### 3. Low Stock Alert
Dipicu saat stok cross threshold (current > min → new <= min)
- Nama item
- Current stock
- Minimum stock
- Unit

### 4. Shift Opened
Dipicu saat shift baru dibuka
- Kasir
- Opening cash
- Waktu

### 5. Shift Closed
Dipicu saat shift ditutup
- Kasir
- Total sales
- Cash / QRIS
- Expected cash
- Actual cash
- Variance
- Notes

---

## Pencegahan Duplikat

Sistem memiliki pencegahan duplikat untuk:
- **Order number** - Setiap order hanya dikirim satu kali
- **Shift ID** - Setiap shift hanya dikirim satu kali
- **Low stock ID** - Setiap item hanya alert sekali sampai di-restock

---

## Error Handling

Kegagalan Telegram **tidak** membatalkan:
- ✅ Pembayaran tetap berhasil
- ✅ Stok tetap berkurang
- ✅ Shift tetap ditutup
- ✅ Transaksi tetap disimpan

Error hanya di-log ke debugPrint dan tidak ditampilkan ke user untuk UX yang seamless.

---

## Troubleshooting

### Direct Bot API - "Koneksi terputus atau timeout"
- Pastikan bot token valid
- Pastikan chat ID benar
- Cek internet connection
- Pastikan bot memiliki permission kirim pesan ke target

### Relay Webhook - "Gagal menghubungi Secure Relay"
- Pastikan worker deployed dan online
- Pastikan URL endpoint benar
- Cek CORS configuration di worker
- Pastikan environment variable TELEGRAM_BOT_TOKEN tersedia

### Pesan tidak muncul di Telegram
- Cek status badge di settings
- Pastikan Telegram enabled (toggle ON)
- Cek log console browser untuk error
- Pastikan bot tidak diblokir oleh Telegram

---

## Rekomendasi Mode

| Use Case | Mode yang Disarankan |
|----------|---------------------|
| Demo lokal tanpa internet | SIMULATION |
| Testing personal / sandbox | DIRECT BOT API |
| Production dengan multiple users | RELAY WEBHOOK |
| Demo dengan pesan nyata | DIRECT BOT API (token test) |

---

## Catatan Penting

⚠️ **JANGAN** commit bot token ke Git
⚠️ **JANGAN** hardcode bot token di source code
⚠️ **JANGAN** gunakan Direct Bot API dengan token production
⚠️ **PASTIKAN** relay worker valid sebelum mode production
⚠️ **HAPUS** config dari browser setelah demo selesai (untuk Direct Bot API)

---

## Support

Untuk bantuan setup Cloudflare Worker atau backend relay, referensi:
- [Cloudflare Workers Documentation](https://developers.cloudflare.com/workers/)
- [Telegram Bot API Documentation](https://core.telegram.org/bots/api)
