-- GRAIN ops backend, part 3: the Greenhouse Dashboard feed, the labeled sample orgs, and the schedule.

-- ---------------------------------------------------------------------------
-- Dashboard feed helpers
-- ---------------------------------------------------------------------------
create or replace function ops_private.mc_activity(p_org uuid, p_engine text)
returns jsonb language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'time', public.mc_ago(e.at),
           'text', '<strong>' || public.mc_esc(e.title) || '</strong>' || coalesce(' · ' || public.mc_esc(e.detail), ''),
           'status', e.status) order by e.at desc), '[]'::jsonb)
  from (select at, title, detail, status from public.mc_events
        where org_id = p_org and engine = p_engine and at <= now() order by at desc limit 5) e;
$$;

create or replace function ops_private.bars14(p_org uuid, p_kind text)
returns jsonb language sql stable set search_path = '' as $$
  with d as (select g::date as day
             from generate_series(((now() at time zone 'America/Chicago')::date - 13)::timestamp, ((now() at time zone 'America/Chicago')::date)::timestamp, interval '1 day') g),
  v as (
    select (created_at at time zone 'America/Chicago')::date as day, count(*)::numeric as n
    from public.mc_leads where p_kind = 'leads' and org_id = p_org and created_at >= now() - interval '15 days' group by 1
    union all
    select (created_at at time zone 'America/Chicago')::date, round(avg(response_seconds))
    from public.mc_leads where p_kind = 'response' and org_id = p_org and created_at >= now() - interval '15 days' group by 1
    union all
    select (at at time zone 'America/Chicago')::date, count(*)
    from public.mc_events where p_kind in ('A', 'N') and engine = p_kind and org_id = p_org and at >= now() - interval '15 days' group by 1
    union all
    select (at at time zone 'America/Chicago')::date, sum(records)
    from public.mc_sync_runs where p_kind = 'sync' and org_id = p_org and at >= now() - interval '15 days' group by 1)
  select jsonb_agg(coalesce(v.n, 0) order by d.day) from d left join v on v.day = d.day;
$$;

