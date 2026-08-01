-- Require a fresh, server-checked player position before a virtual fishing
-- session can unlock a reward. Exact player coordinates are never persisted.

alter table public.fishing_spots
  add column if not exists gameplay_radius_m double precision;

update public.fishing_spots
   set gameplay_radius_m = 250
 where gameplay_radius_m is null;

alter table public.fishing_spots
  alter column gameplay_radius_m set default 250,
  alter column gameplay_radius_m set not null;

do $$
begin
  if not exists (
    select 1
      from pg_constraint
     where conrelid = 'public.fishing_spots'::regclass
       and conname = 'fishing_spots_gameplay_radius_m_check'
  ) then
    alter table public.fishing_spots
      add constraint fishing_spots_gameplay_radius_m_check
      check (gameplay_radius_m between 25 and 500);
  end if;
end;
$$;

alter table public.player_fishing_sessions
  add column if not exists location_verified boolean not null default false,
  add column if not exists location_distance_m double precision,
  add column if not exists location_accuracy_m double precision;

alter table public.player_fishing_sessions
  drop constraint if exists player_fishing_sessions_location_distance_m_check,
  drop constraint if exists player_fishing_sessions_location_accuracy_m_check;

alter table public.player_fishing_sessions
  add constraint player_fishing_sessions_location_distance_m_check
  check (location_distance_m is null or location_distance_m >= 0),
  add constraint player_fishing_sessions_location_accuracy_m_check
  check (location_accuracy_m is null or location_accuracy_m between 0 and 250);

create index if not exists player_fishing_sessions_location_idx
  on public.player_fishing_sessions (user_id, location_verified, created_at desc);

-- Retain the old signature for a clear upgrade error, but remove its ability
-- to create a reward-bearing session. New clients must use the six-argument
-- location-verified signature below.
create or replace function public.start_virtual_fishing_session(
  p_spot_id text,
  p_lure_id text,
  p_fish_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Keep the legacy inputs opaque while making the upgrade error independent
  -- of their values; this signature must never create a session.
  if p_spot_id is null and p_lure_id is null and p_fish_id is null then
    raise exception 'location verification required' using errcode = '42501';
  end if;
  raise exception 'location verification required' using errcode = '42501';
end;
$$;

create or replace function public.start_virtual_fishing_session(
  p_spot_id text,
  p_lure_id text,
  p_fish_id text,
  p_player_latitude double precision,
  p_player_longitude double precision,
  p_accuracy_m double precision
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_id text;
  now_at timestamptz;
  bite_delay_ms integer;
  session_id uuid;
  spot_row public.fishing_spots%rowtype;
  distance_m double precision;
  allowed_radius_m double precision;
begin
  if auth.uid() is null then
    raise exception 'authenticated session required' using errcode = '42501';
  end if;
  if p_spot_id is null or char_length(trim(p_spot_id)) = 0
     or char_length(p_spot_id) > 80 then
    raise exception 'invalid fishing spot' using errcode = '22023';
  end if;
  if p_lure_id is null or p_lure_id not in (
    'basic_bait', 'harbor_lure', 'island_lure'
  ) then
    raise exception 'invalid fishing lure' using errcode = '22023';
  end if;
  if p_fish_id is null or char_length(trim(p_fish_id)) = 0
     or char_length(p_fish_id) > 80 then
    raise exception 'invalid fishing fish' using errcode = '22023';
  end if;
  if p_player_latitude is null or p_player_latitude not between -90 and 90
     or p_player_longitude is null or p_player_longitude not between -180 and 180
     or p_accuracy_m is null or p_accuracy_m < 0 or p_accuracy_m > 250 then
    raise exception 'invalid player location' using errcode = '22023';
  end if;

  actor_id := auth.uid()::text;
  perform pg_advisory_xact_lock(hashtextextended(actor_id, 0));

  select *
    into spot_row
    from public.fishing_spots fs
   where fs.id = trim(p_spot_id)
     and fs.active = true
     and fs.verification_status = 'verified';
  if not found then
    raise exception 'fishing spot is not active' using errcode = '22023';
  end if;

  now_at := clock_timestamp();
  if (
    select count(*)
      from public.player_fishing_sessions pfs
     where pfs.user_id = actor_id
       and pfs.created_at >= now_at - interval '60 seconds'
  ) >= 6 then
    raise exception 'fishing session start rate limit exceeded' using errcode = 'P0001';
  end if;

  distance_m := 6371008.8 * acos(
    greatest(-1.0, least(1.0,
      sin(radians(p_player_latitude)) * sin(radians(spot_row.latitude)) +
      cos(radians(p_player_latitude)) * cos(radians(spot_row.latitude)) *
      cos(radians(spot_row.longitude - p_player_longitude))
    ))
  );
  allowed_radius_m := spot_row.gameplay_radius_m + least(p_accuracy_m, 75);
  if distance_m > allowed_radius_m then
    raise exception 'player is too far from fishing spot' using errcode = '22023';
  end if;

  update public.player_fishing_sessions
     set status = 'expired',
         resolved_at = now_at
   where user_id = actor_id
     and status = 'armed';

  bite_delay_ms := 1600 + floor(random() * 1001)::integer;
  insert into public.player_fishing_sessions (
    user_id,
    spot_id,
    lure_id,
    fish_id,
    started_at,
    bite_at,
    success_window_ends_at,
    expires_at,
    location_verified,
    location_distance_m,
    location_accuracy_m
  ) values (
    actor_id,
    trim(p_spot_id),
    p_lure_id,
    trim(p_fish_id),
    now_at,
    now_at + bite_delay_ms * interval '1 millisecond',
    now_at + (bite_delay_ms + 900) * interval '1 millisecond',
    now_at + interval '12 seconds',
    true,
    distance_m,
    p_accuracy_m
  ) returning id into session_id;

  return jsonb_build_object(
    'session_id', session_id,
    'fish_id', trim(p_fish_id),
    'bite_delay_ms', bite_delay_ms,
    'success_window_ms', 900,
    'expires_in_ms', 12000,
    'location_verified', true
  );
end;
$$;

revoke all on function public.start_virtual_fishing_session(text, text, text)
  from public, anon, authenticated;
revoke all on function public.start_virtual_fishing_session(
  text, text, text, double precision, double precision, double precision
) from public, anon;
grant execute on function public.start_virtual_fishing_session(
  text, text, text, double precision, double precision, double precision
) to authenticated;
