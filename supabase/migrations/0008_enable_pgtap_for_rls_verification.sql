-- Keep the linked project's two-user RLS verification runnable.
-- The extensions schema is not exposed through the PostgREST API config.
create extension if not exists pgtap with schema extensions;
