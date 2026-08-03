set search_path = extensions, public;

begin;

select extensions.plan(26);

select extensions.ok(
  to_regclass('public.player_profiles') is not null,
  'remote player_profiles exists'
);
select extensions.ok(
  to_regclass('public.player_fish_collections') is not null,
  'remote player_fish_collections exists'
);
select extensions.ok(
  to_regclass('public.player_catches') is not null,
  'remote player_catches exists'
);
select extensions.ok(
  (select relrowsecurity
     from pg_class
    where oid = 'public.player_profiles'::regclass),
  'remote player_profiles has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity
     from pg_class
    where oid = 'public.player_fish_collections'::regclass),
  'remote player_fish_collections has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity
     from pg_class
    where oid = 'public.player_catches'::regclass),
  'remote player_catches has RLS enabled'
);

-- Use disposable local Auth rows when the test runner permits it. Managed
-- Supabase runners may reject synthetic auth inserts, so the exception block
-- falls back to two existing non-anonymous users supplied by the protected
-- hosted smoke environment. Public rows remain transaction-local either way.
do $$
begin
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
      '00000000-0000-0000-0000-000000000021',
      'authenticated',
      'authenticated',
      'remote-rls-user-a@example.test',
      now(),
      '{}'::jsonb,
      '{}'::jsonb,
      now(),
      now(),
      false
    ),
    (
      '00000000-0000-0000-0000-000000000022',
      'authenticated',
      'authenticated',
      'remote-rls-user-b@example.test',
      now(),
      '{}'::jsonb,
      '{}'::jsonb,
      now(),
      now(),
      false
    )
  on conflict (id) do nothing;
exception when others then
  null;
end;
$$;

create temp table rls_test_ids as
select
  '00000000-0000-0000-0000-000000000021'::uuid as user_a,
  '00000000-0000-0000-0000-000000000022'::uuid as user_b
 where exists (
   select 1 from auth.users
    where id = '00000000-0000-0000-0000-000000000021'::uuid
 )
   and exists (
     select 1 from auth.users
      where id = '00000000-0000-0000-0000-000000000022'::uuid
   );
insert into rls_test_ids (user_a, user_b)
select candidate_a.id, candidate_b.id
  from (
    select id, row_number() over (order by created_at, id) as row_number
      from auth.users
     where coalesce(is_anonymous, false) = false
  ) candidate_a
  cross join (
    select id, row_number() over (order by created_at, id) as row_number
      from auth.users
     where coalesce(is_anonymous, false) = false
  ) candidate_b
 where candidate_a.row_number = 1
   and candidate_b.row_number = 2
   and not exists (select 1 from rls_test_ids);
select extensions.ok(
  (select count(*)::integer from rls_test_ids) = 1,
  'RLS behavior has two Auth users'
);
grant select on rls_test_ids to authenticated;

set local role postgres;
insert into public.player_profiles (user_id, avatar_name)
select user_b, 'Remote User B'
  from rls_test_ids;
insert into public.player_fish_collections (user_id, fish_id)
select user_b, 'fish-remote-b'
  from rls_test_ids;
insert into public.player_catches (user_id, fish_id, fish_name)
select user_b, 'fish-remote-b', 'Remote Fish B'
  from rls_test_ids;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  (select user_a::text from rls_test_ids),
  true
);

select extensions.lives_ok(
  $$insert into public.player_profiles (user_id, avatar_name)
    select user_a, 'Remote User A' from rls_test_ids$$,
  'remote User A can insert an own profile'
);
select extensions.lives_ok(
  $$insert into public.player_fish_collections (user_id, fish_id)
    select user_a, 'fish-remote-a' from rls_test_ids$$,
  'remote User A can insert an own collection'
);
select extensions.lives_ok(
  $$insert into public.player_catches (user_id, fish_id, fish_name)
    select user_a, 'fish-remote-a', 'Remote Fish A' from rls_test_ids$$,
  'remote User A can insert an own catch'
);

