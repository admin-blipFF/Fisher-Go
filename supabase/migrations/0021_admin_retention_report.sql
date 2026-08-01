-- Privacy-safe retention reporting.
--
-- The report never returns actor_key or raw events. It aggregates the
-- project-local actor hash into install cohorts and D2/D7 return counts.

create index if not exists analytics_events_actor_name_occurred_idx
  on public.analytics_events(actor_key, event_name, occurred_at);

create or replace function public.analytics_retention_report(
  p_from_date date default (current_date - 90),
  p_to_date date default current_date
)
returns table (
  cohort_date date,
  cohort_size integer,
  day_2_returners integer,
  day_7_returners integer,
  day_2_rate numeric,
  day_7_rate numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'admin session required' using errcode = '42501';
  end if;
  if p_from_date is null or p_to_date is null
     or p_from_date > p_to_date
     or p_to_date > current_date
     or p_to_date - p_from_date > 370 then
    raise exception 'invalid retention report range' using errcode = '22023';
  end if;

  return query
  with first_seen as (
    select
      ae.actor_key,
      min((ae.occurred_at at time zone 'UTC')::date) as cohort_date
    from public.analytics_events ae
    where ae.event_name = 'app_bootstrap'
    group by ae.actor_key
  ), cohorts as (
    select fs.actor_key, fs.cohort_date
      from first_seen fs
     where fs.cohort_date between p_from_date and p_to_date
  ), return_flags as (
    select
      c.actor_key,
      c.cohort_date,
      exists (
        select 1
          from public.analytics_events ae
         where ae.actor_key = c.actor_key
           and (ae.occurred_at at time zone 'UTC')::date = c.cohort_date + 2
      ) as returned_day_2,
      exists (
        select 1
          from public.analytics_events ae
         where ae.actor_key = c.actor_key
           and (ae.occurred_at at time zone 'UTC')::date = c.cohort_date + 7
      ) as returned_day_7
    from cohorts c
  )
  select
    rf.cohort_date,
    count(*)::integer,
    count(*) filter (where rf.returned_day_2)::integer,
    count(*) filter (where rf.returned_day_7)::integer,
    round(
      count(*) filter (where rf.returned_day_2) * 100.0 /
        nullif(count(*), 0),
      2
    ),
    round(
      count(*) filter (where rf.returned_day_7) * 100.0 /
        nullif(count(*), 0),
      2
    )
  from return_flags rf
  group by rf.cohort_date
  order by rf.cohort_date;
end;
$$;

revoke all on function public.analytics_retention_report(date, date)
  from public, anon;
grant execute on function public.analytics_retention_report(date, date)
  to authenticated;
