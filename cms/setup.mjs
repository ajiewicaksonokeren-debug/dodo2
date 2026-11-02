// Setup CMS Directus untuk Pick'em: koleksi, role (PIC Skor, Editor Konten), hak akses per kolom, dashboard metrik.
// Aman dijalankan berulang (idempoten). Butuh Node 18+.
//   DIRECTUS_URL=https://cms.esportsku.com DIRECTUS_EMAIL=owner@... DIRECTUS_PASSWORD=... node cms/setup.mjs
const { DIRECTUS_URL: URL, DIRECTUS_EMAIL, DIRECTUS_PASSWORD } = process.env;
if (!URL || !DIRECTUS_EMAIL || !DIRECTUS_PASSWORD) throw new Error('Isi DIRECTUS_URL, DIRECTUS_EMAIL, DIRECTUS_PASSWORD');

let token;
async function api(method, path, body) {
  const r = await fetch(URL + path, {
    method, body: body && JSON.stringify(body),
    headers: { 'content-type': 'application/json', ...(token && { authorization: `Bearer ${token}` }) },
  });
  const j = r.status === 204 ? {} : await r.json();
  if (!r.ok) throw new Error(`${method} ${path} → ${JSON.stringify(j.errors?.map(e => e.message))}`);
  return j.data;
}
const label = (id, en = id) => [{ language: 'id-ID', translation: id }, { language: 'en-US', translation: en }];

/* ---------- 1. Koleksi (tabel sudah ada di Supabase; di sini hanya tampilan & catatan) ---------- */
const COLLECTIONS = {
  matches: {
    icon: 'sports_esports', sort: 1, accountability: 'all', translations: label('Hasil & Jadwal', 'Matches'),
    note: 'Isi hasil maks 30 menit setelah match selesai. Poin, klasemen (≤1 menit) & tim babak berikut terisi otomatis.',
    display_template: 'M{{id}} · {{round}} · {{team_a}} vs {{team_b}}', sort_field: 'id',
  },
  announcements: {
    icon: 'campaign', sort: 2, accountability: 'all', translations: label('Pengumuman', 'Announcements'),
    note: 'Tampil di atas tool untuk semua pemain (3 terbaru yang aktif).', display_template: '{{body}}',
  },
  settings: {
    icon: 'tune', sort: 3, singleton: true, accountability: 'all', translations: label('Teks Tool & Sponsor', 'Tool settings'),
    note: 'Judul, sponsor, info hadiah, S&K. Berubah di tool tanpa deploy.',
  },
  metrics: {
    icon: 'monitoring', sort: 4, singleton: true, accountability: null, translations: label('Metrik Tes', 'Test metrics'),
    note: 'Diperbarui otomatis tiap menit. Pageview/share/iklan: lihat GA4 & AdSense.',
  },
  metrics_per_match: { icon: 'bar_chart', sort: 5, accountability: null, translations: label('Tebakan per Match', 'Picks per match'), display_template: 'M{{id}}' },
  admin_log: {
    icon: 'history', sort: 6, accountability: null, translations: label('Log Perubahan Match', 'Match log'),
    note: 'Termasuk perubahan otomatis bracket. Riwayat per orang juga ada di Activity Directus.', sort_field: null,
  },
};

