-- Align the remote catch table with the real-photo verification payload.
-- These fields are additive so existing catch rows remain readable.
alter table public.catches
  add column if not exists is_real_catch_proof boolean not null default false,
  add column if not exists recognized_species_id text,
  add column if not exists recognition_confidence numeric,
  add column if not exists verified_at timestamptz;

create index if not exists catches_verified_leaderboard_idx
  on public.catches (verified_at desc, length_cm desc, score desc)
  where is_real_catch_proof = true and verified_at is not null;

-- Public competition data is intentionally aggregate-like: the function never
-- returns user_id, private notes, coordinates, or photo storage paths.
create or replace function public.get_public_leaderboard(
  window_days integer default 7,
  limit_count integer default 50
)
returns table (
  species_id uuid,
  species_name text,
  length_cm numeric,
  verified_at timestamptz,
  score integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.species_id,
    c.species_name,
    c.length_cm,
    c.verified_at,
    c.score
  from public.catches c
  where c.is_real_catch_proof = true
    and c.verified_at is not null
    and c.verified_at >= now() - make_interval(
      days => greatest(1, least(coalesce(window_days, 7), 31))
    )
  order by c.length_cm desc nulls last, c.score desc, c.verified_at asc
  limit greatest(1, least(coalesce(limit_count, 50), 100));
$$;

revoke all on function public.get_public_leaderboard(integer, integer)
  from public;
grant execute on function public.get_public_leaderboard(integer, integer)
  to authenticated;
