-- GRAIN ops backend, part 2: onboarding, daily numbers, guarantees, updates, HQ, ingest.
-- The logic lives in ops_private (not exposed by the API). Public functions are thin, checked wrappers.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create policy "staff insert" on public.mc_payments for insert to authenticated with check ((select public.is_staff()));
create policy "staff delete" on public.mc_payments for delete to authenticated using ((select public.is_staff()));

-- Payback eligibility follows the frozen list total
create or replace function public.orgs_before_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.unsold_estimates_frozen_total is not null then
    new.payback_eligible := new.unsold_estimates_frozen_total >= 1500000;
  end if;
  return new;
end $$;
create trigger orgs_before_write before insert or update of unsold_estimates_frozen_total on public.orgs
  for each row execute function public.orgs_before_write();
revoke all on function public.orgs_before_write() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Onboarding and go-live
-- ---------------------------------------------------------------------------
create or replace function ops_private.start_onboarding(p_org uuid, p_kickoff timestamptz)
returns int language plpgsql set search_path = '' as $$
declare n int; k date := (p_kickoff at time zone 'America/Chicago')::date;
begin
  update public.orgs set kickoff_at = p_kickoff, signed_at = coalesce(signed_at, now()),
    status = case when status = 'live' then status else 'onboarding' end
  where id = p_org;
  if not found then raise exception 'org not found'; end if;
  delete from public.onboarding_tasks where org_id = p_org and done_at is null;
  insert into public.onboarding_tasks (org_id, template_id, milestone, milestone_title, title, owner, sort, due_at)
  select p_org, t.id, t.milestone, t.milestone_title, t.title, t.owner, t.sort,
         ((k + (t.day_to - 1))::timestamp + time '17:00') at time zone 'America/Chicago'
  from public.onboarding_template t
  where not exists (select 1 from public.onboarding_tasks x where x.org_id = p_org and x.template_id = t.id);
  get diagnostics n = row_count;
  insert into public.ops_tasks (title, kind, due_at, org_id, auto_key)
  values ('Start Guarantee check: live by day 14 or month one is free', 'checkpoint',
          ((k + 13)::timestamp + time '09:00') at time zone 'America/Chicago', p_org, 'start:' || p_org)
  on conflict (auto_key) do update set due_at = excluded.due_at, done_at = null, note = null;
  return n;
end $$;

create or replace function ops_private.mark_live(p_org uuid, p_live timestamptz)
returns void language plpgsql set search_path = '' as $$
declare o public.orgs;
begin
  update public.orgs set live_at = p_live, status = 'live' where id = p_org returning * into o;
  if not found then raise exception 'org not found'; end if;
  update public.onboarding_pauses set ended_at = p_live where org_id = p_org and ended_at is null;
  insert into public.ops_tasks (title, kind, due_at, org_id, auto_key)
  values ('Charge setup plus month one (go-live)', 'checkpoint', p_live, p_org, 'golive-charge:' || p_org)
  on conflict (auto_key) do nothing;
  if o.payback_eligible then
    insert into public.ops_tasks (title, kind, due_at, org_id, auto_key) values
      ('Payback check, day 90: if revived jobs have not covered what they paid, pause the monthly', 'checkpoint', p_live + interval '90 days', p_org, 'payback90:' || p_org),
      ('Payback check, day 180: refund the difference if still short', 'checkpoint', p_live + interval '180 days', p_org, 'payback180:' || p_org)
    on conflict (auto_key) do update set due_at = excluded.due_at;
  end if;
  update public.ops_tasks set done_at = coalesce(done_at, now()),
    note = case when o.kickoff_at is null then 'No kickoff date on file'
                when p_live <= o.kickoff_at + interval '14 days' + ops_private.pause_time(p_org, p_live) then 'Met: live inside 14 days'
                else 'Missed: month one is free' end
  where auto_key = 'start:' || p_org;
  insert into public.outbox (org_id, audience, channel, kind, to_addr, body, dedupe_key)
  values (p_org, 'internal', 'slack', 'onboarding', '#onboarding', o.name || ' is live.', 'live:' || p_org)
  on conflict (dedupe_key) do nothing;
end $$;

-- ---------------------------------------------------------------------------
-- Daily client numbers (one row per client per Central-time day)
-- ---------------------------------------------------------------------------
create or replace function ops_private.compute_daily(p_day date)
returns int language plpgsql set search_path = '' as $$
declare n int;
  d0 timestamptz := p_day::timestamp at time zone 'America/Chicago';
  d1 timestamptz := (p_day + 1)::timestamp at time zone 'America/Chicago';
begin
  insert into public.client_daily_metrics as m (org_id, day, inbound_calls, answered_60s, answer_rate, avg_response_seconds, new_leads, booked,
    followups_sent, estimates_in_followup, estimates_revived, revived_booked_value, revived_paid_value, computed_at)
  select o.id, p_day, l.calls, l.ans, case when l.calls > 0 then round(l.ans::numeric / l.calls, 4) end, l.avg_resp, l.n, a.n, e.n,
    (select count(*) from public.mc_estimates x where x.org_id = o.id and x.status = 'open' and x.frozen = false and x.sent_at < d1 and x.sent_at >= d1 - interval '90 days'),
    r.n, coalesce(r.v, 0), coalesce(p.v, 0), now()
  from public.orgs o
  cross join lateral (select count(*) filter (where channel = 'call') calls, count(*) filter (where channel = 'call' and response_seconds <= 60) ans,
                             round(avg(response_seconds) filter (where channel = 'call'), 1) avg_resp, count(*) n
                      from public.mc_leads where org_id = o.id and created_at >= d0 and created_at < d1) l
  cross join lateral (select count(*) n from public.mc_appointments where org_id = o.id and created_at >= d0 and created_at < d1) a
  cross join lateral (select count(*) n from public.mc_events where org_id = o.id and engine = 'A' and title = 'Follow-up sent' and at >= d0 and at < d1) e
  cross join lateral (select count(*) n, sum(amount) v from public.mc_estimates where org_id = o.id and won_via = 'revival' and won_at >= d0 and won_at < d1) r
  cross join lateral (select sum(coalesce(paid_amount, amount)) v from public.mc_estimates where org_id = o.id and won_via = 'revival' and completed_paid_at >= d0 and completed_paid_at < d1) p
  where o.status in ('onboarding', 'live')
  on conflict (org_id, day) do update set inbound_calls = excluded.inbound_calls, answered_60s = excluded.answered_60s, answer_rate = excluded.answer_rate,
    avg_response_seconds = excluded.avg_response_seconds, new_leads = excluded.new_leads, booked = excluded.booked, followups_sent = excluded.followups_sent,
    estimates_in_followup = excluded.estimates_in_followup, estimates_revived = excluded.estimates_revived,
    revived_booked_value = excluded.revived_booked_value, revived_paid_value = excluded.revived_paid_value, computed_at = now();
  get diagnostics n = row_count;
  return n;
