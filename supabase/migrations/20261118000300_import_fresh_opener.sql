-- Demand scoring fix (Nov 18, 2026): a re-import without an opener writes a fresh one, so it never quotes an old map rank.

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
          -- Clay's opener, or none so the trigger writes a fresh one from the new numbers
          opener = nullif(r->>'opener', ''),
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

