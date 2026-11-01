-- Pick'em Playoff MPL ID S18 — jalankan sekali di Supabase SQL Editor.
-- Semua aturan (kunci, validasi skor, poin, bracket) dijaga di sini. Browser tidak dipercaya.

create table public.matches (
  id         smallint primary key,
  round      text not null,
  best_of    smallint not null check (best_of in (3, 5, 7)),
  starts_at  timestamptz not null,           -- tebakan terkunci di jam ini
  time_tbc   boolean not null default false, -- true = jam resmi belum ada, starts_at = batas aman
  team_a     text,
  team_b     text,
  src_a      text check (src_a ~ '^[WL][1-8]$'), -- 'W1' = pemenang M1, 'L3' = kalah M3
  src_b      text check (src_b ~ '^[WL][1-8]$'),
  score_a    smallint check (score_a >= 0),
  score_b    smallint check (score_b >= 0),
  void       boolean not null default false,  -- walkover/batal: semua tebakan 0 poin, Joker kembali
  check ((score_a is null) = (score_b is null)),
  check (score_a is null or greatest(score_a, score_b) = (best_of + 1) / 2 and score_a <> score_b)
);

create table public.predictions (
  user_id    uuid not null references auth.users on delete cascade,
  match_id   smallint not null references public.matches,
  pick_a     smallint not null,
  pick_b     smallint not null,
  is_joker   boolean not null default false,
  points     smallint,
  updated_at timestamptz not null default now(),
  primary key (user_id, match_id)
);
create unique index one_joker_per_user on public.predictions (user_id) where is_joker;
create index predictions_match on public.predictions (match_id);

-- Tebakan yang dihapus karena tim babak berikut berubah (koreksi skor admin).
create table public.pick_resets (
  user_id  uuid not null references auth.users on delete cascade,
  match_id smallint not null references public.matches,
  reset_at timestamptz not null default now()
);

-- Nama publik dihitung sekali (bukan tiap refresh klasemen).
create table public.players (
  user_id uuid primary key references auth.users on delete cascade,
  name    text not null
);

alter table public.players     enable row level security;
alter table public.matches     enable row level security;
alter table public.predictions enable row level security;
alter table public.pick_resets enable row level security;

create policy matches_read on public.matches for select using (true);
create policy own_predictions on public.predictions for select to authenticated using (user_id = auth.uid());
create policy own_resets on public.pick_resets for select to authenticated using (user_id = auth.uid());

revoke all on public.players, public.matches, public.predictions, public.pick_resets from anon, authenticated;
grant select on public.matches to anon, authenticated;
grant select on public.predictions, public.pick_resets to authenticated;
-- Tulis tebakan hanya lewat save_prediction(); tulis hasil hanya admin (Table Editor = service role).

-- Poin satu tebakan terhadap hasil match.
create function public.score_points(m public.matches, p public.predictions) returns smallint
language sql immutable as $$
  select case
    when m.void then 0
    when m.score_a is null then null
    when sign(p.pick_a - p.pick_b) <> sign(m.score_a - m.score_b) then 0
    else (case when p.pick_a = m.score_a and p.pick_b = m.score_b then 5 else 3 end)
         * (case when p.is_joker then 2 else 1 end)
  end::smallint
$$;

create function public.save_prediction(p_match smallint, p_a smallint, p_b smallint, p_joker boolean default false)
returns boolean -- true = mengganti tebakan lama
language plpgsql security definer set search_path = public as $$
declare
  m public.matches;
  uid uuid := auth.uid();
  existed boolean;
  win smallint;
begin
  if uid is null then raise exception 'Masuk dulu untuk menyimpan' using errcode = '28000'; end if;
  -- Hanya akun Google (satu akun per orang + data pemenang). Email/anonymous sign-up ditolak walau provider lain lupa dimatikan.
  if not exists (select 1 from auth.users where id = uid and raw_app_meta_data->'providers' ? 'google') then
    raise exception 'Hanya bisa masuk pakai Google' using errcode = '28000';
  end if;
  select * into m from public.matches where id = p_match;
  if not found then raise exception 'Match tidak ada'; end if;
  if m.team_a is null or m.team_b is null then raise exception 'Dibuka setelah lawan ditentukan'; end if;
  if m.void then raise exception 'Match dibatalkan'; end if;
  if now() >= m.starts_at then raise exception 'Tebakan sudah ditutup' using errcode = 'P0001'; end if;
  win := (m.best_of + 1) / 2;
  if greatest(p_a, p_b) <> win or least(p_a, p_b) < 0 or p_a = p_b then
    raise exception 'Skor tidak sesuai format BO%', m.best_of;
  end if;
  if p_joker and exists (
    select 1 from public.predictions
    where user_id = uid and is_joker and match_id <> p_match
  ) then raise exception 'Joker sudah dipakai di match lain'; end if;

  insert into public.players (user_id, name)
  select uid, public.public_name(raw_user_meta_data) from auth.users where id = uid
  on conflict (user_id) do nothing;
  select exists (select 1 from public.predictions where user_id = uid and match_id = p_match) into existed;
  insert into public.predictions (user_id, match_id, pick_a, pick_b, is_joker)
  values (uid, p_match, p_a, p_b, p_joker)
  on conflict (user_id, match_id) do update
    set pick_a = excluded.pick_a, pick_b = excluded.pick_b, is_joker = excluded.is_joker, updated_at = now();
  return existed;
