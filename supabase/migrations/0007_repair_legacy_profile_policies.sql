-- Remove stale policies left by the pre-RLS cloud-sync deployment.
-- Keep the additive ownership policies from 0005 as the single source of truth.

drop policy if exists "player_profiles_select_own" on public.player_profiles;
drop policy if exists "player_profiles_insert_own" on public.player_profiles;
drop policy if exists "player_profiles_update_own" on public.player_profiles;
drop policy if exists "player_profiles_delete_own" on public.player_profiles;

drop policy if exists "player_fish_collections_select_own"
  on public.player_fish_collections;
drop policy if exists "player_fish_collections_insert_own"
  on public.player_fish_collections;
drop policy if exists "player_fish_collections_update_own"
  on public.player_fish_collections;
drop policy if exists "player_fish_collections_delete_own"
  on public.player_fish_collections;

drop policy if exists "player_catches_select_own" on public.player_catches;
drop policy if exists "player_catches_insert_own" on public.player_catches;
drop policy if exists "player_catches_update_own" on public.player_catches;
drop policy if exists "player_catches_delete_own" on public.player_catches;

-- Legacy profiles are player-owned. Public discovery can use a separate,
-- intentionally limited read model later.
drop policy if exists "profiles are readable by authenticated users"
  on public.profiles;
drop policy if exists "users read their own profile" on public.profiles;
create policy "users read their own profile"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

revoke all on table public.profiles from anon;
grant select, insert, update on table public.profiles to authenticated;
