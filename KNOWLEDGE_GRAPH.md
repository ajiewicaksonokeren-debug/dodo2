# Knowledge Graph — Pick'em Playoff MPL ID S18

> Edit inkremental, jangan generate ulang. Sumber: PRD Pick'em Playoff MPL ID S18 (21 Okt 2026). Token visual: Clipper DS v2 (tanpa logo Clipper).

Last verified: 2026-10-31 — `supabase/schema.sql` dites di Postgres 16 + stub `auth` (lock, validasi BO, Joker, poin, auto-bracket, koreksi skor + reset, void, RLS, leaderboard, hapus akun). `index.html` dites di Chromium 390px dengan Supabase di-mock (logout, login, hasil, klasemen, XSS nama).

## Stack

- Frontend: `index.html` satu file, vanilla JS, `@supabase/supabase-js@2.45.4` UMD dari jsDelivr, font Plus Jakarta Sans. Host statis di subdomain (atau tempel di blok Custom HTML WP — sama saja).
- Backend: Supabase (free tier): Auth Google + Postgres. Semua aturan di DB; browser hanya menampilkan.
- Admin: Supabase Table Editor → tabel `matches` (service role, trigger tetap jalan).

## Nodes

| ID | Tipe | Path | Tanggung jawab |
|---|---|---|---|
| `page:pickem` | page | index.html | Tab Tebak + Klasemen, login sheet, footer akun |
| `ui:match-card` | ui | index.html `matchCard()` | 8 state card (belum login, TBD, tersimpan, terkunci+distribusi, selesai+poin, void, reset, error) |
| `ui:board` | ui | index.html `renderBoard()` | Kartu rank saya + top 100, Global / Hari ini (tanggal WIB, di-clamp ke 4–8 Nov) |
| `ui:ads` | ad | index.html `buildDays()`, `[data-ad]`, `adIO`, `fillAd()` | 6 posisi AdSense statis (tidak di-render ulang = tidak refresh), lazy-load ±300px dari layar, 1× per posisi. Tebak: `tebak-1` (setelah 4 Nov), `tebak-3` (setelah 6 Nov), `tebak-end`. Klasemen: `board-10` (selalu kalau ada baris), `board-50` (>50 baris), `board-end` (>90 baris). Hari kosong / tidak terisi / iframe → tidak tampil |
| `test:attack` | test | supabase/tests/attack.sql | 27 skenario curang dalam BEGIN…ROLLBACK; semua harus 'AMAN' |
| `ui:in-app-banner` | ui | index.html `showInApp()` | Instagram/FB/TikTok/LINE/WA in-app → "Buka di Chrome" (intent Android) / "Buka di Safari" |
| `cfg` | config | index.html `CFG` | SUPABASE_URL, SUPABASE_KEY (anon), GA_ID, SPONSOR, TERMS_URL, DAYS |
| `table:matches` | table | supabase/schema.sql | Jadwal, BO, `starts_at` (= kunci), `time_tbc`, tim, `src_a/b` (W1/L3), skor, `void` |
| `table:predictions` | table | supabase/schema.sql | 1 tebakan per user per match, `is_joker`, `points` (hanya trigger yang isi) |
| `table:players` | table | supabase/schema.sql | Nama publik (depan + inisial), diisi sekali saat tebakan pertama |
| `table:board` | table | supabase/schema.sql | Snapshot klasemen per scope (`global` / tanggal WIB), tanpa FK supaya refresh murah |
| `table:board_dirty` | table | supabase/schema.sql | Hari yang skornya dikoreksi → ikut di-refresh |
| `table:stats` | table | supabase/schema.sql | Snapshot distribusi pilihan (match terkunci saja) |
| `job:pickem-refresh` | pg_cron | supabase/schema.sql `refresh_all()` | Tiap menit: board global + hari ini + hari dirty, stats |
| `table:pick_resets` | table | supabase/schema.sql | Log tebakan yang dihapus karena tim berubah → status card |
| `fn:save_prediction` | rpc | supabase/schema.sql | Satu-satunya jalur tulis: login, tim pasti, belum mulai (jam server), skor valid BO, Joker 1x |
| `fn:on_match_change` | trigger | supabase/schema.sql | Hitung ulang poin, isi tim babak berikut, hapus+log tebakan kalau tim berubah, kembalikan Joker saat void |
| `fn:score_points` | sql | supabase/schema.sql | +3 pemenang, +2 skor tepat, x2 Joker, void = 0 |
| `fn:leaderboard` | rpc | supabase/schema.sql | Baca `board`: top 100 + baris saya (index scan, ~0,5 ms) |
| `fn:pick_stats` | rpc | supabase/schema.sql | Baca `stats` |
| `fn:refresh_board` | sql | supabase/schema.sql | Hitung ulang 1 scope; tiebreak poin → skor tepat → `max(updated_at)` lebih awal |
| `fn:delete_my_account` | rpc | supabase/schema.sql | UU PDP: hapus auth user → cascade tebakan |
| `ext:ga4` | tracking | index.html `track()` | pickem_view/login/save/board/share/joker via `gtag` |

