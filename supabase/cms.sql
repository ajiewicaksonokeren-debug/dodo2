-- Akses database untuk CMS Directus. Jalankan di SQL Editor SETELAH schema.sql.
-- Directus hanya melihat tabel yang di-grant di sini. Tebakan pemain, nama, email: tidak pernah terlihat di CMS.

-- 1) Role database khusus CMS. GANTI password (min. 32 karakter acak), simpan untuk env DB_PASSWORD Directus.
create role directus with login password 'GANTI-DENGAN-PASSWORD-ACAK-PANJANG';
grant usage, create on schema public to directus;   -- create: Directus membuat tabel sistemnya (directus_*)

grant select on public.matches, public.announcements, public.settings, public.admin_log,
                public.metrics, public.metrics_per_match to directus;
grant update (score_a, score_b, starts_at, time_tbc, void) on public.matches to directus;  -- nama tim, BO, bracket: tidak
grant insert, update, delete on public.announcements to directus;
grant update (sponsor_name, hero_title, hero_subtitle, prize_info, terms) on public.settings to directus;
grant usage on sequence public.announcements_id_seq to directus;

-- RLS untuk role directus (pembatasan per orang diatur di Directus: Owner / PIC Skor / Editor Konten).
create policy cms_matches_update on public.matches for update to directus using (true) with check (true);
create policy cms_announcements  on public.announcements for all to directus using (true) with check (true);
create policy cms_settings       on public.settings for update to directus using (true) with check (true);
create policy cms_admin_log      on public.admin_log for select to directus using (true);
create policy cms_metrics        on public.metrics for select to directus using (true);
create policy cms_metrics_match  on public.metrics_per_match for select to directus using (true);

-- 2) Jalankan bagian ini SETELAH Directus pertama kali hidup (tabel directus_* sudah dibuat).
--    Mengunci tabel sistem Directus (berisi hash password admin) dari API publik Supabase.
-- do $$ declare t text; begin
--   for t in select tablename from pg_tables where schemaname = 'public' and tablename like 'directus\_%' loop
--     execute format('alter table public.%I enable row level security', t);
--     execute format('revoke all on public.%I from anon, authenticated', t);
--   end loop;
-- end $$;
