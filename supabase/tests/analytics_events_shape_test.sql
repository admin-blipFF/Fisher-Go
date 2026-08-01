set search_path = extensions, public;

select extensions.plan(14);

select extensions.ok(
  to_regclass('public.analytics_events') is not null,
  'analytics events table exists'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.record_analytics_event(text,timestamptz,text,text,text,jsonb)'::regprocedure
  ),
  'analytics ingestion RPC exists'
);
select extensions.ok(
  (select prosecdef from pg_proc
    where oid = 'public.record_analytics_event(text,timestamptz,text,text,text,jsonb)'::regprocedure),
  'analytics ingestion RPC is security definer'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.record_analytics_event(text,timestamptz,text,text,text,jsonb)',
    'EXECUTE'
  ),
  'authenticated can submit analytics'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.record_analytics_event(text,timestamptz,text,text,text,jsonb)',
    'EXECUTE'
  ),
  'anonymous cannot submit analytics without a session'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.analytics_events', 'INSERT'),
  'authenticated cannot insert analytics directly'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.analytics_events', 'SELECT'),
  'authenticated cannot read analytics'
);
select extensions.ok(
  (select relrowsecurity from pg_class
    where oid = 'public.analytics_events'::regclass),
  'analytics table keeps RLS enabled'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.record_analytics_event(text,timestamptz,text,text,text,jsonb)'::regprocedure
      and proconfig @> array['search_path=public, extensions']
  ),
  'analytics RPC pins the search path'
);
select extensions.ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.analytics_events'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%jsonb_typeof(fields)%'
  ),
  'analytics fields remain JSON objects'
);
select extensions.ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.analytics_events'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%map_idle%'
  ),
  'analytics event allowlist includes map idle'
);
select extensions.ok(
  exists (
    select 1 from pg_index
    where indrelid = 'public.analytics_events'::regclass
      and indexrelid::regclass::text = 'analytics_events_actor_received_idx'
  ),
  'analytics actor index exists'
);
select extensions.ok(
  exists (
    select 1 from pg_index
    where indrelid = 'public.analytics_events'::regclass
      and indexrelid::regclass::text = 'analytics_events_name_received_idx'
  ),
  'analytics event index exists'
);
select extensions.ok(
  (select proconfig from pg_proc
    where oid = 'public.record_analytics_event(text,timestamptz,text,text,text,jsonb)'::regprocedure)
    @> array['search_path=public, extensions'],
  'analytics RPC has a fixed search path configuration'
);
select * from extensions.finish();
