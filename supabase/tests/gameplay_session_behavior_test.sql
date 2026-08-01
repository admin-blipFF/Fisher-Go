set search_path = extensions, public;

begin;

select extensions.plan(13);

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
  'session-user-a@example.test',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now(),
  false
);

insert into public.player_profiles (user_id, coins)
values ('00000000-0000-0000-0000-000000000031', 500);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000031',
  true
);
select set_config(
  'request.jwt.claim.email',
  'session-user-a@example.test',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000031","email":"session-user-a@example.test","role":"authenticated","aud":"authenticated"}',
  true
);

select extensions.ok(
  (public.start_virtual_fishing_session(
    'P001', 'basic_bait', 'fish-001', 22.286060, 114.162570, 10
  )->>'session_id') is not null,
  'authenticated player receives a one-time fishing session'
);

set local role postgres;
select extensions.is(
  (select status from public.player_fishing_sessions
    where user_id = '00000000-0000-0000-0000-000000000031'
    order by created_at desc limit 1),
  'armed',
  'new fishing session starts armed'
);
update public.player_fishing_sessions
   set started_at = now() - interval '2 seconds',
       bite_at = now() - interval '1 second',
       success_window_ends_at = now() + interval '1 second',
       expires_at = now() + interval '10 seconds'
 where id = (
   select id from public.player_fishing_sessions
    where user_id = '00000000-0000-0000-0000-000000000031'
    order by created_at desc limit 1
 );

set local role authenticated;
select extensions.is(
  (public.resolve_virtual_fishing_session(
    (select id from public.player_fishing_sessions
      where user_id = '00000000-0000-0000-0000-000000000031'
      order by created_at desc limit 1),
    2000
  )->>'success')::boolean,
  true,
  'server accepts a pull inside the bite window'
);
select extensions.is(
  (select status from public.player_fishing_sessions
    where user_id = '00000000-0000-0000-0000-000000000031'
    order by created_at desc limit 1),
  'resolved_success',
  'successful pull is persisted as resolved success'
);
select extensions.is(
  (public.claim_gameplay_reward_ticket(
    'virtual_catch', 999, 'session-claim-1', 'fish-001',
    (select id from public.player_fishing_sessions
      where user_id = '00000000-0000-0000-0000-000000000031'
      order by created_at desc limit 1)
  )->>'reward_coins')::integer,
  160,
  'successful session unlocks the bounded virtual reward'
);
select extensions.is(
  (public.claim_gameplay_reward_ticket(
    'virtual_catch', 160, 'session-claim-1', 'fish-001',
    (select id from public.player_fishing_sessions
      where user_id = '00000000-0000-0000-0000-000000000031'
      order by created_at desc limit 1)
  )->>'claimed')::boolean,
  false,
  'session reward remains idempotent'
);
select extensions.is(
  (select claimed_at is not null from public.player_fishing_sessions
    where user_id = '00000000-0000-0000-0000-000000000031'
    order by created_at desc limit 1),
  true,
  'successful session is marked claimed after wallet credit'
);
select extensions.is(
  (select coins from public.player_profiles
    where user_id = '00000000-0000-0000-0000-000000000031'),
  660,
  'session reward credits the wallet atomically'
);
select extensions.throws_ok(
  $$select public.claim_gameplay_reward_ticket(
      'virtual_catch', 8, 'generic-virtual-bypass', 'fish-001')$$,
  '22023',
  'virtual fishing session required',
  'generic virtual ticket cannot bypass a fishing session'
);

select extensions.ok(
  (public.start_virtual_fishing_session(
    'P001', 'basic_bait', 'fish-002', 22.286060, 114.162570, 10
  )->>'session_id') is not null,
  'player can start a second session after claiming the first'
);
set local role postgres;
update public.player_fishing_sessions
   set expires_at = now() + interval '10 seconds'
 where id = (
   select id from public.player_fishing_sessions
    where user_id = '00000000-0000-0000-0000-000000000031'
      and status = 'armed'
    order by created_at desc limit 1
 );
set local role authenticated;
select extensions.is(
  (public.resolve_virtual_fishing_session(
    (select id from public.player_fishing_sessions
      where user_id = '00000000-0000-0000-0000-000000000031'
        and status = 'armed'
      order by created_at desc limit 1),
    0
  )->>'success')::boolean,
  false,
  'early pull is rejected by the server'
);
select extensions.throws_ok(
  $$select public.claim_gameplay_reward_ticket(
      'virtual_catch', 8, 'early-session-claim', 'fish-002',
      (select id from public.player_fishing_sessions
        where user_id = '00000000-0000-0000-0000-000000000031'
          and status = 'resolved_miss'
        order by created_at desc limit 1))$$,
  '22023',
  'virtual fishing session not successfully resolved',
  'missed bite cannot unlock a virtual reward'
);
set local role postgres;
select extensions.is(
  (select count(*)::integer from public.player_gameplay_reward_claims
    where user_id = '00000000-0000-0000-0000-000000000031'),
  1,
  'only the successful fishing session created a reward claim'
);

select * from extensions.finish();
rollback;
