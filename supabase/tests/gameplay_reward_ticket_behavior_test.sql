set search_path = extensions, public;

begin;

select extensions.plan(9);

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
  '00000000-0000-0000-0000-000000000021',
  'authenticated',
  'authenticated',
  'ticket-user-a@example.test',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now(),
  false
);

insert into public.player_profiles (user_id, coins)
values ('00000000-0000-0000-0000-000000000021', 500);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000021',
  true
);
select set_config(
  'request.jwt.claim.email',
  'ticket-user-a@example.test',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000021","email":"ticket-user-a@example.test","role":"authenticated","aud":"authenticated"}',
  true
);

select extensions.is(
  (public.claim_gameplay_reward_ticket(
    'daily_task_catch_2_fish', 999, 'daily-fish-1'
  )->>'reward_coins')::integer,
  20,
  'daily task reward is fixed by the server'
);
select extensions.is(
  (public.claim_gameplay_reward_ticket(
    'daily_task_catch_2_fish', 20, 'daily-fish-2'
  )->>'claimed')::boolean,
  false,
  'daily task cannot be claimed twice in one day'
);
select extensions.throws_ok(
  $$select public.claim_gameplay_reward_ticket(
      'virtual_catch', 8, 'generic-virtual-bypass', 'fish-010')$$,
  '22023',
  'virtual fishing session required',
  'generic virtual ticket cannot bypass a fishing session'
);
select extensions.throws_ok(
  $$insert into public.player_gameplay_reward_claims
      (user_id, reward_kind, claim_key, requested_amount, reward_amount, balance_after)
    values ('00000000-0000-0000-0000-000000000021', 'virtual_catch', 'direct', 1, 1, 1)$$,
  '42501',
  'permission denied for table player_gameplay_reward_claims',
  'clients cannot insert gameplay tickets directly'
);
select extensions.throws_ok(
  $$select public.adjust_player_coins(100, 'bypass', 'bypass-1')$$,
  '42501',
  'permission denied for function adjust_player_coins',
  'clients cannot bypass tickets with the generic adjust RPC'
);
select extensions.is(
  (public.claim_gameplay_reward_ticket(
    'daily_announcement', 999, 'announcement-1'
  )->>'reward_coins')::integer,
  50,
  'announcement reward is fixed by the server'
);
select extensions.is(
  (public.claim_gameplay_reward_ticket(
    'daily_task_catch_2_species', 999, 'daily-species-1'
  )->>'reward_coins')::integer,
  30,
  'species task reward is fixed by the server'
);
select extensions.is(
  (select coins from public.player_profiles
    where user_id = '00000000-0000-0000-0000-000000000021'),
  600,
  'ticket claims update the wallet in one transaction'
);
set local role postgres;
select extensions.is(
  (select count(*)::integer from public.player_gameplay_reward_claims
    where user_id = '00000000-0000-0000-0000-000000000021'),
  3,
  'only valid non-virtual tickets are persisted'
);

select * from extensions.finish();
rollback;
