-- FisherGO admin operations: announcements, events, fish-rate boosts, coin grants.

create table if not exists public.admin_users (
  email text primary key,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  coin_reward integer not null default 0,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.admin_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.fish_rate_boosts (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.admin_events(id) on delete cascade,
  fish_name text not null,
  multiplier numeric not null default 2.0 check (multiplier > 0),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.coin_grants (
  id uuid primary key default gen_random_uuid(),
  target_email text,
  amount integer not null check (amount > 0),
  reason text not null default 'admin grant',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.coin_grant_claims (
  grant_id uuid not null references public.coin_grants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key (grant_id, user_id)
);

alter table public.admin_users enable row level security;
alter table public.admin_announcements enable row level security;
alter table public.admin_events enable row level security;
alter table public.fish_rate_boosts enable row level security;
alter table public.coin_grants enable row level security;
alter table public.coin_grant_claims enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_users au
    where lower(au.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

create or replace function public.claim_my_coin_grants()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  total integer := 0;
begin
  with eligible as (
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
    select id, auth.uid() from eligible
    returning grant_id
  )
  select coalesce(sum(e.amount), 0)
    into total
    from eligible e
    join inserted i on i.grant_id = e.id;

  return coalesce(total, 0);
end;
$$;

-- Drop/recreate policies so migration is idempotent during iterative development.
drop policy if exists "admins read admin users" on public.admin_users;
drop policy if exists "admins manage announcements" on public.admin_announcements;
drop policy if exists "players read active announcements" on public.admin_announcements;
drop policy if exists "admins manage events" on public.admin_events;
drop policy if exists "players read active events" on public.admin_events;
drop policy if exists "admins manage boosts" on public.fish_rate_boosts;
drop policy if exists "players read active boosts" on public.fish_rate_boosts;
drop policy if exists "admins manage coin grants" on public.coin_grants;
drop policy if exists "players read own coin grants" on public.coin_grants;
drop policy if exists "players read own coin grant claims" on public.coin_grant_claims;

create policy "admins read admin users"
  on public.admin_users for select
  to authenticated
  using (public.is_admin());

create policy "admins manage announcements"
  on public.admin_announcements for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "players read active announcements"
  on public.admin_announcements for select
  to authenticated
  using (starts_at <= now() and (ends_at is null or ends_at >= now()));

create policy "admins manage events"
  on public.admin_events for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "players read active events"
  on public.admin_events for select
  to authenticated
  using (starts_at <= now() and (ends_at is null or ends_at >= now()));

create policy "admins manage boosts"
  on public.fish_rate_boosts for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "players read active boosts"
  on public.fish_rate_boosts for select
  to authenticated
  using (starts_at <= now() and (ends_at is null or ends_at >= now()));

create policy "admins manage coin grants"
  on public.coin_grants for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "players read own coin grants"
  on public.coin_grants for select
  to authenticated
  using (
    starts_at <= now()
    and (ends_at is null or ends_at >= now())
    and (
      target_email is null
      or lower(target_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
  );

create policy "players read own coin grant claims"
  on public.coin_grant_claims for select
  to authenticated
  using (user_id = auth.uid());

grant execute on function public.is_admin() to authenticated;
grant execute on function public.claim_my_coin_grants() to authenticated;
