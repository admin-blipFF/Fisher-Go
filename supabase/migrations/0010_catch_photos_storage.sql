-- Private Storage bucket for authenticated real-catch evidence.
insert into storage.buckets (id, name, public)
values ('catch-photos', 'catch-photos', false)
on conflict (id) do update set public = excluded.public;

drop policy if exists "authenticated users upload own catch photos"
  on storage.objects;
create policy "authenticated users upload own catch photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'catch-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "authenticated users read own catch photos"
  on storage.objects;
create policy "authenticated users read own catch photos"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'catch-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "authenticated users update own catch photos"
  on storage.objects;
create policy "authenticated users update own catch photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'catch-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'catch-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "authenticated users delete own catch photos"
  on storage.objects;
create policy "authenticated users delete own catch photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'catch-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
