set search_path = extensions, public;

select extensions.plan(8);

select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.fishing_spots'::regclass),
  'fishing spots keep RLS enabled'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'fishing_spots'
      and policyname = 'admins read all fishing spots'
      and qual like '%is_admin%'
  ),
  'admins can read every fishing spot for moderation'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'fishing_spots'
      and policyname = 'admins update fishing spots'
      and qual like '%is_admin%'
      and with_check like '%is_admin%'
  ),
  'admins can update fishing spot moderation fields'
);
select extensions.ok(
  has_table_privilege('authenticated', 'public.fishing_spots', 'UPDATE'),
  'authenticated role has update privilege for RLS-gated admin updates'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.fishing_spots', 'INSERT'),
  'authenticated role cannot insert fishing spots'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.fishing_spots', 'DELETE'),
  'authenticated role cannot delete fishing spots'
);
select extensions.ok(
  has_table_privilege('anon', 'public.fishing_spots', 'SELECT')
    and not has_table_privilege('anon', 'public.fishing_spots', 'UPDATE'),
  'anonymous role can read but cannot mutate fishing spots'
);
select extensions.ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'fishing_spots'
      and policyname = 'public reads active verified fishing spots'
  ),
  'players still use the public verified spot read policy'
);

select * from extensions.finish();
