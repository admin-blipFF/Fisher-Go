-- Give admins a controlled way to review and suspend spots without granting
-- ordinary authenticated players any write access to the registry.

drop policy if exists "admins read all fishing spots" on public.fishing_spots;
create policy "admins read all fishing spots"
  on public.fishing_spots for select
  to authenticated
  using (public.is_admin());

drop policy if exists "admins update fishing spots" on public.fishing_spots;
create policy "admins update fishing spots"
  on public.fishing_spots for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

revoke insert, delete on table public.fishing_spots from authenticated;
grant select on table public.fishing_spots to authenticated;
grant update on table public.fishing_spots to authenticated;