end $$;

-- ---------------------------------------------------------------------------
-- Guarantee status for one client
-- ---------------------------------------------------------------------------
-- Time the 14-day clock has been paused (client's late inputs only), up to a point in time
create or replace function ops_private.pause_time(p_org uuid, p_until timestamptz)
returns interval language sql stable set search_path = '' as $$
  select coalesce(sum(least(coalesce(ended_at, p_until), p_until) - started_at), interval '0')
  from public.onboarding_pauses where org_id = p_org and started_at < p_until;
$$;

create or replace function ops_private.guarantees(p_org uuid)
returns jsonb language plpgsql stable set search_path = '' as $$
declare o public.orgs; paid numeric; revived numeric; m0 timestamptz; n_calls int; n_ans int; d int; due timestamptz; paused boolean; held interval;
begin
  select * into o from public.orgs where id = p_org;
  if not found then return null; end if;
  held := ops_private.pause_time(p_org, coalesce(o.live_at, now()));
  paused := o.live_at is null and exists (select 1 from public.onboarding_pauses where org_id = p_org and ended_at is null);
  due := o.kickoff_at + interval '14 days' + held;
  m0 := date_trunc('month', now() at time zone 'America/Chicago') at time zone 'America/Chicago';
  select count(*), count(*) filter (where response_seconds <= 60) into n_calls, n_ans
  from public.mc_leads where org_id = p_org and channel = 'call' and created_at >= m0;
  select coalesce(sum(amount), 0) into paid from public.mc_payments where org_id = p_org;
  select coalesce(sum(coalesce(paid_amount, amount)), 0) into revived
  from public.mc_estimates where org_id = p_org and won_via = 'revival' and completed_paid_at is not null;
  d := case when o.live_at is not null then floor(extract(epoch from now() - o.live_at) / 86400)::int end;
  return jsonb_build_object(
    'start', jsonb_build_object(
      'status', case when o.kickoff_at is null then 'not_started'
                     when o.live_at is not null and o.live_at <= due then 'met'
                     when o.live_at is not null then 'missed'
                     when paused then 'paused'
                     when now() > due then 'missed' else 'on_track' end,
      'due', due, 'live_at', o.live_at, 'paused', paused, 'pause_days', round((extract(epoch from held) / 86400)::numeric, 1),
      'days_left', case when o.kickoff_at is not null and o.live_at is null then greatest(0, ceil(extract(epoch from due - now()) / 86400))::int end),
    'call_promise', jsonb_build_object(
      'month', to_char(now() at time zone 'America/Chicago', 'YYYY-MM'), 'inbound', n_calls, 'answered_60s', n_ans,
      'rate', case when n_calls > 0 then round(n_ans::numeric / n_calls, 4) end,
      'status', case when o.live_at is null then 'not_live' when n_calls = 0 then 'no_calls'
                     when n_ans::numeric / n_calls >= 0.99 then 'met' else 'at_risk' end),
    'payback', jsonb_build_object(
      'eligible', o.payback_eligible, 'paid_to_grain', paid, 'revived_paid', revived, 'gap', greatest(paid - revived, 0), 'day', d,
      'day90', o.live_at + interval '90 days', 'day180', o.live_at + interval '180 days',
      'status', case when not o.payback_eligible then 'not_eligible' when o.live_at is null then 'not_live'
                     when paid > 0 and revived >= paid then 'covered' when d >= 180 then 'refund_due'
                     when d >= 90 then 'monthly_paused' else 'in_window' end));
end $$;

-- ---------------------------------------------------------------------------
-- GRAIN's own week: touches, conversations, audits (week starts Monday, Central)
-- ---------------------------------------------------------------------------
create or replace function ops_private.week_stats(p_start date)
returns jsonb language sql stable set search_path = '' as $$
  with b as (select p_start::timestamp at time zone 'America/Chicago' as t0, (p_start + 7)::timestamp at time zone 'America/Chicago' as t1)
  select jsonb_build_object(
    'week_start', p_start,
    'touches', (select count(*) from public.prospect_touches t, b where t.at >= b.t0 and t.at < b.t1),
    'conversations', (select count(*) from public.prospect_touches t, b where t.at >= b.t0 and t.at < b.t1 and t.outcome in ('conversation', 'audit_booked')),
    'audits_booked', (select count(*) from public.prospect_touches t, b where t.at >= b.t0 and t.at < b.t1 and t.outcome = 'audit_booked'),
    'audits_held', (select count(*) from public.prospects p, b where p.audit_held_at >= b.t0 and p.audit_held_at < b.t1),
    'wins', (select count(*) from public.prospects p, b where p.won_at >= b.t0 and p.won_at < b.t1),
    'targets', jsonb_build_object('touches', jsonb_build_array(40, 60), 'conversations', jsonb_build_array(8, 12), 'audits_held', jsonb_build_array(2, 3)));
$$;

-- "1 job", "3 jobs": updates read like a person wrote them
create or replace function ops_private.n(p_n numeric, p_one text, p_many text)
returns text language sql immutable set search_path = '' as $$
  select to_char(coalesce(p_n, 0), 'FM999,999,990') || ' ' || case when p_n = 1 then p_one else p_many end;
$$;

-- ---------------------------------------------------------------------------
-- Daily updates: the HQ digest, client updates, alerts, Monday summaries, monthly call-promise checks.
-- Everything lands in public.outbox. Nothing here sends.
-- ---------------------------------------------------------------------------
create or replace function ops_private.generate_updates(p_day date)
returns int language plpgsql set search_path = '' as $$
declare
  n int := 0; c int; r record; pipe record; y date := p_day - 1;
  t_int timestamptz := (p_day::timestamp + time '07:00') at time zone 'America/Chicago';
  t_cli timestamptz := (p_day::timestamp + time '07:30') at time zone 'America/Chicago';
  eod timestamptz := (p_day + 1)::timestamp at time zone 'America/Chicago';
  wk date := date_trunc('week', p_day::timestamp)::date;
  ws jsonb; body text; clients text := ''; first_calls text; due_n int; m0 date; m_calls int; m_ans int; rev_paid numeric;
begin
  for r in
    select o.id, o.name, o.comms_channel, o.slack_channel, o.primary_contact_phone, o.primary_contact_email,
           m.inbound_calls, m.answered_60s, m.answer_rate, m.avg_response_seconds, m.booked, m.followups_sent, m.estimates_revived, m.revived_booked_value
    from public.orgs o join public.client_daily_metrics m on m.org_id = o.id and m.day = y
    where o.is_demo = false and o.status = 'live'
  loop
    body := r.name || ', yesterday: ' || case when r.inbound_calls = 0 then 'no calls came in' else ops_private.n(r.inbound_calls, 'call', 'calls') || ', ' || r.answered_60s || ' answered inside 60 seconds' end
      || case when r.inbound_calls > 0 then ' (' || round(r.answer_rate * 100, 1) || '%)' else '' end
      || '. ' || ops_private.n(r.booked, 'job', 'jobs') || ' booked. ' || ops_private.n(r.followups_sent, 'follow-up', 'follow-ups') || ' sent.'
      || case when r.estimates_revived > 0 then ' ' || ops_private.n(r.estimates_revived, 'old estimate came back as a job', 'old estimates came back as jobs') || ' (' || public.mc_money(r.revived_booked_value) || ').' else '' end
      || ' Questions? Reply here.';
    if r.comms_channel <> 'none' then
      insert into public.outbox (org_id, audience, channel, kind, to_addr, body, scheduled_for, dedupe_key)
      values (r.id, 'client', r.comms_channel, 'daily_update',
              case r.comms_channel when 'sms' then r.primary_contact_phone when 'slack' then r.slack_channel else r.primary_contact_email end,
              body, t_cli, 'daily:' || r.id || ':' || p_day)
      on conflict (dedupe_key) do nothing;
      get diagnostics c = row_count; n := n + c;
    end if;
    clients := clients || E'\n• ' || r.name || ': ' || ops_private.n(r.inbound_calls, 'call', 'calls') || ', '
      || coalesce(round(r.answer_rate * 100, 1) || '% inside 60s', 'none to answer') || ', ' || r.booked || ' booked, '
      || public.mc_money(r.revived_booked_value) || ' revived';
    if r.inbound_calls > 0 and r.answer_rate < 0.99 then
      insert into public.outbox (org_id, audience, channel, kind, to_addr, body, scheduled_for, dedupe_key)
      values (r.id, 'internal', 'slack', 'alert', '#alerts',
              r.name || ': ' || round(r.answer_rate * 100, 1) || '% of calls answered inside 60 seconds yesterday (' || r.answered_60s || ' of ' || r.inbound_calls
                || '). The promise is 99% for the month. Check forwarding and the voice agent.',
              t_int, 'alert:rate:' || r.id || ':' || y)
      on conflict (dedupe_key) do nothing;
      get diagnostics c = row_count; n := n + c;
    end if;
    if coalesce(r.avg_response_seconds, 0) > 60 then
      insert into public.outbox (org_id, audience, channel, kind, to_addr, body, scheduled_for, dedupe_key)
      values (r.id, 'internal', 'slack', 'alert', '#alerts',
              r.name || ': average response was ' || round(r.avg_response_seconds) || ' seconds yesterday. The standard is under 60.',
              t_int, 'alert:resp:' || r.id || ':' || y)
      on conflict (dedupe_key) do nothing;
      get diagnostics c = row_count; n := n + c;
    end if;
  end loop;

  select count(*) into c from public.ingest_events where received_at >= now() - interval '24 hours' and processed_at is null;
  if c > 0 then
    insert into public.outbox (audience, channel, kind, to_addr, body, scheduled_for, dedupe_key)
    values ('internal', 'slack', 'alert', '#alerts', ops_private.n(c, 'webhook event', 'webhook events') || ' in the last 24 hours could not be matched to a client or processed. Open HQ, System.', t_int, 'alert:ingest:' || p_day)
    on conflict (dedupe_key) do nothing;
  end if;

  select count(*) filter (where stage = 'qualified') q, count(*) filter (where stage = 'contacted') ct, count(*) filter (where stage = 'conversation') cv,
         count(*) filter (where stage = 'audit_booked') ab, count(*) filter (where stage = 'proposal') pr
  into pipe from public.prospects;
  ws := ops_private.week_stats(wk);
  select count(*) into due_n from public.ops_tasks where done_at is null and due_at < eod;
  select coalesce(string_agg('• ' || x.business_name || ' (' || x.score || ')' || coalesce(': ' || x.next_action, ''), E'\n' order by x.rn), '• Nobody queued. Add prospects in HQ.')
  into first_calls
  from (select business_name, score, next_action,
               row_number() over (order by (next_action_at is not null and next_action_at < eod) desc, score desc) rn
        from public.prospects where stage not in ('won', 'lost', 'nurture') and disqualified_reason is null) x
  where x.rn <= 5;
  body := 'GRAIN daily, ' || to_char(p_day, 'Dy Mon FMDD')
    || E'\nThis week: ' || (ws->>'touches') || ' touches (goal 40 to 60), ' || (ws->>'conversations') || ' owner conversations (8 to 12), '
    || (ws->>'audits_held') || ' audits held (2 to 3)'
    || E'\nPipeline: ' || pipe.q || ' qualified, ' || pipe.ct || ' contacted, ' || pipe.cv || ' in conversation, ' || pipe.ab || ' audits booked, ' || pipe.pr || ' proposals out'
    || E'\nDue today: ' || ops_private.n(due_n, 'task', 'tasks')
    || E'\nCall first:\n' || first_calls
    || case when clients <> '' then E'\nClients yesterday:' || clients else '' end;
  insert into public.outbox (audience, channel, kind, to_addr, body, scheduled_for, dedupe_key)
  values ('internal', 'slack', 'hq_digest', '#hq-daily', body, t_int, 'hq-digest:' || p_day)
  on conflict (dedupe_key) do nothing;
  get diagnostics c = row_count; n := n + c;

  if extract(isodow from p_day) = 1 then
    for r in
      select o.id, o.name, o.tier, o.slack_channel, o.primary_contact_email,
             sum(m.inbound_calls) calls, sum(m.answered_60s) ans, sum(m.booked) booked, sum(m.followups_sent) fu, sum(m.estimates_revived) rv, sum(m.revived_booked_value) rvv
      from public.orgs o join public.client_daily_metrics m on m.org_id = o.id and m.day between p_day - 7 and y
      where o.is_demo = false and o.status = 'live' group by o.id
    loop
      insert into public.outbox (org_id, audience, channel, kind, to_addr, subject, body, scheduled_for, dedupe_key)
      values (r.id, 'client', case when r.tier = 'greenhouse' then 'email' else 'slack' end, 'weekly_summary',
              case when r.tier = 'greenhouse' then r.primary_contact_email else r.slack_channel end, 'Your week with GRAIN',
              r.name || ', last week: ' || ops_private.n(r.calls, 'call', 'calls') || ', '
                || case when r.calls > 0 then round(r.ans * 100.0 / r.calls, 1) || '% answered inside 60 seconds' else 'none to answer' end
                || '. ' || ops_private.n(r.booked, 'job', 'jobs') || ' booked. ' || ops_private.n(r.fu, 'follow-up', 'follow-ups') || ' sent. ' || ops_private.n(r.rv, 'old estimate', 'old estimates') || ' back as ' || case when r.rv = 1 then 'a job' else 'jobs' end || ', worth ' || public.mc_money(r.rvv) || '.',
              t_cli, 'weekly:' || r.id || ':' || p_day)
      on conflict (dedupe_key) do nothing;
      get diagnostics c = row_count; n := n + c;
    end loop;
    ws := ops_private.week_stats(wk - 7);
    insert into public.outbox (audience, channel, kind, to_addr, body, scheduled_for, dedupe_key)
    values ('internal', 'slack', 'weekly_scorecard', '#hq-daily',
            'Last week: ' || (ws->>'touches') || ' touches (goal 40 to 60), ' || (ws->>'conversations') || ' owner conversations (8 to 12), '
              || (ws->>'audits_held') || ' audits held (2 to 3), ' || (ws->>'wins') || ' signed. '
              || ops_private.n((select count(*) from public.orgs where is_demo = false and status = 'live'), 'client', 'clients') || ' live (goal 5 by Dec 31).',
            t_int, 'scorecard:' || p_day)
    on conflict (dedupe_key) do nothing;
    get diagnostics c = row_count; n := n + c;
  end if;

  if extract(day from p_day) = 1 then
    m0 := (p_day - interval '1 month')::date;
    for r in select o.id, o.name from public.orgs o where o.is_demo = false and o.status = 'live' loop
      select coalesce(sum(inbound_calls), 0), coalesce(sum(answered_60s), 0) into m_calls, m_ans
      from public.client_daily_metrics where org_id = r.id and day >= m0 and day < p_day;
      insert into public.ops_tasks (title, kind, due_at, org_id, auto_key, note)
      values ('Call promise check for ' || to_char(m0, 'FMMonth') || ': ' || r.name, 'checkpoint', t_int, r.id,
              'callpromise:' || r.id || ':' || to_char(m0, 'YYYY-MM'),
              case when m_calls = 0 then 'No inbound calls on record.'
                   when m_ans::numeric / m_calls >= 0.99 then 'Met: ' || round(m_ans * 100.0 / m_calls, 2) || '% (' || m_ans || ' of ' || m_calls || ').'
                   else 'Missed: ' || round(m_ans * 100.0 / m_calls, 2) || '% (' || m_ans || ' of ' || m_calls || '). Credit that month.' end)
      on conflict (auto_key) do nothing;
      select coalesce(sum(coalesce(paid_amount, amount)), 0) into rev_paid
      from public.mc_estimates
      where org_id = r.id and won_via = 'revival'
        and completed_paid_at >= (m0::timestamp at time zone 'America/Chicago') and completed_paid_at < (p_day::timestamp at time zone 'America/Chicago');
      if rev_paid > 0 then
        insert into public.ops_tasks (title, kind, due_at, org_id, auto_key, note)
        values ('Invoice the 10% revival share for ' || to_char(m0, 'FMMonth') || ': ' || r.name, 'checkpoint', t_int, r.id,
                'share:' || r.id || ':' || to_char(m0, 'YYYY-MM'),
                '$' || to_char(round(rev_paid * 0.10, 2), 'FM999,999,990.00') || ' due on $' || to_char(rev_paid, 'FM999,999,990')
                  || ' of revived jobs completed and paid last month. Reconcile against the client''s report first.')
        on conflict (auto_key) do nothing;
      end if;
    end loop;
  end if;
  return n;
end $$;

-- Slack is the only channel that sends from here, and only once a webhook is saved for that channel.
-- Texts and emails wait in the outbox until GoHighLevel is connected. Stale messages are never sent late.
create or replace function ops_private.send_due()
returns int language plpgsql set search_path = '' as $$
declare r record; hook text; n int := 0;
begin
  update public.outbox set status = 'skipped', error = 'Expired before a sender was connected'
  where status = 'queued' and scheduled_for < now() - interval '18 hours';
  for r in select * from public.outbox where status = 'queued' and channel = 'slack' and scheduled_for <= now() order by scheduled_for limit 25 loop
    select value into hook from ops_private.secrets where name = 'slack_webhook:' || coalesce(r.to_addr, '');
    if hook is null and r.audience = 'internal' then
      select value into hook from ops_private.secrets where name = 'slack_webhook:default';
    end if;
    continue when hook is null;
    perform net.http_post(url := hook,
      body := jsonb_build_object('text', case when r.audience = 'internal' then '[' || coalesce(r.to_addr, 'hq') || '] ' else '' end || r.body),
      headers := jsonb_build_object('Content-Type', 'application/json'));
    update public.outbox set status = 'sent', sent_at = now() where id = r.id;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Runs every 15 minutes. Central time, safe across daylight saving, once per day per job.
create or replace function ops_private.tick()
returns void language plpgsql set search_path = '' as $$
declare lt timestamp := now() at time zone 'America/Chicago'; today date := lt::date; fresh int;
begin
  if lt::time >= time '00:15' then
    insert into ops_private.job_runs (job, day) values ('compute_daily', today) on conflict do nothing;
    get diagnostics fresh = row_count;
    if fresh = 1 then
      perform ops_private.demo_roll(today);
      perform ops_private.compute_daily(today - 1);
    end if;
  end if;
  if lt::time >= time '07:00' then
    insert into ops_private.job_runs (job, day) values ('generate_updates', today) on conflict do nothing;
    get diagnostics fresh = row_count;
    if fresh = 1 then
      perform ops_private.compute_daily(today - 1);
      perform ops_private.generate_updates(today);
    end if;
  end if;
  perform ops_private.send_due();
  delete from ops_private.job_runs where day < today - 30;
end $$;

-- ---------------------------------------------------------------------------
-- HQ: one call returns the whole morning view
-- ---------------------------------------------------------------------------
create or replace function ops_private.hq_overview()
returns jsonb language plpgsql stable set search_path = '' as $$
declare
  tz constant text := 'America/Chicago';
  lt timestamp := now() at time zone tz;
  today date := lt::date;
  eod timestamptz := (today + 1)::timestamp at time zone tz;
begin
  return jsonb_build_object(
    'today', today, 'now', now(),
    'week', ops_private.week_stats(date_trunc('week', lt)::date),
    'goal', jsonb_build_object(
      'clients_live', (select count(*) from public.orgs where is_demo = false and status = 'live'),
      'clients_onboarding', (select count(*) from public.orgs where is_demo = false and status = 'onboarding'),
      'target', 5, 'by', '2026-12-31',
      'collected_30d', (select coalesce(sum(p.amount), 0) from public.mc_payments p join public.orgs o on o.id = p.org_id
                        where o.is_demo = false and p.at >= now() - interval '30 days')),
    'tasks', (select coalesce(jsonb_agg(to_jsonb(x) order by x.due_at nulls last), '[]'::jsonb) from (
        select t.id, t.title, t.kind, t.due_at, t.note, o.name as org, coalesce(t.due_at < now(), false) as overdue
        from public.ops_tasks t left join public.orgs o on o.id = t.org_id
        where t.done_at is null and (t.due_at is null or t.due_at < eod) order by t.due_at nulls last limit 40) x),
    'upcoming', (select coalesce(jsonb_agg(to_jsonb(x) order by x.due_at), '[]'::jsonb) from (
        select t.id, t.title, t.kind, t.due_at, o.name as org
        from public.ops_tasks t left join public.orgs o on o.id = t.org_id
        where t.done_at is null and t.due_at >= eod and t.due_at < eod + interval '14 days' order by t.due_at limit 20) x),
    'pipeline', (select jsonb_object_agg(s.stage, coalesce(c.n, 0))
                 from unnest(array['sourced','qualified','contacted','conversation','audit_booked','audit_held','proposal','won','lost','nurture']) as s(stage)
                 left join (select stage, count(*) n from public.prospects group by stage) c on c.stage = s.stage),
    'prospects', (select coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.rn), '[]'::jsonb) from (
        select p.id, p.business_name, p.trade, p.city, p.service_area, p.score, p.qualified, p.stage, p.source, p.phone, p.website,
               p.owner_name, p.owner_phone, p.owner_email, p.revenue_band, p.after_hours_result, p.est_unsold_band, p.next_action, p.next_action_at,
               p.touch_count, p.last_touch_at, p.disqualified_reason, p.notes, p.runs_ads, p.google_reviews, p.callback_minutes, p.locations,
               (p.next_action_at is not null and p.next_action_at < eod) as due,
               row_number() over (order by (p.next_action_at is not null and p.next_action_at < eod) desc, (p.disqualified_reason is null) desc, p.score desc, p.created_at desc) rn
        from public.prospects p where p.stage not in ('won', 'lost')) x where x.rn <= 80),
    'clients', (select coalesce(jsonb_agg(q.c order by q.c->>'name'), '[]'::jsonb) from (
        select jsonb_build_object(
          'id', o.id, 'slug', o.slug, 'name', o.name, 'tier', o.tier, 'status', o.status, 'trade', o.trade, 'service_area', o.service_area,
          'kickoff_at', o.kickoff_at, 'live_at', o.live_at, 'comms_channel', o.comms_channel, 'unsold_total', o.unsold_estimates_frozen_total,
          'day', case when o.kickoff_at is not null and o.live_at is null then (today - (o.kickoff_at at time zone tz)::date) + 1 end,
          'onboarding', (select jsonb_build_object('done', count(*) filter (where t.done_at is not null), 'total', count(*),
                'open', coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'milestone', t.milestone, 'title', t.title, 'owner', t.owner, 'due_at', t.due_at,
                                                             'overdue', t.due_at < now()) order by t.due_at, t.sort) filter (where t.done_at is null), '[]'::jsonb))
              from public.onboarding_tasks t where t.org_id = o.id),
          'last7', (select jsonb_build_object('inbound_calls', coalesce(sum(m.inbound_calls), 0), 'answered_60s', coalesce(sum(m.answered_60s), 0),
                'avg_response_seconds', round(avg(m.avg_response_seconds), 1), 'booked', coalesce(sum(m.booked), 0),
                'revived_booked_value', coalesce(sum(m.revived_booked_value), 0), 'revived_paid_value', coalesce(sum(m.revived_paid_value), 0))
              from public.client_daily_metrics m where m.org_id = o.id and m.day >= today - 7),
          'pause', (select jsonb_build_object('input', x.input, 'started_at', x.started_at, 'note', x.note)
                    from public.onboarding_pauses x where x.org_id = o.id and x.ended_at is null),
          'log', (select coalesce(jsonb_agg(to_jsonb(l) order by l.at desc), '[]'::jsonb)
                  from (select id, at, kind, score, minutes, body from public.client_log where org_id = o.id order by at desc limit 6) l),
          'qa_avg_30d', (select round(avg(score), 1) from public.client_log where org_id = o.id and kind = 'call_qa' and at >= now() - interval '30 days'),
          'access', (select coalesce(jsonb_agg(jsonb_build_object('email', i.email, 'claimed', i.claimed_at is not null) order by i.created_at), '[]'::jsonb)
                     from public.org_invites i where i.org_id = o.id),
          'guarantees', ops_private.guarantees(o.id)) as c
        from public.orgs o where o.is_demo = false) q),
    'outbox', (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) from (
        select b.id, b.created_at, b.audience, b.channel, b.kind, b.to_addr, b.subject, b.body, b.status, b.scheduled_for, b.sent_at, b.error, o.name as org
        from public.outbox b left join public.orgs o on o.id = b.org_id order by b.created_at desc limit 30) x),
    'system', jsonb_build_object(
      'slack_channels', (select coalesce(jsonb_agg(replace(name, 'slack_webhook:', '')), '[]'::jsonb) from ops_private.secrets where name like 'slack_webhook:%'),
      'ingest_key_set', exists (select 1 from ops_private.secrets where name = 'ingest_key'),
      'last_ingest_at', (select max(received_at) from public.ingest_events),
      'ingest_unprocessed', (select count(*) from public.ingest_events where processed_at is null),
      'last_runs', (select coalesce(jsonb_object_agg(j.job, j.ran_at), '{}'::jsonb) from (select job, max(ran_at) ran_at from ops_private.job_runs group by job) j),
      'website_leads_7d', (select count(*) from public.leads where created_at >= now() - interval '7 days' and coalesce(status, '') <> 'spam'),
      'demo_orgs', (select coalesce(jsonb_agg(slug), '[]'::jsonb) from public.orgs where is_demo)));