end $$;

-- Admin isi/koreksi skor atau ubah tim → hitung ulang poin & isi babak berikutnya.
create function public.on_match_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  winner text; loser text; d public.matches; new_a text; new_b text;
begin
  insert into public.board_dirty values
    (to_char(new.starts_at at time zone 'Asia/Jakarta', 'YYYY-MM-DD')),
    (to_char(old.starts_at at time zone 'Asia/Jakarta', 'YYYY-MM-DD'))
  on conflict do nothing;
  if new.void and not old.void then
    update public.predictions set is_joker = false where match_id = new.id; -- Joker dikembalikan
  end if;

  update public.predictions p set points = public.score_points(new, p) where p.match_id = new.id;

  if new.score_a is null then winner := null; loser := null;
  elsif new.score_a > new.score_b then winner := new.team_a; loser := new.team_b;
  else winner := new.team_b; loser := new.team_a; end if;

  for d in select * from public.matches where src_a in ('W'||new.id, 'L'||new.id) or src_b in ('W'||new.id, 'L'||new.id) loop
    new_a := case d.src_a when 'W'||new.id then winner when 'L'||new.id then loser else d.team_a end;
    new_b := case d.src_b when 'W'||new.id then winner when 'L'||new.id then loser else d.team_b end;
    if new_a is distinct from d.team_a or new_b is distinct from d.team_b then
      if (d.team_a is not null and new_a is distinct from d.team_a)
         or (d.team_b is not null and new_b is distinct from d.team_b) then
        with gone as (delete from public.predictions where match_id = d.id returning user_id)
        insert into public.pick_resets (user_id, match_id) select user_id, d.id from gone;
      end if;
      update public.matches set team_a = new_a, team_b = new_b where id = d.id;
    end if;
  end loop;
  return new;
end $$;

create trigger match_change after update on public.matches
for each row when (old.* is distinct from new.*) execute function public.on_match_change();

-- "Budi Santoso" → "Budi S.", kosong → "Pemain". Email tidak pernah keluar.
create function public.public_name(meta jsonb) returns text
language sql immutable as $$
  select case
    when n = '' then 'Pemain'
    when strpos(n, ' ') = 0 then n
    else split_part(n, ' ', 1) || ' ' || upper(left(reverse(split_part(reverse(n), ' ', 1)), 1)) || '.'
  end
  from (select regexp_replace(btrim(coalesce(nullif(meta->>'full_name', ''), meta->>'name', '')), '\s+', ' ', 'g') as n) x
$$;

-- Klasemen & distribusi = snapshot. Dihitung ulang tiap menit oleh pg_cron (refresh_all),
-- jadi ribuan orang buka Klasemen cuma baca index, bukan agregasi seluruh tebakan.
create table public.board (
  scope   text not null,               -- 'global' atau tanggal WIB 'YYYY-MM-DD'
  user_id uuid not null,               -- tanpa FK: insert 50rb baris/menit jadi jauh lebih murah
  rank    int not null,
  name    text not null,
  points  int not null,
  exact   int not null,
  picks   int not null,
  primary key (scope, user_id)
);
create index board_rank on public.board (scope, rank);
create table public.board_dirty (scope text primary key); -- hari yang skornya dikoreksi
create table public.stats (match_id smallint primary key references public.matches, total int not null, pct_a int not null);
alter table public.board enable row level security;
alter table public.board_dirty enable row level security;
alter table public.stats enable row level security;
revoke all on public.board, public.board_dirty, public.stats from anon, authenticated;