// Urutan form: yang paling sering diisi PIC di atas (hasil → void → jadwal), info read-only di bawah.
const f = (name, sort, meta = {}) => ({ sort, translations: label(name), ...meta });
const ro = (name, sort, meta = {}) => f(name, sort, { readonly: true, interface: 'input', width: 'half', ...meta });
const SCORE_CHOICES = { choices: [0, 1, 2, 3, 4].map(v => ({ text: String(v), value: v })), allowNone: true };
const FIELDS = {
  matches: {
    score_a: f('Skor Tim A', 1, { interface: 'select-dropdown', width: 'half', options: SCORE_CHOICES,
      note: 'Pemenang = 3 (BO5) / 4 (BO7). Kosongkan dua-duanya untuk menghapus hasil. Kombinasi tidak valid ditolak saat simpan.' }),
    score_b: f('Skor Tim B', 2, { interface: 'select-dropdown', width: 'half', options: SCORE_CHOICES,
      note: '⚠ Mengubah pemenang yang sudah diisi = tebakan pemain di match babak berikut DIHAPUS.' }),
    void: f('Void / batal', 3, { interface: 'boolean', width: 'full',
      note: 'Walkover/batal: semua tebakan 0 poin, Joker dikembalikan. Isi skor juga kalau ada pemenang (bracket jalan).' }),
    starts_at: f('Mulai (tebakan terkunci)', 4, { interface: 'datetime', width: 'half', note: 'Jam tampil sesuai zona waktu perangkat kamu (WIB di Indonesia barat).' }),
    time_tbc: f('Jam belum resmi', 5, { interface: 'boolean', width: 'half', note: 'Centang → tool menampilkan "Jam menyusul"' }),
    team_a: ro('Tim A', 6, { note: 'Otomatis dari bracket' }), team_b: ro('Tim B', 7, { note: 'Otomatis dari bracket' }),
    round: ro('Babak', 8), best_of: ro('Format (BO)', 9), id: ro('Match', 10),
    src_a: { hidden: true }, src_b: { hidden: true },
  },
  announcements: {
    body: f('Isi', 1, { interface: 'input-multiline', note: 'Maks 280 huruf', required: true }),
    link: f('Link', 2, { interface: 'input', note: 'Opsional, wajib diawali https://' }),
    active: f('Tayang', 3, { interface: 'boolean', note: 'Matikan untuk menarik pengumuman' }),
    created_at: ro('Dibuat', 4, { interface: 'datetime' }), id: { hidden: true },
  },
  settings: {
    hero_title: f('Judul', 1, { interface: 'input', required: true }),
    hero_subtitle: f('Subjudul', 2, { interface: 'input-multiline', required: true }),
    sponsor_name: f('Nama sponsor', 3, { interface: 'input', note: 'Tampil "· by <sponsor>" di header & pesan WhatsApp. Kosongkan kalau tidak ada.' }),
    prize_info: f('Info hadiah', 4, { interface: 'input-multiline', note: 'Tampil di kartu Pengumuman. Contoh: Juara global 1.000 diamond dari <sponsor>' }),
    terms: f('Syarat & Ketentuan', 5, { interface: 'input-multiline', note: 'WAJIB kalau ada hadiah: ikut gratis, pemenang dari ranking, verifikasi identitas, pajak hadiah.' }),
    id: { hidden: true },
  },
  metrics: Object.fromEntries([['pemain', 'Pemain terdaftar'], ['tebakan', 'Total tebakan'], ['tebakan_per_pemain', 'Tebakan per pemain'],
    ['kembali_2_hari', 'Kembali di ≥ 2 hari'], ['persen_kembali', '% kembali'], ['main_hari_ini', 'Menebak hari ini'],
    ['joker_dipakai', 'Joker dipakai'], ['diperbarui', 'Diperbarui']].map(([k, n], i) => [k, ro(n, i + 1)]).concat([['id', { hidden: true }]])),
};

/* ---------- 2. Hak akses per role ---------- */
const MATCH_EDIT = ['score_a', 'score_b', 'starts_at', 'time_tbc', 'void'];
const SETTINGS_EDIT = ['sponsor_name', 'hero_title', 'hero_subtitle', 'prize_info', 'terms'];
const read = c => ({ collection: c, action: 'read', fields: ['*'] });
const POLICIES = {
  'PIC Skor': {
    icon: 'scoreboard', description: 'Isi hasil, jadwal, void; pengumuman. Tidak bisa ubah teks tool / sponsor.',
    permissions: [
      read('matches'), { collection: 'matches', action: 'update', fields: MATCH_EDIT },
      read('announcements'), { collection: 'announcements', action: 'create', fields: ['body', 'link', 'active'] },
      { collection: 'announcements', action: 'update', fields: ['body', 'link', 'active'] },
      read('settings'), read('metrics'), read('metrics_per_match'), read('admin_log'),
    ],
  },
  'Editor Konten': {
    icon: 'edit_note', description: 'Pengumuman, teks tool, sponsor, S&K. Tidak bisa menyentuh skor & jadwal.',
    permissions: [
      read('matches'),
      read('announcements'), { collection: 'announcements', action: 'create', fields: ['body', 'link', 'active'] },
      { collection: 'announcements', action: 'update', fields: ['body', 'link', 'active'] },
      { collection: 'announcements', action: 'delete' },
      read('settings'), { collection: 'settings', action: 'update', fields: SETTINGS_EDIT },
      read('metrics'), read('metrics_per_match'),
    ],
  },
};

