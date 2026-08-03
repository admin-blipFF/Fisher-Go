-- Store provider tokens only behind the authenticated player boundary.
create table if not exists public.player_notification_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  provider text not null check (provider in ('fcm', 'apns', 'web_push')),
  token text not null check (char_length(token) between 16 and 4096),
  enabled boolean not null default true,
  last_seen_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, provider, token)
);

create index if not exists player_notification_tokens_user_idx
  on public.player_notification_tokens (user_id, enabled);

alter table public.player_notification_tokens enable row level security;

revoke all on public.player_notification_tokens from anon;
revoke all on public.player_notification_tokens from authenticated;

drop policy if exists "players read own notification tokens"
  on public.player_notification_tokens;
create policy "players read own notification tokens"
  on public.player_notification_tokens for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "players insert own notification tokens"
  on public.player_notification_tokens;
create policy "players insert own notification tokens"
  on public.player_notification_tokens for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "players update own notification tokens"
  on public.player_notification_tokens;
create policy "players update own notification tokens"
  on public.player_notification_tokens for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "players delete own notification tokens"
  on public.player_notification_tokens;
create policy "players delete own notification tokens"
  on public.player_notification_tokens for delete to authenticated
  using (auth.uid() = user_id);

create or replace function public.register_notification_device_token(
  p_platform text,
  p_provider text,
  p_token text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_platform text := lower(trim(coalesce(p_platform, '')));
  normalized_provider text := lower(trim(coalesce(p_provider, '')));
  normalized_token text := trim(coalesce(p_token, ''));
  registered_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if normalized_platform not in ('android', 'ios', 'web') then
    raise exception 'unsupported notification platform'
      using errcode = '22023';
  end if;
  if normalized_provider not in ('fcm', 'apns', 'web_push') then
    raise exception 'unsupported notification provider'
      using errcode = '22023';
  end if;
  if char_length(normalized_token) < 16
     or char_length(normalized_token) > 4096 then
    raise exception 'invalid notification token length'
      using errcode = '22023';
  end if;

  insert into public.player_notification_tokens (
    user_id, platform, provider, token, enabled, last_seen_at, updated_at
  ) values (
    auth.uid(), normalized_platform, normalized_provider, normalized_token,
    true, timezone('utc', now()), timezone('utc', now())
  )
  on conflict (user_id, provider, token) do update
    set platform = excluded.platform,
        enabled = true,
        last_seen_at = timezone('utc', now()),
        updated_at = timezone('utc', now())
  returning id into registered_id;

  return registered_id;
end;
$$;

create or replace function public.unregister_notification_device_token(
  p_provider text,
  p_token text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  removed_count integer;
  removed boolean;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  delete from public.player_notification_tokens
   where user_id = auth.uid()
     and provider = lower(trim(coalesce(p_provider, '')))
     and token = trim(coalesce(p_token, ''));
  get diagnostics removed_count = row_count;
  removed := removed_count > 0;
  return removed;
end;
$$;

revoke all on function public.register_notification_device_token(text, text, text)
  from public, anon;
revoke all on function public.unregister_notification_device_token(text, text)
  from public, anon;
grant execute on function public.register_notification_device_token(text, text, text)
  to authenticated;
grant execute on function public.unregister_notification_device_token(text, text)
  to authenticated;
