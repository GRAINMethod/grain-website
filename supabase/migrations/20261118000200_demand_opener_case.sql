-- Demand scoring fix (Nov 18, 2026): keep acronyms in the opener ("AC repair", not "ac repair").

-- Service names read naturally inside a sentence: "water heater", but "AC repair" and "HVAC replacement" keep their capitals.
create or replace function public.service_phrase(p text)
returns text language sql immutable set search_path = '' as $$
  select case when p is null or p = '' then p
              when substr(p, 2, 1) ~ '[A-Z]' then p
              else lower(substr(p, 1, 1)) || substr(p, 2) end;
$$;
revoke all on function public.service_phrase(text) from public, anon;
grant execute on function public.service_phrase(text) to authenticated;

create or replace function public.prospects_before_write()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  auto_reasons text[] := array['trade_not_served','revenue_under_500k','conflict_existing_client','no_conversation_after_6_touches'];
  dq text;
  old_demand numeric;
  old_missed numeric;
begin
  new.updated_at := now();

  -- Demand: computed here unless the Clay import sent its own totals
  if new.searches_monthly is not null and new.avg_ticket is not null and coalesce(new.demand_source, 'hq') <> 'clay' then
    new.market_demand_monthly := round(new.searches_monthly * 0.03 * 0.45 * coalesce(new.close_rate, 1) * new.avg_ticket, 2);
    new.missed_monthly := round(new.market_demand_monthly * (1 - public.prospect_rank_share(new.map_rank)), 2);
    new.demand_source := coalesce(new.demand_source, 'hq');
  end if;
  if new.biggest_gap is null and new.missed_monthly is not null then new.biggest_gap := new.main_service; end if;
  if (new.opener is null or coalesce(new.demand_source, 'hq') <> 'clay')
     and new.searches_monthly is not null and coalesce(new.biggest_gap, new.main_service) is not null then
    new.opener := 'About ' || to_char(new.searches_monthly, 'FM999,999,999') || ' people a month search for '
      || public.service_phrase(coalesce(new.biggest_gap, new.main_service))
      || coalesce(' around ' || nullif(trim(coalesce(new.city, new.service_area, '')), ''), '')
      || ', and ' || new.business_name
      || case when new.map_rank is not null and new.map_rank <= 20 then ' is #' || new.map_rank || ' on the map.'
              else ' isn''t in the top 20 on the map.' end;
  end if;

  new.score := public.prospect_score(new);
  dq := public.prospect_auto_dq(new);
  if new.disqualified_reason is null or new.disqualified_reason = any (auto_reasons) then
    new.disqualified_reason := dq;
  end if;
  if dq = 'no_conversation_after_6_touches' and new.stage in ('sourced','qualified','contacted') then
    new.stage := 'nurture';
  end if;
  new.qualified := new.score >= 60 and new.disqualified_reason is null;
  if new.stage = 'sourced' and new.qualified then
    new.stage := 'qualified';
  end if;

  new.demand_tier := case
    when new.missed_monthly is null then null
    when new.qualified and new.missed_monthly >= 10000 then 'A'
    when new.qualified and new.missed_monthly >= 3000 then 'B'
    else 'C' end;
  if tg_op = 'INSERT' then
    if new.missed_monthly is not null then new.demand_updated_at := coalesce(new.demand_updated_at, now()); end if;
  else
    old_demand := old.market_demand_monthly; old_missed := old.missed_monthly;
    if new.market_demand_monthly is distinct from old_demand or new.missed_monthly is distinct from old_missed then
      new.demand_updated_at := now();
    end if;
  end if;

  if new.stage = 'conversation' and new.conversation_at is null then new.conversation_at := now(); end if;
  if new.stage = 'audit_held' and new.audit_held_at is null then new.audit_held_at := now(); end if;
  if new.stage = 'won' and new.won_at is null then new.won_at := now(); end if;
  return new;
end;
$$;
