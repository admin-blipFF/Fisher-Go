-- Align remote catches table with the offline catch queue payload.
-- Additive only: safe to apply after 0001/0002.

alter table public.catches
  add column if not exists species_name text,
  add column if not exists length_cm numeric,
  add column if not exists weight_kg numeric,
  add column if not exists notes text,
  add column if not exists local_photo_name text,
  add column if not exists checkpoint_count integer not null default 0,
  add column if not exists checkpoint_path jsonb not null default '[]'::jsonb;

create index if not exists catches_user_caught_at_idx
  on public.catches(user_id, caught_at desc);