-- Tiebreak: poin → skor tepat → yang lebih dulu mengunci tebakan terakhirnya.
create function public.refresh_board(p_scope text) returns void
language sql security definer set search_path = public set work_mem = '32MB' as $$
  delete from public.board where scope = p_scope;
  insert into public.board (scope, user_id, rank, name, points, exact, picks)
  select p_scope, s.user_id,
         row_number() over (order by s.points desc, s.exact desc, s.last_lock asc, s.user_id),
         pl.name, s.points, s.exact, s.picks
  from (
    select p.user_id,
           coalesce(sum(p.points), 0)::int as points,
           count(*) filter (where m.score_a = p.pick_a and m.score_b = p.pick_b and not m.void)::int as exact,
           count(*)::int as picks,
           max(p.updated_at) as last_lock
    from public.predictions p join public.matches m on m.id = p.match_id
    where p_scope = 'global' or to_char(m.starts_at at time zone 'Asia/Jakarta', 'YYYY-MM-DD') = p_scope
    group by p.user_id
  ) s join public.players pl on pl.user_id = s.user_id;
$$;

create function public.refresh_all() returns void
language plpgsql security definer set search_path = public as $$
declare s text;
begin
  perform public.refresh_board('global');
  perform public.refresh_board(to_char(now() at time zone 'Asia/Jakarta', 'YYYY-MM-DD'));
  for s in delete from public.board_dirty returning scope loop perform public.refresh_board(s); end loop;
  -- Distribusi hanya untuk match yang sudah terkunci (F8): tidak memengaruhi tebakan orang lain.
  delete from public.stats;
  insert into public.stats
  select p.match_id, count(*), round(100.0 * count(*) filter (where p.pick_a > p.pick_b) / count(*))
  from public.predictions p join public.matches m on m.id = p.match_id
  where now() >= m.starts_at
  group by p.match_id;
end $$;

-- Top 100 + baris saya (walau di luar top 100). p_day null = global.
create function public.leaderboard(p_day date default null)
returns table (rank int, name text, points int, exact int, picks int, is_me boolean)
language sql stable security definer set search_path = public as $$
  select b.rank, b.name, b.points, b.exact, b.picks, b.user_id is not distinct from auth.uid()
  from public.board b
  where b.scope = coalesce(to_char(p_day, 'YYYY-MM-DD'), 'global')
    and (b.rank <= 100 or b.user_id = auth.uid())
  order by b.rank
$$;

create function public.pick_stats()
returns table (match_id smallint, total int, pct_a int)
language sql stable security definer set search_path = public as $$
  select match_id, total, pct_a from public.stats
$$;

-- UU PDP: hapus akun & semua tebakan.
create function public.delete_my_account() returns void
language sql security definer set search_path = public, auth as $$
  delete from public.board where user_id = auth.uid();
  delete from auth.users where id = auth.uid();
$$;

-- Supabase memberi anon/authenticated EXECUTE ke semua fungsi baru secara default → cabut semua, buka yang perlu saja.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.leaderboard(date), public.pick_stats() to anon, authenticated;
grant execute on function public.save_prediction(smallint, smallint, smallint, boolean), public.delete_my_account() to authenticated;

-- Refresh snapshot tiap menit. Supabase: pg_cron tersedia di semua plan.
do $$ begin
  create extension if not exists pg_cron with schema pg_catalog;
  perform cron.schedule('pickem-refresh', '* * * * *', 'select public.refresh_all()');
exception when others then
  raise notice 'pg_cron belum aktif: Database > Extensions > pg_cron, lalu jalankan ulang blok ini';
end $$;

-- Jadwal. starts_at = batas tebak. Untuk time_tbc=true sengaja dipasang 12.00 WIB (lebih awal = aman):
-- begitu jam resmi keluar, update starts_at dan set time_tbc=false.
insert into public.matches (id, round, best_of, starts_at, time_tbc, team_a, team_b, src_a, src_b) values
 (1, 'Upper R1',        5, '2026-11-04 13:00+07', false, 'Alter Ego',            'ONIC', null, null),
 (2, 'Upper R1',        5, '2026-11-04 18:00+07', false, 'Bigetron by Vitality', 'EVOS', null, null),
 (3, 'Upper Semifinal', 5, '2026-11-05 12:00+07', true,  'NAVI',                 null,   null, 'W1'),
 (4, 'Upper Semifinal', 5, '2026-11-05 12:00+07', true,  'Team Liquid ID',       null,   null, 'W2'),
 (5, 'Lower Semifinal', 5, '2026-11-06 12:00+07', true,  null, null, 'L3', 'L4'),
 (6, 'Upper Final',     5, '2026-11-06 12:00+07', true,  null, null, 'W3', 'W4'),
 (7, 'Lower Final',     7, '2026-11-07 12:00+07', true,  null, null, 'L6', 'W5'),
 (8, 'Grand Final',     7, '2026-11-08 12:00+07', true,  null, null, 'W6', 'W7');

select public.refresh_all();
