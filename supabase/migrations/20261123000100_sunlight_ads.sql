-- Sunlight on the Greenhouse Dashboard (Nov 23, 2026).
-- What the ads cost, what they brought in, what they booked, and the cost per booked job, by channel.
-- Shops whose ads someone else runs still see leads and bookings by ad channel; spend shows once it's recorded.

alter table public.orgs add column if not exists sunlight boolean not null default false;

create table if not exists public.mc_ad_spend (
  org_id uuid not null references public.orgs(id) on delete cascade,
  day date not null,
  channel text not null check (channel in ('Google Local Services', 'Google Search', 'Facebook')),
  spend numeric(10, 2) not null default 0 check (spend >= 0),
  clicks int not null default 0 check (clicks >= 0),
  primary key (org_id, day, channel)
);
alter table public.mc_ad_spend enable row level security;
drop policy if exists "read own or demo" on public.mc_ad_spend;
create policy "read own or demo" on public.mc_ad_spend for select to anon, authenticated using (public.mc_can_read(org_id));

-- The ads block for one org, last 30 days. Lead channels match mc_leads.source.
create or replace function ops_private.mc_ads(p_org uuid)
returns jsonb language sql stable set search_path = '' as $$
  with ch(channel, label, ord) as (
    values ('Google Local Services', 'Local Services Ads', 1), ('Google Search', 'Google Search ads', 2), ('Facebook', 'Facebook and Instagram', 3)),
  sp as (
    select channel, sum(spend) as spend from public.mc_ad_spend
    where org_id = p_org and day > (now() at time zone 'America/Chicago')::date - 30 group by channel),
  ld as (
    select source as channel, count(*) as leads, count(*) filter (where status = 'booked') as booked,
           coalesce(sum(est_value) filter (where status = 'booked'), 0) as booked_value
    from public.mc_leads
    where org_id = p_org and created_at >= now() - interval '30 days' and source in ('Google Local Services', 'Google Search', 'Facebook')
    group by source),
  r as (
    select ch.label, ch.ord, coalesce(sp.spend, 0) as spend, coalesce(ld.leads, 0) as leads, coalesce(ld.booked, 0) as booked,
           coalesce(ld.booked_value, 0) as booked_value
    from ch left join sp on sp.channel = ch.channel left join ld on ld.channel = ch.channel
    where coalesce(sp.spend, 0) > 0 or coalesce(ld.leads, 0) > 0),
  t as (select sum(spend) as spend, sum(leads) as leads, sum(booked) as booked, sum(booked_value) as booked_value from r)
  select jsonb_build_object(
    'managed', coalesce((select o.sunlight from public.orgs o where o.id = p_org), false),
    'rows', coalesce((select jsonb_agg(jsonb_build_object(
        'channel', r.label,
        'spend', case when r.spend > 0 then public.mc_money(r.spend) else '–' end,
        'leads', r.leads, 'booked', r.booked,
        'per_booked', case when r.booked > 0 and r.spend > 0 then public.mc_money(r.spend / r.booked) else '–' end) order by r.ord) from r), '[]'::jsonb),
    'total', (select jsonb_build_object(
        'spend', case when t.spend > 0 then public.mc_money(t.spend) else '–' end,
        'leads', coalesce(t.leads, 0), 'booked', coalesce(t.booked, 0),
        'per_booked', case when t.booked > 0 and t.spend > 0 then public.mc_money(t.spend / t.booked) else '–' end,
        'booked_value', public.mc_money(coalesce(t.booked_value, 0)),
        'return', case when t.spend > 0 then to_char(t.booked_value / t.spend, 'FM990.0') || 'x' end) from t));
$$;

-- Sample orgs only: each paid lead adds what it would have cost to that day's spend, at a realistic cost per lead
-- (Local Services Ads charge per lead, so no clicks there).
create or replace function ops_private.demo_ad_cost()
returns trigger language plpgsql set search_path = '' as $$
declare cpl numeric; h numeric;
begin
  if not exists (select 1 from public.orgs where id = new.org_id and is_demo and sunlight) then return new; end if;
  cpl := case new.source when 'Google Local Services' then 55 when 'Google Search' then 105 else 45 end;
  h := (('x' || substr(md5(new.id::text), 1, 7))::bit(28)::int) / 268435455.0;
  insert into public.mc_ad_spend as a (org_id, day, channel, spend, clicks)
  values (new.org_id, (new.created_at at time zone 'America/Chicago')::date, new.source, round(cpl * (0.75 + 0.5 * h), 2),
          case when new.source = 'Google Local Services' then 0 else (3 + floor(h * 9))::int end)
  on conflict (org_id, day, channel) do update set spend = a.spend + excluded.spend, clicks = a.clicks + excluded.clicks;
  return new;
