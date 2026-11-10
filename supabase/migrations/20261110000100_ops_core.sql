-- GRAIN ops backend, part 1: tables, RLS, scoring.
-- Shared operating model v1. Additive only. Nothing here touches public.leads or submit_lead.

-- ---------------------------------------------------------------------------
-- Staff allowlist
-- ---------------------------------------------------------------------------
create table public.staff (
  email text primary key,
  user_id uuid unique references auth.users(id) on delete set null,
  name text,
  created_at timestamptz not null default now()
);
insert into public.staff (email, name) values ('johnny@grainmethod.com', 'Johnny Dibb');

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from auth.users u
    join public.staff s
      on s.user_id = u.id
      or (u.email_confirmed_at is not null and lower(s.email) = lower(u.email))
    where u.id = (select auth.uid())
  );
$$;
revoke all on function public.is_staff() from public, anon;
grant execute on function public.is_staff() to authenticated;

-- ---------------------------------------------------------------------------
-- Prospects (the pipeline) and touches
-- ---------------------------------------------------------------------------
create table public.prospects (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  lead_id uuid,                                   -- public.leads.id when it came from the website
  business_name text not null,
  trade text check (trade is null or trade in ('hvac','plumbing','roofing','electrical','remodeling','painting','fencing','pools','landscaping','garage_doors','other')),
  city text,
  state text,
  service_area text,
  website text,
  phone text,
  owner_name text,
  owner_email text,
  owner_phone text,
  revenue_band text check (revenue_band is null or revenue_band in ('under_500k','under_1m','1m_3m','3m_10m','10m_plus','unknown')),
  locations int not null default 1,
  runs_ads boolean,
  google_reviews int,
  after_hours_result text check (after_hours_result is null or after_hours_result in ('not_tested','no_answer','voicemail','callback','answered_live')),
  callback_minutes int,
  est_unsold_band text check (est_unsold_band is null or est_unsold_band in ('under_500k','500k_1_5m','1_5m_plus','unknown')),
  source text not null default 'outbound' check (source in ('website','outbound','after_hours_test','referral','linkedin','event','other')),
  stage text not null default 'sourced' check (stage in ('sourced','qualified','contacted','conversation','audit_booked','audit_held','proposal','won','lost','nurture')),
  score int not null default 0,
  qualified boolean not null default false,
  disqualified_reason text,
  next_action text,
  next_action_at timestamptz,
  notes text,
  touch_count int not null default 0,
  last_touch_at timestamptz,
  conversation_at timestamptz,
  audit_held_at timestamptz,
  won_at timestamptz,
  org_id uuid references public.orgs(id) on delete set null
);
create index prospects_stage_score on public.prospects (stage, score desc);
create index prospects_next_action on public.prospects (next_action_at) where next_action_at is not null;
create index prospects_lead on public.prospects (lead_id) where lead_id is not null;

create table public.prospect_touches (
  id uuid primary key default gen_random_uuid(),
  prospect_id uuid not null references public.prospects(id) on delete cascade,
  at timestamptz not null default now(),
  channel text not null check (channel in ('call','sms','email','linkedin','loom','in_person','after_hours_test')),
  outcome text not null check (outcome in ('no_answer','voicemail','conversation','audit_booked','not_interested','follow_up')),
  note text,
  by_user uuid references auth.users(id) on delete set null
);
create index prospect_touches_prospect on public.prospect_touches (prospect_id, at desc);
create index prospect_touches_at on public.prospect_touches (at desc);

-- ---------------------------------------------------------------------------
-- Client ops columns on orgs
-- ---------------------------------------------------------------------------
alter table public.orgs
  add column status text not null default 'onboarding' check (status in ('onboarding','live','paused','churned')),
  add column trade text,
  add column service_area text,
  add column primary_contact_name text,
  add column primary_contact_phone text,
  add column primary_contact_email text,
  add column comms_channel text not null default 'none' check (comms_channel in ('none','sms','slack','email')),
  add column slack_channel text,
  add column ghl_location_id text,
  add column retell_agent_id text,
  add column unsold_estimates_frozen_total numeric(12,2),
  add column payback_eligible boolean not null default false,
  add column demo_ticked_at timestamptz,
  add column default_answer_seconds int not null default 6;
create unique index mc_estimates_org_no on public.mc_estimates (org_id, estimate_no) where estimate_no is not null;

