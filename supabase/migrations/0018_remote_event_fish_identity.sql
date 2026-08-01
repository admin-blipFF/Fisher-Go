-- Remote event boosts need a stable catalog key.
-- Keep fish_name for compatibility with existing admin rows and inspection.

alter table public.fish_rate_boosts
  add column if not exists fish_id text;

create index if not exists fish_rate_boosts_fish_id_idx
  on public.fish_rate_boosts(fish_id);
