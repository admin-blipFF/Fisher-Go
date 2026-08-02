begin;

select extensions.plan(18);

select extensions.ok(
  to_regclass('public.profiles') is not null,
  'legacy profiles exists'
);
select extensions.ok(
  to_regclass('public.catches') is not null,
  'legacy catches exists'
);
select extensions.ok(
  (select relrowsecurity
     from pg_class
    where oid = 'public.profiles'::regclass),
  'legacy profiles has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity
     from pg_class
    where oid = 'public.catches'::regclass),
  'legacy catches has RLS enabled'
);
select extensions.ok(
  not exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'profiles'
       and policyname = 'profiles are readable by authenticated users'
  ),
  'legacy profiles do not expose a universal read policy'
);
select extensions.ok(
  not exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'profiles'
       and coalesce(qual, '') = 'true'
  ),
  'legacy profiles are not universally readable'
);
select extensions.ok(
  exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'profiles'
       and coalesce(qual, '') like '%auth.uid()%'
  ),
  'legacy profile policy checks auth.uid()'
);

-- Auth user rows are created by the protected REST sign-in step. All rows
-- below are transaction-local and are rolled back at the end of this file.
set local role postgres;
delete from public.catches
 where user_id in (
   '__FISHERGO_USER_A__'::uuid,
   '__FISHERGO_USER_B__'::uuid
 );
delete from public.profiles
 where id in (
   '__FISHERGO_USER_A__'::uuid,
   '__FISHERGO_USER_B__'::uuid
 );
insert into public.profiles (id, display_name)
values ('__FISHERGO_USER_B__'::uuid, 'RLS probe User B');
insert into public.catches (user_id, species_name, score)
values ('__FISHERGO_USER_B__'::uuid, 'RLS probe catch B', 1);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '__FISHERGO_USER_A__',
  true
);

select extensions.lives_ok(
  $$insert into public.profiles (id, display_name)
    values ('__FISHERGO_USER_A__'::uuid, 'RLS probe User A')$$,
  'User A can insert an own profile record'
);
select extensions.lives_ok(
  $$insert into public.catches (user_id, species_name, score)
    values ('__FISHERGO_USER_A__'::uuid, 'RLS probe catch A', 1)$$,
  'User A can insert an own catch record'
);
select extensions.throws_ok(
  $$insert into public.profiles (id, display_name)
    values ('__FISHERGO_USER_B__'::uuid, 'forbidden')$$,
  '42501',
  'new row violates row-level security policy for table "profiles"',
  'User A cannot insert User B legacy profile'
);
select extensions.throws_ok(
  $$insert into public.catches (user_id, species_name)
    values ('__FISHERGO_USER_B__'::uuid, 'forbidden')$$,
  '42501',
  'new row violates row-level security policy for table "catches"',
  'User A cannot insert User B catch record'
);
select extensions.is(
  (select count(*)::integer
     from public.profiles
    where id in ('__FISHERGO_USER_A__'::uuid, '__FISHERGO_USER_B__'::uuid)),
  1,
  'User A sees only own legacy profile'
);
select extensions.is(
  (select count(*)::integer
     from public.catches
    where user_id in (
      '__FISHERGO_USER_A__'::uuid,
      '__FISHERGO_USER_B__'::uuid
    )),
  1,
  'User A sees only own catch record'
);

update public.catches
   set score = 99
 where user_id = '__FISHERGO_USER_B__'::uuid;
set local role postgres;
select extensions.is(
  (select score
     from public.catches
    where user_id = '__FISHERGO_USER_B__'::uuid),
  1,
  'User A cannot update User B catch record'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '__FISHERGO_USER_A__',
  true
);
delete from public.catches
 where user_id = '__FISHERGO_USER_B__'::uuid;
set local role postgres;
select extensions.ok(
  exists (
    select 1
      from public.catches
     where user_id = '__FISHERGO_USER_B__'::uuid
  ),
  'User A cannot delete User B catch record'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '__FISHERGO_USER_B__',
  true
);
select extensions.is(
  (select count(*)::integer
     from public.profiles
    where id = '__FISHERGO_USER_B__'::uuid),
  1,
  'User B sees only own legacy profile'
);
select extensions.is(
  (select count(*)::integer
     from public.catches
    where user_id = '__FISHERGO_USER_B__'::uuid),
  1,
  'User B sees only own catch record'
);
select extensions.lives_ok(
  $$update public.profiles
       set display_name = 'RLS probe User B updated'
     where id = '__FISHERGO_USER_B__'::uuid$$,
  'User B can update an own legacy profile'
);

select * from extensions.finish();
rollback;
