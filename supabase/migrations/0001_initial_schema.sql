create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  level integer not null default 1,
  total_species_unlocked integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fish_species (
  id uuid primary key default gen_random_uuid(),
  afcd_id text unique,
  common_name_zh text not null,
  common_name_en text,
  scientific_name text,
  family text,
  description_zh text,
  habitat_zh text,
  danger_level text not null default 'unknown',
  image_url text,
  silhouette_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.catches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  species_id uuid references public.fish_species(id),
  photo_url text,
  latitude double precision,
  longitude double precision,
  caught_at timestamptz not null default now(),
  ai_confidence numeric,
  is_new_species boolean not null default false,
  score integer not null default 1,
  sync_status text not null default 'synced' check (sync_status in ('pending','syncing','synced','failed')),
  created_at timestamptz not null default now()
);

create table if not exists public.daily_leaderboard (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  score integer not null default 0,
  catches_count integer not null default 0,
  new_species_count integer not null default 0,
  updated_at timestamptz not null default now(),
  unique(user_id, date)
);

alter table public.profiles enable row level security;
alter table public.fish_species enable row level security;
alter table public.catches enable row level security;
alter table public.daily_leaderboard enable row level security;

create policy "profiles are readable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "users insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "users update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "fish species are readable by authenticated users"
  on public.fish_species for select
  to authenticated
  using (true);

create policy "users read their own catches"
  on public.catches for select
  to authenticated
  using (auth.uid() = user_id);

create policy "users insert their own catches"
  on public.catches for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "users update their own catches"
  on public.catches for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "daily leaderboard readable by authenticated users"
  on public.daily_leaderboard for select
  to authenticated
  using (true);

-- No client insert/update policies on daily_leaderboard.
-- Scores should be maintained by trusted server-side trigger or Edge Function.

create index if not exists catches_user_id_idx on public.catches(user_id);
create index if not exists catches_species_id_idx on public.catches(species_id);
create index if not exists catches_caught_at_idx on public.catches(caught_at);
create index if not exists daily_leaderboard_date_score_idx on public.daily_leaderboard(date, score desc);