end $$;

-- ---------------------------------------------------------------------------
-- Ingest: one normalized event in, the right dashboard rows out
-- ---------------------------------------------------------------------------
create or replace function ops_private.apply_event(p_id bigint)
returns text language plpgsql set search_path = '' as $$
declare e public.ingest_events; n jsonb; o public.orgs; secs int; ah boolean; ts timestamptz; st text; src text; amt numeric;
begin
  select * into e from public.ingest_events where id = p_id for update;
  if e.org_id is null then
    update public.ingest_events set error = 'No client matches this event' where id = p_id;
    return 'no_org';
  end if;
  select * into o from public.orgs where id = e.org_id;
  n := e.payload;
  ts := coalesce((n->>'at')::timestamptz, e.received_at);
  if e.event_type = 'call' then
    secs := coalesce((n->>'response_seconds')::int, case when coalesce((n->>'answered')::boolean, true) then o.default_answer_seconds end);
    ah := coalesce((n->>'after_hours')::boolean,
                   extract(hour from ts at time zone 'America/Chicago') not between 8 and 17 or extract(isodow from ts at time zone 'America/Chicago') > 5);
    st := case when coalesce((n->>'booked')::boolean, false) then 'booked' when secs is not null then 'responded' else 'new' end;
    insert into public.mc_leads (org_id, created_at, source, channel, name, area, job_type, est_value, response_seconds, after_hours, status, handoff)
    values (o.id, ts, coalesce(n->>'source', 'Phone'), 'call', n->>'name', n->>'area', n->>'job_type', (n->>'est_value')::numeric, secs, ah, st, coalesce((n->>'handoff')::boolean, false));
    insert into public.mc_events (org_id, at, engine, title, detail, status)
    values (o.id, ts, 'R', case when ah then 'After-hours call' else 'Inbound call' end,
            concat_ws(' · ', case when secs is not null then 'answered in ' || secs || 's' else 'not answered' end, n->>'job_type', case when st = 'booked' then 'booked' end),
            case st when 'booked' then 'booked' when 'responded' then 'qualified' else 'live' end);
  elsif e.event_type = 'lead' then
    insert into public.mc_leads (org_id, created_at, source, channel, name, area, job_type, est_value, response_seconds, after_hours, status)
    values (o.id, ts, coalesce(n->>'source', 'Website'), case when n->>'channel' = 'sms' then 'sms' else 'form' end, n->>'name', n->>'area', n->>'job_type',
            (n->>'est_value')::numeric, (n->>'response_seconds')::int, coalesce((n->>'after_hours')::boolean, false),
            case when (n->>'response_seconds') is not null then 'responded' else 'new' end);
    insert into public.mc_events (org_id, at, engine, title, detail, status)
    values (o.id, ts, 'G', case when n->>'channel' = 'sms' then 'Text lead' else 'Form lead' end, concat_ws(' · ', n->>'source', n->>'job_type', n->>'area'), 'qualified');
  elsif e.event_type = 'appointment' then
    src := case when n->>'source' in ('followup', 'revival') then n->>'source' else 'respond' end;
    insert into public.mc_appointments (org_id, created_at, source, scheduled_for, value)
    values (o.id, ts, src, (n->>'scheduled_for')::timestamptz, (n->>'value')::numeric);
    insert into public.mc_events (org_id, at, engine, title, detail, status)
    values (o.id, ts, case src when 'followup' then 'A' when 'revival' then 'N' else 'R' end, 'Appointment booked',
            concat_ws(' · ', n->>'job_type', case when (n->>'value') is not null then public.mc_money((n->>'value')::numeric) end), 'booked');
  elsif e.event_type = 'estimate' then
    amt := (n->>'amount')::numeric;
    if coalesce(n->>'estimate_no', '') = '' or amt is null then raise exception 'estimate needs estimate_no and amount'; end if;
    insert into public.mc_estimates (org_id, estimate_no, customer, job_type, amount, sent_at, frozen, status, won_via, won_at, completed_paid_at, paid_amount)
    values (o.id, n->>'estimate_no', n->>'customer', n->>'job_type', amt, coalesce((n->>'sent_at')::timestamptz, ts), coalesce((n->>'frozen')::boolean, false),
            coalesce(n->>'status', 'open'), n->>'won_via', (n->>'won_at')::timestamptz, (n->>'completed_paid_at')::timestamptz, (n->>'paid_amount')::numeric)
    on conflict (org_id, estimate_no) where estimate_no is not null do update set
      amount = excluded.amount, status = excluded.status,
      customer = coalesce(excluded.customer, public.mc_estimates.customer), job_type = coalesce(excluded.job_type, public.mc_estimates.job_type),
      won_via = coalesce(excluded.won_via, public.mc_estimates.won_via), won_at = coalesce(excluded.won_at, public.mc_estimates.won_at),
      completed_paid_at = coalesce(excluded.completed_paid_at, public.mc_estimates.completed_paid_at),
      paid_amount = coalesce(excluded.paid_amount, public.mc_estimates.paid_amount);
    if n->>'status' = 'won' then
      insert into public.mc_events (org_id, at, engine, title, detail, status)
      values (o.id, ts, case when n->>'won_via' = 'revival' then 'N' else 'A' end,
              case when n->>'won_via' = 'revival' then 'Old estimate back as a job' else 'Quote won' end,
              concat_ws(' · ', n->>'job_type', public.mc_money(amt)), 'booked');
    end if;
  elsif e.event_type = 'followup' then
    update public.mc_estimates set touches = touches + 1, last_touch_at = ts where org_id = o.id and estimate_no = n->>'estimate_no';
    insert into public.mc_events (org_id, at, engine, title, detail, status)
    values (o.id, ts, case when coalesce((n->>'revival')::boolean, false) then 'N' else 'A' end,
            case when coalesce((n->>'revival')::boolean, false) then 'Revival message sent' else 'Follow-up sent' end,
            concat_ws(' · ', n->>'channel', case when (n->>'day') is not null then 'day ' || (n->>'day') end, n->>'job_type'), 'live');
  elsif e.event_type = 'sync' then
    insert into public.mc_sync_runs (org_id, at, records, latency_ms, ok)
    values (o.id, ts, coalesce((n->>'records')::int, 0), coalesce((n->>'latency_ms')::int, 0), coalesce((n->>'ok')::boolean, true));
    insert into public.mc_events (org_id, at, engine, title, detail, status)
    values (o.id, ts, 'I', 'CRM sync', coalesce((n->>'records')::int, 0) || ' records · ' || coalesce(n->>'system', o.crm, 'CRM'),
            case when coalesce((n->>'ok')::boolean, true) then 'qualified' else 'live' end);
  else
    update public.ingest_events set error = 'Unmapped event type' where id = p_id;
    return 'unmapped';
  end if;
  update public.ingest_events set processed_at = now(), error = null where id = p_id;
  return 'ok';
