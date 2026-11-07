"""Bangun supabase/quiz/seed.sql dari fakta MPL ID yang sudah dicek silang (riset 2026-11-02).
Tambah/ubah fakta di sini, lalu:  python3 supabase/quiz/build.py
Aturan: hanya fakta yang konsisten di >= 2 sumber. Yang bertentangan (mis. skor final S13) TIDAK dijadikan soal.
"""
import json, random, pathlib

SRC_CHAMP = "oneesports.id/mobile-legends/daftar-juara-mpl-indonesia; upstation.media/article/daftar-juara-mpl-id"
SRC_MVP = "ggwp.id daftar MVP MPL ID; skor.id daftar MVP MPL Indonesia sepanjang masa"
# season: (juara, runner-up, skor final atau None kalau sumber bertentangan, Finals MVP, tim Finals MVP)
SEASONS = {
    1: ("Team NXL", "EVOS", "3–2", "Watt", "Team NXL"),
    2: ("RRQ", "EVOS", "3–0", "AyamJAGO", "RRQ"),
    3: ("ONIC", "Louvre", "3–0", "Udil", "ONIC"),
    4: ("EVOS", "RRQ", "3–1", "Rekt", "EVOS"),
    5: ("RRQ", "EVOS", "3–2", "Vynnn", "RRQ"),
    6: ("RRQ", "Alter Ego", "3–2", "Alberttt", "RRQ"),
    7: ("EVOS", "Bigetron", "4–2", "Luminaire", "EVOS"),
    8: ("ONIC", "RRQ", "4–3", "CW", "ONIC"),
    9: ("RRQ", "ONIC", "4–1", "Clayyy", "RRQ"),
    10: ("ONIC", "RRQ", "4–1", "Kairi", "ONIC"),
    11: ("ONIC", "EVOS", "4–0", "Sanz", "ONIC"),
    12: ("ONIC", "Geek Fam ID", "4–2", "Kiboy", "ONIC"),
    13: ("ONIC", "EVOS", None, "CW", "ONIC"),          # Fnatic ONIC vs EVOS Glory; skor final tidak konsisten antar sumber
    14: ("Team Liquid ID", "RRQ", "4–3", "Widy", "Team Liquid ID"),
    15: ("ONIC", "RRQ", "4–3", "Sanz", "ONIC"),
    16: ("ONIC", "Alter Ego", "4–1", "Kairi", "ONIC"),
    17: ("Bigetron", "ONIC", "4–1", "Moreno", "Bigetron"),
}
REG_MVP = {2: "AyamJAGO", 3: "Psychoo", 4: "Lemon", 5: "Branz", 6: "Lemon", 7: "Alberttt", 9: "Alberttt",
           13: "EMANN", 14: "Faviannn", 15: "Idok", 16: "Sanz", 17: "Kelra"}
SRC_REG = "liquipedia MPL Indonesia (Regular Season MVP); duniagames.co.id MPL ID S17 awards"
TEAMS = ["ONIC", "RRQ", "EVOS", "Alter Ego", "Bigetron", "Team Liquid ID", "Geek Fam ID", "Team NXL", "Louvre"]
NAME = {"RRQ": "RRQ Hoshi", "EVOS": "EVOS", "Bigetron": "Bigetron"}
PLAYERS = sorted({s[3] for s in SEASONS.values()} | set(REG_MVP.values()))

rng = random.Random(18)  # deterministik: seed.sql sama tiap build
Q = []

def add(category, question, answer, pool, fact, source, season=None, n=4):
    others = [p for p in dict.fromkeys(pool) if p != answer]
    opts = rng.sample(others, min(n - 1, len(others))) + [answer]
    rng.shuffle(opts)
    Q.append(dict(category=category, season=season, question=question, options=opts,
                  answer=opts.index(answer), fact=fact, source=source))

def team(t, s=None):
    if s == 13 and t == "ONIC": return "ONIC (Fnatic ONIC)"
    if s == 13 and t == "EVOS": return "EVOS (EVOS Glory)"
    if s == 17 and t == "Bigetron": return "Bigetron by Vitality"
    return NAME.get(t, t)