## Edges

- `page:pickem` → reads `table:matches` (anon), `table:predictions` + `table:pick_resets` (RLS: milik sendiri), calls `fn:pick_stats`, `fn:leaderboard`, `fn:save_prediction`, `fn:delete_my_account`.
- `admin` → writes `table:matches` → triggers `fn:on_match_change` → writes `table:predictions.points`, `table:matches.team_*` (rekursif ke babak berikut), `table:pick_resets`, `table:board_dirty`.
- `fn:save_prediction` → writes `table:predictions`, `table:players`.
- `job:pickem-refresh` → reads `table:predictions`, `table:matches`, `table:players`, `table:board_dirty` → writes `table:board`, `table:stats`.
- `fn:leaderboard` → reads `table:board`; `fn:pick_stats` → reads `table:stats`.
- Bracket: M1→W:M3.b · M2→W:M4.b · M3→W:M6.a L:M5.a · M4→W:M6.b L:M5.b · M6→W:M8.a L:M7.a · M5→W:M7.b · M7→W:M8.b.

## Invarian

1. `anon`/`authenticated` tidak punya INSERT/UPDATE/DELETE langsung di tabel mana pun; tulis tebakan hanya via `fn:save_prediction`.
2. Kunci pakai `now()` server vs `starts_at`; jam device tidak berpengaruh.
3. Email tidak pernah keluar dari DB; nama publik hanya lewat `public_name()`.
4. Distribusi pilihan tidak tampil sebelum match terkunci.
5. Slot iklan tidak berada di dalam card dan tidak di-render ulang.

## Flow pemain (PRD §Alur)

1. Buka → semua match tampil tanpa login (`INITIAL_SESSION` → `load()`).
2. Klik skor tanpa login → skor disimpan di `localStorage.pk_pending` → sheet login (pemberitahuan privasi) → Google → balik → `afterAuth()` simpan otomatis + scroll ke card (F2).
3. Ganti skor = klik skor lain; Joker toggle di card yang sudah ditebak.
4. Admin isi `score_a/score_b` → poin + babak berikut otomatis.
5. Klasemen → tantang via WhatsApp (pesan memuat tebakan Grand Final).
6. Embed di artikel (iframe): Google menolak login di iframe → klik "Masuk dengan Google" membuka halaman penuh `?pick=<tebakan>` → tebakan dipindah ke localStorage, URL dibersihkan, dialog login langsung terbuka.
   Snippet artikel WP (blok Custom HTML): `<iframe src="https://tebak.esportsku.com/" style="width:100%;height:1400px;border:0" loading="lazy" title="Pick'em MPL ID S18"></iframe>`
- Dialog login ditutup tanpa login (Esc / Nanti saja) → tebakan tertunda dibuang (tidak tersimpan diam-diam saat login berikutnya).
- Auto-save setelah login tidak mengecek jam di browser; server yang menolak kalau sudah terkunci, pesannya tampil di card. Joker lama di match itu dipertahankan.

## Uji kecurangan (2026-11-01, lokal, stub meniru default privileges Supabase)

27/27 AMAN: insert/update/delete langsung, poin palsu, tebak atas nama orang lain, intip tebakan orang, tebak/ganti setelah kunci, skor mustahil/seri/negatif/NULL, match TBD/tidak ada, Joker kedua, race 2 Joker bersamaan ×20 (unique index), ubah/buat match, ubah snapshot klasemen, baca players/auth.users, spam refresh_all/refresh_board, hapus akun orang lain, akun email, anon menebak/membaca, distribusi bocor setelah jadwal diundur (diperbaiki: pick_stats cek kunci saat dibaca).
Belum dicegah (bukan pelanggaran aturan, tapi penyalahgunaan): multi-akun Google (PRD: dicek saat verifikasi hadiah); spam save_prediction dari akun sah (tidak ada rate limit per user — ~1 ms/panggilan, hanya mengubah baris miliknya sendiri).

## Keputusan iklan

- 6 slot (3 per tab), bukan 2 seperti PRD — permintaan owner 2026-11-01. Batas yang dipegang: tidak pernah di dalam card / bersebelahan tombol skor, hanya di jeda antar hari/blok, tidak refresh. Estimasi PRD: 2 slot ≈ $22 di 5rb pemain (eCPM $1); 6 slot kira-kira $40–50 karena slot bawah jarang terlihat. Pantau metrik 'kembali lagi' — kalau turun, kurangi slot (hapus entri di `TEBAK_ADS` / sembunyikan `board-50`).