-- The dashboard page's data, in the exact shape its renderer expects (kpi[4], engines G/R/A/I/N).
-- Anyone can read a sample org. A real client's dashboard needs a signed-in member of that org, or staff.
create or replace function public.mc_view(p_slug text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  o public.orgs; t30 timestamptz := now() - interval '30 days';
  l record; b record; q record; rv record; s record;
  bg jsonb; br jsonb; ba jsonb; bi jsonb; bn jsonb;
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
            jsonb_build_object('label', 'Quotes in follow-up', 'value', q.open_n::text, 'unit', ''),
            jsonb_build_object('label', 'Avg touches per quote', 'value', coalesce(q.touches, 0)::text, 'unit', ''),
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

-- ---------------------------------------------------------------------------
-- Sample orgs. Everything below only ever touches orgs where is_demo = true.
-- ---------------------------------------------------------------------------
-- Tops one day up to a realistic volume. Safe to call again and again: it only adds what is missing.
create or replace function ops_private.demo_day(p_org uuid, p_day date, p_scale numeric, p_until timestamptz default null)
returns void language plpgsql set search_path = '' as $$
declare
  d0 timestamptz := p_day::timestamp at time zone 'America/Chicago';
  lim timestamptz := least(coalesce(p_until, d0 + interval '1 day'), d0 + interval '1 day');
  f numeric := greatest(0, least(1, extract(epoch from lim - d0) / 86400.0));
  h numeric := (('x' || substr(md5(p_org::text || p_day::text), 1, 7))::bit(28)::int) / 268435455.0;
  need int; i int; ts timestamptz; hr numeric; secs int; ah boolean; st text; ch text; src text; job text; area text; val numeric; est record; is_install boolean;
  sources text[] := array['Google Local Services', 'Google Search', 'Website', 'Referral', 'Google Business Profile', 'Facebook', 'Repeat customer'];
  svc_jobs text[] := array['No-heat call', 'Tune-up', 'Thermostat install', 'Duct repair', 'Maintenance plan', 'AC repair'];
  inst_jobs text[] := array['Furnace replacement', 'Heat pump install', 'Water heater'];
  areas text[] := array['East Nashville', 'Franklin', 'Brentwood', 'Mt. Juliet', 'Hendersonville', 'Bellevue', 'Donelson', 'Green Hills', 'Murfreesboro', 'Antioch'];
begin
  if not exists (select 1 from public.orgs where id = p_org and is_demo and (live_at is null or (live_at at time zone 'America/Chicago')::date <= p_day)) or f <= 0 then return; end if;

  need := round((6 + 8 * h) * p_scale * case when extract(isodow from p_day) > 5 then 0.6 else 1 end * f)::int
          - (select count(*) from public.mc_leads where org_id = p_org and created_at >= d0 and created_at < d0 + interval '1 day')::int;
  for i in 1..greatest(need, 0) loop
    hr := case when random() < 0.32 then 18 + random() * 14 else 8 + random() * 10 end;
    ts := d0 + (hr - case when hr >= 24 then 24 else 0 end) * interval '1 hour';
    continue when ts >= lim;
    ah := hr >= 18 or extract(isodow from p_day) > 5;
    ch := (array['call', 'call', 'call', 'form', 'sms'])[1 + floor(random() * 5)::int];
    src := sources[1 + floor(random() * 7)::int];
    is_install := random() < 0.15;
    job := case when is_install then inst_jobs[1 + floor(random() * 3)::int] else svc_jobs[1 + floor(random() * 6)::int] end;
    area := areas[1 + floor(random() * 10)::int];
    val := case when is_install then round((2400 + random() * 11600)::numeric, -1) else round((150 + random() * random() * 1100)::numeric, -1) end;
    secs := case when ch = 'call' then 4 + floor(random() * 9)::int when random() < 0.008 then 70 + floor(random() * 60)::int else 15 + floor(random() * 36)::int end;
    st := (array['booked', 'booked', 'qualified', 'qualified', 'responded', 'lost'])[1 + floor(random() * 6)::int];
    insert into public.mc_leads (org_id, created_at, source, channel, area, job_type, est_value, quality, response_seconds, after_hours, status, handoff)
    values (p_org, ts, src, ch, area, job, val, null, secs, ah, st, random() < 0.12);
    insert into public.mc_events (org_id, at, engine, title, detail, status) values
      (p_org, ts, 'G', case ch when 'call' then 'Call' when 'sms' then 'Text lead' else 'Form lead' end || ' from ' || src, job || ' · ' || area,
       case when st = 'booked' then 'booked' else 'qualified' end),
      (p_org, ts + secs * interval '1 second', 'R',
       case when ah then 'After-hours ' else 'Inbound ' end || case ch when 'call' then 'call' when 'sms' then 'text' else 'form' end,
       'answered in ' || secs || 's · ' || job || case when st = 'booked' then ' · booked' else '' end,
       case st when 'booked' then 'booked' when 'lost' then 'live' else 'qualified' end);
    if st = 'booked' then
      insert into public.mc_appointments (org_id, created_at, source, scheduled_for, value)
      values (p_org, ts + interval '4 minutes', 'respond', ts + (1 + floor(random() * 4)) * interval '1 day', val);
    end if;
    if is_install and st <> 'lost' then
      insert into public.mc_estimates (org_id, estimate_no, job_type, amount, sent_at, status)
      values (p_org, 'E-' || to_char(ts, 'YYMMDD') || '-' || substr(md5(random()::text), 1, 6), job, val, least(ts + interval '3 hours', lim), 'open');
    end if;
  end loop;

  need := round((6 + 6 * h) * p_scale * case when extract(isodow from p_day) > 5 then 0.6 else 1 end * f)::int
          - (select count(*) from public.mc_events where org_id = p_org and engine = 'A' and at >= d0 and at < d0 + interval '1 day')::int;
  for est in select id, job_type, amount, sent_at from public.mc_estimates
             where org_id = p_org and status = 'open' and not frozen and sent_at < d0 and sent_at > d0 - interval '90 days'
             order by random() limit greatest(need, 0) loop
    ts := d0 + (9 + random() * 9) * interval '1 hour';
    continue when ts >= lim;
    update public.mc_estimates set touches = touches + 1, last_touch_at = ts where id = est.id;
    if random() < 0.03 then
      update public.mc_estimates set status = 'won', won_via = 'followup', won_at = ts where id = est.id;
      insert into public.mc_appointments (org_id, created_at, source, scheduled_for, value) values (p_org, ts, 'followup', ts + interval '2 days', est.amount);
      insert into public.mc_events (org_id, at, engine, title, detail, status)
      values (p_org, ts, 'A', 'Quote won on follow-up', est.job_type || ' · ' || public.mc_money(est.amount), 'booked');
    else
      insert into public.mc_events (org_id, at, engine, title, detail, status)
      values (p_org, ts, 'A', 'Follow-up sent',
              (array['text', 'email'])[1 + floor(random() * 2)::int] || ' · day ' || greatest(1, p_day - (est.sent_at at time zone 'America/Chicago')::date) || ' · ' || est.job_type, 'live');
    end if;
  end loop;

  need := round((2.5 + 3 * (1 - h)) * p_scale * f)::int
          - (select count(*) from public.mc_events where org_id = p_org and engine = 'N' and at >= d0 and at < d0 + interval '1 day')::int;
  for est in select id, job_type, amount, sent_at from public.mc_estimates
             where org_id = p_org and frozen and status = 'open' order by random() limit greatest(need, 0) loop
    ts := d0 + (10 + random() * 7) * interval '1 hour';
    continue when ts >= lim;
    update public.mc_estimates set touches = touches + 1, last_touch_at = ts where id = est.id;
    if random() < 0.004 then
      update public.mc_estimates set status = 'won', won_via = 'revival', won_at = ts where id = est.id;
      insert into public.mc_appointments (org_id, created_at, source, scheduled_for, value) values (p_org, ts, 'revival', ts + interval '3 days', est.amount);
      insert into public.mc_events (org_id, at, engine, title, detail, status)
      values (p_org, ts, 'N', 'Old estimate back as a job', est.job_type || ' · ' || public.mc_money(est.amount), 'booked');
    else
      insert into public.mc_events (org_id, at, engine, title, detail, status)
      values (p_org, ts, 'N', 'Revival message sent', est.job_type || ' · quoted ' || to_char(est.sent_at, 'Mon YYYY'), 'live');
    end if;
  end loop;
  -- A steady floor of revived jobs, so the sample never shows an empty month
  if (p_day - date '2026-01-01') % (case when p_scale > 1 then 5 else 10 end) = 3 and d0 + interval '14 hours' < lim
     and not exists (select 1 from public.mc_estimates where org_id = p_org and won_via = 'revival' and won_at >= d0 and won_at < d0 + interval '1 day') then
    select id, job_type, amount, sent_at into est from public.mc_estimates where org_id = p_org and frozen and status = 'open' order by random() limit 1;
    if found then
      ts := d0 + interval '14 hours';
      update public.mc_estimates set status = 'won', won_via = 'revival', won_at = ts, touches = touches + 1, last_touch_at = ts where id = est.id;
      insert into public.mc_appointments (org_id, created_at, source, scheduled_for, value) values (p_org, ts, 'revival', ts + interval '3 days', est.amount);
      insert into public.mc_events (org_id, at, engine, title, detail, status)
      values (p_org, ts, 'N', 'Old estimate back as a job', est.job_type || ' · ' || public.mc_money(est.amount), 'booked');
    end if;
  end if;
  update public.mc_estimates set completed_paid_at = d0 + interval '15 hours', paid_amount = amount
  where org_id = p_org and won_via = 'revival' and completed_paid_at is null and won_at < d0 - interval '6 days' and d0 + interval '15 hours' < lim;

  for i in 0..11 loop
    ts := d0 + i * interval '2 hours' + interval '7 minutes';
    continue when ts >= lim or exists (select 1 from public.mc_sync_runs where org_id = p_org and at = ts);
    insert into public.mc_sync_runs (org_id, at, records, latency_ms, ok)
    values (p_org, ts, (8 + floor(random() * 40 * p_scale))::int, (180 + floor(random() * 420))::int, true);
    if i in (4, 6, 8, 10) then
      insert into public.mc_events (org_id, at, engine, title, detail, status)
      select p_org, ts, 'I', 'CRM sync', r.records || ' records · ' || r.latency_ms || ' ms', 'qualified'
      from public.mc_sync_runs r where r.org_id = p_org and r.at = ts;
    end if;
  end loop;
end $$;

-- Nightly: finish yesterday for the sample orgs and trim old rows so the sample never grows without limit
create or replace function ops_private.demo_roll(p_today date)
returns void language plpgsql set search_path = '' as $$
declare o record; cut timestamptz := now() - interval '61 days';
begin
  for o in select id, case when tier = 'greenhouse' then 1 else 2.4 end as scale from public.orgs where is_demo loop
    perform ops_private.demo_day(o.id, p_today - 1, o.scale, null);
    delete from public.mc_events where org_id = o.id and at < cut;
    delete from public.mc_leads where org_id = o.id and created_at < cut;
    delete from public.mc_appointments where org_id = o.id and created_at < cut;
    delete from public.mc_sync_runs where org_id = o.id and at < cut;
    delete from public.client_daily_metrics where org_id = o.id and day < p_today - 61;
  end loop;
end $$;

-- Rebuilds the two sample orgs from scratch (history since each one's go-live, up to 60 days). Only ever run by hand.
create or replace function public.mc_seed_demo()
returns text language plpgsql security definer set search_path = '' as $$
declare today date := (now() at time zone 'America/Chicago')::date; o record; d date;
  jobs text[] := array['Furnace replacement', 'Heat pump install', 'AC replacement', 'Ductwork', 'Water heater', 'Whole-home system', 'Mini-split install'];
begin
  delete from public.orgs where is_demo and slug in ('hollow-creek-hvac', 'ridgeline-home-services');
  insert into public.orgs (slug, name, tier, is_demo, crm, locations, signed_at, kickoff_at, live_at, status, trade, service_area, comms_channel)
  values ('hollow-creek-hvac', 'Hollow Creek Heating & Air', 'greenhouse', true, 'ServiceTitan', 1,
          now() - interval '62 days', now() - interval '59 days', now() - interval '46 days', 'live', 'hvac', 'Nashville', 'sms'),
         ('ridgeline-home-services', 'Ridgeline Home Services', 'orchard', true, 'Housecall Pro', 3,
          now() - interval '68 days', now() - interval '65 days', now() - interval '52 days', 'live', 'hvac', 'Middle Tennessee', 'slack');
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

-- The only write a visitor can trigger: keeps a sample org moving while someone is watching.
-- At most once every 40 seconds per org, sample orgs only, capped per day.
create or replace function public.mc_demo_tick(p_slug text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare o public.orgs; sc numeric; today date := (now() at time zone 'America/Chicago')::date; x float := random(); est record;
begin
  select * into o from public.orgs where slug = p_slug and is_demo for update skip locked;
  if not found or (o.demo_ticked_at is not null and o.demo_ticked_at > now() - interval '40 seconds') then return false; end if;
  update public.orgs set demo_ticked_at = now() where id = o.id;
  sc := case when o.tier = 'greenhouse' then 1 else 2.4 end;
  perform ops_private.demo_day(o.id, today, sc, now());
  if (select count(*) from public.mc_events where org_id = o.id and at >= now() - interval '12 hours') < 260 * sc then
    if x < 0.45 then
      select job_type, sent_at into est from public.mc_estimates where org_id = o.id and status = 'open' and not frozen order by random() limit 1;
      if found then
        insert into public.mc_events (org_id, at, engine, title, detail, status)
        values (o.id, now(), 'A', 'Follow-up sent', (array['text', 'email'])[1 + floor(random() * 2)::int] || ' · day '
                || greatest(1, today - (est.sent_at at time zone 'America/Chicago')::date) || ' · ' || est.job_type, 'live');
      end if;
    elsif x < 0.75 then
      select job_type, sent_at into est from public.mc_estimates where org_id = o.id and status = 'open' and frozen order by random() limit 1;
      if found then
        insert into public.mc_events (org_id, at, engine, title, detail, status)
        values (o.id, now(), 'N', 'Revival message sent', est.job_type || ' · quoted ' || to_char(est.sent_at, 'Mon YYYY'), 'live');
      end if;
    else
      insert into public.mc_sync_runs (org_id, at, records, latency_ms, ok) values (o.id, now(), (3 + floor(random() * 14))::int, (180 + floor(random() * 420))::int, true);
      insert into public.mc_events (org_id, at, engine, title, detail, status)
      values (o.id, now(), 'I', 'CRM sync', (3 + floor(random() * 14))::int || ' records · ' || coalesce(o.crm, 'CRM'), 'qualified');
    end if;
  end if;
  return true;
end $$;

revoke all on all functions in schema ops_private from public, anon, authenticated;
revoke all on function public.mc_seed_demo() from public, anon, authenticated;
revoke all on function public.mc_view(text), public.mc_demo_tick(text) from public;
grant execute on function public.mc_view(text), public.mc_demo_tick(text) to anon, authenticated;

-- Build the sample orgs, then start the 15-minute schedule
select public.mc_seed_demo();
select cron.schedule('grain-ops-tick', '*/15 * * * *', 'select ops_private.tick()');
