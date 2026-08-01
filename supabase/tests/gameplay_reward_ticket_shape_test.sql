set search_path = extensions, public;

select extensions.plan(12);

select extensions.ok(
  to_regclass('public.player_gameplay_reward_claims') is not null,
  'gameplay reward claims table exists'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.claim_gameplay_reward_ticket(text,integer,text,text)'::regprocedure
  ),
  'gameplay reward ticket RPC exists'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.claim_gameplay_reward_ticket(text,integer,text,text)'::regprocedure),
  'gameplay reward ticket RPC is security definer'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.claim_gameplay_reward_ticket(text,integer,text,text)',
    'EXECUTE'
  ),
  'authenticated can claim gameplay tickets'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.claim_gameplay_reward_ticket(text,integer,text,text)',
    'EXECUTE'
  ),
  'anonymous cannot claim gameplay tickets'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.player_gameplay_reward_claims',
    'INSERT'
  ),
  'authenticated cannot insert reward claims directly'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.player_gameplay_reward_claims',
    'UPDATE'
  ),
  'authenticated cannot update reward claims directly'
);
select extensions.ok(
  not has_table_privilege(
    'anon',
    'public.player_gameplay_reward_claims',
    'SELECT'
  ),
  'anonymous cannot read reward claims'
);
select extensions.ok(
  not has_function_privilege(
    'authenticated',
    'public.adjust_player_coins(integer,text,text)',
    'EXECUTE'
  ),
  'authenticated cannot bypass the ticket RPC with adjust RPC'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.claim_gameplay_reward_ticket(text,integer,text,text)'::regprocedure
      and proconfig @> array['search_path=public']
  ),
  'ticket RPC pins the search path'
);
select extensions.ok(
  (select relrowsecurity from pg_class
    where oid = 'public.player_gameplay_reward_claims'::regclass),
  'reward claims keep RLS enabled'
);
select extensions.ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.player_gameplay_reward_claims'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid) like '%user_id, reward_kind, claim_key%'
  ),
  'reward claims enforce per-user idempotency'
);

select * from extensions.finish();
