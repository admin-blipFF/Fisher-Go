-- Extend the privacy-safe analytics allowlist for the map idle boundary.
-- This is additive because migration 0019 may already be applied remotely.

alter table public.analytics_events
  drop constraint if exists analytics_events_event_name_check;

alter table public.analytics_events
  add constraint analytics_events_event_name_check check (event_name in (
    'app_bootstrap',
    'app_error',
    'auth_identity_selected',
    'map_ready',
    'map_idle',
    'map_fallback',
    'minigame_started',
    'minigame_completed',
    'catch_upload',
    'catch_sync',
    'reward_claimed'
  ));

create or replace function public.record_analytics_event(
  p_event_name text,
  p_occurred_at timestamptz default null,
  p_build_time text default '',
  p_release_id text default '',
  p_environment text default '',
  p_fields jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor_hash text;
  v_received_at timestamptz := clock_timestamp();
  safe_fields jsonb;
begin
  if auth.uid() is null then
    raise exception 'authenticated session required' using errcode = '42501';
  end if;

  if p_event_name is null or p_event_name not in (
    'app_bootstrap',
    'app_error',
    'auth_identity_selected',
    'map_ready',
    'map_idle',
    'map_fallback',
    'minigame_started',
    'minigame_completed',
    'catch_upload',
    'catch_sync',
    'reward_claimed'
  ) then
    raise exception 'unsupported analytics event' using errcode = '22023';
  end if;
  if p_fields is null or jsonb_typeof(p_fields) <> 'object' then
    raise exception 'analytics fields must be an object' using errcode = '22023';
  end if;
  if char_length(p_fields::text) > 12000 then
    raise exception 'analytics fields are too large' using errcode = '22023';
  end if;

  actor_hash := encode(digest(auth.uid()::text, 'sha256'), 'hex');

  if (
    select count(*)
      from public.analytics_events ae
     where ae.actor_key = actor_hash
       and ae.received_at >= v_received_at - interval '1 minute'
  ) >= 120 then
    return;
  end if;

  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
    into safe_fields
    from jsonb_each(p_fields)
   where char_length(key) <= 64
     and jsonb_typeof(value) in ('null', 'string', 'number', 'boolean')
     and lower(key) not like '%user%'
     and lower(key) not like '%email%'
     and lower(key) not like '%token%'
     and lower(key) not like '%password%'
     and lower(key) not like '%latitude%'
     and lower(key) not like '%longitude%'
     and lower(key) not like '%photo%'
     and lower(key) not like '%path%'
     and lower(key) not like '%note%'
     and lower(key) not like '%stack%'
     and lower(key) not like '%exception%';

  insert into public.analytics_events (
    actor_key,
    event_name,
    occurred_at,
    received_at,
    build_time,
    release_id,
    environment,
    fields
  ) values (
    actor_hash,
    p_event_name,
    greatest(
      v_received_at - interval '30 days',
      least(coalesce(p_occurred_at, v_received_at), v_received_at + interval '5 minutes')
    ),
    v_received_at,
    left(coalesce(trim(p_build_time), ''), 120),
    left(coalesce(trim(p_release_id), ''), 160),
    left(coalesce(trim(p_environment), ''), 40),
    safe_fields
  );
end;
$$;

revoke all on function public.record_analytics_event(text, timestamptz, text, text, text, jsonb)
  from public, anon;
grant execute on function public.record_analytics_event(text, timestamptz, text, text, text, jsonb)
  to authenticated;
