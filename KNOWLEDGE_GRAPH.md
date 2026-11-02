# Knowledge Graph — Pick'em Playoff MPL ID S18

> Edit inkremental, jangan generate ulang. Sumber: PRD Pick'em Playoff MPL ID S18 (21 Okt 2026). Token visual: Clipper DS v2 (tanpa logo Clipper).

Last verified: 2026-10-31 — `supabase/schema.sql` dites di Postgres 16 + stub `auth` (lock, validasi BO, Joker, poin, auto-bracket, koreksi skor + reset, void, RLS, leaderboard, hapus akun). `public/index.html` dites di Chromium 390px dengan Supabase di-mock (logout, login, hasil, klasemen, XSS nama).

## Stack

- Frontend: `public/index.html` satu file, vanilla JS, `@supabase/supabase-js@2.45.4` UMD dari jsDelivr, font Plus Jakarta Sans. Host statis di subdomain (atau tempel di blok Custom HTML WP — sama saja).
- Backend: Supabase (free tier): Auth Google + Postgres. Semua aturan di DB; browser hanya menampilkan.
- Admin & konten: `public/sayangku26/` (statis, ikut Cloudflare Pages). Hak admin = email di `admins` + login Google, dijaga RLS. Dashboard Supabase hanya untuk owner.

## Nodes