for s, (ch, ru, score, mvp, mvp_team) in SEASONS.items():
    pool = [team(t, s) for t in TEAMS]
    fin = f"Final MPL ID S{s}: {team(ch, s)} vs {team(ru, s)}" + (f", {score}" if score else "") + f". Finals MVP: {mvp}."
    add("Juara", f"Siapa juara MPL ID Season {s}?", team(ch, s), pool, fin, SRC_CHAMP, s)
    add("Final", f"Siapa yang dikalahkan {team(ch, s)} di final MPL ID Season {s}?", team(ru, s),
        [t for t in pool if t != team(ch, s)], fin, SRC_CHAMP, s)
    if score:
        fmt = ["3–0", "3–1", "3–2"] if score.startswith("3") else ["4–0", "4–1", "4–2", "4–3"]
        add("Skor final", f"Berapa skor final MPL ID Season {s} ({team(ch, s)} vs {team(ru, s)})?", score, fmt, fin, SRC_CHAMP, s)
    add("MVP", f"Siapa Finals MVP MPL ID Season {s}?", mvp, PLAYERS, fin, SRC_MVP, s)
    add("MVP", f"{mvp} jadi Finals MVP MPL ID Season {s}. Saat itu ia membela tim apa?", team(mvp_team, s), pool, fin, SRC_MVP, s)

for s, p in REG_MVP.items():
    add("MVP", f"Siapa MVP Regular Season MPL ID Season {s}?", p, PLAYERS, f"MVP Regular Season MPL ID S{s}: {p}.", SRC_REG, s)

F = [  # (kategori, soal, jawaban, pilihan lain, fakta, sumber)
    ("Rekor", "Berapa gelar MPL ID yang dikumpulkan ONIC sampai Season 16?", "8", ["5", "6", "7"],
     "ONIC juara S3, S8, S10, S11, S12, S13, S15, S16: 8 gelar.", "en.moonton.com/news/350; duniagames.co.id (BTR juara S17)"),
    ("Rekor", "Berapa kali RRQ Hoshi juara MPL ID (S1–S17)?", "4", ["2", "3", "5"],
     "RRQ juara S2, S5, S6, S9.", SRC_CHAMP),
    ("Rekor", "Berapa kali EVOS juara MPL ID (S1–S17)?", "2", ["1", "3", "4"], "EVOS juara S4 dan S7.", SRC_CHAMP),
    ("Rekor", "Tim mana yang juara MPL ID empat musim beruntun (S10–S13)?", "ONIC", ["RRQ Hoshi", "EVOS", "Alter Ego"],
     "ONIC juara S10, S11, S12, S13 berturut-turut.", "duniagames.co.id (dominasi ONIC S10–S13)"),
    ("Rekor", "Di season berapa Bigetron meraih gelar MPL ID pertamanya?", "Season 17", ["Season 7", "Season 13", "Season 15"],
     "Bigetron by Vitality juara MPL ID S17 (14 Juni 2026), gelar pertama setelah 17 musim.", "duniagames.co.id; en.moonton.com/news/350"),
    ("Rekor", "Mulai season berapa grand final MPL ID memakai format BO7?", "Season 7", ["Season 5", "Season 8", "Season 10"],
     "S1–S6 final berakhir 3–x (BO5); sejak S7 (EVOS 4–2 Bigetron) final berakhir 4–x (BO7).", SRC_CHAMP),
    ("Rekor", "Tim mana yang kalah di final MPL ID Season 1 DAN Season 2?", "EVOS", ["RRQ Hoshi", "ONIC", "Louvre"],
     "EVOS kalah dari Team NXL (S1) dan RRQ (S2) di final.", SRC_CHAMP),
    ("Rekor", "Pemain mana yang jadi Finals MVP MPL ID di Season 10 dan Season 16?", "Kairi", ["Sanz", "CW", "Kiboy"],
     "Kairi (ONIC) Finals MVP S10 dan S16.", "detik.com S10; duniagames.co.id onic-kairi-mvp-finals-mpl-id-s16"),
    ("Rekor", "Pemain mana yang jadi Finals MVP MPL ID di Season 11 dan Season 15?", "Sanz", ["Kairi", "CW", "Kiboy"],
     "Sanz (ONIC) Finals MVP S11 dan S15.", SRC_MVP),
    ("Rekor", "Pemain mana yang jadi Finals MVP MPL ID di Season 8 dan Season 13?", "CW", ["Kairi", "Sanz", "Alberttt"],
     "CW (ONIC) Finals MVP S8 dan S13 (S13 pakai Claude).", SRC_MVP + "; vcgamers (S13)"),
    ("Internasional", "Tim Indonesia mana yang juara M1 World Championship (2019)?", "EVOS", ["RRQ Hoshi", "ONIC", "Bigetron"],
     "EVOS Legends juara M1 setelah seri 7 game.", "en.wikipedia.org/wiki/MPL_Indonesia; Mobile Legends M1"),
    ("Internasional", "Tim Indonesia mana yang juara MSC 2023?", "ONIC", ["EVOS", "RRQ Hoshi", "Geek Fam ID"],
     "ONIC juara MSC 2023, gelar MSC kedua organisasi ONIC.", "en.wikipedia.org/wiki/MSC_2023"),
    ("Internasional", "Wakil Indonesia yang jadi runner-up M6 World Championship adalah…", "Team Liquid ID", ["ONIC", "RRQ Hoshi", "EVOS"],
     "Grand final M6: Fnatic ONIC Philippines 4–1 Team Liquid ID.", "en.wikipedia.org/wiki/MLBB_M6_World_Championship"),
    ("Internasional", "Di grand final M7 World Championship, Alter Ego kalah dari siapa?", "Aurora Gaming PH",
     ["Fnatic ONIC PH", "Team Liquid PH", "AP Bren"], "Grand final M7: Aurora Gaming PH 4–0 Alter Ego.",
     "en.wikipedia.org/wiki/MLBB_M7_World_Championship"),
    ("Tim", "Julukan ONIC di MPL ID adalah…", "Sang Raja Langit", ["Sang Raja", "Macan Putih", "Kuda Hitam"],
     "ONIC dijuluki Sang Raja Langit (Sky Kings).", "detik.com (jadwal MPL ID S16); en.moonton.com/news/350"),
    ("Tim", "Tim MPL ID yang dijuluki \"Sang Raja\" adalah…", "RRQ Hoshi", ["ONIC", "EVOS", "Bigetron"],
     "RRQ dijuluki Sang Raja.", "detik.com (hasil MPL ID S12 week 5)"),
    ("Venue", "Di mana grand final MPL ID Season 17 digelar?", "Jakarta International Velodrome",
     ["Istora Senayan", "JIExpo Kemayoran", "Tennis Indoor Senayan"],
     "GF S17 (14 Juni 2026) di Jakarta International Velodrome.", "duniagames.co.id; en.moonton.com/news/350"),
    ("Venue", "Di mana grand final MPL ID Season 11 digelar?", "JIExpo Kemayoran",
     ["Jakarta International Velodrome", "Istora Senayan", "Tennis Indoor Senayan"],
     "GF S11 (9 April 2023) di JIExpo Kemayoran.", "selular.id; afkgaming.com (MPL ID S11)"),
    ("Penonton", "Berapa peak viewers grand final MPL ID Season 10 (versi Esports Charts)?", "2,38 juta",
     ["1,2 juta", "3,5 juta", "4,1 juta"], "GF S10 mencatat 2,38 juta peak viewers.", "skor.id (GF MPL ID S10 2,38 juta peak viewers)"),
]
for cat, q, a, others, fact, src in F:
    add(cat, q, a, [a] + others, fact, src)