/* ---------- 3. Dashboard metrik (Insights) ---------- */
const METRIC_PANELS = [
  ['pemain', 'Pemain terdaftar', ''], ['tebakan_per_pemain', 'Tebakan per pemain (maks 8)', ''],
  ['persen_kembali', 'Kembali menebak di ≥ 2 hari', '%'], ['main_hari_ini', 'Menebak hari ini', ''],
  ['joker_dipakai', 'Joker dipakai', ''], ['tebakan', 'Total tebakan', ''],
];

async function main() {
  ({ access_token: token } = await api('POST', '/auth/login', { email: DIRECTUS_EMAIL, password: DIRECTUS_PASSWORD }));

  await api('PATCH', '/settings', { project_name: "Pick'em esportsku", project_color: '#1D5BFF', default_language: 'id-ID' });

  for (const [collection, meta] of Object.entries(COLLECTIONS)) {
    await api('PATCH', `/collections/${collection}`, { meta }); // tabel sudah ada di DB → cukup daftarkan tampilannya
    for (const [field, fmeta] of Object.entries(FIELDS[collection] || {})) await api('PATCH', `/fields/${collection}/${field}`, { meta: fmeta });
    console.log('✓ koleksi', collection);
  }

  const policies = await api('GET', '/policies?limit=-1&fields=id,name');
  const roles = await api('GET', '/roles?limit=-1&fields=id,name');
  for (const [name, p] of Object.entries(POLICIES)) {
    let pol = policies.find(x => x.name === name);
    const body = { name, icon: p.icon, description: p.description, app_access: true, admin_access: false, enforce_tfa: false };
    pol = pol ? await api('PATCH', `/policies/${pol.id}`, body) : await api('POST', '/policies', body);
    const old = await api('GET', `/permissions?limit=-1&fields=id&filter[policy][_eq]=${pol.id}`);
    if (old.length) await api('DELETE', '/permissions', old.map(x => x.id));
    await api('POST', '/permissions', p.permissions.map(x => ({ ...x, policy: pol.id })));
    let role = roles.find(x => x.name === name);
    role = role ? await api('PATCH', `/roles/${role.id}`, { icon: p.icon, description: p.description })
      : await api('POST', '/roles', { name, icon: p.icon, description: p.description });
    const linked = await api('GET', `/access?fields=id&filter[role][_eq]=${role.id}&filter[policy][_eq]=${pol.id}`);
    if (!linked.length) await api('POST', '/access', { role: role.id, policy: pol.id });
    console.log('✓ role', name);
  }

  const dashes = await api('GET', '/dashboards?fields=id,name');
  let dash = dashes.find(d => d.name === 'Metrik Tes Pick\'em');
  dash = dash || await api('POST', '/dashboards', { name: "Metrik Tes Pick'em", icon: 'monitoring', note: 'Bahan keputusan lanjut/stop 10 Nov. Diperbarui tiap menit.' });
  const oldPanels = await api('GET', `/panels?fields=id&filter[dashboard][_eq]=${dash.id}`);
  if (oldPanels.length) await api('DELETE', '/panels', oldPanels.map(x => x.id));
  await api('POST', '/panels', METRIC_PANELS.map(([field, name, suffix], i) => ({
    dashboard: dash.id, name, type: 'metric', show_header: true, icon: 'insights',
    position_x: 1 + (i % 3) * 12, position_y: 1 + Math.floor(i / 3) * 8, width: 12, height: 8,
    options: { collection: 'metrics', field, function: 'max', sortField: 'id', suffix, abbreviate: false },
  })));
  console.log('✓ dashboard', dash.name);
  console.log('\nSelesai. Undang orang: Pengaturan → Pengguna → Undang, pilih role "PIC Skor" atau "Editor Konten".');
}
main().catch(e => { console.error('✗', e.message); process.exit(1); });