| ID | Tipe | Path | Tanggung jawab |
|---|---|---|---|
| `table:admin_log` | table | supabase/schema.sql | Trigger `match_log`: siapa/kapan/sebelum→sesudah tiap perubahan match (termasuk perubahan otomatis bracket) |
| `table:save_days` | table | supabase/schema.sql | Hari WIB pemain menyimpan tebakan → metrik "kembali ≥2 hari" |
| `deploy:pages` | infra | public/_headers | Tool pemain di Cloudflare Pages (`tebak.esportsku.com`): yang dipublikasi hanya folder `public/`; header keamanan + cache 60 s; tanpa X-Frame-Options (embed artikel) |
| `page:admin` | page | public/sayangku26/index.html | `/sayangku26/` (noindex): login Google → `is_admin()`; metrik, hasil/jadwal/void (dropdown skor valid + konfirmasi + peringatan koreksi), pengumuman, **pemain & verifikasi pemenang** (email, IP sama, diskualifikasi, unduh CSV), teks tool & sponsor, log |
| `table:admins` | table | supabase/schema.sql | Email Google admin (huruf kecil). Hanya diisi lewat SQL Editor |
| `fn:is_admin` | sql | supabase/schema.sql | Email user ada di `admins` DAN login Google |
| `table:settings` | table | supabase/schema.sql | Singleton id=1: judul, subjudul, sponsor, info hadiah, S&K → dibaca tool, diubah admin (5 kolom) |
| `fn:admin_metrics` | rpc | supabase/schema.sql | Pemain, tebakan, kembali ≥2 hari, hari ini, Joker, diskualifikasi, per match |
| `fn:admin_players` | rpc | supabase/schema.sql | Semua pemain (maks 50rb) urut rank global: nama, email, daftar, login terakhir, poin, `same_ip` (akun lain dari IP sama, dari auth.sessions) |
| `fn:admin_set_disqualified` | rpc | supabase/schema.sql | Wajib alasan; set `players.disqualified` → keluar dari board & champions (≤1 menit, hari terkait ditandai dirty) |
| `table:quiz_questions` | table | supabase/schema.sql + supabase/quiz/seed.sql | 115 soal pilihan ganda MPL ID S1–S17 (juara, final, skor, MVP, rekor, internasional, venue); `source` per soal; `active` diatur admin. Pemain tidak bisa SELECT (kunci jawaban) |
| `script:quiz-build` | script | supabase/quiz/build.py | Fakta terverifikasi → seed.sql deterministik (seed 18). Fakta yang bertentangan antar sumber tidak dijadikan soal |
| `table:quiz_answers` | table | supabase/schema.sql | PK (user, soal): satu soal sekali seumur pemain; `day` WIB |
| `fn:quiz_today` | rpc | supabase/schema.sql | 5 soal/hari/pemain via `quiz_set()` (urutan md5(user,hari,id), stabil; tanpa soal yang pernah dijawab); kunci & fakta hanya untuk soal terjawab |
| `fn:quiz_answer` | rpc | supabase/schema.sql | Login Google, soal harus di set hari ini, belum dijawab; tulis players + save_days (ikut metrik "kembali") |
| `fn:refresh_quiz_board` / `fn:quiz_leaderboard` | rpc | supabase/schema.sql | Board scope `kuis` tiap menit: poin = benar, seri → selesai lebih awal; diskualifikasi berlaku |
| `ui:quiz` | ui | public/index.html `loadQuiz()/renderQuiz()/answerQuiz()` | Tab Kuis; Klasemen → segmen Kuis. Tanpa slot iklan di dekat pilihan jawaban |
| `page:pickem` | page | public/index.html | Tab Tebak + Klasemen, login sheet, footer akun |
| `ui:match-card` | ui | public/index.html `matchCard()` | 8 state card (belum login, TBD, tersimpan, terkunci+distribusi, selesai+poin, void, reset, error) |
| `ui:board` | ui | public/index.html `renderBoard()` | Kartu rank saya + top 100, Global / Hari ini (tanggal WIB, di-clamp ke 4–8 Nov) |
| `ui:ads` | ad | public/index.html `buildDays()`, `[data-ad]`, `adIO`, `fillAd()` | 6 posisi AdSense statis (tidak di-render ulang = tidak refresh), lazy-load ±300px dari layar, 1× per posisi. Tebak: `tebak-1` (setelah 4 Nov), `tebak-3` (setelah 6 Nov), `tebak-end`. Klasemen: `board-10` (selalu kalau ada baris), `board-50` (>50 baris), `board-end` (>90 baris). Hari kosong / tidak terisi / iframe → tidak tampil |
| `test:attack` | test | supabase/tests/attack.sql | 27 skenario curang dalam BEGIN…ROLLBACK; semua harus 'AMAN' |
| `ui:in-app-banner` | ui | public/index.html `showInApp()` | Instagram/FB/TikTok/LINE/WA in-app → "Buka di Chrome" (intent Android) / "Buka di Safari" |
| `cfg` | config | public/index.html `CFG` | SUPABASE_URL, SUPABASE_KEY (anon), GA_ID, ADSENSE_CLIENT/SLOT/SLOTS, TEBAK_ADS, DAYS. Teks/sponsor/hadiah/S&K → CMS (`table:settings`) |
| `table:matches` | table | supabase/schema.sql | Jadwal, BO, `starts_at` (= kunci), `time_tbc`, tim, `src_a/b` (W1/L3), skor, `void` |
| `table:predictions` | table | supabase/schema.sql | 1 tebakan per user per match, `is_joker`, `points` (hanya trigger yang isi) |
| `table:players` | table | supabase/schema.sql | Nama publik (depan + inisial), diisi sekali saat tebakan pertama |
| `table:board` | table | supabase/schema.sql | Snapshot klasemen per scope (`global` / tanggal WIB), tanpa FK supaya refresh murah |
| `table:board_dirty` | table | supabase/schema.sql | Hari yang skornya dikoreksi → ikut di-refresh |
| `table:stats` | table | supabase/schema.sql | Snapshot distribusi pilihan (match terkunci saja) |
| `job:pickem-refresh` | pg_cron | supabase/schema.sql `refresh_all()` | Tiap menit: board global + hari ini + hari dirty, stats |
| `table:announcements` | table | supabase/schema.sql | Pengumuman admin (≤280 huruf, link https opsional); publik hanya lihat `active` |
| `fn:champions` | rpc | supabase/schema.sql | Juara harian (rank 1 scope hari itu, setelah semua match hari itu selesai/void) + juara global (setelah match id terbesar selesai) |
| `ui:news` | ui | public/index.html `renderNews()` | Kartu "Pengumuman" di bawah tab, tampil di kedua tab: 3 pengumuman terbaru + maks 3 juara; kosong = tidak tampil |
| `table:pick_resets` | table | supabase/schema.sql | Log tebakan yang dihapus karena tim berubah → status card |
| `fn:save_prediction` | rpc | supabase/schema.sql | Satu-satunya jalur tulis: login, tim pasti, belum mulai (jam server), skor valid BO, Joker 1x |
| `fn:on_match_change` | trigger | supabase/schema.sql | Hitung ulang poin, isi tim babak berikut, hapus+log tebakan kalau tim berubah, kembalikan Joker saat void |
| `fn:score_points` | sql | supabase/schema.sql | +3 pemenang, +2 skor tepat, x2 Joker, void = 0 |
| `fn:leaderboard` | rpc | supabase/schema.sql | Baca `board`: top 100 + baris saya (index scan, ~0,5 ms) |
| `fn:pick_stats` | rpc | supabase/schema.sql | Baca `stats` |
| `fn:refresh_board` | sql | supabase/schema.sql | Hitung ulang 1 scope; tiebreak poin → skor tepat → `max(updated_at)` lebih awal |
| `fn:delete_my_account` | rpc | supabase/schema.sql | UU PDP: hapus auth user → cascade tebakan |
| `ext:ga4` | tracking | public/index.html `track()` | pickem_view/login/save/board/share/joker via `gtag` |

