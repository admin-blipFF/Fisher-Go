-- Server-authoritative wallet primitives.
--
-- Clients may spend an existing balance and claim grants that the server has
-- already issued. They cannot write the ledger or choose a positive delta.

create table if not exists public.player_coin_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  delta integer not null check (delta <> 0),
  reason text not null,
  idempotency_key text,
  balance_after integer not null check (balance_after >= 0),
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

alter table public.player_coin_transactions enable row level security;
revoke all on table public.player_coin_transactions from anon, authenticated;

-- Keep profile customization writable, but make the wallet columns and row
-- lifecycle writable only through security-definer functions.
revoke insert on table public.player_profiles from authenticated;
revoke update on table public.player_profiles from authenticated;
revoke delete on table public.player_profiles from authenticated;
grant insert (
  user_id,
  avatar_name,
  avatar_color,
  equipped_rod,
  equipped_bait,
  equipped_hat,
  equipped_vest,
  equipped_boat
) on table public.player_profiles to authenticated;
grant update (
  avatar_name,
  avatar_color,
  equipped_rod,
  equipped_bait,
  equipped_hat,
  equipped_vest,
  equipped_boat
) on table public.player_profiles to authenticated;

create or replace function public.adjust_player_coins(
  p_amount integer,
  p_reason text,
  p_idempotency_key text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_id text;
  current_balance integer;
  existing_balance integer;
  updated_balance integer;
begin
  if auth.uid() is null then
    raise exception 'authenticated session required' using errcode = '42501';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount > 100000 then
    raise exception 'invalid coin reward amount' using errcode = '22003';
  end if;
  if p_reason is null or char_length(trim(p_reason)) = 0 or char_length(p_reason) > 120 then
    raise exception 'invalid coin reward reason' using errcode = '22023';
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

  if p_idempotency_key is not null then
    select pct.balance_after
      into existing_balance
      from public.player_coin_transactions pct
     where pct.user_id = actor_id
       and pct.idempotency_key = p_idempotency_key;
    if found then
      return existing_balance;
    end if;
  end if;

  updated_balance := current_balance + p_amount;

  update public.player_profiles
     set coins = updated_balance,
         total_coins_earned = total_coins_earned + p_amount,
         updated_at = now()
   where user_id = actor_id;

  insert into public.player_coin_transactions (
    user_id,
    delta,
    reason,
    idempotency_key,
    balance_after
  ) values (
    actor_id,
    p_amount,
    trim(p_reason),
    p_idempotency_key,
    updated_balance
  );

  return updated_balance;
end;
$$;

create or replace function public.spend_player_coins(
  p_amount integer,
  p_idempotency_key text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_id text;
  current_balance integer;
  existing_balance integer;
  updated_balance integer;
begin
  if auth.uid() is null then
    raise exception 'authenticated session required' using errcode = '42501';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount > 100000 then
    raise exception 'invalid coin spend amount' using errcode = '22003';
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

  if p_idempotency_key is not null then
    select pct.balance_after
      into existing_balance
      from public.player_coin_transactions pct
     where pct.user_id = actor_id
       and pct.idempotency_key = p_idempotency_key;
    if found then
      return existing_balance;
    end if;
  end if;

  if current_balance < p_amount then
    raise exception 'insufficient coins' using errcode = 'P0001';
  end if;

  updated_balance := current_balance - p_amount;

  update public.player_profiles
     set coins = updated_balance,
         updated_at = now()
   where user_id = actor_id;

  insert into public.player_coin_transactions (
    user_id,
    delta,
    reason,
    idempotency_key,
    balance_after
  ) values (
    actor_id,
    -p_amount,
    'client_spend',
    p_idempotency_key,
    updated_balance
  );

  return updated_balance;
end;
$$;

-- Replace the legacy claim function so claiming a grant also credits the
-- profile in the same database transaction. The client only receives the
-- amount claimed and then refreshes its cloud balance.
create or replace function public.claim_my_coin_grants()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_id text;
  current_balance integer;
  total integer := 0;
begin
  if auth.uid() is null then
    raise exception 'authenticated session required' using errcode = '42501';
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

  with eligible as materialized (
    select cg.id, cg.amount
      from public.coin_grants cg
     where cg.starts_at <= now()
       and (cg.ends_at is null or cg.ends_at >= now())
       and (
         cg.target_email is null
         or lower(cg.target_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
       )
       and not exists (
         select 1
           from public.coin_grant_claims cgc
          where cgc.grant_id = cg.id
            and cgc.user_id = auth.uid()
       )
  ), inserted as (
    insert into public.coin_grant_claims (grant_id, user_id)
    select e.id, auth.uid()
      from eligible e
    on conflict (grant_id, user_id) do nothing
    returning grant_id
  )
  select coalesce(sum(e.amount), 0)
    into total
    from eligible e
    join inserted i on i.grant_id = e.id;

  if total > 0 then
    update public.player_profiles
       set coins = current_balance + total,
           total_coins_earned = total_coins_earned + total,
           updated_at = now()
     where user_id = actor_id;
  end if;

  return total;
end;
$$;

revoke all on function public.spend_player_coins(integer, text) from public;
revoke all on function public.adjust_player_coins(integer, text, text) from public;
revoke all on function public.claim_my_coin_grants() from public;
grant execute on function public.adjust_player_coins(integer, text, text) to authenticated;
grant execute on function public.spend_player_coins(integer, text) to authenticated;
grant execute on function public.claim_my_coin_grants() to authenticated;
