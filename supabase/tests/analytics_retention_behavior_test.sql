set search_path = extensions, public;

begin;

select extensions.plan(8);

insert into auth.users (
  id, aud, role, email, email_confirmed_at, raw_app_meta_data,
  raw_user_meta_data, created_at, updated_at, is_anonymous
)
values
  (
    '00000000-0000-0000-0000-000000000041', 'authenticated', 'authenticated',
    'retention-admin@example.test', now(), '{}'::jsonb, '{}'::jsonb,
    now(), now(), false
  ),
  (
    '00000000-0000-0000-0000-000000000042', 'authenticated', 'authenticated',
    'retention-player@example.test', now(), '{}'::jsonb, '{}'::jsonb,
    now(), now(), false
  );

insert into public.admin_users (email)
values ('retention-admin@example.test');

set local role postgres;
insert into public.analytics_events (
  actor_key, event_name, occurred_at, fields
)
values
  ('actor-a', 'app_bootstrap', '2026-01-01T10:00:00Z', '{}'::jsonb),
  ('actor-a', 'map_ready', '2026-01-03T10:00:00Z', '{}'::jsonb),
  ('actor-a', 'reward_claimed', '2026-01-08T10:00:00Z', '{}'::jsonb),
  ('actor-b', 'app_bootstrap', '2026-01-01T11:00:00Z', '{}'::jsonb),
  ('actor-b', 'map_ready', '2026-01-08T11:00:00Z', '{}'::jsonb),
  ('actor-c', 'app_bootstrap', '2026-01-02T11:00:00Z', '{}'::jsonb),
  ('actor-c', 'map_ready', '2026-01-09T11:00:00Z', '{}'::jsonb);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000041',
  true
);
select set_config(
  'request.jwt.claim.email',
  'retention-admin@example.test',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000041","email":"retention-admin@example.test","role":"authenticated","aud":"authenticated"}',
  true
);

select extensions.is(
  (select cohort_size from public.analytics_retention_report(
    '2026-01-01', '2026-01-03'
  ) where cohort_date = '2026-01-01'),
  2,
  'report counts the install cohort without actor rows'
);
select extensions.is(
  (select day_2_returners from public.analytics_retention_report(
    '2026-01-01', '2026-01-03'
  ) where cohort_date = '2026-01-01'),
  1,
  'report counts D2 returners'
);
select extensions.is(
  (select day_7_returners from public.analytics_retention_report(
    '2026-01-01', '2026-01-03'
  ) where cohort_date = '2026-01-01'),
  2,
  'report counts D7 returners'
);
select extensions.is(
  (select day_2_rate from public.analytics_retention_report(
    '2026-01-01', '2026-01-03'
  ) where cohort_date = '2026-01-01'),
  50.00::numeric,
  'report returns a bounded D2 percentage'
);
select extensions.is(
  (select day_7_rate from public.analytics_retention_report(
    '2026-01-01', '2026-01-03'
  ) where cohort_date = '2026-01-01'),
  100.00::numeric,
  'report returns a bounded D7 percentage'
);
select extensions.is(
  (select day_2_returners from public.analytics_retention_report(
    '2026-01-01', '2026-01-03'
  ) where cohort_date = '2026-01-02'),
  0,
  'report keeps a cohort with no D2 returners'
);
select extensions.is(
  (select day_7_returners from public.analytics_retention_report(
    '2026-01-01', '2026-01-03'
  ) where cohort_date = '2026-01-02'),
  1,
  'report counts a later cohort D7 returner'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000042',
  true
);
select set_config(
  'request.jwt.claim.email',
  'retention-player@example.test',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000042","email":"retention-player@example.test","role":"authenticated","aud":"authenticated"}',
  true
);
select extensions.throws_ok(
  $$select * from public.analytics_retention_report('2026-01-01', '2026-01-03')$$,
  '42501',
  'admin session required',
  'non-admins cannot query retention aggregates'
);

select * from extensions.finish();
rollback;
