begin;

select plan(1);

select ok(
  exists (
    select 1
    from storage.buckets
    where id = 'catch-photos'
      and public is false
      and file_size_limit = 8388608
      and allowed_mime_types @> array[
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/heic',
        'image/heif'
      ]::text[]
      and not exists (
        select 1
        from unnest(coalesce(allowed_mime_types, array[]::text[])) as mime
        where mime like 'video/%'
      )
  ),
  'catch photo bucket is private, bounded, and still-image only'
);

select * from finish();
rollback;
