-- Server-validated gameplay reward tickets.
--
-- The client submits only a reward kind, a bounded requested amount, and an
-- idempotency key. The server owns the allowlist, fixed daily rewards, caps,
-- rate limits, and the wallet update.

create table if not exists public.player_gameplay_reward_claims (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  reward_kind text not null check (
    reward_kind in (
      'daily_announcement',
      'daily_task_catch_2_fish',
      'daily_task_catch_2_species',
      'virtual_catch',
      'spot_bonus',
      'checkpoint',
      'real_catch'
    )
  ),
  claim_key text not null,
  fish_id text,
  requested_amount integer not null check (requested_amount > 0),
  reward_amount integer not null check (reward_amount > 0),
  balance_after integer not null check (balance_after >= 0),
  created_at timestamptz not null default now(),
  unique (user_id, reward_kind, claim_key)
);

alter table public.player_gameplay_reward_claims enable row level security;
revoke all on table public.player_gameplay_reward_claims from anon, authenticated;

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
declare
  actor_id text;
  current_balance integer;
  existing_balance integer;
  reward_amount integer;
  maximum_amount integer;
  updated_balance integer;
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

  -- Daily rewards are fixed by the server and cannot be inflated by the
  -- requested amount or by changing the local task state.
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

  -- Stop rapid replay even when a cheater generates a fresh client key.
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

  return jsonb_build_object(
    'claimed', true,
    'reward_coins', reward_amount,
    'balance', updated_balance
  );
end;
$$;

revoke all on function public.claim_gameplay_reward_ticket(text, integer, text, text)
  from public;
grant execute on function public.claim_gameplay_reward_ticket(text, integer, text, text)
  to authenticated;

-- Once ticket claims are deployed, authenticated clients must not bypass the
-- allowlist with the older generic positive-adjustment RPC.
revoke all on function public.adjust_player_coins(integer, text, text)
  from authenticated;
