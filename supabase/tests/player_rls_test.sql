set search_path = extensions, public;

begin;

select extensions.plan(27);

select extensions.ok(
  to_regclass('public.player_profiles') is not null,
  'player_profiles exists'
);
select extensions.ok(
  to_regclass('public.player_fish_collections') is not null,
  'player_fish_collections exists'
);
select extensions.ok(
  to_regclass('public.player_catches') is not null,
  'player_catches exists'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.player_profiles'::regclass),
  'player_profiles has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.player_fish_collections'::regclass),
  'player_fish_collections has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.player_catches'::regclass),
  'player_catches has RLS enabled'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.catches'::regclass),
  'catches has RLS enabled'
);
select extensions.ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename in ('player_profiles', 'player_fish_collections', 'player_catches')
      and (coalesce(qual, '') = 'true' or coalesce(with_check, '') = 'true')
  ),
  'player policies are not universally permissive'
);
select extensions.ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fish_species'
      and policyname = 'fish_species_anon_insert'
  ),
  'anonymous catalog insert policy is removed'
);
select extensions.ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles are readable by authenticated users'
  ),
  'legacy profiles do not have a public authenticated read policy'
);
select extensions.ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and coalesce(qual, '') = 'true'
  ),
  'legacy profile policies are not universally readable'
);

-- Seed auth users so the legacy catches table foreign key is exercised too.
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
    '00000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'rls-user-a@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    false
  ),
  (
    '00000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'rls-user-b@example.test',
    now(),
    '{}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    false
  )
on conflict (id) do nothing;

insert into public.profiles (id, display_name)
values
  ('00000000-0000-0000-0000-000000000002', 'User B');

insert into public.player_profiles (user_id, avatar_name)
values
  ('00000000-0000-0000-0000-000000000002', 'User B');
insert into public.player_fish_collections (user_id, fish_id)
values
  ('00000000-0000-0000-0000-000000000002', 'fish-002');
insert into public.player_catches (user_id, fish_id)
values
  ('00000000-0000-0000-0000-000000000002', 'fish-002');
insert into public.catches (user_id)
values
  ('00000000-0000-0000-0000-000000000002');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',
  true
);

select extensions.lives_ok(
  $$insert into public.player_profiles (user_id, avatar_name)
    values ('00000000-0000-0000-0000-000000000001', 'User A')$$,
  'User A can insert an own profile'
);
select extensions.lives_ok(
  $$insert into public.player_fish_collections (user_id, fish_id)
    values ('00000000-0000-0000-0000-000000000001', 'fish-001')$$,
  'User A can insert an own collection'
);
select extensions.lives_ok(
  $$insert into public.player_catches (user_id, fish_id)
    values ('00000000-0000-0000-0000-000000000001', 'fish-001')$$,
  'User A can insert an own catch'
);
select extensions.lives_ok(
  $$insert into public.catches (user_id)
    values ('00000000-0000-0000-0000-000000000001')$$,
  'User A can insert an own catch record'
);
select extensions.lives_ok(
  $$insert into public.profiles (id, display_name)
    values ('00000000-0000-0000-0000-000000000001', 'User A')$$,
  'User A can insert an own profile record'
);
select extensions.throws_ok(
  $$insert into public.player_profiles (user_id, avatar_name)
    values ('00000000-0000-0000-0000-000000000002', 'forbidden')$$,
  '42501',
  'new row violates row-level security policy for table "player_profiles"',
  'User A cannot insert User B profile'
);
select extensions.throws_ok(
  $$insert into public.catches (user_id)
    values ('00000000-0000-0000-0000-000000000002')$$,
  '42501',
  'new row violates row-level security policy for table "catches"',
  'User A cannot insert User B catch record'
);
select extensions.throws_ok(
  $$insert into public.profiles (id, display_name)
    values ('00000000-0000-0000-0000-000000000002', 'forbidden')$$,
  '42501',
  'new row violates row-level security policy for table "profiles"',
  'User A cannot insert User B legacy profile'
);

select extensions.is(
  (select count(*)::integer from public.player_profiles),
  1,
  'User A sees only one profile'
);
select extensions.is(
  (select count(*)::integer from public.player_fish_collections),
  1,
  'User A sees only one collection'
);
select extensions.is(
  (select count(*)::integer from public.player_catches),
  1,
  'User A sees only one catch'
);
select extensions.is(
  (select count(*)::integer from public.profiles),
  1,
  'User A sees only own legacy profile'
);

update public.player_fish_collections
   set catch_count = 99
 where user_id = '00000000-0000-0000-0000-000000000002';
set local role postgres;
select extensions.is(
  (select catch_count from public.player_fish_collections
    where user_id = '00000000-0000-0000-0000-000000000002'),
  1,
  'User A cannot mutate User B collection'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',
  true
);
delete from public.player_catches
 where user_id = '00000000-0000-0000-0000-000000000002';
set local role postgres;
select extensions.ok(
  exists (
    select 1 from public.player_catches
     where user_id = '00000000-0000-0000-0000-000000000002'
  ),
  'User A cannot delete User B catch'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',
  true
);
update public.catches
   set score = 99
 where user_id = '00000000-0000-0000-0000-000000000002';
set local role postgres;
select extensions.is(
  (select score from public.catches
    where user_id = '00000000-0000-0000-0000-000000000002'),
  1,
  'User A cannot update User B catch record'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',
  true
);
delete from public.catches
 where user_id = '00000000-0000-0000-0000-000000000002';
set local role postgres;
select extensions.ok(
  exists (
    select 1 from public.catches
     where user_id = '00000000-0000-0000-0000-000000000002'
  ),
  'User A cannot delete User B catch record'
);

select * from extensions.finish();
rollback;
