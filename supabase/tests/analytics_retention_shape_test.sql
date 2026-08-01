set search_path = extensions, public;

select extensions.plan(9);

select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.analytics_retention_report(date,date)'::regprocedure
  ),
  'retention report RPC exists'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.analytics_retention_report(date,date)'::regprocedure),
  'retention report RPC is security definer'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.analytics_retention_report(date,date)',
    'EXECUTE'
  ),
  'authenticated role can call the retention report boundary'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.analytics_retention_report(date,date)',
    'EXECUTE'
  ),
  'anonymous role cannot call the retention report'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.analytics_events', 'SELECT'),
  'authenticated role cannot read raw analytics events'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.analytics_retention_report(date,date)'::regprocedure
      and proconfig @> array['search_path=public']
  ),
  'retention report pins the search path'
);
select extensions.ok(
  (select pg_get_function_result(
    'public.analytics_retention_report(date,date)'::regprocedure
  ) like '%day_2_returners%'
     and pg_get_function_result(
       'public.analytics_retention_report(date,date)'::regprocedure
     ) like '%day_7_returners%'),
  'retention report exposes only cohort aggregates'
);
select extensions.ok(
  exists (
    select 1 from pg_index
    where indrelid = 'public.analytics_events'::regclass
      and indexrelid::regclass::text = 'analytics_events_actor_name_occurred_idx'
  ),
  'retention report has an actor event index'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.analytics_retention_report(date,date)'::regprocedure
      and not pg_get_function_result(
        'public.analytics_retention_report(date,date)'::regprocedure
      ) like '%actor_key%'
  ),
  'retention report does not return actor keys'
);

select * from extensions.finish();
