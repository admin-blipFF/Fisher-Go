set search_path = extensions, public;

begin;

select extensions.plan(4);

insert into auth.users (
  id, aud, role, email, email_confirmed_at, raw_app_meta_data,
  raw_user_meta_data, created_at, updated_at, is_anonymous
)
values (
  '00000000-0000-0000-0000-000000000051', 'authenticated', 'authenticated',
  'event-player@example.test', now(), '{}'::jsonb, '{}'::jsonb,
  now(), now(), false
);

set local role postgres;
with active_event as (
  insert into public.admin_events (
    title, description, starts_at, ends_at
  ) values (
    'Active event', 'Valid test event', now() - interval '1 hour',
    now() + interval '1 hour'
  ) returning id
), expired_event as (
  insert into public.admin_events (
    title, description, starts_at, ends_at
  ) values (
    'Expired event', 'Expired test event', now() - interval '2 hours',
    now() - interval '1 hour'
  ) returning id
)
insert into public.fish_rate_boosts (
  event_id, fish_id, fish_name, multiplier, starts_at, ends_at
)
select id, 'fish-072', '石斑魚', 2.5, now() - interval '1 hour',
       now() + interval '1 hour'
  from active_event
union all
select id, 'fish-073', '青斑', 5.0, now() - interval '2 hours',
       now() + interval '1 hour'
  from expired_event;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000051',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000051","email":"event-player@example.test","role":"authenticated","aud":"authenticated"}',
  true
);

select extensions.is(
  (select count(*)::integer from public.get_active_fishing_event_config()),
  1,
  'only a boost under an active parent event is returned'
);
select extensions.is(
  (select fish_id from public.get_active_fishing_event_config() limit 1),
  'fish-072',
  'active event configuration preserves stable fish id'
);
select extensions.is(
  (select multiplier from public.get_active_fishing_event_config() limit 1),
  2.5::numeric,
  'active event configuration preserves server multiplier'
);
select extensions.is(
  (select event_title from public.get_active_fishing_event_config() limit 1),
  'Active event',
  'active event configuration returns the server event label'
);

select * from extensions.finish();
rollback;
