-- Server-validated bite and pull sessions.
--
-- A virtual catch can only earn a ticket after the server has issued a
-- one-time session and resolved the pull inside its bite window. The client
-- still owns animation and haptics, but it no longer owns the reward result.

create table if not exists public.player_fishing_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  spot_id text not null,
  lure_id text not null check (lure_id in ('basic_bait', 'harbor_lure', 'island_lure')),
  fish_id text not null,
  started_at timestamptz not null,
  bite_at timestamptz not null,
  success_window_ends_at timestamptz not null,
  expires_at timestamptz not null,
  status text not null default 'armed' check (
    status in ('armed', 'resolved_success', 'resolved_miss', 'expired')
  ),
  pull_elapsed_ms integer,
  resolved_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.player_fishing_sessions enable row level security;
revoke all on table public.player_fishing_sessions from anon, authenticated;
create policy "players read own fishing sessions"
  on public.player_fishing_sessions for select
  to authenticated
  using (auth.uid()::text = user_id);
grant select on table public.player_fishing_sessions to authenticated;

create index if not exists player_fishing_sessions_user_status_idx
  on public.player_fishing_sessions (user_id, status, expires_at);
create index if not exists player_fishing_sessions_created_idx
  on public.player_fishing_sessions (user_id, created_at desc);

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
declare
  actor_id text;
  now_at timestamptz;
  bite_delay_ms integer;
  session_id uuid;
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

  actor_id := auth.uid()::text;
  -- Serialize starts for one player so a double tap cannot create two live
  -- sessions that could both be resolved.
  perform pg_advisory_xact_lock(hashtextextended(actor_id, 0));
  if not exists (
    select 1
      from public.fishing_spots fs
     where fs.id = trim(p_spot_id)
       and fs.active = true
       and fs.verification_status = 'verified'
  ) then
    raise exception 'fishing spot is not active' using errcode = '22023';
  end if;

  now_at := clock_timestamp();
  update public.player_fishing_sessions
     set status = 'expired',
         resolved_at = now_at
   where user_id = actor_id
     and status = 'armed';

  -- Keep the bite timing unpredictable while exposing only the timing needed
  -- by the UI to animate the bobber.
  bite_delay_ms := 1600 + floor(random() * 1001)::integer;
  insert into public.player_fishing_sessions (
    user_id,
    spot_id,
    lure_id,
    fish_id,
    started_at,
    bite_at,
    success_window_ends_at,
    expires_at
  ) values (
    actor_id,
    trim(p_spot_id),
    p_lure_id,
    trim(p_fish_id),
    now_at,
    now_at + bite_delay_ms * interval '1 millisecond',
    now_at + (bite_delay_ms + 900) * interval '1 millisecond',
    now_at + interval '12 seconds'
  ) returning id into session_id;

  return jsonb_build_object(
    'session_id', session_id,
    'fish_id', trim(p_fish_id),
    'bite_delay_ms', bite_delay_ms,
    'success_window_ms', 900,
    'expires_in_ms', 12000
  );
end;
$$;

