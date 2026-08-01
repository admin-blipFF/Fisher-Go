-- Server-authoritative active event configuration.
--
-- Players receive only the currently valid event/boost projection. The
-- client no longer decides whether a parent event has expired by querying the
-- raw boost table directly.

create index if not exists admin_events_active_window_idx
  on public.admin_events(starts_at, ends_at);
create index if not exists fish_rate_boosts_active_window_idx
  on public.fish_rate_boosts(starts_at, ends_at);

create or replace function public.get_active_fishing_event_config()
returns table (
  event_id uuid,
  event_title text,
  event_description text,
  fish_id text,
  fish_name text,
  multiplier numeric,
  ends_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ae.id,
    ae.title,
    ae.description,
    frb.fish_id,
    frb.fish_name,
    frb.multiplier,
    least(ae.ends_at, frb.ends_at) as ends_at
  from public.admin_events ae
  join public.fish_rate_boosts frb on frb.event_id = ae.id
  where auth.uid() is not null
    and ae.starts_at <= now()
    and (ae.ends_at is null or ae.ends_at >= now())
    and frb.starts_at <= now()
    and (frb.ends_at is null or frb.ends_at >= now())
  order by ae.starts_at desc, ae.id, frb.fish_id nulls last, frb.fish_name;
$$;

revoke all on function public.get_active_fishing_event_config()
  from public, anon;
grant execute on function public.get_active_fishing_event_config()
  to authenticated;
