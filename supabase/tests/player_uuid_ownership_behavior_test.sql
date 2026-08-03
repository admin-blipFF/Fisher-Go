set search_path = extensions, public;

begin;

select plan(8);

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
values
  (
    '00000000-0000-0000-0000-000000000031',
    'authenticated',
    'authenticated',
    'uuid-ownership-a@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    false
  ),
  (
    '00000000-0000-0000-0000-000000000032',
    'authenticated',
    'authenticated',
    'uuid-ownership-b@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    false
  )
on conflict (id) do nothing;

set local role postgres;
insert into public.player_profiles (user_id, avatar_name)
values
  ('00000000-0000-0000-0000-000000000031', 'Cascade A'),
  ('00000000-0000-0000-0000-000000000032', 'Cascade B');
insert into public.player_fish_collections (user_id, fish_id)
values ('00000000-0000-0000-0000-000000000031', 'fish-031');
insert into public.player_catches (user_id, fish_id)
values ('00000000-0000-0000-0000-000000000031', 'fish-031');
insert into public.player_coin_transactions (
  user_id, delta, reason, balance_after
)
values ('00000000-0000-0000-0000-000000000031', 10, 'cascade test', 510);
insert into public.player_gameplay_reward_claims (
  user_id,
  reward_kind,
  claim_key,
  requested_amount,
  reward_amount,
  balance_after
)
values (
  '00000000-0000-0000-0000-000000000031',
  'checkpoint',
  'cascade-test',
  5,
  5,
  515
);
insert into public.player_fishing_sessions (
  user_id,
  spot_id,
  lure_id,
  fish_id,
  started_at,
  bite_at,
  success_window_ends_at,
  expires_at
)
values (
  '00000000-0000-0000-0000-000000000031',
  'spot-cascade-test',
  'basic_bait',
  'fish-031',
  now(),
  now(),
  now() + interval '1 second',
  now() + interval '12 seconds'
);

select is(
  (select count(*)::integer from public.player_profiles
    where user_id = '00000000-0000-0000-0000-000000000031'),
  1,
  'cascade fixture creates the player profile'
);

delete from auth.users
 where id = '00000000-0000-0000-0000-000000000031';

select is(
  (select count(*)::integer from public.player_profiles
    where user_id = '00000000-0000-0000-0000-000000000031'),
  0,
  'profile is deleted with its Auth user'
);
select is(
  (select count(*)::integer from public.player_fish_collections
    where user_id = '00000000-0000-0000-0000-000000000031'),
  0,
  'collection is deleted with its Auth user'
);
select is(
  (select count(*)::integer from public.player_catches
    where user_id = '00000000-0000-0000-0000-000000000031'),
  0,
  'catch is deleted with its Auth user'
);
select is(
  (select count(*)::integer from public.player_coin_transactions
    where user_id = '00000000-0000-0000-0000-000000000031'),
  0,
  'coin ledger is deleted with its Auth user'
);
select is(
  (select count(*)::integer from public.player_gameplay_reward_claims
    where user_id = '00000000-0000-0000-0000-000000000031'),
  0,
  'reward tickets are deleted with its Auth user'
);
select is(
  (select count(*)::integer from public.player_fishing_sessions
    where user_id = '00000000-0000-0000-0000-000000000031'),
  0,
  'fishing sessions are deleted with its Auth user'
);
select is(
  (select count(*)::integer from public.player_profiles
    where user_id = '00000000-0000-0000-0000-000000000032'),
  1,
  'another user remains isolated during cascade'
);

select * from finish();
rollback;