## Edges

- `page:pickem` → reads `table:matches` (anon), `table:predictions` + `table:pick_resets` (RLS: milik sendiri), calls `fn:pick_stats`, `fn:leaderboard`, `fn:save_prediction`, `fn:delete_my_account`.
- `admin` → writes `table:matches` → triggers `fn:on_match_change` → writes `table:predictions.points`, `table:matches.team_*` (rekursif ke babak berikut), `table:pick_resets`, `table:board_dirty`.
- `fn:save_prediction` → writes `table:predictions`, `table:players`, `table:save_days`.
- `page:admin` → updates `table:matches` (5 kolom, guarded-by `matches_admin_update` + `fn:is_admin`) → triggers `fn:on_match_change` + `match_log` → `table:admin_log`; writes `table:announcements`, `table:settings`; calls `fn:admin_metrics`, `fn:admin_players`, `fn:admin_set_disqualified` → `table:players`, `table:board_dirty`.
- `fn:refresh_board` → reads `table:players` (lewati `disqualified`).
- `ui:quiz` → calls `fn:quiz_today`, `fn:quiz_answer` → writes `table:quiz_answers`, `table:players`, `table:save_days`; `job:pickem-refresh` → `fn:refresh_quiz_board` → `table:board` (scope kuis).
- `page:admin` → reads/updates (`active`) `table:quiz_questions`.
- `page:pickem` → reads `table:settings`.
- `job:pickem-refresh` → reads `table:predictions`, `table:matches`, `table:players`, `table:board_dirty` → writes `table:board`, `table:stats`.
- `fn:champions` → reads `table:board`, `table:matches`; `page:pickem` → reads `table:announcements`.
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

42/42 AMAN (termasuk kuis: kunci jawaban, set harian, tulis langsung; pengumuman palsu, draft, metrik/log admin, ubah tim/best_of/sponsor, lihat email pemain, diskualifikasi orang, daftar diri jadi admin; peniru email admin via login email ditolak): insert/update/delete langsung, poin palsu, tebak atas nama orang lain, intip tebakan orang, tebak/ganti setelah kunci, skor mustahil/seri/negatif/NULL, match TBD/tidak ada, Joker kedua, race 2 Joker bersamaan ×20 (unique index), ubah/buat match, ubah snapshot klasemen, baca players/auth.users, spam refresh_all/refresh_board, hapus akun orang lain, akun email, anon menebak/membaca, distribusi bocor setelah jadwal diundur (diperbaiki: pick_stats cek kunci saat dibaca).
Belum dicegah (bukan pelanggaran aturan, tapi penyalahgunaan): multi-akun Google (PRD: dicek saat verifikasi hadiah); spam save_prediction dari akun sah (tidak ada rate limit per user — ~1 ms/panggilan, hanya mengubah baris miliknya sendiri).

## Keputusan iklan

- 6 slot (3 per tab), bukan 2 seperti PRD — permintaan owner 2026-11-01. Batas yang dipegang: tidak pernah di dalam card / bersebelahan tombol skor, hanya di jeda antar hari/blok, tidak refresh. Estimasi PRD: 2 slot ≈ $22 di 5rb pemain (eCPM $1); 6 slot kira-kira $40–50 karena slot bawah jarang terlihat. Pantau metrik 'kembali lagi' — kalau turun, kurangi slot (hapus entri di `TEBAK_ADS` / sembunyikan `board-50`).

## Keputusan: kuis harian (2026-11-02)

Owner minta "ratusan soal dari materi MPL season lama" (tidak ada file materi yang dikirim) → owner pilih **kuis harian, klasemen terpisah**. Riset via WebSearch (Liquipedia/oneesports/skor.id diblokir untuk WebFetch di sesi ini): fakta dipakai hanya jika konsisten di ≥2 sumber; skor final S13 (sumber bertentangan) & julukan EVOS/Bigetron (tidak ditemukan) tidak dijadikan soal. 115 soal (bukan ratusan): menambah soal = tambah fakta terverifikasi di build.py, bukan mengarang.
Uji: attack.sql 42/42 AMAN (baca kunci, quiz_set, bocor via quiz_today, jawab di luar set, tulis langsung, ubah soal); set stabil saat refresh, hari berikut 5 soal baru tanpa ulang, jawab dua kali ditolak, klasemen kuis & tiebreak benar; UI kuis & bank soal admin lolos di Chromium.

## Keputusan: tanpa CMS (2026-11-02, final)