-- ---------------------------------------------------------------------------
-- Onboarding: template and per-org tasks
-- ---------------------------------------------------------------------------
create table public.onboarding_template (
  id serial primary key,
  milestone text not null,               -- M0 (signing day), then M1..M4 as the website shows them
  milestone_title text not null,
  day_from int not null,                 -- days from kickoff (kickoff = day 1; signing day = day 0)
  day_to int not null,
  sort int not null,
  title text not null,
  owner text not null default 'grain' check (owner in ('grain','client'))
);
insert into public.onboarding_template (milestone, milestone_title, day_from, day_to, sort, title, owner) values
  ('M0','Signing day',0,0,10,'Agreement signed, card or ACH on file ($0 charged)','grain'),
  ('M0','Signing day',0,0,20,'GHL sub-account cloned from the GRAIN snapshot','grain'),
  ('M0','Signing day',0,0,30,'A2P texting registration filed','grain'),
  ('M0','Signing day',0,0,40,'Welcome message sent with the kickoff date and what to bring','grain'),
  ('M1','Kickoff',1,1,10,'60-minute kickoff: services, area, hours, pricing rules, emergencies, on-call, booking rules','grain'),
  ('M1','Kickoff',1,1,20,'Access received: job software, Google profile, website forms, phone carrier','client'),
  ('M1','Kickoff',1,1,30,'24 months of estimates exported','client'),
  ('M1','Kickoff',1,1,40,'Estimate list frozen: file saved, copy emailed to the owner, count and total recorded','grain'),
  ('M1','Kickoff',1,1,50,'Baseline pulled: 30 days of calls, estimates written and closed','grain'),
  ('M1','Kickoff',1,1,60,'Call forwarding plan chosen and the test date set','grain'),
  ('M2','Your report',2,2,10,'Baseline report sent to the owner, in dollars','grain'),
  ('M3','We build, you approve',3,6,10,'Voice agent built: knowledge base, disclosure, emergency transfer, safety rule, owner summary text','grain'),
  ('M3','We build, you approve',3,6,20,'Booking, missed-call and web-form text-back, tracking numbers set up','grain'),
  ('M3','We build, you approve',3,6,30,'90-day estimate follow-up and review request loaded','grain'),
  ('M3','We build, you approve',3,6,40,'Google Business Profile checked: hours, phone, services, service area','grain'),
  ('M3','We build, you approve',3,9,50,'Estimate list cleaned and checked against the Do Not Call registers','grain'),
  ('M3','We build, you approve',7,9,60,'20 scripted test calls passed, end to end','grain'),
  ('M3','We build, you approve',7,9,70,'Owner calls in, hears 3 recordings and approves in writing','client'),
  ('M3','We build, you approve',10,10,80,'Call forwarding on for after-hours and overflow','client'),
  ('M3','We build, you approve',10,12,90,'Soft launch: every call reviewed for 48 hours, issues fixed the same day','grain'),
  ('M3','We build, you approve',12,12,100,'Owner approves the revival wording and any offer','client'),
  ('M3','We build, you approve',10,13,110,'Office one-pager sent','grain'),
  ('M4','Live',14,14,10,'Full forwarding on and a live test call books','grain'),
  ('M4','Live',14,14,20,'Setup plus month one charged and cleared','grain'),
  ('M4','Live',14,14,30,'Dashboard login sent and the daily update channel set','grain'),
  ('M4','Live',14,14,40,'First revival sends go out (email until texting is approved)','grain'),
  ('M4','Live',14,14,50,'Go-live message sent and the first monthly review booked','grain');

create table public.onboarding_tasks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  template_id int references public.onboarding_template(id),
  milestone text not null,
  milestone_title text not null,
  title text not null,
  owner text not null default 'grain',
  sort int not null default 0,
  due_at timestamptz not null,
  done_at timestamptz,
  created_at timestamptz not null default now()
);
create index onboarding_tasks_org on public.onboarding_tasks (org_id, due_at);

-- ---------------------------------------------------------------------------
-- Client KPIs per day
-- ---------------------------------------------------------------------------
create table public.client_daily_metrics (
  org_id uuid not null references public.orgs(id) on delete cascade,
  day date not null,
  inbound_calls int not null default 0,
  answered_60s int not null default 0,
  answer_rate numeric(5,4),
  avg_response_seconds numeric(8,1),
  new_leads int not null default 0,
  booked int not null default 0,
  followups_sent int not null default 0,
  estimates_in_followup int not null default 0,
  estimates_revived int not null default 0,
  revived_booked_value numeric(12,2) not null default 0,
  revived_paid_value numeric(12,2) not null default 0,
  computed_at timestamptz not null default now(),
  primary key (org_id, day)
);

