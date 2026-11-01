-- Uji kecurangan: jalankan di SQL Editor SETELAH schema.sql. Semua di dalam transaksi lalu ROLLBACK → tidak ada data tertinggal.
-- Hasil: lihat NOTICE. Harus semuanya 'AMAN'.
begin;
insert into auth.users values
 ('aaaaaaaa-0000-0000-0000-000000000001','{"full_name":"Penyerang"}', default),
 ('bbbbbbbb-0000-0000-0000-000000000002','{"full_name":"Korban Satu"}', default),
 ('eeeeeeee-0000-0000-0000-000000000003','{"name":"Akun Email"}','{"provider":"email","providers":["email"]}');
update matches set team_b = 'ONIC' where id = 3; update matches set team_b = 'EVOS' where id = 4;
-- korban menebak M1 (terbuka) & M2; lalu M2 dikunci & dibuka distribusinya
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false);
set role authenticated;
select save_prediction(1::smallint,3::smallint,2::smallint,true), save_prediction(2::smallint,0::smallint,3::smallint);
reset role;
update matches set starts_at = now() - interval '1 min' where id = 2;
select refresh_all();
-- serangan: login sebagai penyerang
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false);
set role authenticated;
create function pg_temp.t(label text, q text, expect_rows int default null) returns void language plpgsql as $f$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  if expect_rows is not null and n <= expect_rows then raise notice 'AMAN   | % (0 baris bocor)', label;
  else raise notice 'LOLOS! | %', label; end if;
exception when others then raise notice 'AMAN   | % → %', label, sqlerrm;
end $f$;
select pg_temp.t('01 Insert tebakan langsung ke tabel (lewati aturan)', $$insert into predictions values ('aaaaaaaa-0000-0000-0000-000000000001',3,3,0,false,99,now())$$);
select pg_temp.t('02 Ubah poin sendiri jadi 999', $$update predictions set points = 999 where user_id = auth.uid()$$);
select pg_temp.t('03 Hapus tebakan korban', $$delete from predictions$$);
select pg_temp.t('04 Intip tebakan korban sebelum match mulai', $$select * from predictions where user_id <> auth.uid()$$, 0);
select pg_temp.t('05 Tebak atas nama korban (user_id palsu)', $$insert into predictions (user_id,match_id,pick_a,pick_b) values ('bbbbbbbb-0000-0000-0000-000000000002',3,3,0)$$);
select pg_temp.t('06 Tebak setelah match mulai (M2 terkunci)', $$select save_prediction(2::smallint,3::smallint,0::smallint)$$);
select pg_temp.t('07 Ganti tebakan setelah terkunci (M2)', $$select save_prediction(2::smallint,0::smallint,3::smallint)$$);
select pg_temp.t('08 Skor mustahil 5-0 di BO5', $$select save_prediction(1::smallint,5::smallint,0::smallint)$$);
select pg_temp.t('09 Skor seri 3-3', $$select save_prediction(1::smallint,3::smallint,3::smallint)$$);
select pg_temp.t('10 Skor negatif 3-(-1)', $$select save_prediction(1::smallint,3::smallint,(-1)::smallint)$$);
select pg_temp.t('11 Skor NULL', $$select save_prediction(1::smallint,null,3::smallint)$$);
select pg_temp.t('12 Tebak match yang lawannya belum ada (M5)', $$select save_prediction(5::smallint,3::smallint,0::smallint)$$);
select pg_temp.t('13 Match yang tidak ada (M99)', $$select save_prediction(99::smallint,3::smallint,0::smallint)$$);
select save_prediction(1::smallint,3::smallint,1::smallint,true);
select pg_temp.t('14 Joker kedua di match lain', $$select save_prediction(4::smallint,3::smallint,0::smallint,true)$$);
select pg_temp.t('15 Admin: isi skor match sendiri', $$update matches set score_a = 3, score_b = 1 where id = 1$$);
select pg_temp.t('16 Admin: undur jam match yang sudah terkunci', $$update matches set starts_at = now() + interval '1 day' where id = 2$$);
select pg_temp.t('17 Bikin match palsu', $$insert into matches (id,round,best_of,starts_at) values (9,'x',5,now()+interval '1 day')$$);
select pg_temp.t('18 Baca/ubah snapshot klasemen langsung', $$update board set points = 999$$);
select pg_temp.t('19 Baca email/nama semua pemain (players)', $$select * from players$$, 0);
select pg_temp.t('20 Spam refresh_all() untuk bebani DB', $$select refresh_all()$$);
select pg_temp.t('21 Panggil refresh_board() langsung', $$select refresh_board('global')$$);
select pg_temp.t('22 Baca auth.users (email)', $$select * from auth.users$$, 0);
select set_config('request.jwt.claim.sub','eeeeeeee-0000-0000-0000-000000000003',false);
select pg_temp.t('24 Akun email (bukan Google) menebak', $$select save_prediction(1::smallint,3::smallint,0::smallint)$$);
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false);
select pg_temp.t('28 Tulis pengumuman palsu', $$insert into announcements (body) values ('Hadiah 1 juta, transfer dulu ke ...')$$);
select pg_temp.t('29 Intip pengumuman nonaktif (draft admin)', $$select * from announcements where not active$$, 0);
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select pg_temp.t('25 Tanpa login: menebak', $$select save_prediction(1::smallint,3::smallint,0::smallint)$$);
select pg_temp.t('26 Tanpa login: baca semua tebakan', $$select * from predictions$$, 0);
reset role;
set role anon; select count(*) as m1_bocor from pick_stats() where match_id = 1; reset role;
select user_id, match_id, pick_a, pick_b, is_joker, points from predictions order by 1,2;
-- 23: penyerang hapus akun lewat delete_my_account → yang terhapus hanya dirinya
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-0000-0000-000000000001',false);
set role authenticated; select delete_my_account(); reset role;
do $$ begin
  if exists (select 1 from auth.users where id='bbbbbbbb-0000-0000-0000-000000000002')
     and not exists (select 1 from auth.users where id='aaaaaaaa-0000-0000-0000-000000000001')
  then raise notice 'AMAN   | 23 delete_my_account hanya menghapus akun sendiri, korban utuh';
  else raise notice 'LOLOS! | 23 delete_my_account'; end if;
end $$;
-- 27: jadwal diundur setelah sempat terkunci → distribusi tertutup lagi
update matches set starts_at = now() + interval '1 day' where id = 2;
set role anon;
do $$ begin
  if (select count(*) from pick_stats() where match_id = 2) = 0 then raise notice 'AMAN   | 27 Distribusi tertutup lagi setelah jadwal diundur';
  else raise notice 'LOLOS! | 27 distribusi bocor'; end if;
end $$;
reset role;
rollback;
