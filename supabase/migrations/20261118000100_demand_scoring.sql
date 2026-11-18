-- Demand scoring (Nov 18, 2026)
-- Notion: GRAIN HQ, Operations, 1. Find and qualify leads, "Enrichment and demand scoring in Clay".
-- Clay adds missed $ a month to every prospect: search demand in his area that his map rank doesn't catch.
-- The 0 to 100 score does not change. Missed $ sorts the qualified list and sets the tier (A, B, C).
--
-- The math (same as the GRAIN Audit Demand Map sheet and lib/demand.ts):
--   demand $ a month = searches a month x 3% (leads for a top-3 shop) x 45% (book) x close rate x average ticket
--   share he catches by map rank: 1 to 3 = 100%, 4 to 10 = 25%, 11 to 20 = 5%, not in the top 20 = 0%
--   missed $ a month = demand x (1 - share)
--   tier: A = qualified and missed $10,000+; B = qualified and missed $3,000+; C = everything else with a number
-- 3% and the rank shares are planning assumptions. Replace them after 15 audits.

alter table public.prospects
  add column main_service text,
  add column searches_monthly int check (searches_monthly is null or searches_monthly >= 0),
  add column map_rank int check (map_rank is null or map_rank >= 1),
  add column top3_avg_reviews int check (top3_avg_reviews is null or top3_avg_reviews >= 0),
  add column avg_ticket numeric(12,2) check (avg_ticket is null or avg_ticket >= 0),
  add column close_rate numeric(5,4) check (close_rate is null or (close_rate >= 0 and close_rate <= 1)),
  add column market_demand_monthly numeric(12,2),
  add column missed_monthly numeric(12,2),
  add column biggest_gap text,
  add column demand_tier text check (demand_tier is null or demand_tier in ('A','B','C')),
  add column opener text,
  add column demand_source text check (demand_source is null or demand_source in ('clay','hq','audit')),
  add column demand_updated_at timestamptz;

comment on column public.prospects.demand_source is
  'clay: totals came from the Clay import and are kept as sent. hq or audit: computed here from the main service inputs (audit = his real ticket and close rate).';

create index prospects_demand on public.prospects (demand_tier, missed_monthly desc nulls last) where stage not in ('won','lost');

-- Share of the demand a shop catches at a given map rank (planning assumption)
create or replace function public.prospect_rank_share(p_rank int)
returns numeric language sql immutable set search_path = '' as $$
  select case when p_rank is null then 0 when p_rank <= 3 then 1.0 when p_rank <= 10 then 0.25 when p_rank <= 20 then 0.05 else 0 end::numeric;
$$;

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
      || lower(coalesce(new.biggest_gap, new.main_service))
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