Owner: "bikin simple, tanpa CMS". Directus, VPS, `cms.sql`, `deploy/` dihapus. Admin = halaman statis `/sayangku26/` (dipulihkan dari commit 889f619 + bagian Pemain/verifikasi & Teks tool). Hosting: Supabase (DB+Auth) + Cloudflare Pages (`public/`: tool + admin). Biaya hosting 0 selain Supabase.
URL rahasia BUKAN pengaman (noindex saja); pengaman = `admins` + RLS. Email pemain hanya untuk pick'em & hubungi pemenang (sesuai pemberitahuan privasi); pakai untuk promosi butuh opt-in terpisah (UU PDP) — belum ada.
Uji: attack.sql 36/36 AMAN; alur admin (isi hasil, sponsor, admin_players + same_ip, diskualifikasi wajib alasan → keluar klasemen) lolos di Postgres 16; halaman admin lolos di Chromium (tabel, CSV + netralisasi formula, DQ, simpan teks).

## (Lama) Keputusan: Supabase + Cloudflare Pages + VPS (2026-11-02)

Tool pemain → Cloudflare Pages (gratis komersial, bandwidth statis tanpa batas), output dir `public/` supaya SQL/skrip CMS tidak ikut tayang (Pages tidak punya file ignore). CMS tetap VPS (Directus butuh server Node yang terus hidup; tidak jalan di Pages/Workers). `cms.esportsku.com` boleh di-Proxied Cloudflare (SSL Full strict) setelah sertifikat Caddy terbit.

## (Lama) Keputusan: Supabase + Vercel + VPS (2026-11-02, revisi)

Owner: database Supabase, sisanya Vercel. Tool pemain → Vercel. CMS Directus TIDAK bisa di Vercel (butuh server Node yang terus hidup; Vercel = fungsi serverless berumur pendek) → CMS tetap di VPS owner (`deploy/`, Caddy hanya `cms.`). Vercel Hobby melarang penggunaan komersial → perlu Pro; alternatif gratis untuk komersial: Cloudflare Pages.

## (Lama) Keputusan: hosting di VPS owner (2026-11-02)

Tool (statis) + CMS di satu VPS lewat Caddy. Database TETAP Supabase (Auth Google, RLS, cron, backup sudah jalan; memindah Postgres ke VPS = urus backup, auth, update sendiri 2 hari sebelum playoff). Caddyfile belum divalidasi dengan binary caddy (unduhan diblokir di sesi pembuatan) → `docker compose up` pertama: cek `docker compose logs caddy`.

## (Lama, DIGANTIKAN "tanpa CMS") Keputusan: CMS Directus 11 (2026-11-02)

Owner: ada editor konten & banyak admin → pakai CMS. Directus dipilih karena dipasang DI ATAS database yang ada (trigger poin/bracket/anti-curang tetap jalan, tanpa migrasi); Payload/Strapi mau memiliki skema sendiri = bangun ulang. Versi 11.17.4, bukan 12: Directus 12 tanpa lisensi (Core) mengabaikan hak akses per kolom, mematikan SSO user biasa, dan membatasi seat (diverifikasi di kode `@directus/api` 12.6.0: `custom_permission_rules_enabled` ditolak). v11 BSL 1.1: gratis produksi bila total keuangan < US$5 jt. Risiko: v11 tidak lagi dapat update; dampak dibatasi role DB `directus` (tidak bisa baca tebakan/nama/email, hanya 5 kolom matches).
Diuji lokal (Postgres 16 + Directus 11.17.4): PIC isi skor ✓ (bracket & log jalan), PIC ubah tim/BO/sponsor/hapus pengumuman/baca tebakan ✗; Editor ubah sponsor/hapus pengumuman ✓, isi skor/jadwal/baca log/nama ✗; Owner pun tidak bisa baca predictions/players (grant DB).

## (Lama) Keputusan: admin panel statis, bukan Next.js (2026-11-01) — diganti CMS di atas

Owner bertanya kenapa tidak CMS/Next.js. Admin panel memang perlu (PIC skor tidak boleh pegang dashboard Supabase = akses penuh DB; perlu jejak siapa ubah skor). Next.js ditolak: 3 hari sebelum playoff, menambah build + server + hosting kedua tanpa fitur tambahan — hak akses tetap harus dijaga di database. Kalau setelah tes (10 Nov) diputuskan lanjut ke Tebak Skor penuh (multi-turnamen, banyak admin, editor konten), saat itulah pindah ke Next.js.

## Arsitektur: kenapa satu file HTML