end $$;

create or replace function public.mc_view(p_slug text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  o public.orgs; t30 timestamptz := now() - interval '30 days';
  l record; b record; q record; rv record; s record;
  bg jsonb; br jsonb; ba jsonb; bi jsonb; bn jsonb; ads jsonb;
begin
  select * into o from public.orgs where slug = p_slug;
  if not found or not public.mc_can_read(o.id) then return null; end if;

  select count(*) filter (where created_at >= t30) n, count(*) filter (where created_at < t30) prev,
         count(*) filter (where created_at >= t30 and response_seconds <= 60) fast,
         round(avg(response_seconds) filter (where created_at >= t30)) avg_secs,
         count(distinct source) filter (where created_at >= t30) sources,
         count(*) filter (where created_at >= t30 and after_hours) ah,
         round(avg(quality) filter (where created_at >= t30), 1) quality,
         count(*) filter (where created_at >= t30 and handoff) handoffs,
         count(*) filter (where created_at >= t30 and channel = 'call') calls,
         count(*) filter (where created_at >= t30 and channel = 'call' and response_seconds <= 60) calls_fast
  into l from public.mc_leads where org_id = o.id and created_at >= now() - interval '60 days';
  select count(*) n, count(*) filter (where source in ('followup', 'revival')) auto, coalesce(sum(value), 0) val,
         coalesce(sum(value) filter (where source = 'revival'), 0) rev_val
  into b from public.mc_appointments where org_id = o.id and created_at >= t30;
  select count(*) filter (where status = 'open' and not frozen and sent_at >= now() - interval '90 days') open_n,
         round(avg(touches) filter (where status = 'open' and not frozen and sent_at >= now() - interval '90 days'), 1) touches,
         count(*) filter (where won_via = 'followup' and won_at >= t30) won_fu
  into q from public.mc_estimates where org_id = o.id;
  select count(*) filter (where frozen and status = 'open') pool,
         count(*) filter (where won_via = 'revival' and won_at >= t30) won_n,
         coalesce(sum(amount) filter (where won_via = 'revival' and won_at >= t30), 0) won_val
  into rv from public.mc_estimates where org_id = o.id;
  select coalesce(sum(records), 0) records, round(avg(latency_ms)) latency,
         case when count(*) > 0 then round(count(*) filter (where ok) * 100.0 / count(*), 1) end ok_rate
  into s from public.mc_sync_runs where org_id = o.id and at >= t30;

  bg := ops_private.bars14(o.id, 'leads');  br := ops_private.bars14(o.id, 'response');
  ba := ops_private.bars14(o.id, 'A');      bi := ops_private.bars14(o.id, 'sync');
  bn := ops_private.bars14(o.id, 'N');
  -- Ads never take the dashboard down: if this block fails, the rest still loads.
  begin
    ads := ops_private.mc_ads(o.id);
  exception when others then
    ads := null;
  end;

  return jsonb_build_object(
    'org', jsonb_build_object('slug', o.slug, 'name', o.name, 'tier', o.tier, 'is_demo', o.is_demo, 'status', o.status, 'live_at', o.live_at),
    'generated_at', now(),
    'guarantees', ops_private.guarantees(o.id),
    'view', jsonb_build_object(
      'client', o.slug,
      'kpi', jsonb_build_array(
        jsonb_build_object('label', 'Leads, last 30 days', 'value', l.n::text, 'unit', '',
          'delta', case when l.prev > 0 and o.live_at <= now() - interval '60 days' then to_char(round((l.n - l.prev) * 100.0 / l.prev), 'FMSG9990') || '% vs the 30 days before' else 'calls, forms and texts' end),
        jsonb_build_object('label', 'Answered inside 60 seconds', 'value', case when l.n > 0 then round(l.fast * 100.0 / l.n, 1)::text else '0' end, 'unit', '%',
          'delta', case when l.avg_secs is not null then l.avg_secs || ' sec on average' else 'no leads yet' end),
        jsonb_build_object('label', 'Jobs booked', 'value', b.n::text, 'unit', '', 'delta', b.auto || ' from follow-up and old estimates'),
        jsonb_build_object('label', 'Booked job value', 'value', public.mc_money(b.val), 'unit', '', 'delta', public.mc_money(b.rev_val) || ' from old estimates')),
      'engines', jsonb_build_object(
        'G', jsonb_build_object(
          'ads', ads,
          'summary', jsonb_build_array(
            jsonb_build_object('label', 'Sources bringing leads', 'value', coalesce(l.sources, 0)::text, 'unit', ''),
            jsonb_build_object('label', 'Arrived after hours', 'value', case when l.n > 0 then round(l.ah * 100.0 / l.n)::text else '0' end, 'unit', '%'),
            case when l.quality is not null then jsonb_build_object('label', 'Lead quality (avg)', 'value', l.quality::text, 'unit', '/10')
                 else jsonb_build_object('label', 'Calls', 'value', l.calls::text, 'unit', '') end),
          'chart', jsonb_build_object('title', 'Leads, last 14 days', 'stat', (select coalesce(sum(x::numeric), 0) from jsonb_array_elements_text(bg) x) || ' total', 'bars', bg),
          'activity', ops_private.mc_activity(o.id, 'G')),
        'R', jsonb_build_object(
          'summary', jsonb_build_array(
            jsonb_build_object('label', 'Avg response time', 'value', coalesce(l.avg_secs, 0)::text, 'unit', 's'),
            jsonb_build_object('label', 'Calls answered inside 60s', 'value', case when l.calls > 0 then round(l.calls_fast * 100.0 / l.calls, 1)::text else '0' end, 'unit', '%'),
            jsonb_build_object('label', 'Hot leads handed to your team', 'value', l.handoffs::text, 'unit', '')),
          'chart', jsonb_build_object('title', 'Response time, last 14 days (avg sec)', 'stat', coalesce(l.avg_secs, 0) || ' sec avg', 'bars', br),
          'activity', ops_private.mc_activity(o.id, 'R')),
        'A', jsonb_build_object(
          'summary', jsonb_build_array(
            jsonb_build_object('label', 'Estimates in follow-up', 'value', q.open_n::text, 'unit', ''),
            jsonb_build_object('label', 'Avg touches per estimate', 'value', coalesce(q.touches, 0)::text, 'unit', ''),
            jsonb_build_object('label', 'Won on follow-up, 30 days', 'value', q.won_fu::text, 'unit', '')),
          'chart', jsonb_build_object('title', 'Follow-ups, last 14 days', 'stat', (select coalesce(sum(x::numeric), 0) from jsonb_array_elements_text(ba) x) || ' sent', 'bars', ba),
          'activity', ops_private.mc_activity(o.id, 'A')),
        'I', jsonb_build_object(
          'summary', jsonb_build_array(
            jsonb_build_object('label', 'Records synced, 30 days', 'value', to_char(s.records, 'FM999,999,990'), 'unit', ''),
            jsonb_build_object('label', 'Avg sync time', 'value', coalesce(s.latency, 0)::text, 'unit', 'ms'),
            jsonb_build_object('label', 'Syncs that succeeded', 'value', coalesce(s.ok_rate, 0)::text, 'unit', '%')),
          'chart', jsonb_build_object('title', 'Records synced, last 14 days', 'stat', coalesce(o.crm, 'CRM'), 'bars', bi),
          'activity', ops_private.mc_activity(o.id, 'I')),
        'N', jsonb_build_object(
          'summary', jsonb_build_array(
            jsonb_build_object('label', 'Old estimates being worked', 'value', rv.pool::text, 'unit', ''),
            jsonb_build_object('label', 'Back as jobs, 30 days', 'value', rv.won_n::text, 'unit', ''),
            jsonb_build_object('label', 'Revived revenue, 30 days', 'value', public.mc_money(rv.won_val), 'unit', '')),
          'chart', jsonb_build_object('title', 'Revival messages, last 14 days', 'stat', rv.won_n || ' jobs back', 'bars', bn),
          'activity', ops_private.mc_activity(o.id, 'N')))));
end $$;

create or replace function public.mc_seed_demo()
returns text language plpgsql security definer set search_path = '' as $$
declare today date := (now() at time zone 'America/Chicago')::date; o record; d date;
  jobs text[] := array['Furnace replacement', 'Heat pump install', 'AC replacement', 'Ductwork', 'Water heater', 'Whole-home system', 'Mini-split install'];
begin
  delete from public.orgs where is_demo and slug in ('hollow-creek-hvac', 'ridgeline-home-services');
  insert into public.orgs (slug, name, tier, is_demo, crm, locations, signed_at, kickoff_at, live_at, status, trade, service_area, comms_channel, sunlight)
  values ('hollow-creek-hvac', 'Hollow Creek Heating & Air', 'greenhouse', true, 'ServiceTitan', 1,
          now() - interval '62 days', now() - interval '59 days', now() - interval '46 days', 'live', 'hvac', 'Nashville', 'sms', true),
         ('ridgeline-home-services', 'Ridgeline Home Services', 'orchard', true, 'Housecall Pro', 3,
          now() - interval '68 days', now() - interval '65 days', now() - interval '52 days', 'live', 'hvac', 'Middle Tennessee', 'slack', true);
  for o in select id, tier, live_at, case when tier = 'greenhouse' then 1 else 2.4 end as scale from public.orgs where is_demo loop
    insert into public.mc_estimates (org_id, estimate_no, job_type, amount, sent_at, frozen, status)
    select o.id, 'F-' || g, jobs[1 + floor(random() * 7)::int], round((3500 + random() * 14500)::numeric, -1),
           o.live_at - interval '30 days' - random() * interval '660 days', true, 'open'
    from generate_series(1, (170 * o.scale)::int) g;
    update public.orgs set unsold_estimates_frozen_total = (select sum(amount) from public.mc_estimates where org_id = o.id and frozen) where id = o.id;
    insert into public.mc_estimates (org_id, estimate_no, job_type, amount, sent_at, status)
    select o.id, 'Q-' || g, jobs[1 + floor(random() * 7)::int], round((2400 + random() * 11600)::numeric, -1),
           now() - interval '31 days' - random() * interval '45 days', 'open'
    from generate_series(1, (40 * o.scale)::int) g;
    insert into public.mc_payments (org_id, at, kind, amount)
    values (o.id, o.live_at, 'setup', case when o.tier = 'greenhouse' then 1500 else 4500 end);
    insert into public.mc_payments (org_id, at, kind, amount)
    select o.id, o.live_at + g * interval '30 days', 'monthly', case when o.tier = 'greenhouse' then 2997 else 6991 end
    from generate_series(0, floor(extract(epoch from now() - o.live_at) / 2592000)::int) g;
    for d in select g::date from generate_series((today - 60)::timestamp, (today - 1)::timestamp, interval '1 day') g loop
      perform ops_private.demo_day(o.id, d, o.scale, null);
    end loop;
    perform ops_private.demo_day(o.id, today, o.scale, now());
    insert into public.mc_payments (org_id, at, kind, amount)
    select o.id, now() - interval '2 days', 'share', round(sum(paid_amount) * 0.10, 2)
    from public.mc_estimates where org_id = o.id and won_via = 'revival' and completed_paid_at is not null having sum(paid_amount) > 0;
    update public.orgs set demo_ticked_at = now() where id = o.id;
  end loop;
  for d in select g::date from generate_series((today - 60)::timestamp, (today - 1)::timestamp, interval '1 day') g loop
    perform ops_private.compute_daily(d);
  end loop;
  return 'ok';
end $$;

-- The two sample accounts run Sunlight. Backfill their spend from the paid leads already there, then keep it current.
update public.orgs set sunlight = true where is_demo;
insert into public.mc_ad_spend (org_id, day, channel, spend, clicks)
select l.org_id, (l.created_at at time zone 'America/Chicago')::date, l.source,
       round(sum(case l.source when 'Google Local Services' then 55 when 'Google Search' then 105 else 45 end * (0.75 + 0.5 * ((('x' || substr(md5(l.id::text), 1, 7))::bit(28)::int) / 268435455.0))), 2),
       sum(case when l.source = 'Google Local Services' then 0 else (3 + floor(((('x' || substr(md5(l.id::text), 1, 7))::bit(28)::int) / 268435455.0) * 9))::int end)
from public.mc_leads l
where l.org_id in (select id from public.orgs where is_demo) and l.source in ('Google Local Services', 'Google Search', 'Facebook')
group by l.org_id, (l.created_at at time zone 'America/Chicago')::date, l.source
on conflict (org_id, day, channel) do nothing;

drop trigger if exists mc_leads_demo_ad_cost on public.mc_leads;
create trigger mc_leads_demo_ad_cost after insert on public.mc_leads
  for each row when (new.source in ('Google Local Services', 'Google Search', 'Facebook'))
  execute function ops_private.demo_ad_cost();

revoke all on function ops_private.mc_ads(uuid), ops_private.demo_ad_cost() from public, anon, authenticated;
revoke all on function public.mc_seed_demo() from public, anon, authenticated;
revoke all on function public.mc_view(text) from public;
grant execute on function public.mc_view(text) to anon, authenticated;