select extensions.throws_ok(
  $$insert into public.player_profiles (user_id, avatar_name)
    select user_b, 'forbidden' from rls_test_ids$$,
  '42501',
  'new row violates row-level security policy for table "player_profiles"',
  'remote User A cannot insert User B profile'
);
select extensions.throws_ok(
  $$insert into public.player_fish_collections (user_id, fish_id)
    select user_b, 'fish-forbidden' from rls_test_ids$$,
  '42501',
  'new row violates row-level security policy for table "player_fish_collections"',
  'remote User A cannot insert User B collection'
);
select extensions.throws_ok(
  $$insert into public.player_catches (user_id, fish_id)
    select user_b, 'fish-forbidden' from rls_test_ids$$,
  '42501',
  'new row violates row-level security policy for table "player_catches"',
  'remote User A cannot insert User B catch'
);

select extensions.is(
  (select count(*)::integer
     from public.player_profiles
    where user_id in (select user_a from rls_test_ids union all
                      select user_b from rls_test_ids)),
  1,
  'remote User A sees only one profile'
);
select extensions.is(
  (select count(*)::integer
     from public.player_fish_collections
    where user_id in (select user_a from rls_test_ids union all
                      select user_b from rls_test_ids)),
  1,
  'remote User A sees only one collection'
);
select extensions.is(
  (select count(*)::integer
     from public.player_catches
    where user_id in (select user_a from rls_test_ids union all
                      select user_b from rls_test_ids)),
  1,
  'remote User A sees only one catch'
);

update public.player_profiles
   set avatar_name = 'forbidden'
 where user_id = (select user_b from rls_test_ids);
update public.player_fish_collections
   set catch_count = 99
 where user_id = (select user_b from rls_test_ids);
update public.player_catches
   set fish_name = 'forbidden'
 where user_id = (select user_b from rls_test_ids);

set local role postgres;
select extensions.is(
  (select avatar_name from public.player_profiles
    where user_id = (select user_b from rls_test_ids)),
  'Remote User B',
  'remote User A cannot update User B profile'
);
select extensions.is(
  (select catch_count from public.player_fish_collections
    where user_id = (select user_b from rls_test_ids)),
  1,
  'remote User A cannot update User B collection'
);
select extensions.is(
  (select fish_name from public.player_catches
    where user_id = (select user_b from rls_test_ids)),
  'Remote Fish B',
  'remote User A cannot update User B catch'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  (select user_a::text from rls_test_ids),
  true
);
select extensions.throws_ok(
  $$delete from public.player_profiles
     where user_id = (select user_b from rls_test_ids)$$,
  '42501',
  'permission denied for table player_profiles',
  'remote User A cannot delete User B profile'
);
delete from public.player_fish_collections
 where user_id = (select user_b from rls_test_ids);
delete from public.player_catches
 where user_id = (select user_b from rls_test_ids);

set local role postgres;
select extensions.ok(
  exists (select 1 from public.player_profiles
           where user_id = (select user_b from rls_test_ids)),
  'remote User A cannot delete User B profile'
);
select extensions.ok(
  exists (select 1 from public.player_fish_collections
           where user_id = (select user_b from rls_test_ids)),
  'remote User A cannot delete User B collection'
);
select extensions.ok(
  exists (select 1 from public.player_catches
           where user_id = (select user_b from rls_test_ids)),
  'remote User A cannot delete User B catch'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  (select user_b::text from rls_test_ids),
  true
);
select extensions.is(
  (select count(*)::integer
     from public.player_profiles
    where user_id in (select user_a from rls_test_ids union all
                      select user_b from rls_test_ids)),
  1,
  'remote User B sees only one profile'
);
select extensions.is(
  (select count(*)::integer
     from public.player_fish_collections
    where user_id in (select user_a from rls_test_ids union all
                      select user_b from rls_test_ids)),
  1,
  'remote User B sees only one collection'
);
select extensions.is(
  (select count(*)::integer
     from public.player_catches
    where user_id in (select user_a from rls_test_ids union all
                      select user_b from rls_test_ids)),
  1,
  'remote User B sees only one catch'
);

select * from extensions.finish();
rollback;
