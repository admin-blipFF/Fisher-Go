-- Keep real-catch evidence small and limited to still-image formats.
-- This is additive because migration 0010 is already part of the linked
-- history and must not be edited in place.
update storage.buckets
set public = false,
    file_size_limit = 8388608,
    allowed_mime_types = array[
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif'
    ]::text[]
where id = 'catch-photos';

do $$
begin
  if not exists (
    select 1 from storage.buckets where id = 'catch-photos'
  ) then
    raise exception 'catch-photos storage bucket is missing';
  end if;
end;
$$;
