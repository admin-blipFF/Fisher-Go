-- Keep private Storage object paths separate from public URL fields.
-- The client resolves this path to a short-lived signed URL on demand.
alter table public.catches
  add column if not exists photo_storage_path text;

create index if not exists catches_photo_storage_path_idx
  on public.catches(photo_storage_path)
  where photo_storage_path is not null;