-- ---------------------------------------------------------------------------
-- Outbox: every message GRAIN sends, internal or client
-- ---------------------------------------------------------------------------
create table public.outbox (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  org_id uuid references public.orgs(id) on delete cascade,
  audience text not null check (audience in ('internal','client')),
  channel text not null check (channel in ('slack','sms','email')),
  kind text not null,
  to_addr text,                            -- slack channel name, phone or email
  subject text,
  body text not null,
  scheduled_for timestamptz not null default now(),
  status text not null default 'queued' check (status in ('queued','sent','skipped','failed')),
  sent_at timestamptz,
  error text,
  dedupe_key text unique
);
create index outbox_due on public.outbox (status, scheduled_for);
create index outbox_org on public.outbox (org_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Ops tasks (Johnny's to-dos, including auto-created checkpoints)
-- ---------------------------------------------------------------------------
create table public.ops_tasks (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  title text not null,
  kind text not null default 'manual',    -- manual | checkpoint | onboarding | pipeline
  due_at timestamptz,
  done_at timestamptz,
  org_id uuid references public.orgs(id) on delete cascade,
  prospect_id uuid references public.prospects(id) on delete cascade,
  auto_key text unique,
  note text
);
create index ops_tasks_due on public.ops_tasks (due_at) where done_at is null;
create index ops_tasks_org on public.ops_tasks (org_id);
create index ops_tasks_prospect on public.ops_tasks (prospect_id);

-- ---------------------------------------------------------------------------
-- Ingest events (raw webhooks from GHL and Retell)
-- ---------------------------------------------------------------------------
create table public.ingest_events (
  id bigserial primary key,
  received_at timestamptz not null default now(),
  source text not null check (source in ('ghl','retell','manual')),
  external_id text not null,
  event_type text,
  org_id uuid references public.orgs(id) on delete set null,
  payload jsonb not null,
  processed_at timestamptz,
  error text,
  unique (source, external_id)
);
create index ingest_events_unprocessed on public.ingest_events (received_at desc) where processed_at is null;
create index ingest_events_org on public.ingest_events (org_id);

-- ---------------------------------------------------------------------------
-- Private schema: secrets and job bookkeeping. Not exposed by the API; only definer code reads it.
-- ---------------------------------------------------------------------------
create schema if not exists ops_private;
revoke all on schema ops_private from public, anon, authenticated;
create table ops_private.secrets (
  name text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);
create table ops_private.job_runs (
  job text not null,
  day date not null,
  ran_at timestamptz not null default now(),
  primary key (job, day)
);
alter table ops_private.secrets enable row level security;
alter table ops_private.job_runs enable row level security;
revoke all on all tables in schema ops_private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.staff enable row level security;
alter table public.prospects enable row level security;
alter table public.prospect_touches enable row level security;
alter table public.onboarding_template enable row level security;
alter table public.onboarding_tasks enable row level security;
alter table public.client_daily_metrics enable row level security;
alter table public.outbox enable row level security;
alter table public.ops_tasks enable row level security;
alter table public.ingest_events enable row level security;

-- Staff can read every org (mc_can_read now includes staff), so one select policy per table is enough.
create or replace function public.mc_can_read(p_org uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_staff()
      or exists (select 1 from public.orgs o where o.id = p_org and o.is_demo)
      or exists (select 1 from public.org_members m where m.org_id = p_org and m.user_id = (select auth.uid()));
$$;

create policy "staff read staff" on public.staff for select to authenticated using ((select public.is_staff()));

create policy "staff all" on public.prospects for all to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff all" on public.prospect_touches for all to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff read" on public.onboarding_template for select to authenticated using ((select public.is_staff()));

create policy "read own or demo" on public.onboarding_tasks for select to authenticated using (public.mc_can_read(org_id));
create policy "staff insert" on public.onboarding_tasks for insert to authenticated with check ((select public.is_staff()));
create policy "staff update" on public.onboarding_tasks for update to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff delete" on public.onboarding_tasks for delete to authenticated using ((select public.is_staff()));

create policy "read own or demo" on public.client_daily_metrics for select to authenticated using (public.mc_can_read(org_id));
create policy "staff insert" on public.client_daily_metrics for insert to authenticated with check ((select public.is_staff()));
create policy "staff update" on public.client_daily_metrics for update to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff delete" on public.client_daily_metrics for delete to authenticated using ((select public.is_staff()));

create policy "staff all" on public.outbox for all to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff all" on public.ops_tasks for all to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff read" on public.ingest_events for select to authenticated using ((select public.is_staff()));

-- Staff manage orgs and members from HQ (select already comes through mc_can_read)
create policy "staff insert" on public.orgs for insert to authenticated with check ((select public.is_staff()));
create policy "staff update" on public.orgs for update to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff delete" on public.orgs for delete to authenticated using ((select public.is_staff()));
drop policy "read own membership" on public.org_members;
create policy "read own membership or staff" on public.org_members for select to authenticated using (user_id = (select auth.uid()) or (select public.is_staff()));
create policy "staff insert" on public.org_members for insert to authenticated with check ((select public.is_staff()));
create policy "staff update" on public.org_members for update to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff delete" on public.org_members for delete to authenticated using ((select public.is_staff()));

-- ---------------------------------------------------------------------------
-- Scoring (rubric from the shared operating model)
-- ---------------------------------------------------------------------------
create or replace function public.prospect_is_metro(p_city text, p_service_area text)
returns boolean language sql immutable set search_path = '' as $$
  select lower(trim(coalesce(p_city, ''))) in (
    'nashville','franklin','brentwood','murfreesboro','hendersonville','mt. juliet','mt juliet','mount juliet',
    'gallatin','smyrna','spring hill','lebanon','goodlettsville','antioch','hermitage','nolensville','la vergne','lavergne','madison'
  ) or coalesce(p_service_area, '') ilike '%nashville%';
$$;

create or replace function public.prospect_score(p public.prospects)
returns int language sql immutable set search_path = '' as $$
  select
    case p.revenue_band when '3m_10m' then 25 when '1m_3m' then 20 when '10m_plus' then 20 when 'under_1m' then 0 when 'under_500k' then 0 else 5 end
  + case p.after_hours_result
      when 'no_answer' then 25 when 'voicemail' then 20
      when 'callback' then case when coalesce(p.callback_minutes, 0) >= 30 then 15 else 0 end
      when 'answered_live' then 0 else 5 end
  + case p.est_unsold_band when '1_5m_plus' then 15 when '500k_1_5m' then 8 when 'under_500k' then 0 else 4 end
  + case when p.runs_ads then 8 else 0 end
  + case when coalesce(p.google_reviews, 0) >= 100 then 7 when coalesce(p.google_reviews, 0) >= 50 then 4 else 0 end
  + case when nullif(trim(coalesce(p.owner_name, '')), '') is not null
          and (nullif(trim(coalesce(p.owner_phone, '')), '') is not null or nullif(trim(coalesce(p.owner_email, '')), '') is not null)
         then 10 else 0 end
  + case when public.prospect_is_metro(p.city, p.service_area) then 10 else 0 end;
$$;

-- Auto disqualifiers. Manual reasons are kept; auto reasons are re-evaluated.
create or replace function public.prospect_auto_dq(p public.prospects)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when p.trade is not null and p.trade = 'other' then 'trade_not_served'
    when p.revenue_band = 'under_500k' then 'revenue_under_500k'
    when p.trade is not null and p.service_area is not null and exists (
      select 1 from public.orgs o
      where o.is_demo = false and o.status in ('onboarding','live')
        and o.trade = p.trade and lower(trim(o.service_area)) = lower(trim(p.service_area))
        and (p.org_id is null or o.id <> p.org_id)
    ) then 'conflict_existing_client'
    when p.touch_count >= 6 and p.conversation_at is null and p.stage not in ('won','lost') then 'no_conversation_after_6_touches'
    else null end;
$$;

create or replace function public.prospects_before_write()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  auto_reasons text[] := array['trade_not_served','revenue_under_500k','conflict_existing_client','no_conversation_after_6_touches'];
  dq text;
begin
  new.updated_at := now();
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
  if new.stage = 'conversation' and new.conversation_at is null then new.conversation_at := now(); end if;
  if new.stage = 'audit_held' and new.audit_held_at is null then new.audit_held_at := now(); end if;
  if new.stage = 'won' and new.won_at is null then new.won_at := now(); end if;
  return new;
end;
$$;
create trigger prospects_before_write before insert or update on public.prospects
  for each row execute function public.prospects_before_write();

-- A touch updates the prospect and can move its stage
create or replace function public.prospect_touches_after_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  p public.prospects;
begin
  select * into p from public.prospects where id = new.prospect_id for update;
  if not found then return new; end if;
  update public.prospects set
    touch_count = touch_count + 1,
    last_touch_at = greatest(coalesce(last_touch_at, new.at), new.at),
    conversation_at = case when new.outcome in ('conversation','audit_booked') then coalesce(conversation_at, new.at) else conversation_at end,
    stage = case
      when stage in ('won','lost') then stage
      when new.outcome = 'not_interested' then 'lost'
      when new.outcome = 'audit_booked' and stage in ('sourced','qualified','contacted','conversation','nurture') then 'audit_booked'
      when new.outcome = 'conversation' and stage in ('sourced','qualified','contacted','nurture') then 'conversation'
      when stage in ('sourced','qualified') then 'contacted'
      else stage end
  where id = new.prospect_id;
  return new;
end;
$$;
create trigger prospect_touches_after_insert after insert on public.prospect_touches
  for each row execute function public.prospect_touches_after_insert();

-- ---------------------------------------------------------------------------
-- Website leads flow into the pipeline. Never fails the lead insert.
-- ---------------------------------------------------------------------------
create or replace function public.leads_to_prospect()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  t text;
  band text;
  v_name text;
  rev text;
  rev_band text;
  loc text;
begin
  begin
    t := lower(replace(coalesce(new.trade, ''), '-', '_'));
    if t not in ('hvac','plumbing','roofing','electrical','remodeling','painting','fencing','pools','landscaping','garage_doors') then
      t := case when t = '' then null else 'other' end;
    end if;
    band := case
      when coalesce(new.estimates_band, '') ~* '1[.,_]?5' or coalesce(new.estimates_band, '') ~* '2m|3m|5m|plus|\+' then '1_5m_plus'
      when coalesce(new.estimates_band, '') ~* '500' then '500k_1_5m'
      when coalesce(new.estimates_band, '') ~* 'under|less|<' then 'under_500k'
      else 'unknown' end;
    rev := lower(substring(coalesce(new.message, '') from 'Annual revenue: ([^\s]+)'));
    rev_band := case rev
      when 'under-500k' then 'under_500k' when '500k-1m' then 'under_1m' when '1m-3m' then '1m_3m'
      when '3m-10m' then '3m_10m' when '10m-25m' then '10m_plus' when '25m+' then '10m_plus' else 'unknown' end;
    loc := substring(coalesce(new.message, '') from 'Locations: ([^\s]+)');
    v_name := coalesce(nullif(trim(new.shop), ''), nullif(trim(new.name), ''), coalesce(new.email, new.phone, 'Website lead'));

    insert into public.prospects (
      lead_id, business_name, trade, service_area, website, phone, owner_name, owner_email, owner_phone,
      est_unsold_band, revenue_band, locations, source, stage, after_hours_result, next_action, next_action_at, notes
    ) values (
      new.id, left(v_name, 160), t, left(new.area, 160), new.website, new.shop_phone, new.name, new.email, new.phone,
      band, rev_band,
      case loc when '2-3' then 2 when '4-10' then 4 when '10+' then 10 else 1 end,
      'website', 'sourced',
      case when new.wants_test then 'not_tested' else null end,
      'Website form came in. Call them back fast.',
      now(),
      concat_ws(E'\n',
        'Website form: ' || coalesce(new.kind, ''),
        nullif('Software: ' || coalesce(new.software, ''), 'Software: '),
        nullif('Best time: ' || coalesce(new.best_time, ''), 'Best time: '),
        nullif(new.message, ''))
    );
  exception when others then
    raise warning 'leads_to_prospect skipped: %', sqlerrm;
  end;
  return new;
end;
$$;
create trigger leads_to_prospect after insert on public.leads
  for each row execute function public.leads_to_prospect();

-- Helper functions are internal: nobody calls them through the API
revoke all on function public.prospect_is_metro(text, text) from public, anon, authenticated;
revoke all on function public.prospect_score(public.prospects) from public, anon, authenticated;
revoke all on function public.prospect_auto_dq(public.prospects) from public, anon, authenticated;
revoke all on function public.prospects_before_write() from public, anon, authenticated;
revoke all on function public.prospect_touches_after_insert() from public, anon, authenticated;
revoke all on function public.leads_to_prospect() from public, anon, authenticated;
