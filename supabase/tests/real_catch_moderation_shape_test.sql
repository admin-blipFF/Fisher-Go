set search_path = extensions, public;

select extensions.plan(15);

select extensions.ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'catches'
      and column_name = 'moderation_status'
  ),
  'catches expose a moderation status'
);
select extensions.ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'catches'
      and column_name = 'moderation_reason'
  ),
  'catches expose a moderation reason'
);
select extensions.ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'catches'
      and column_name = 'moderated_by'
  ),
  'catches expose the moderating admin id'
);
select extensions.ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'catches'
      and column_name = 'moderated_at'
  ),
  'catches expose the moderation timestamp'
);
select extensions.ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.catches'::regclass
      and pg_get_constraintdef(oid) like '%moderation_status%pending%approved%'
  ),
  'catch moderation status is bounded'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where proname = 'guard_catch_moderation'
  ),
  'catch moderation has a server trigger guard'
);
select extensions.ok(
  exists (
    select 1 from pg_trigger
    where tgrelid = 'public.catches'::regclass
      and tgname = 'guard_catch_moderation_trigger'
  ),
  'catch moderation guard is attached to catches'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'catches'
      and policyname = 'admins read all catches'
      and qual like '%is_admin%'
  ),
  'admins can read catches for moderation'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'catches'
      and policyname = 'admins update catches'
      and qual like '%is_admin%'
      and with_check like '%is_admin%'
  ),
  'admins can update catch moderation fields'
);
select extensions.ok(
  has_table_privilege('authenticated', 'public.catches', 'UPDATE'),
  'authenticated role keeps update privilege for trigger and admin RLS'
);
select extensions.ok(
  exists (
    select 1 from pg_proc
    where oid = 'public.get_public_leaderboard(integer,integer)'::regprocedure
      and pg_get_functiondef(oid) like '%moderation_status = ''approved''%'
  ),
  'public leaderboard filters to approved catches'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'admins read catch photos'
  ),
  'admins can review private catch photos through storage policy'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'admins read catch photos'
      and qual like '%is_admin%'
  ),
  'admin catch photo access remains admin-gated'
);
select extensions.ok(
  exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and tablename = 'catches'
      and indexname = 'catches_moderation_queue_idx'
  ),
  'catch moderation queue has a bounded index'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.is_admin()',
    'EXECUTE'
  ),
  'moderation relies on the existing admin boundary'
);

select * from extensions.finish();