create or replace function public.resolve_virtual_fishing_session(
  p_session_id uuid,
  p_pull_elapsed_ms integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_id text;
  now_at timestamptz;
  server_elapsed_ms integer;
  session_row public.player_fishing_sessions%rowtype;
  succeeded boolean;
  next_status text;
begin
  if auth.uid() is null then
    raise exception 'authenticated session required' using errcode = '42501';
  end if;
  if p_session_id is null then
    raise exception 'invalid fishing session' using errcode = '22023';
  end if;
  if p_pull_elapsed_ms is null or p_pull_elapsed_ms < 0
     or p_pull_elapsed_ms > 15000 then
    raise exception 'invalid pull timing' using errcode = '22023';
  end if;

  actor_id := auth.uid()::text;
  select *
    into session_row
    from public.player_fishing_sessions pfs
   where pfs.id = p_session_id
     and pfs.user_id = actor_id
   for update;
  if not found then
    raise exception 'fishing session not found' using errcode = '42501';
  end if;

  if session_row.status <> 'armed' then
    return jsonb_build_object(
      'session_id', session_row.id,
      'success', session_row.status = 'resolved_success',
      'status', session_row.status,
      'already_resolved', true
    );
  end if;

  now_at := clock_timestamp();
  server_elapsed_ms := greatest(
    0,
    (extract(epoch from (now_at - session_row.started_at)) * 1000)::integer
  );

  if now_at >= session_row.expires_at then
    update public.player_fishing_sessions
       set status = 'expired',
           resolved_at = now_at,
           pull_elapsed_ms = p_pull_elapsed_ms
     where id = session_row.id;
    return jsonb_build_object(
      'session_id', session_row.id,
      'success', false,
      'status', 'expired',
      'server_elapsed_ms', server_elapsed_ms
    );
  end if;

  -- The client supplies its local elapsed time for responsive interaction;
  -- the server independently checks the bite window and bounds clock drift.
  succeeded := now_at >= session_row.bite_at - interval '300 milliseconds'
    and now_at <= session_row.success_window_ends_at + interval '1200 milliseconds'
    and p_pull_elapsed_ms >= (
      extract(epoch from (session_row.bite_at - session_row.started_at)) * 1000
    )::integer
    and p_pull_elapsed_ms <= (
      extract(epoch from (session_row.success_window_ends_at - session_row.started_at)) * 1000
    )::integer
    and abs(server_elapsed_ms - p_pull_elapsed_ms) <= 1800;
  next_status := case when succeeded then 'resolved_success' else 'resolved_miss' end;

  update public.player_fishing_sessions
     set status = next_status,
         resolved_at = now_at,
         pull_elapsed_ms = p_pull_elapsed_ms
   where id = session_row.id;

  return jsonb_build_object(
    'session_id', session_row.id,
    'success', succeeded,
    'status', next_status,
    'server_elapsed_ms', server_elapsed_ms
  );
end;
$$;

-- Five arguments are used by the current client. The old four-argument
-- overload remains for daily/non-virtual rewards during remote rollout, but
-- it explicitly rejects generic virtual catches.
create or replace function public.claim_gameplay_reward_ticket(
  p_reward_kind text,
  p_requested_amount integer,
  p_claim_key text,
  p_fish_id text,
  p_gameplay_session_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_id text;
  current_balance integer;
  existing_balance integer;
  reward_amount integer;
  maximum_amount integer;
  updated_balance integer;
  session_row public.player_fishing_sessions%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authenticated session required' using errcode = '42501';
  end if;
  if p_reward_kind is null or p_reward_kind not in (
    'daily_announcement',
    'daily_task_catch_2_fish',
    'daily_task_catch_2_species',
    'virtual_catch',
    'spot_bonus',
    'checkpoint',
    'real_catch'
  ) then
    raise exception 'unsupported gameplay reward kind' using errcode = '22023';
  end if;
  if p_requested_amount is null or p_requested_amount <= 0 then
    raise exception 'invalid gameplay reward amount' using errcode = '22003';
  end if;
  if p_claim_key is null or char_length(trim(p_claim_key)) = 0
     or char_length(p_claim_key) > 160 then
    raise exception 'invalid gameplay reward claim key' using errcode = '22023';
  end if;
  if p_fish_id is not null and char_length(p_fish_id) > 80 then
    raise exception 'invalid gameplay reward fish id' using errcode = '22023';
  end if;

  actor_id := auth.uid()::text;
  insert into public.player_profiles (user_id)
  values (actor_id)
  on conflict (user_id) do nothing;

  select pp.coins
    into current_balance
    from public.player_profiles pp
   where pp.user_id = actor_id
   for update;

  select pgc.balance_after
    into existing_balance
    from public.player_gameplay_reward_claims pgc
   where pgc.user_id = actor_id
     and pgc.reward_kind = p_reward_kind
     and pgc.claim_key = trim(p_claim_key);
  if found then
    return jsonb_build_object(
      'claimed', false,
      'reward_coins', 0,
      'balance', existing_balance
    );
  end if;

  if p_reward_kind = 'virtual_catch' then
    if p_gameplay_session_id is null then
      raise exception 'virtual fishing session required' using errcode = '22023';
    end if;
    select *
      into session_row
      from public.player_fishing_sessions pfs
     where pfs.id = p_gameplay_session_id
       and pfs.user_id = actor_id
     for update;
    if not found or session_row.status <> 'resolved_success' then
      raise exception 'virtual fishing session not successfully resolved'
        using errcode = '22023';
    end if;
    if session_row.fish_id is distinct from nullif(trim(coalesce(p_fish_id, '')), '') then
      raise exception 'virtual fishing fish mismatch' using errcode = '22023';
    end if;
    if session_row.claimed_at is not null then
      return jsonb_build_object(
        'claimed', false,
        'reward_coins', 0,
        'balance', current_balance
      );
    end if;
  end if;

  reward_amount := case p_reward_kind
    when 'daily_announcement' then 50
    when 'daily_task_catch_2_fish' then 20
    when 'daily_task_catch_2_species' then 30
    when 'real_catch' then 20
    else least(p_requested_amount, case p_reward_kind
      when 'virtual_catch' then 160
      when 'spot_bonus' then 10
      when 'checkpoint' then 5
      else 0
    end)
  end;

  maximum_amount := case p_reward_kind
    when 'virtual_catch' then 160
    when 'spot_bonus' then 10
    when 'checkpoint' then 5
    when 'real_catch' then 20
    when 'daily_announcement' then 50
    when 'daily_task_catch_2_fish' then 20
    when 'daily_task_catch_2_species' then 30
    else 0
  end;
  if reward_amount <= 0 or reward_amount > maximum_amount then
    raise exception 'gameplay reward amount exceeds server cap' using errcode = '22003';
  end if;

  if p_reward_kind = 'virtual_catch' and (
    select count(*)
      from public.player_gameplay_reward_claims pgc
     where pgc.user_id = actor_id
       and pgc.reward_kind = p_reward_kind
       and pgc.created_at >= now() - interval '30 seconds'
  ) >= 3 then
    raise exception 'gameplay reward rate limit' using errcode = 'P0001';
  end if;
  if p_reward_kind = 'checkpoint' and (
    select count(*)
      from public.player_gameplay_reward_claims pgc
     where pgc.user_id = actor_id
       and pgc.reward_kind = p_reward_kind
       and pgc.created_at >= now() - interval '1 hour'
  ) >= 20 then
    raise exception 'checkpoint reward rate limit' using errcode = 'P0001';
  end if;
  if p_reward_kind in (
    'daily_announcement',
    'daily_task_catch_2_fish',
    'daily_task_catch_2_species'
  ) and exists (
    select 1
      from public.player_gameplay_reward_claims pgc
     where pgc.user_id = actor_id
       and pgc.reward_kind = p_reward_kind
       and pgc.created_at >= date_trunc('day', now())
  ) then
    return jsonb_build_object(
      'claimed', false,
      'reward_coins', 0,
      'balance', current_balance
    );
  end if;

  updated_balance := current_balance + reward_amount;
  update public.player_profiles
     set coins = updated_balance,
         total_coins_earned = total_coins_earned + reward_amount,
         updated_at = now()
   where user_id = actor_id;

  insert into public.player_gameplay_reward_claims (
    user_id,
    reward_kind,
    claim_key,
    fish_id,
    requested_amount,
    reward_amount,
    balance_after
  ) values (
    actor_id,
    p_reward_kind,
    trim(p_claim_key),
    nullif(trim(coalesce(p_fish_id, '')), ''),
    p_requested_amount,
    reward_amount,
    updated_balance
  );

  if p_reward_kind = 'virtual_catch' then
    update public.player_fishing_sessions
       set claimed_at = now()
     where id = p_gameplay_session_id;
  end if;

  return jsonb_build_object(
    'claimed', true,
    'reward_coins', reward_amount,
    'balance', updated_balance
  );
end;
$$;

create or replace function public.claim_gameplay_reward_ticket(
  p_reward_kind text,
  p_requested_amount integer,
  p_claim_key text,
  p_fish_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_reward_kind = 'virtual_catch' then
    raise exception 'virtual fishing session required' using errcode = '22023';
  end if;
  return public.claim_gameplay_reward_ticket(
    p_reward_kind,
    p_requested_amount,
    p_claim_key,
    p_fish_id,
    null::uuid
  );
end;
$$;

revoke all on function public.start_virtual_fishing_session(text,text,text)
  from public;
grant execute on function public.start_virtual_fishing_session(text,text,text)
  to authenticated;
revoke all on function public.resolve_virtual_fishing_session(uuid,integer)
  from public;
grant execute on function public.resolve_virtual_fishing_session(uuid,integer)
  to authenticated;
revoke all on function public.claim_gameplay_reward_ticket(text,integer,text,text,uuid)
  from public;
grant execute on function public.claim_gameplay_reward_ticket(text,integer,text,text,uuid)
  to authenticated;
revoke all on function public.claim_gameplay_reward_ticket(text,integer,text,text)
  from public;
grant execute on function public.claim_gameplay_reward_ticket(text,integer,text,text)
  to authenticated;
