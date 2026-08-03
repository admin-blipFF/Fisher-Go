set search_path = extensions, public;

begin;

select plan(5);

select ok(
  not exists (
    select 1
      from information_schema.columns
     where table_schema = 'public'
       and table_name in (
         'player_profiles',
         'player_fish_collections',
         'player_catches',
         'player_coin_transactions',
         'player_gameplay_reward_claims',
         'player_fishing_sessions'
       )
       and column_name = 'user_id'
       and udt_name <> 'uuid'
  ),
  'all player-owned user_id columns are UUIDs'
);

select ok(
  (
    select count(*)::integer
      from pg_constraint c
      join pg_attribute a
        on a.attrelid = c.conrelid
       and a.attnum = any(c.conkey)
     where c.contype = 'f'
       and c.confrelid = 'auth.users'::regclass
       and c.confdeltype = 'c'
       and a.attname = 'user_id'
       and c.conrelid in (
         'public.player_profiles'::regclass,
         'public.player_fish_collections'::regclass,
         'public.player_catches'::regclass,
         'public.player_coin_transactions'::regclass,
         'public.player_gameplay_reward_claims'::regclass,
         'public.player_fishing_sessions'::regclass
       )
  ) = 6,
  'every player-owned table cascades from auth.users'
);

select ok(
  exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'player_profiles'
       and policyname = 'players_manage_own_profiles'
       and qual like '%auth.uid() = user_id%'
       and with_check like '%auth.uid() = user_id%'
  )
  and exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'player_fish_collections'
       and policyname = 'players_manage_own_fish_collections'
       and qual like '%auth.uid() = user_id%'
       and with_check like '%auth.uid() = user_id%'
  )
  and exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'player_catches'
       and policyname = 'players_manage_own_catches'
       and qual like '%auth.uid() = user_id%'
       and with_check like '%auth.uid() = user_id%'
  ),
  'primary player policies compare UUID ownership directly'
);

select ok(
  exists (
    select 1
      from pg_constraint
     where conrelid = 'public.player_fishing_sessions'::regclass
       and contype = 'f'
       and confrelid = 'auth.users'::regclass
       and confdeltype = 'c'
       and pg_get_constraintdef(oid) like '%(user_id)%'
  ),
  'server-validated fishing sessions have an auth cascade'
);

select ok(
  not exists (
    select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind = 'f'
       and pg_get_functiondef(p.oid) like '%actor_id text;%'
  ),
  'installed player RPC actor variables are no longer text'
);

select * from finish();
rollback;
