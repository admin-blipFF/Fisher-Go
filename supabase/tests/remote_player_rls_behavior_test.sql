set search_path = extensions, public;

begin;

select extensions.plan(25);

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

-- The player_* tables keep text ownership for app compatibility and do not
-- require auth.users rows. This lets the linked check exercise real RLS
-- behavior with JWT claims without mutating managed authentication data.
create temp table rls_test_ids as
select gen_random_uuid()::text as user_a, gen_random_uuid()::text as user_b;
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
  (select user_a from rls_test_ids),
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
  (select user_a from rls_test_ids),
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
  (select user_b from rls_test_ids),
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
