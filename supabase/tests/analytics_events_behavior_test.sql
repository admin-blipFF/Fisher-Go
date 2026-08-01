set search_path = extensions, public;

begin;

select extensions.plan(8);

insert into auth.users (
  id,
  aud,
  role,
  email,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  is_anonymous
)
values (
  '00000000-0000-0000-0000-000000000031',
  'authenticated',
  'authenticated',
  'analytics-user-a@example.test',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now(),
  false
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000031',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000031","role":"authenticated","aud":"authenticated"}',
  true
);

select extensions.lives_ok(
  $$select public.record_analytics_event(
    'app_bootstrap',
    now(),
    'test-build',
    'test-release',
    'test',
    '{"outcome":"success","email":"remove-me","latitude":22.3,"nested":{"no":"store"}}'::jsonb
  )$$,
  'valid analytics event is accepted'
);
select extensions.lives_ok(
  $$select public.record_analytics_event(
    'map_idle',
    now(),
    'test-build',
    'test-release',
    'test',
    '{"durationMs":1320}'::jsonb
  )$$,
  'map idle analytics event is accepted'
);
set local role postgres;
select extensions.is(
  (select count(*)::integer from public.analytics_events),
  2,
  'valid analytics events are stored'
);
select extensions.is(
  (select fields from public.analytics_events limit 1),
  '{"outcome":"success"}'::jsonb,
  'server removes sensitive and nested fields'
);
set local role authenticated;
select extensions.throws_ok(
  $$select public.record_analytics_event('unknown_event')$$,
  '22023',
  'unsupported analytics event',
  'unknown event names are rejected'
);
set local role authenticated;
select extensions.throws_ok(
  $$select public.record_analytics_event(
    'map_ready', now(), '', '', '', '[1,2,3]'::jsonb
  )$$,
  '22023',
  'analytics fields must be an object',
  'non-object analytics fields are rejected'
);
select extensions.throws_ok(
  $$select public.record_analytics_event(
    'map_ready', now(), '', '', '',
    jsonb_build_object('payload', repeat('x', 12001))
  )$$,
  '22023',
  'analytics fields are too large',
  'oversized analytics fields are rejected'
);
select extensions.throws_ok(
  $$insert into public.analytics_events
      (actor_key, event_name, occurred_at, fields)
    values ('direct', 'map_ready', now(), '{}'::jsonb)$$,
  '42501',
  'permission denied for table analytics_events',
  'clients cannot insert analytics directly'
);

select * from extensions.finish();
rollback;
