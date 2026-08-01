set search_path = extensions, public;

select extensions.plan(27);

select extensions.ok(
  to_regclass('public.player_fishing_sessions') is not null,
  'fishing session table exists'
);
select extensions.ok(
  (select relrowsecurity from pg_class
    where oid = 'public.player_fishing_sessions'::regclass),
  'fishing sessions keep RLS enabled'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.player_fishing_sessions', 'INSERT'),
  'authenticated cannot insert fishing sessions directly'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.player_fishing_sessions', 'UPDATE'),
  'authenticated cannot update fishing sessions directly'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.start_virtual_fishing_session(text,text,text)'::regprocedure
  ),
  'start fishing session RPC exists'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.start_virtual_fishing_session(text,text,text)'::regprocedure),
  'start fishing session RPC is security definer'
);
select extensions.ok(
  not has_function_privilege(
    'authenticated',
    'public.start_virtual_fishing_session(text,text,text)',
    'EXECUTE'
  ),
  'legacy start RPC cannot bypass location verification'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.start_virtual_fishing_session(text,text,text)',
    'EXECUTE'
  ),
  'anonymous cannot start fishing sessions'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.start_virtual_fishing_session(text,text,text,double precision,double precision,double precision)'::regprocedure
  ),
  'location-verified start fishing session RPC exists'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.start_virtual_fishing_session(text,text,text,double precision,double precision,double precision)'::regprocedure),
  'location-verified start fishing session RPC is security definer'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.start_virtual_fishing_session(text,text,text,double precision,double precision,double precision)',
    'EXECUTE'
  ),
  'authenticated can start location-verified fishing sessions'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.start_virtual_fishing_session(text,text,text,double precision,double precision,double precision)',
    'EXECUTE'
  ),
  'anonymous cannot start location-verified fishing sessions'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.resolve_virtual_fishing_session(uuid,integer)'::regprocedure
  ),
  'resolve fishing session RPC exists'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.resolve_virtual_fishing_session(uuid,integer)'::regprocedure),
  'resolve fishing session RPC is security definer'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.resolve_virtual_fishing_session(uuid,integer)',
    'EXECUTE'
  ),
  'authenticated can resolve fishing sessions'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.resolve_virtual_fishing_session(uuid,integer)',
    'EXECUTE'
  ),
  'anonymous cannot resolve fishing sessions'
);
select extensions.ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.player_fishing_sessions'::regclass
      and pg_get_constraintdef(oid) like '%armed%resolved_success%resolved_miss%expired%'
  ),
  'fishing sessions constrain lifecycle states'
);
select extensions.ok(
  to_regclass('public.player_fishing_sessions_user_status_idx') is not null,
  'fishing sessions have an owner status index'
);
select extensions.ok(
  exists (
    select 1 from information_schema.columns
     where table_schema = 'public'
       and table_name = 'player_fishing_sessions'
       and column_name = 'location_verified'
  ),
  'fishing sessions store a location verification result'
);
select extensions.ok(
  exists (
    select 1 from information_schema.columns
     where table_schema = 'public'
       and table_name = 'fishing_spots'
       and column_name = 'gameplay_radius_m'
  ),
  'fishing spots expose a gameplay radius'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.claim_gameplay_reward_ticket(text,integer,text,text,uuid)'::regprocedure
  ),
  'session-bound ticket RPC exists'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.claim_gameplay_reward_ticket(text,integer,text,text,uuid)'::regprocedure),
  'session-bound ticket RPC is security definer'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.claim_gameplay_reward_ticket(text,integer,text,text,uuid)',
    'EXECUTE'
  ),
  'authenticated can claim session-bound tickets'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.claim_gameplay_reward_ticket(text,integer,text,text,uuid)',
    'EXECUTE'
  ),
  'anonymous cannot claim session-bound tickets'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.claim_gameplay_reward_ticket(text,integer,text,text,uuid)'::regprocedure
      and proconfig @> array['search_path=public']
  ),
  'session-bound ticket RPC pins the search path'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.start_virtual_fishing_session(text,text,text)'::regprocedure
      and proconfig @> array['search_path=public']
  ),
  'start RPC pins the search path'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.start_virtual_fishing_session(text,text,text,double precision,double precision,double precision)'::regprocedure
      and proconfig @> array['search_path=public']
  ),
  'location-verified start RPC pins the search path'
);

select * from extensions.finish();
