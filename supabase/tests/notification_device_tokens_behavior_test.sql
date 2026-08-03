set search_path = extensions, public;

begin;

select extensions.plan(8);

insert into auth.users (
  id, aud, role, email, email_confirmed_at, raw_app_meta_data,
  raw_user_meta_data, created_at, updated_at, is_anonymous
)
values
  ('00000000-0000-0000-0000-000000000071', 'authenticated', 'authenticated',
   'notification-a@example.test', now(), '{}'::jsonb, '{}'::jsonb,
   now(), now(), false),
  ('00000000-0000-0000-0000-000000000072', 'authenticated', 'authenticated',
   'notification-b@example.test', now(), '{}'::jsonb, '{}'::jsonb,
   now(), now(), false);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-0000-0000-000000000071', true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000071","role":"authenticated","aud":"authenticated"}',
  true
);

select extensions.lives_ok(
  $$select public.register_notification_device_token(
    'android', 'fcm', 'notification-token-a-1234567890'
  )$$,
  'authenticated player can register a notification token'
);
select extensions.is(
  public.register_notification_device_token(
    'android', 'fcm', 'notification-token-a-1234567890'
  ) is not null,
  true,
  'registering the same token is idempotent'
);
select extensions.throws_ok(
  $$select public.register_notification_device_token(
    'desktop', 'fcm', 'notification-token-invalid'
  )$$,
  '22023',
  'unsupported notification platform',
  'unsupported platforms are rejected'
);
select extensions.throws_ok(
  $$select public.register_notification_device_token(
    'android', 'fcm', 'short'
  )$$,
  '22023',
  'invalid notification token length',
  'short provider tokens are rejected'
);

set local role postgres;
select extensions.is(
  (select count(*)::integer from public.player_notification_tokens),
  1,
  'duplicate registration keeps one token row'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '00000000-0000-0000-0000-000000000072', true
);
select extensions.throws_ok(
  $$select * from public.player_notification_tokens$$,
  '42501',
  'permission denied for table player_notification_tokens',
  'a different player cannot read another player token'
);
select extensions.is(
  public.unregister_notification_device_token(
    'fcm', 'notification-token-a-1234567890'
  ),
  false,
  'a different player cannot unregister another player token'
);

set local role postgres;
select extensions.is(
  (select count(*)::integer from public.player_notification_tokens),
  1,
  'cross-player unregister leaves the token intact'
);

select * from extensions.finish();
rollback;
