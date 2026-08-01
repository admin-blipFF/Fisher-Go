-- The linked pgTAP runner connects through Supabase's authenticator role.
-- Keep this limited to the non-API extensions schema and test functions.
grant usage on schema extensions to authenticator;
grant execute on all functions in schema extensions to authenticator;
