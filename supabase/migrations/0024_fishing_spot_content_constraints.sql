-- Keep admin-edited habitat and spawn content bounded and machine-readable.

create or replace function public.is_valid_fishing_spot_habitat_tags(
  tags text[]
)
returns boolean
language sql
immutable
as $$
  select coalesce(array_length(tags, 1), 0) <= 12
    and not exists (
      select 1
      from unnest(tags) as tag
      where tag is null
         or tag !~ '^[a-z0-9][a-z0-9-]*$'
    );
$$;

create or replace function public.is_valid_fishing_spot_species_weights(
  weights jsonb
)
returns boolean
language sql
immutable
as $$
  select jsonb_typeof(weights) = 'object'
    and not exists (
      select 1
      from jsonb_each(weights) as entry(key, value)
      where key !~ '^fish-[0-9]+$'
         or jsonb_typeof(value) <> 'number'
         or case
              when jsonb_typeof(value) = 'number'
                then (value #>> '{}')::numeric <= 0
                  or (value #>> '{}')::numeric > 100
              else true
            end
    );
$$;

revoke all on function public.is_valid_fishing_spot_habitat_tags(text[])
  from public;
revoke all on function public.is_valid_fishing_spot_species_weights(jsonb)
  from public;
grant execute on function public.is_valid_fishing_spot_habitat_tags(text[])
  to anon, authenticated;
grant execute on function public.is_valid_fishing_spot_species_weights(jsonb)
  to anon, authenticated;

alter table public.fishing_spots
  drop constraint if exists fishing_spots_habitat_tags_shape_check;
alter table public.fishing_spots
  add constraint fishing_spots_habitat_tags_shape_check
  check (public.is_valid_fishing_spot_habitat_tags(habitat_tags));

alter table public.fishing_spots
  drop constraint if exists fishing_spots_species_weights_shape_check;
alter table public.fishing_spots
  add constraint fishing_spots_species_weights_shape_check
  check (public.is_valid_fishing_spot_species_weights(species_weights));

-- Re-state the write boundary next to the content constraints so future
-- changes cannot accidentally expose content editing to ordinary players.
drop policy if exists "admins update fishing spots" on public.fishing_spots;
create policy "admins update fishing spots"
  on public.fishing_spots for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());
