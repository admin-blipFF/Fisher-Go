set search_path = extensions, public;

begin;

select extensions.plan(12);

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
    '00000000-0000-0000-0000-000000000011',
    'authenticated',
    'authenticated',
    'wallet-user-a@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    false
  ),
  (
    '00000000-0000-0000-0000-000000000012',
    'authenticated',
    'authenticated',
    'wallet-user-b@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    false
  );

insert into public.player_profiles (user_id, coins)
values ('00000000-0000-0000-0000-000000000011', 500);

insert into public.coin_grants (target_email, amount, reason)
values ('wallet-user-a@example.test', 60, 'behavior test grant');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000011',
  true
);
select set_config(
  'request.jwt.claim.email',
  'wallet-user-a@example.test',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000011","email":"wallet-user-a@example.test","role":"authenticated","aud":"authenticated"}',
  true
);

select extensions.is(
  public.spend_player_coins(125, 'behavior-purchase-1'),
  375,
  'spend RPC returns the updated balance'
);
select extensions.is(
  (select coins from public.player_profiles
    where user_id = '00000000-0000-0000-0000-000000000011'),
  375,
  'spend RPC updates the profile atomically'
);
select extensions.is(
  public.spend_player_coins(125, 'behavior-purchase-1'),
  375,
  'repeating an idempotency key does not spend twice'
);
set local role postgres;
select extensions.is(
  (select count(*)::integer from public.player_coin_transactions
    where user_id = '00000000-0000-0000-0000-000000000011'),
  1,
  'idempotent spending creates one ledger row'
);
set local role authenticated;
select extensions.throws_ok(
  $$insert into public.player_coin_transactions
      (user_id, delta, reason, balance_after)
    values ('00000000-0000-0000-0000-000000000011', 999, 'forbidden', 1374)$$,
  '42501',
  'permission denied for table player_coin_transactions',
  'clients cannot insert coin ledger rows directly'
);
select extensions.throws_ok(
  $$select public.spend_player_coins(1000, 'behavior-too-large')$$,
  'P0001',
  'insufficient coins',
  'spending cannot overdraw the profile'
);

select extensions.is(
  public.claim_my_coin_grants(),
  60,
  'claim RPC returns the newly claimed grant amount'
);
select extensions.is(
  (select coins from public.player_profiles
    where user_id = '00000000-0000-0000-0000-000000000011'),
  435,
  'claim RPC credits the profile atomically'
);
select extensions.is(
  (select total_coins_earned from public.player_profiles
    where user_id = '00000000-0000-0000-0000-000000000011'),
  60,
  'claim RPC increments earned coins once'
);
select extensions.is(
  public.claim_my_coin_grants(),
  0,
  'a claimed grant cannot be claimed twice'
);
set local role postgres;
select extensions.is(
  (select count(*)::integer from public.coin_grant_claims
    where user_id = '00000000-0000-0000-0000-000000000011'),
  1,
  'one grant creates one claim row'
);
set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000012',
  true
);
select set_config(
  'request.jwt.claim.email',
  'wallet-user-b@example.test',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000012","email":"wallet-user-b@example.test","role":"authenticated","aud":"authenticated"}',
  true
);
select extensions.is(
  public.claim_my_coin_grants(),
  0,
  'another user cannot claim a targeted grant'
);

select * from extensions.finish();
rollback;