-- HQ overview: send the demand fields and work the list by tier, then missed $, then score.
do $mig$
declare d text;
begin
  d := pg_get_functiondef('ops_private.hq_overview()'::regprocedure);
  d := replace(d,
    'p.touch_count, p.last_touch_at, p.disqualified_reason, p.notes, p.runs_ads, p.google_reviews, p.callback_minutes, p.locations,',
    'p.touch_count, p.last_touch_at, p.disqualified_reason, p.notes, p.runs_ads, p.google_reviews, p.callback_minutes, p.locations,
               p.main_service, p.searches_monthly, p.map_rank, p.top3_avg_reviews, p.avg_ticket, p.close_rate, p.market_demand_monthly,
               p.missed_monthly, p.biggest_gap, p.demand_tier, p.opener, p.demand_source, p.demand_updated_at,');
  d := replace(d,
    '(p.disqualified_reason is null) desc, p.score desc, p.created_at desc) rn',
    '(p.disqualified_reason is null) desc, coalesce(p.demand_tier, ''D'') asc, p.missed_monthly desc nulls last, p.score desc, p.created_at desc) rn');
  if position('p.demand_tier, p.opener' in d) = 0 or position('coalesce(p.demand_tier' in d) = 0 then
    raise exception 'hq_overview did not match; nothing changed';
  end if;
  execute d;
end
$mig$;

-- Bulk import from Clay (rows parsed in HQ). Matches an existing prospect by phone, or by name and city.
-- New shops come in as sourced, source outbound. Existing ones get the enrichment and demand fields refreshed.
create or replace function public.hq_import_prospects(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r jsonb; v_id uuid; v_phone text; v_trade text; v_band text;
  ins int := 0; upd int := 0; skip int := 0; errs jsonb := '[]'::jsonb;
  trades text[] := array['hvac','plumbing','roofing','electrical','remodeling','painting','fencing','pools','landscaping','garage_doors',
                         'health_fitness','real_estate','auto','tech','other'];
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then raise exception 'rows must be a list'; end if;
  if jsonb_array_length(p_rows) > 500 then raise exception 'import 500 rows or fewer at a time'; end if;

  for r in select value from jsonb_array_elements(p_rows) loop
    if nullif(trim(coalesce(r->>'business_name', '')), '') is null then skip := skip + 1; continue; end if;
    v_phone := nullif(regexp_replace(coalesce(r->>'phone', ''), '[^0-9]', '', 'g'), '');
    v_trade := lower(replace(nullif(trim(coalesce(r->>'trade', '')), ''), ' ', '_'));
    if v_trade is not null and not (v_trade = any (trades)) then v_trade := 'other'; end if;
    v_band := nullif(r->>'revenue_band', '');
    if v_band is not null and v_band not in ('under_500k','under_1m','1m_3m','3m_10m','10m_plus','unknown') then v_band := 'unknown'; end if;

    select p.id into v_id from public.prospects p
    where (v_phone is not null and regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g') = v_phone)
       or (lower(trim(p.business_name)) = lower(trim(r->>'business_name'))
           and lower(trim(coalesce(p.city, ''))) = lower(trim(coalesce(r->>'city', ''))))
    order by p.created_at limit 1;

    begin
      if v_id is null then
        insert into public.prospects (
          business_name, trade, city, service_area, website, phone, owner_name, owner_phone, owner_email,
          revenue_band, runs_ads, google_reviews, source, notes,
          main_service, searches_monthly, map_rank, top3_avg_reviews, avg_ticket, close_rate,
          market_demand_monthly, missed_monthly, biggest_gap, opener, demand_source)
        values (
          trim(r->>'business_name'), v_trade, nullif(r->>'city', ''), nullif(coalesce(r->>'service_area', r->>'city'), ''),
          nullif(r->>'website', ''), nullif(r->>'phone', ''), nullif(r->>'owner_name', ''), nullif(r->>'owner_phone', ''), nullif(r->>'owner_email', ''),
          coalesce(v_band, 'unknown'), (r->>'runs_ads')::boolean, nullif(r->>'google_reviews', '')::int, 'outbound', nullif(r->>'notes', ''),
          nullif(r->>'main_service', ''), nullif(r->>'searches_monthly', '')::int, nullif(r->>'map_rank', '')::int,
          nullif(r->>'top3_avg_reviews', '')::int, nullif(r->>'avg_ticket', '')::numeric, nullif(r->>'close_rate', '')::numeric,
          nullif(r->>'market_demand_monthly', '')::numeric, nullif(r->>'missed_monthly', '')::numeric,
          nullif(r->>'biggest_gap', ''), nullif(r->>'opener', ''),
          case when nullif(r->>'missed_monthly', '') is not null then 'clay' else 'hq' end);
        ins := ins + 1;
      else
        update public.prospects set
          trade = coalesce(trade, v_trade),
          website = coalesce(website, nullif(r->>'website', '')),
          phone = coalesce(phone, nullif(r->>'phone', '')),
          owner_name = coalesce(owner_name, nullif(r->>'owner_name', '')),
          owner_phone = coalesce(owner_phone, nullif(r->>'owner_phone', '')),
          owner_email = coalesce(owner_email, nullif(r->>'owner_email', '')),
          revenue_band = case when revenue_band is null or revenue_band = 'unknown' then coalesce(v_band, revenue_band) else revenue_band end,
          runs_ads = coalesce((r->>'runs_ads')::boolean, runs_ads),
          google_reviews = coalesce(nullif(r->>'google_reviews', '')::int, google_reviews),
          main_service = coalesce(nullif(r->>'main_service', ''), main_service),
          searches_monthly = coalesce(nullif(r->>'searches_monthly', '')::int, searches_monthly),
          map_rank = case when r ? 'map_rank' then nullif(r->>'map_rank', '')::int else map_rank end,
          top3_avg_reviews = coalesce(nullif(r->>'top3_avg_reviews', '')::int, top3_avg_reviews),
          -- his real ticket and close rate from the audit win over Clay defaults
          avg_ticket = case when demand_source = 'audit' then avg_ticket else coalesce(nullif(r->>'avg_ticket', '')::numeric, avg_ticket) end,
          close_rate = case when demand_source = 'audit' then close_rate else coalesce(nullif(r->>'close_rate', '')::numeric, close_rate) end,
          market_demand_monthly = case when demand_source = 'audit' then market_demand_monthly
                                       else coalesce(nullif(r->>'market_demand_monthly', '')::numeric, market_demand_monthly) end,
          missed_monthly = case when demand_source = 'audit' then missed_monthly
                                else coalesce(nullif(r->>'missed_monthly', '')::numeric, missed_monthly) end,
          biggest_gap = coalesce(nullif(r->>'biggest_gap', ''), biggest_gap),
          opener = coalesce(nullif(r->>'opener', ''), opener),
          demand_source = case when demand_source = 'audit' then 'audit'
                               when nullif(r->>'missed_monthly', '') is not null then 'clay' else coalesce(demand_source, 'hq') end
        where id = v_id;
        upd := upd + 1;
      end if;
    exception when others then
      skip := skip + 1;
      errs := errs || jsonb_build_object('row', r->>'business_name', 'error', sqlerrm);
    end;
  end loop;
  return jsonb_build_object('inserted', ins, 'updated', upd, 'skipped', skip, 'errors', errs);
end $$;

revoke all on function public.hq_import_prospects(jsonb) from public, anon;
grant execute on function public.hq_import_prospects(jsonb) to authenticated;
revoke all on function public.prospect_rank_share(int) from public, anon;
grant execute on function public.prospect_rank_share(int) to authenticated;
