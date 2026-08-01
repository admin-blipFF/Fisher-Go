set search_path = extensions, public;

begin;

select extensions.plan(8);

insert into auth.users (
  id, aud, role, email, email_confirmed_at, raw_app_meta_data,
  raw_user_meta_data, created_at, updated_at, is_anonymous
)
values
  (
    '00000000-0000-0000-0000-000000000061', 'authenticated', 'authenticated',
    'catch-moderation-player@example.test', now(), '{}'::jsonb, '{}'::jsonb,
    now(), now(), false
  ),
  (
    '00000000-0000-0000-0000-000000000062', 'authenticated', 'authenticated',
    'catch-moderation-admin@example.test', now(), '{}'::jsonb, '{}'::jsonb,
    now(), now(), false
  );

insert into public.admin_users (email)
values ('catch-moderation-admin@example.test');

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000061","email":"catch-moderation-player@example.test","role":"authenticated","aud":"authenticated"}',
  true
);

insert into public.catches (
  id, user_id, species_name, caught_at, is_real_catch_proof,
  verified_at, moderation_status, score
)
values (
  '00000000-0000-0000-0000-000000000063',
  '00000000-0000-0000-0000-000000000061',
  '測試石斑', now(), true, now(), 'approved', 99
);

select extensions.is(
  (select moderation_status from public.catches
   where id = '00000000-0000-0000-0000-000000000063'),
  'pending',
  'new player real catches always enter moderation pending'
);
select extensions.is(
  (select count(*)::integer from public.get_public_leaderboard(7, 50)
   where species_name = '測試石斑'),
  0,
  'pending real catches stay out of the public leaderboard'
);

update public.catches
set moderation_status = 'approved', moderation_reason = 'player bypass'
where id = '00000000-0000-0000-0000-000000000063';
select extensions.is(
  (select moderation_status from public.catches
   where id = '00000000-0000-0000-0000-000000000063'),
  'pending',
  'non-admin players cannot self-approve a catch'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000062","email":"catch-moderation-admin@example.test","role":"authenticated","aud":"authenticated"}',
  true
);

update public.catches
set moderation_status = 'approved', moderation_reason = 'photo reviewed'
where id = '00000000-0000-0000-0000-000000000063';
select extensions.is(
  (select moderation_status from public.catches
   where id = '00000000-0000-0000-0000-000000000063'),
  'approved',
  'admin can approve a real catch'
);
select extensions.is(
  (select moderated_by::text from public.catches
   where id = '00000000-0000-0000-0000-000000000063'),
  '00000000-0000-0000-0000-000000000062',
  'admin approval records the moderator'
);
select extensions.ok(
  (select moderated_at is not null from public.catches
   where id = '00000000-0000-0000-0000-000000000063'),
  'admin approval records the moderation timestamp'
);
select extensions.is(
  (select count(*)::integer from public.get_public_leaderboard(7, 50)
   where species_name = '測試石斑'),
  1,
  'approved real catches enter the public leaderboard'
);

update public.catches
set moderation_status = 'suspended', moderation_reason = 'evidence rejected'
where id = '00000000-0000-0000-0000-000000000063';
select extensions.is(
  (select count(*)::integer from public.get_public_leaderboard(7, 50)
   where species_name = '測試石斑'),
  0,
  'suspended real catches leave the public leaderboard'
);

select * from extensions.finish();
rollback;
