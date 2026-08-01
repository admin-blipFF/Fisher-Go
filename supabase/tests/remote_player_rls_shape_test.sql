set search_path = extensions, public;

select extensions.plan(15);

select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.player_profiles'::regclass),
  'remote player_profiles has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.player_fish_collections'::regclass),
  'remote player_fish_collections has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.player_catches'::regclass),
  'remote player_catches has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'remote profiles has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.catches'::regclass),
  'remote catches has RLS enabled'
);
select extensions.ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'player_profiles',
        'player_fish_collections',
        'player_catches',
        'profiles',
        'catches'
      )
      and (coalesce(qual, '') = 'true' or coalesce(with_check, '') = 'true')
  ),
  'remote player-owned policies are not universally permissive'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'player_profiles'
      and policyname = 'players_manage_own_profiles'
      and qual like '%auth.uid()%'
      and with_check like '%auth.uid()%'
  ),
  'remote player profile policy checks auth.uid'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'player_fish_collections'
      and policyname = 'players_manage_own_fish_collections'
      and qual like '%auth.uid()%'
      and with_check like '%auth.uid()%'
  ),
  'remote fish collection policy checks auth.uid'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'player_catches'
      and policyname = 'players_manage_own_catches'
      and qual like '%auth.uid()%'
      and with_check like '%auth.uid()%'
  ),
  'remote player catch policy checks auth.uid'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'users read their own profile'
      and qual = '(auth.uid() = id)'
  ),
  'remote legacy profile reads are owner-scoped'
);
select extensions.ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles are readable by authenticated users'
  ),
  'remote stale public profile policy is absent'
);
select extensions.ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'fish_species'
      and policyname = 'fish_species_anon_insert'
  ),
  'remote anonymous catalog insert policy is absent'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'fishing_spots'
      and policyname = 'public reads active verified fishing spots'
      and qual like '%active%'
      and qual like '%verified%'
  ),
  'remote fishing spots are filtered to active verified rows'
);
select extensions.ok(
  has_table_privilege('anon', 'public.player_profiles', 'select') = false
    and has_table_privilege('anon', 'public.player_fish_collections', 'select') = false
    and has_table_privilege('anon', 'public.player_catches', 'select') = false,
  'remote anonymous users have no player-table read grants'
);
select extensions.ok(
  has_table_privilege('anon', 'public.fishing_spots', 'select')
    and not has_table_privilege('anon', 'public.fishing_spots', 'insert'),
  'remote anonymous users can browse but not mutate fishing spots'
);
select * from extensions.finish();
