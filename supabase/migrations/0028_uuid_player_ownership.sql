-- Promote the remaining player-owned tables from text identifiers to real
-- Auth ownership. This is additive: legacy migration history remains intact,
-- while malformed or orphaned hosted rows fail closed before any type change.

do $$
declare
  table_name text;
  has_invalid boolean;
  has_orphan boolean;
begin
  foreach table_name in array array[
    'player_profiles',
    'player_fish_collections',
    'player_catches',
    'player_coin_transactions',
    'player_gameplay_reward_claims',
    'player_fishing_sessions'
  ] loop
    execute format(
      'select exists (
         select 1 from public.%I
          where user_id is null
             or user_id !~* %L
       )',
      table_name,
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    ) into has_invalid;
    if has_invalid then
      raise exception
        'cannot promote %.user_id: malformed Auth UUID exists', table_name;
    end if;

    execute format(
      'select exists (
         select 1
           from public.%I player_row
           left join auth.users auth_user
             on auth_user.id = player_row.user_id::uuid
          where auth_user.id is null
       )',
      table_name
    ) into has_orphan;
    if has_orphan then
      raise exception
        'cannot promote %.user_id: orphaned Auth UUID exists', table_name;
    end if;
  end loop;
end;
$$;

-- Policies store parsed expressions that depend on the old text type. Remove
-- them before ALTER COLUMN, then recreate the UUID expressions below.
drop policy if exists "players_manage_own_profiles"
  on public.player_profiles;
drop policy if exists "players_manage_own_fish_collections"
  on public.player_fish_collections;
drop policy if exists "players_manage_own_catches"
  on public.player_catches;
drop policy if exists "players read own fishing sessions"
  on public.player_fishing_sessions;

alter table public.player_profiles
  alter column user_id type uuid using user_id::uuid;
alter table public.player_fish_collections
  alter column user_id type uuid using user_id::uuid;
alter table public.player_catches
  alter column user_id type uuid using user_id::uuid;
alter table public.player_coin_transactions
  alter column user_id type uuid using user_id::uuid;
alter table public.player_gameplay_reward_claims
  alter column user_id type uuid using user_id::uuid;
alter table public.player_fishing_sessions
  alter column user_id type uuid using user_id::uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'player_profiles_user_id_fkey'
  ) then
    alter table public.player_profiles
      add constraint player_profiles_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
     where conname = 'player_fish_collections_user_id_fkey'
  ) then
    alter table public.player_fish_collections
      add constraint player_fish_collections_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
     where conname = 'player_catches_user_id_fkey'
  ) then
    alter table public.player_catches
      add constraint player_catches_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
     where conname = 'player_coin_transactions_user_id_fkey'
  ) then
    alter table public.player_coin_transactions
      add constraint player_coin_transactions_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
     where conname = 'player_gameplay_reward_claims_user_id_fkey'
  ) then
    alter table public.player_gameplay_reward_claims
      add constraint player_gameplay_reward_claims_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
     where conname = 'player_fishing_sessions_user_id_fkey'
  ) then
    alter table public.player_fishing_sessions
      add constraint player_fishing_sessions_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
end;
$$;

drop policy if exists "players_manage_own_profiles"
  on public.player_profiles;
create policy "players_manage_own_profiles"
  on public.player_profiles for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "players_manage_own_fish_collections"
  on public.player_fish_collections;
create policy "players_manage_own_fish_collections"
  on public.player_fish_collections for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "players_manage_own_catches"
  on public.player_catches;
create policy "players_manage_own_catches"
  on public.player_catches for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "players read own fishing sessions"
  on public.player_fishing_sessions;
create policy "players read own fishing sessions"
  on public.player_fishing_sessions for select
  to authenticated
  using (auth.uid() = user_id);

-- The server RPCs were originally declared with a text actor variable because
-- their tables used text ownership. Rewrite those installed definitions from
-- PostgreSQL's own source so overloads remain intact while actor comparisons
-- become UUID comparisons. This avoids duplicating long reward/session bodies.
do $$
declare
  function_row record;
  function_source text;
begin
  for function_row in
    select p.oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind = 'f'
  loop
    function_source := pg_get_functiondef(function_row.oid);
    if function_source not like '%actor_id text;%' then
      continue;
    end if;
    function_source := replace(function_source, 'actor_id text;', 'actor_id uuid;');
    function_source := replace(
      function_source,
      'actor_id := auth.uid()::text;',
      'actor_id := auth.uid();'
    );
    function_source := replace(
      function_source,
      'hashtextextended(actor_id, 0)',
      'hashtextextended(actor_id::text, 0)'
    );
    execute function_source;
  end loop;
end;
$$;