## Celah yang diketahui (belum diperbaiki, sengaja)

- Jam device lebih cepat dari jam server → tombol mati lebih awal dari seharusnya (server tetap benar; tidak bisa curang, hanya kehilangan beberapa menit). Perbaikan butuh offset jam server.
- Dalam iframe, Safari iOS kadang memblokir localStorage pihak ketiga → tebakan sebelum login hilang, pemain cukup klik ulang setelah login.

## Setup (sekali)

1. Project: `esportsku-pickem` (ref `lmdpgbzwlrsbrylljpmp`, Singapore), sudah aktif lagi 2026-11-01. SQL Editor → tempel seluruh `supabase/schema.sql` → Run. File ini sekalian menghapus tabel prototipe lama (kosong).
2. Auth → Providers → Google: isi Client ID/Secret dari Google Cloud (OAuth consent: External, publish). Redirect URI di Google = `https://<ref>.supabase.co/auth/v1/callback`.
3. Auth → URL Configuration: Site URL + Redirect URLs = URL subdomain = `https://tebak.esportsku.com/`.
4. `CFG.SUPABASE_URL` + `CFG.SUPABASE_KEY` sudah terisi project di atas; isi `GA_ID` kalau subdomain belum ikut GA esportsku.
5. Upload `index.html` ke host statis subdomain (Cloudflare Pages / Vercel / Netlify / folder di server WP).
6. AdSense: isi `CFG.ADSENSE_CLIENT` (ca-pub-…) + `ADSENSE_SLOT` (1 unit Display responsif dipakai semua posisi; boleh ID khusus per posisi di `ADSENSE_SLOTS` untuk laporan per posisi). Posisi Tebak diatur di `CFG.TEBAK_ADS`. Lalu:
   - Pastikan `esportsku.com/ads.txt` memuat baris `google.com, pub-…, DIRECT, f08c47fec0942fa0` (subdomain ikut ads.txt domain utama).
   - Auto ads: matikan untuk `tebak.esportsku.com` (AdSense → Iklan → Menurut situs → Pengecualian halaman). Auto ads bisa menaruh iklan menempel di tombol skor = risiko klik tidak sengaja → akun dibanned.
   - Jangan pasang Monetag popunder/push di subdomain yang sama dengan AdSense (kebijakan AdSense soal pop-up).
7. Kalau saat jalankan schema muncul NOTICE pg_cron: Database → Extensions → aktifkan pg_cron, lalu jalankan ulang blok `do $$ … cron.schedule …`. Tanpa ini klasemen tidak pernah update.

## Operasional admin

- Hasil: Table Editor → `matches` → isi `score_a`, `score_b` (skor pemenang harus = (BO+1)/2, kalau tidak DB menolak).
- Jam resmi keluar: update `starts_at`, set `time_tbc=false`. Sekarang M3–M8 dipasang 12.00 WIB sebagai batas aman (lebih baik tutup kecepetan daripada orang bisa nebak setelah match mulai).
- Walkover/batal: `void=true` (isi skor juga kalau ada pemenang supaya bracket jalan).
- Koreksi skor: edit skor lagi; kalau tim babak berikut berubah, tebakan match itu terhapus dan pemain lihat pesan di card.

## Temuan / keputusan

- Repo awalnya kosong; "prototipe sudah dibangun" di PRD tidak ada di sini → dibangun ulang.
- Venue beda antar sumber (PRD: Jatim Expo; detik: JIE Convention) — tidak dipakai di UI.
- M7 BO7 (esports.id + sumber lain sepakat Lower Final & Grand Final BO7). Tetap konfirmasi sebelum 7 Nov.
- Beban (diukur 2026-10-31, Postgres 16 lokal 4 core, 50rb pemain / 280rb tebakan):
  - Versi awal: `leaderboard()` 160–240 ms CPU per panggilan → ribuan pembuka klasemen per menit bikin DB tumbang. Diganti snapshot.
  - Sekarang: `leaderboard()` ~0,5 ms, `pick_stats()` ~0,3 ms; `refresh_board('global')` ~0,7 s per menit (dari 1,9 s; nama disimpan di `players`, board tanpa FK, work_mem 32MB).
  - `save_prediction` (pgbench, 50 klien bersamaan): 6.036 save/detik, 0 gagal, rata-rata 8 ms.
  - Supabase Nano (free) CPU-nya jauh lebih lemah dari mesin tes ini, jadi angka di atas bukan angka produksi. Load test ulang di project asli sebelum 4 Nov.
- Frontend: re-render cuma saat ada match yang baru terkunci; reload data saat balik ke tab maksimal 1×/menit.
- Supabase free tier: batas MAU auth 50rb, project pause kalau 7 hari sepi → live sebelum 4 Nov.
