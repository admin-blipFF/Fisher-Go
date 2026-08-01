-- Keep real-catch evidence private and out of public competition until an
-- admin has reviewed the submitted photo and metadata.
alter table public.catches
  add column if not exists moderation_status text not null default 'approved',
  add column if not exists moderation_reason text,
  add column if not exists moderated_by uuid references auth.users(id),
  add column if not exists moderated_at timestamptz;

alter table public.catches
  drop constraint if exists catches_moderation_status_check;

alter table public.catches
  add constraint catches_moderation_status_check
  check (moderation_status in ('pending', 'approved', 'rejected', 'suspended'));

create index if not exists catches_moderation_queue_idx
  on public.catches (moderation_status, caught_at desc)
  where is_real_catch_proof = true;

-- Legacy rows keep their previous leaderboard behavior through the approved
-- default. New player inserts and non-admin updates are forced through the
-- pending/immutable path, so a client cannot self-approve evidence.
create or replace function public.guard_catch_moderation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if public.is_admin() then
    if tg_op = 'UPDATE'
       and new.moderation_status is distinct from old.moderation_status then
      new.moderated_by := auth.uid();
      new.moderated_at := now();
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.moderation_status := 'pending';
    new.moderation_reason := null;
    new.moderated_by := null;
    new.moderated_at := null;
  else
    new.moderation_status := old.moderation_status;
    new.moderation_reason := old.moderation_reason;
    new.moderated_by := old.moderated_by;
    new.moderated_at := old.moderated_at;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_catch_moderation_trigger on public.catches;
create trigger guard_catch_moderation_trigger
before insert or update on public.catches
for each row execute function public.guard_catch_moderation();

drop policy if exists "admins read all catches" on public.catches;
create policy "admins read all catches"
  on public.catches for select
  to authenticated
  using (public.is_admin());

drop policy if exists "admins update catches" on public.catches;
create policy "admins update catches"
  on public.catches for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admins read catch photos" on storage.objects;
create policy "admins read catch photos"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'catch-photos'
    and public.is_admin()
  );

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
    and c.moderation_status = 'approved'
    and c.verified_at is not null
    and c.verified_at >= now() - make_interval(
      days => greatest(1, least(coalesce(window_days, 7), 31))
    )
  order by c.length_cm desc nulls last, c.score desc, c.verified_at asc
  limit greatest(1, least(coalesce(limit_count, 50), 100));
$$;

revoke all on function public.guard_catch_moderation() from public;
revoke all on function public.get_public_leaderboard(integer, integer) from public;
grant execute on function public.get_public_leaderboard(integer, integer)
  to authenticated;
