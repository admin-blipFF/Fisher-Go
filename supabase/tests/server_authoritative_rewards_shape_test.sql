set search_path = extensions, public;

select extensions.plan(22);

select extensions.ok(
  to_regclass('public.player_coin_transactions') is not null,
  'coin transaction ledger exists'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname = 'spend_player_coins'
  ),
  'spend RPC exists'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname = 'claim_my_coin_grants'
  ),
  'grant claim RPC exists'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.adjust_player_coins(integer,text,text)'::regprocedure
  ),
  'adjust RPC exists'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.spend_player_coins(integer,text)'::regprocedure),
  'spend RPC is security definer'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.claim_my_coin_grants()'::regprocedure),
  'grant claim RPC is security definer'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.adjust_player_coins(integer,text,text)'::regprocedure),
  'adjust RPC is security definer'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.spend_player_coins(integer,text)',
    'EXECUTE'
  ),
  'authenticated can execute spend RPC'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.claim_my_coin_grants()',
    'EXECUTE'
  ),
  'authenticated can execute grant claim RPC'
);
select extensions.ok(
  not has_function_privilege(
    'authenticated',
    'public.adjust_player_coins(integer,text,text)',
    'EXECUTE'
  ),
  'authenticated cannot execute adjust RPC after ticket rollout'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.spend_player_coins(integer,text)',
    'EXECUTE'
  ),
  'anonymous cannot execute spend RPC'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.claim_my_coin_grants()',
    'EXECUTE'
  ),
  'anonymous cannot execute grant claim RPC'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.adjust_player_coins(integer,text,text)',
    'EXECUTE'
  ),
  'anonymous cannot execute adjust RPC'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.player_coin_transactions',
    'INSERT'
  ),
  'authenticated cannot insert coin ledger rows directly'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.player_coin_transactions',
    'UPDATE'
  ),
  'authenticated cannot update coin ledger rows directly'
);
select extensions.ok(
  not has_table_privilege(
    'anon',
    'public.player_coin_transactions',
    'SELECT'
  ),
  'anonymous cannot read coin ledger rows'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.player_profiles',
    'DELETE'
  ),
  'authenticated cannot delete player profiles'
);
select extensions.ok(
  not has_column_privilege(
    'authenticated',
    'public.player_profiles',
    'coins',
    'UPDATE'
  ),
  'authenticated cannot update wallet coins directly'
);
select extensions.ok(
  not has_column_privilege(
    'authenticated',
    'public.player_profiles',
    'coins',
    'INSERT'
  ),
  'authenticated cannot insert wallet coins directly'
);
select extensions.ok(
  has_column_privilege(
    'authenticated',
    'public.player_profiles',
    'avatar_name',
    'UPDATE'
  ),
  'authenticated can still update avatar fields'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.spend_player_coins(integer,text)'::regprocedure
      and proconfig @> array['search_path=public']
  ),
  'spend RPC pins the search path'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.adjust_player_coins(integer,text,text)'::regprocedure
      and proconfig @> array['search_path=public']
  ),
  'adjust RPC pins the search path'
);

select * from extensions.finish();
