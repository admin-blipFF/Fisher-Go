-- Supabase CLI's linked pgTAP runner uses cli_login_postgres. The role exists
-- on linked projects, but not in every local Supabase stack, so keep local
-- migration resets portable.
do $$
begin
  if exists (
    select 1
      from pg_roles
     where rolname = 'cli_login_postgres'
  ) then
    execute 'grant usage on schema extensions to cli_login_postgres';
    execute 'grant execute on all functions in schema extensions to cli_login_postgres';
  end if;
end
$$;
