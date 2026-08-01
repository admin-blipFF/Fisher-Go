set search_path = extensions, public;

begin;

select extensions.plan(11);

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
  '00000000-0000-0000-0000-000000000032',
  'authenticated',
  'authenticated',
  'location-user-a@example.test',
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
  '00000000-0000-0000-0000-000000000032',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000032","role":"authenticated","aud":"authenticated"}',
  true
);

select extensions.throws_ok(
  $$select public.start_virtual_fishing_session(
      'P001', 'basic_bait', 'fish-001', 22.300000, 114.200000, 10)$$,
  '22023',
  'player is too far from fishing spot',
  'server rejects a player outside the spot radius'
);
select extensions.throws_ok(
  $$select public.start_virtual_fishing_session(
      'P001', 'basic_bait', 'fish-001', 22.286060, 114.162570, 251)$$,
  '22023',
  'invalid player location',
  'server rejects an unusably inaccurate location'
);
select extensions.ok(
  (public.start_virtual_fishing_session(
    'P001', 'basic_bait', 'fish-001', 22.286060, 114.162570, 10
  )->>'session_id') is not null,
  'server accepts a nearby location'
);

set local role postgres;
select extensions.is(
  (select location_verified from public.player_fishing_sessions
    where user_id = '00000000-0000-0000-0000-000000000032'
    order by created_at desc limit 1),
  true,
  'session stores only a location verification result'
);
select extensions.ok(
  (select location_distance_m < 2 and location_accuracy_m = 10
     from public.player_fishing_sessions
    where user_id = '00000000-0000-0000-0000-000000000032'
    order by created_at desc limit 1),
  'server records bounded location diagnostics without player coordinates'
);

set local role authenticated;
select extensions.ok((public.start_virtual_fishing_session(
  'P001', 'basic_bait', 'fish-002', 22.286060, 114.162570, 10
  )->>'session_id') is not null, 'second nearby session is accepted');
select extensions.ok((public.start_virtual_fishing_session(
  'P001', 'basic_bait', 'fish-003', 22.286060, 114.162570, 10
  )->>'session_id') is not null, 'third nearby session is accepted');
select extensions.ok((public.start_virtual_fishing_session(
  'P001', 'basic_bait', 'fish-004', 22.286060, 114.162570, 10
  )->>'session_id') is not null, 'fourth nearby session is accepted');
select extensions.ok((public.start_virtual_fishing_session(
  'P001', 'basic_bait', 'fish-005', 22.286060, 114.162570, 10
  )->>'session_id') is not null, 'fifth nearby session is accepted');
select extensions.ok((public.start_virtual_fishing_session(
  'P001', 'basic_bait', 'fish-006', 22.286060, 114.162570, 10
  )->>'session_id') is not null, 'sixth nearby session is accepted');
select extensions.throws_ok(
  $$select public.start_virtual_fishing_session(
      'P001', 'basic_bait', 'fish-007', 22.286060, 114.162570, 10)$$,
  'P0001',
  'fishing session start rate limit exceeded',
  'server rate-limits repeated session starts'
);

select * from extensions.finish();
rollback;