`public/index.html` = kerangka statis; SEMUA data (jadwal, skor, klasemen, distribusi, pengumuman, juara) diambil live dari Supabase tiap halaman dibuka. Admin ubah data → langsung tampil, tanpa deploy. Statis dipilih karena: hosting CDN gratis, kuat lonjakan kickoff, tidak ada server yang bisa down. Re-upload hanya kalau `CFG` atau tampilan berubah.

## Celah yang diketahui (belum diperbaiki, sengaja)

- Jam device lebih cepat dari jam server → tombol mati lebih awal dari seharusnya (server tetap benar; tidak bisa curang, hanya kehilangan beberapa menit). Perbaikan butuh offset jam server.
- Dalam iframe, Safari iOS kadang memblokir localStorage pihak ketiga → tebakan sebelum login hilang, pemain cukup klik ulang setelah login.

## Setup (sekali)

1. Project: `esportsku-pickem` (ref `lmdpgbzwlrsbrylljpmp`, Singapore), sudah aktif lagi 2026-11-01. SQL Editor → tempel seluruh `supabase/schema.sql` → Run. File ini sekalian menghapus tabel prototipe lama (kosong).
1b. SQL Editor → jalankan `supabase/quiz/seed.sql` (bank soal kuis; aman diulang).
2. Auth → Providers → Google: isi Client ID/Secret dari Google Cloud (OAuth consent: External, publish). Redirect URI di Google = `https://<ref>.supabase.co/auth/v1/callback`.
3. Auth → URL Configuration: Site URL = `https://tebak.esportsku.com/`, Redirect URLs = `https://tebak.esportsku.com/**` (tool + `/admin/`).
4. `CFG.SUPABASE_URL` + `CFG.SUPABASE_KEY` sudah terisi project di atas; isi `GA_ID` kalau subdomain belum ikut GA esportsku.
5. Cloudflare Pages: Workers & Pages → Create → Pages → Connect to Git → repo ini → Framework preset "None", build command kosong, **Build output directory `public`** → Custom domains: `tebak.esportsku.com`. Push ke branch produksi = deploy otomatis. Gratis untuk komersial.
6. AdSense: isi `CFG.ADSENSE_CLIENT` (ca-pub-…) + `ADSENSE_SLOT` (1 unit Display responsif dipakai semua posisi; boleh ID khusus per posisi di `ADSENSE_SLOTS` untuk laporan per posisi). Posisi Tebak diatur di `CFG.TEBAK_ADS`. Lalu:
   - Pastikan `esportsku.com/ads.txt` memuat baris `google.com, pub-…, DIRECT, f08c47fec0942fa0` (subdomain ikut ads.txt domain utama).
   - Auto ads: matikan untuk `tebak.esportsku.com` (AdSense → Iklan → Menurut situs → Pengecualian halaman). Auto ads bisa menaruh iklan menempel di tombol skor = risiko klik tidak sengaja → akun dibanned.
   - Jangan pasang Monetag popunder/push di subdomain yang sama dengan AdSense (kebijakan AdSense soal pop-up).
7. Kalau saat jalankan schema muncul NOTICE pg_cron: Database → Extensions → aktifkan pg_cron, lalu jalankan ulang blok `do $$ … cron.schedule …`. Tanpa ini klasemen tidak pernah update.


## Operasional admin

Semua lewat `https://tebak.esportsku.com/sayangku26/` (login Google admin). Daftarkan admin: `insert into public.admins values ('nama@gmail.com');` di SQL Editor.

- Hasil: kartu match → dropdown hasil (hanya skor valid) → Simpan → konfirmasi.
- Jam resmi keluar: ubah "Mulai" + hilangkan centang "Jam belum resmi". Jam di CMS mengikuti zona waktu perangkat staf. Sekarang M3–M8 dipasang 12.00 WIB sebagai batas aman (lebih baik tutup kecepetan daripada orang bisa nebak setelah match mulai).
- Pengumuman: bagian Pengumuman → Terbitkan / Tarik. Teks tool, sponsor, hadiah, S&K: bagian Teks tool & sponsor.
- Hadiah: bagian Pemain → cek top N (nama, email, waktu daftar, IP sama) → Diskualifikasi akun ganda (alasan wajib) → Unduh CSV → hubungi pemenang lewat email. Data lengkap juga di Supabase → Authentication → Users. Tampil di tool saat halaman dibuka / balik ke tab.
- Juara harian & global tampil sendiri (≤1 menit setelah skor terakhir hari itu diisi). Konten/sosial tinggal ambil dari kartu Pengumuman.
- Walkover/batal: centang Void (isi hasil juga kalau ada pemenang supaya bracket jalan).
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