# Tambahan 2026-11-07. SELALU tambah di belakang: id soal lama tidak boleh bergeser (jawaban pemain menunjuk id).
SRC_M1 = "oneesports.gg (M1 grand finals EVOS 4-3 RRQ); kakuchopurei.com (EVOS wins M1)"
SRC_MSC = "inet.detik.com (daftar juara MSC, ONIC dua kali); oneesports.id/mobile-legends/msc-daftar-juara"
SRC_S1 = "telkomsel.com (asal-usul MPL ID); en.wikipedia.org/wiki/MPL_Indonesia"
SRC_S18 = "tekno.kompas.com (klasemen akhir MPL ID S18); inet.detik.com (klasemen akhir reguler season S18)"
F2 = [
    ("Internasional", "Berapa skor grand final M1 World Championship antara EVOS dan RRQ?", "4–3", ["4–0", "4–1", "4–2"],
     "Grand final M1 (2019): EVOS 4–3 RRQ, final sesama tim Indonesia.", SRC_M1),
    ("Internasional", "Siapa lawan EVOS di grand final M1 World Championship?", "RRQ Hoshi", ["ONIC", "Bren Esports", "Todak"],
     "Grand final M1 (2019): EVOS 4–3 RRQ.", SRC_M1),
    ("Internasional", "Siapa MVP turnamen M1 World Championship 2019?", "Oura", ["Lemon", "Donkey", "Rekt"],
     "Eko \"Oura\" Julianto (EVOS) jadi MVP turnamen M1.", SRC_M1),
    ("Internasional", "Di kota mana M1 World Championship 2019 digelar?", "Kuala Lumpur", ["Jakarta", "Manila", "Singapura"],
     "M1 World Championship digelar di Kuala Lumpur, Malaysia, November 2019.", SRC_M1),
    ("Internasional", "Grand final M1 World Championship mempertemukan dua tim dari negara…", "Indonesia", ["Filipina", "Malaysia", "Myanmar"],
     "EVOS vs RRQ: final M1 sesama tim Indonesia.", SRC_M1),
    ("Internasional", "Tim Indonesia pertama yang juara MSC adalah…", "ONIC", ["EVOS", "RRQ Hoshi", "Bigetron"],
     "ONIC juara MSC 2019, gelar MSC pertama untuk Indonesia.", SRC_MSC),
    ("Internasional", "Di final MSC 2019, ONIC mengalahkan siapa?", "Louvre", ["EVOS", "RRQ Hoshi", "Aether Main"],
     "Final MSC 2019: ONIC 3–0 Louvre.", SRC_MSC),
    ("Internasional", "Di final MSC 2023, ONIC mengalahkan siapa?", "Blacklist International", ["RSG Philippines", "Echo", "Todak"],
     "ONIC juara MSC 2023 setelah mengalahkan Blacklist International.", SRC_MSC),
    ("Internasional", "Wakil Indonesia yang kalah 0–4 dari RSG Philippines di final MSC 2022 adalah…", "RRQ Hoshi", ["ONIC", "EVOS", "Bigetron"],
     "Final MSC 2022: RSG Philippines 4–0 RRQ Hoshi.", SRC_MSC),
    ("Internasional", "Berapa gelar MSC yang dimiliki ONIC (sampai 2025)?", "2", ["1", "3", "4"],
     "ONIC juara MSC 2019 dan 2023.", SRC_MSC),
    ("Internasional", "MSC tidak digelar pada tahun berapa karena pandemi COVID-19?", "2020", ["2019", "2021", "2022"],
     "MSC 2020 ditiadakan karena pandemi.", SRC_MSC),
    ("Sejarah", "Berapa tim yang bertanding di MPL ID Season 1 (2018)?", "10", ["8", "12", "16"],
     "MPL ID S1 diikuti 10 tim hasil kualifikasi daring.", SRC_S1),
    ("Sejarah", "Berapa tim yang ikut kualifikasi daring MPL ID Season 1?", "2.048", ["512", "1.024", "4.096"],
     "Kualifikasi daring MPL ID S1 (Desember 2017) diikuti 2.048 tim.", SRC_S1),
    ("Season 18", "Tim mana yang finis peringkat 1 regular season MPL ID Season 18?", "Team Liquid ID", ["NAVI", "Alter Ego", "ONIC"],
     "Klasemen akhir regular season S18: Team Liquid ID teratas (12–4).", SRC_S18),
    ("Season 18", "Berapa rekor menang–kalah Team Liquid ID di regular season MPL ID S18?", "12–4", ["10–6", "11–5", "13–3"],
     "Team Liquid ID finis 12 menang, 4 kalah dari 16 pertandingan.", SRC_S18),
    ("Season 18", "Tim mana yang finis peringkat 2 regular season MPL ID S18?", "NAVI", ["Alter Ego", "Bigetron by Vitality", "EVOS"],
     "Peringkat 1–2 regular season S18: Team Liquid ID, NAVI (dapat slot upper bracket playoff).", SRC_S18),
    ("Season 18", "Tim mana yang TIDAK lolos ke playoff MPL ID S18?", "RRQ Hoshi", ["ONIC", "EVOS", "Alter Ego"],
     "Tiga tim terbawah S18: Dewa United Esports, RRQ Hoshi, Geek Fam.", SRC_S18),
    ("Season 18", "Berapa tim yang bertanding di regular season MPL ID S18?", "9", ["8", "10", "12"],
     "Regular season S18 diikuti 9 tim; 6 teratas ke playoff.", SRC_S18),
    ("Season 18", "ONIC finis di peringkat berapa pada regular season MPL ID S18?", "6", ["1", "3", "4"],
     "Klasemen akhir S18: TLID, NAVI, Alter Ego, Bigetron by Vitality, EVOS, ONIC, Dewa United, RRQ Hoshi, Geek Fam.", SRC_S18),
]
for cat, q, a, others, fact, src in F2:
    add(cat, q, a, [a] + others, fact, src)

sql = ["-- DIBANGKITKAN oleh supabase/quiz/build.py. Jangan edit manual; edit build.py lalu jalankan ulang.",
       "-- Jalankan di SQL Editor SETELAH schema.sql. Aman diulang (upsert by id).",
       "insert into public.quiz_questions (id, category, season, question, options, answer, fact, source) values"]
esc = lambda t: "'" + t.replace("'", "''") + "'"
rows = []
for i, q in enumerate(Q, 1):
    opts = "array[" + ",".join(esc(o) for o in q["options"]) + "]"
    rows.append(f" ({i}, {esc(q['category'])}, {q['season'] or 'null'}, {esc(q['question'])}, {opts}, {q['answer']}, {esc(q['fact'])}, {esc(q['source'])})")
sql.append(",\n".join(rows))
sql.append("on conflict (id) do update set category = excluded.category, season = excluded.season, question = excluded.question,\n"
           "  options = excluded.options, answer = excluded.answer, fact = excluded.fact, source = excluded.source;")
out = pathlib.Path(__file__).with_name("seed.sql")
out.write_text("\n".join(sql) + "\n")
print(f"{len(Q)} soal → {out}")