end $$;

create or replace function public.ops_ingest(p_key text, p_source text, p_external_id text, p_event_type text, p_org_ref text, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare k text; v_org uuid; v_id bigint; res text;
begin
  select value into k from ops_private.secrets where name = 'ingest_key';
  if k is null or p_key is null or p_key <> k then raise exception 'not allowed' using errcode = '42501'; end if;
  if p_source not in ('ghl', 'retell', 'manual') or coalesce(p_external_id, '') = '' then raise exception 'bad event'; end if;
  select id into v_org from public.orgs
  where is_demo = false and coalesce(p_org_ref, '') <> '' and (ghl_location_id = p_org_ref or retell_agent_id = p_org_ref or slug = p_org_ref) limit 1;
  insert into public.ingest_events (source, external_id, event_type, org_id, payload)
  values (p_source, left(p_external_id, 200), p_event_type, v_org, coalesce(p_payload, '{}'::jsonb))
  on conflict (source, external_id) do nothing returning id into v_id;
  if v_id is null then return jsonb_build_object('ok', true, 'duplicate', true); end if;
  begin
    res := ops_private.apply_event(v_id);
  exception when others then
    update public.ingest_events set error = left(sqlerrm, 300) where id = v_id;
    return jsonb_build_object('ok', true, 'stored', true, 'processed', false);
  end;
  return jsonb_build_object('ok', true, 'stored', true, 'processed', res = 'ok', 'note', res);
end $$;

-- ---------------------------------------------------------------------------
-- Public wrappers for HQ (staff only)
-- ---------------------------------------------------------------------------
create or replace function public.whoami()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_email text;
begin
  if v_uid is null then return jsonb_build_object('staff', false, 'orgs', '[]'::jsonb); end if;
  select lower(email) into v_email from auth.users
  where id = v_uid and email_confirmed_at is not null and public.session_proves_inbox();
  if v_email is not null then
    insert into public.org_members (org_id, user_id, role)
    select i.org_id, v_uid, 'owner' from public.org_invites i where i.email = v_email
    on conflict do nothing;
    update public.org_invites set claimed_at = now() where email = v_email and claimed_at is null;
    update public.staff set user_id = v_uid where lower(email) = v_email and user_id is null;
  end if;
  return jsonb_build_object('staff', public.is_staff(),
    'orgs', (select coalesce(jsonb_agg(o.slug order by o.name), '[]'::jsonb)
             from public.org_members m join public.orgs o on o.id = m.org_id where m.user_id = v_uid));
end $$;

create or replace function public.hq_overview()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  return ops_private.hq_overview();
end $$;

create or replace function public.ops_start_onboarding(p_org uuid, p_kickoff timestamptz)
returns int language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  return ops_private.start_onboarding(p_org, p_kickoff);
end $$;

create or replace function public.ops_mark_live(p_org uuid, p_live timestamptz default now())
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  perform ops_private.mark_live(p_org, p_live);
end $$;

create or replace function public.hq_win_prospect(p_prospect uuid, p_tier text default 'greenhouse', p_kickoff timestamptz default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare p public.prospects; base text; v_slug text; v_org uuid; i int := 1;
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  select * into p from public.prospects where id = p_prospect for update;
  if not found then raise exception 'prospect not found'; end if;
  if p.org_id is not null then
    v_org := p.org_id;
  else
    base := trim(both '-' from regexp_replace(lower(p.business_name), '[^a-z0-9]+', '-', 'g'));
    if base = '' then base := 'client'; end if;
    v_slug := base;
    while exists (select 1 from public.orgs where slug = v_slug) loop i := i + 1; v_slug := base || '-' || i; end loop;
    insert into public.orgs (slug, name, tier, is_demo, locations, signed_at, status, trade, service_area,
                             primary_contact_name, primary_contact_phone, primary_contact_email)
    values (v_slug, p.business_name, p_tier, false, p.locations, now(), 'onboarding', p.trade, coalesce(p.service_area, p.city),
            p.owner_name, coalesce(p.owner_phone, p.phone), p.owner_email)
    returning id into v_org;
  end if;
  update public.prospects set stage = 'won', org_id = v_org, next_action = null, next_action_at = null where id = p_prospect;
  if p_kickoff is not null then perform ops_private.start_onboarding(v_org, p_kickoff); end if;
  insert into public.outbox (org_id, audience, channel, kind, to_addr, body, dedupe_key)
  values (v_org, 'internal', 'slack', 'win', '#wins',
          'Signed: ' || p.business_name || ' (' || p_tier || ').'
            || case when p_kickoff is not null then ' Kickoff ' || to_char(p_kickoff at time zone 'America/Chicago', 'Dy Mon FMDD') || '.' else '' end,
          'win:' || v_org)
  on conflict (dedupe_key) do nothing;
  return v_org;
end $$;

create or replace function public.hq_set_slack_webhook(p_channel text, p_url text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  if p_url is null or p_url not like 'https://hooks.slack.com/%' then raise exception 'That is not a Slack webhook address'; end if;
  insert into ops_private.secrets (name, value) values ('slack_webhook:' || coalesce(nullif(trim(p_channel), ''), 'default'), p_url)
  on conflict (name) do update set value = excluded.value, updated_at = now();
end $$;

create or replace function public.hq_ingest_key(p_rotate boolean default false)
returns text language plpgsql security definer set search_path = '' as $$
declare k text;
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  select value into k from ops_private.secrets where name = 'ingest_key';
  if k is null or p_rotate then
    k := encode(extensions.gen_random_bytes(24), 'hex');
    insert into ops_private.secrets (name, value) values ('ingest_key', k)
    on conflict (name) do update set value = excluded.value, updated_at = now();
  end if;
  return k;
end $$;

create or replace function public.hq_pause_clock(p_org uuid, p_input text, p_note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare o public.orgs;
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  select * into o from public.orgs where id = p_org;
  if not found then raise exception 'client not found'; end if;
  if o.kickoff_at is null or o.live_at is not null then raise exception 'The 14-day clock is not running for this client'; end if;
  if exists (select 1 from public.onboarding_pauses where org_id = p_org and ended_at is null) then raise exception 'The clock is already paused'; end if;
  insert into public.onboarding_pauses (org_id, input, note) values (p_org, p_input, nullif(trim(coalesce(p_note, '')), ''));
  insert into public.outbox (org_id, audience, channel, kind, to_addr, body)
  values (p_org, 'internal', 'slack', 'onboarding', '#onboarding',
          o.name || ': 14-day clock paused, waiting on ' ||
          case p_input when 'estimates' then 'the estimate export' when 'forwarding' then 'call forwarding' else 'test call approval' end
          || '. Tell the client today.');
end $$;

create or replace function public.hq_resume_clock(p_org uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  update public.onboarding_pauses set ended_at = now() where org_id = p_org and ended_at is null;
  if not found then raise exception 'The clock is not paused'; end if;
end $$;

create or replace function public.hq_invite(p_org uuid, p_email text)
returns void language plpgsql security definer set search_path = '' as $$
declare e text := lower(trim(coalesce(p_email, '')));
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'That does not look like an email address'; end if;
  if not exists (select 1 from public.orgs where id = p_org and is_demo = false) then raise exception 'client not found'; end if;
  insert into public.org_invites (org_id, email) values (p_org, e) on conflict do nothing;
end $$;

-- Preview button in HQ: refresh yesterday's numbers and build today's updates now
create or replace function public.hq_run_daily()
returns int language plpgsql security definer set search_path = '' as $$
declare today date := (now() at time zone 'America/Chicago')::date;
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  perform ops_private.compute_daily(today - 1);
  return ops_private.generate_updates(today);
end $$;

revoke all on all functions in schema ops_private from public, anon, authenticated;
revoke all on function public.whoami(), public.hq_overview(), public.ops_start_onboarding(uuid, timestamptz), public.ops_mark_live(uuid, timestamptz),
  public.hq_win_prospect(uuid, text, timestamptz), public.hq_set_slack_webhook(text, text), public.hq_ingest_key(boolean), public.hq_run_daily(),
  public.hq_pause_clock(uuid, text, text), public.hq_resume_clock(uuid), public.hq_invite(uuid, text)
  from public, anon;
grant execute on function public.whoami(), public.hq_overview(), public.ops_start_onboarding(uuid, timestamptz), public.ops_mark_live(uuid, timestamptz),
  public.hq_win_prospect(uuid, text, timestamptz), public.hq_set_slack_webhook(text, text), public.hq_ingest_key(boolean), public.hq_run_daily(),
  public.hq_pause_clock(uuid, text, text), public.hq_resume_clock(uuid), public.hq_invite(uuid, text)
  to authenticated;
revoke all on function public.ops_ingest(text, text, text, text, text, jsonb) from public;
grant execute on function public.ops_ingest(text, text, text, text, text, jsonb) to anon, authenticated;
