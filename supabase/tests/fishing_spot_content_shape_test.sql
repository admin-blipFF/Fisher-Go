begin;

select plan(9);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.fishing_spots'::regclass
      and conname = 'fishing_spots_habitat_tags_shape_check'
  ),
  'habitat tags shape constraint exists'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.fishing_spots'::regclass
      and conname = 'fishing_spots_species_weights_shape_check'
  ),
  'species weights shape constraint exists'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fishing_spots'
      and policyname = 'admins update fishing spots'
      and qual like '%is_admin%'
      and with_check like '%is_admin%'
  ),
  'content updates remain behind admin RLS'
);

select ok(
  (
    select prosrc
    from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname = 'is_valid_fishing_spot_habitat_tags'
  ) like '%array_length%',
  'habitat tags are bounded'
);

select ok(
  (
    select prosrc
    from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname = 'is_valid_fishing_spot_species_weights'
  ) like '%jsonb_each%',
  'species weights validate each entry'
);

select ok(
  (
    select prosrc
    from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname = 'is_valid_fishing_spot_species_weights'
  ) like '%fish-%',
  'species weights require catalog-style fish ids'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fishing_spots'
      and column_name = 'habitat_tags'
  ),
  'habitat tags column remains present'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fishing_spots'
      and column_name = 'species_weights'
  ),
  'species weights column remains present'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fishing_spots'
      and column_name = 'reviewed_at'
  ),
  'content updates can retain review timestamp'
);

select * from finish();
rollback;
