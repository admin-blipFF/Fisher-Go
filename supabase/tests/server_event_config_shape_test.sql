set search_path = extensions, public;

select extensions.plan(9);

select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.get_active_fishing_event_config()'::regprocedure
  ),
  'active event configuration RPC exists'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.get_active_fishing_event_config()'::regprocedure),
  'active event configuration RPC is security definer'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.get_active_fishing_event_config()',
    'EXECUTE'
  ),
  'authenticated role can read event configuration'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.get_active_fishing_event_config()',
    'EXECUTE'
  ),
  'anonymous role cannot read event configuration'
);
select extensions.ok(
  (select pg_get_function_result(
    'public.get_active_fishing_event_config()'::regprocedure
  ) like '%event_id%'
     and pg_get_function_result(
       'public.get_active_fishing_event_config()'::regprocedure
     ) like '%fish_id%'
     and pg_get_function_result(
       'public.get_active_fishing_event_config()'::regprocedure
     ) like '%multiplier%'),
  'event configuration returns stable fish identity and multiplier'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.get_active_fishing_event_config()'::regprocedure
      and proconfig @> array['search_path=public']
  ),
  'event configuration pins the search path'
);
select extensions.ok(
  (select provolatile = 's' from pg_proc
    where oid = 'public.get_active_fishing_event_config()'::regprocedure),
  'event configuration RPC is stable'
);
select extensions.ok(
  to_regclass('public.admin_events_active_window_idx') is not null,
  'event active-window index exists'
);
select extensions.ok(
  to_regclass('public.fish_rate_boosts_active_window_idx') is not null,
  'boost active-window index exists'
);

select * from extensions.finish();
