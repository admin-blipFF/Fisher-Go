-- Repair the permissive player-cloud policies without rewriting applied history.
-- The legacy user_id columns remain text for compatibility with the current app.

-- Keep this migration self-contained because the old cloud-sync script was
-- previously run manually and is not present in the remote migration history.
create table if not exists public.player_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id text not null unique,
  coins integer not null default 500,
  total_coins_earned integer not null default 0,
  avatar_name text default '默認角色',
  avatar_color text default '#4A90E2',
  equipped_rod text default '木竿',
  equipped_bait text default '紅蟲',
  equipped_hat text default '無',
  equipped_vest text default '無',
  equipped_boat text default '無',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.player_fish_collections (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  fish_id text not null,
  first_caught_at timestamptz default now(),
  catch_count integer default 1,
  best_weight_grams real,
  best_rarity integer,
  unique(user_id, fish_id)
);

create table if not exists public.player_catches (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  fish_id text not null,
  fish_name text,
  spot_name text,
  rarity integer,
  weight_grams real,
  caught_at timestamptz default now(),
  is_boosted boolean default false
);

alter table public.player_profiles enable row level security;
alter table public.player_fish_collections enable row level security;
alter table public.player_catches enable row level security;

drop policy if exists "users_own_profiles" on public.player_profiles;
drop policy if exists "users_own_fish_collections" on public.player_fish_collections;
drop policy if exists "users_own_catches" on public.player_catches;

create policy "players_manage_own_profiles"
  on public.player_profiles for all
  to authenticated
  using (user_id = auth.uid()::text)
  with check (user_id = auth.uid()::text);

create policy "players_manage_own_fish_collections"
  on public.player_fish_collections for all
  to authenticated
  using (user_id = auth.uid()::text)
  with check (user_id = auth.uid()::text);

create policy "players_manage_own_catches"
  on public.player_catches for all
  to authenticated
  using (user_id = auth.uid()::text)
  with check (user_id = auth.uid()::text);

revoke all on table public.player_profiles from anon;
revoke all on table public.player_fish_collections from anon;
revoke all on table public.player_catches from anon;

grant select, insert, update, delete
  on table public.player_profiles to authenticated;
grant select, insert, update, delete
  on table public.player_fish_collections to authenticated;
grant select, insert, update, delete
  on table public.player_catches to authenticated;

-- The app's catch sync still writes to the legacy catches table. Its original
-- migration created RLS policies but never granted table privileges.
alter table public.catches enable row level security;
drop policy if exists "users delete their own catches" on public.catches;
create policy "users delete their own catches"
  on public.catches for delete
  to authenticated
  using (auth.uid() = user_id);

revoke all on table public.catches from anon;
grant select, insert, update, delete
  on table public.catches to authenticated;

-- Profiles contain player-owned fields. Public profile discovery can be added
-- later through a deliberate read model; the legacy table stays private.
alter table public.profiles enable row level security;
drop policy if exists "profiles are readable by authenticated users" on public.profiles;
drop policy if exists "users read their own profile" on public.profiles;
create policy "users read their own profile"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

revoke all on table public.profiles from anon;
grant select, insert, update
  on table public.profiles to authenticated;

-- The species catalog is server-seeded and must never be writable by a client.
drop policy if exists "fish_species_anon_insert" on public.fish_species;
revoke insert, update, delete on table public.fish_species from anon, authenticated;
grant select on table public.fish_species to authenticated;

create or replace function public.update_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_player_profiles_updated_at on public.player_profiles;
create trigger set_player_profiles_updated_at
  before update on public.player_profiles
  for each row execute function public.update_updated_at();
