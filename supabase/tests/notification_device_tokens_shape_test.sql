begin;

select plan(11);

select ok(
  to_regclass('public.player_notification_tokens') is not null,
  'notification token table is private'
);
select ok(
  (select relrowsecurity
   from pg_class
   where oid = 'public.player_notification_tokens'::regclass),
  'notification token table enables RLS'
);
select has_table('public', 'player_notification_tokens',
  'notification token table exists');
select has_column('public', 'player_notification_tokens', 'user_id',
  'notification tokens are user-owned');
select has_column('public', 'player_notification_tokens', 'provider',
  'notification tokens record provider');
select has_column('public', 'player_notification_tokens', 'token',
  'notification tokens record token');
select has_function(
  'public', 'register_notification_device_token', array['text', 'text', 'text'],
  'register notification token RPC exists'
);
select has_function(
  'public', 'unregister_notification_device_token', array['text', 'text'],
  'unregister notification token RPC exists'
);
select ok(
  not has_table_privilege('anon', 'public.player_notification_tokens', 'select'),
  'anonymous cannot read notification tokens'
);
select ok(
  not has_table_privilege(
    'authenticated', 'public.player_notification_tokens', 'select'
  ),
  'authenticated clients cannot read raw notification tokens'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.register_notification_device_token(text,text,text)',
    'execute'
  ),
  'anonymous cannot register notification tokens'
);

select * from finish();
rollback;
