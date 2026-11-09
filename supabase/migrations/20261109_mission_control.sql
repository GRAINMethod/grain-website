-- Mission Control: the real backend behind the dashboard.
-- One row in orgs per client shop. Every mc_ table is scoped by org_id.
-- RLS: members read their own org; anyone can read demo orgs (is_demo).

create table public.orgs (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  tier text not null default 'greenhouse' check (tier in ('greenhouse', 'orchard', 'estate')),
  is_demo boolean not null default false,
  crm text,
  locations int not null default 1,
  signed_at timestamptz,
  kickoff_at timestamptz,
  live_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.org_members (
  org_id uuid not null references public.orgs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner', 'staff', 'grain')),
  created_at timestamptz not null default now(),
  primary key (org_id, user_id)
);

create table public.mc_leads (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  created_at timestamptz not null default now(),
  source text not null,
  channel text not null check (channel in ('call', 'sms', 'form')),
  name text,
  area text,
  job_type text,
  est_value numeric(10, 2),
  quality numeric(3, 1),
  response_seconds int,
  after_hours boolean not null default false,
  status text not null default 'new' check (status in ('new', 'responded', 'qualified', 'booked', 'lost')),
  handoff boolean not null default false
);

create table public.mc_estimates (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  estimate_no text,
  customer text,
  job_type text,
  amount numeric(10, 2) not null,
  sent_at timestamptz not null,
  frozen boolean not null default false,
  status text not null default 'open' check (status in ('open', 'won', 'lost')),
  touches int not null default 0,
  last_touch_at timestamptz,
  won_via text check (won_via in ('followup', 'revival', 'direct')),
  won_at timestamptz,
  completed_paid_at timestamptz,
  paid_amount numeric(10, 2)
);

create table public.mc_appointments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  created_at timestamptz not null default now(),
  source text not null check (source in ('respond', 'followup', 'revival')),
  scheduled_for timestamptz,
  value numeric(10, 2)
);

create table public.mc_sync_runs (
  id bigserial primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  at timestamptz not null default now(),
  records int not null,
  latency_ms int not null,
  ok boolean not null default true
);

create table public.mc_events (
  id bigserial primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  at timestamptz not null default now(),
  engine text not null check (engine in ('G', 'R', 'A', 'I', 'N')),
  title text not null,
  detail text,
  status text not null check (status in ('live', 'qualified', 'booked'))
);

create table public.mc_payments (
  id bigserial primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  at timestamptz not null,
  kind text not null check (kind in ('setup', 'monthly', 'share')),
  amount numeric(10, 2) not null
);

create index mc_leads_org_time on public.mc_leads (org_id, created_at desc);
create index mc_estimates_org_sent on public.mc_estimates (org_id, sent_at desc);
create index mc_estimates_org_won on public.mc_estimates (org_id, won_at desc) where won_at is not null;
create index mc_appts_org_time on public.mc_appointments (org_id, created_at desc);
create index mc_sync_org_time on public.mc_sync_runs (org_id, at desc);
create index mc_events_org_engine_time on public.mc_events (org_id, engine, at desc);
create index mc_payments_org on public.mc_payments (org_id, at);
create index org_members_user on public.org_members (user_id);

-- Who can read an org's data
create or replace function public.mc_can_read(p_org uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.orgs o where o.id = p_org and o.is_demo)
      or exists (select 1 from public.org_members m where m.org_id = p_org and m.user_id = (select auth.uid()));
$$;

alter table public.orgs enable row level security;
alter table public.org_members enable row level security;
alter table public.mc_leads enable row level security;
alter table public.mc_estimates enable row level security;
alter table public.mc_appointments enable row level security;
alter table public.mc_sync_runs enable row level security;
alter table public.mc_events enable row level security;
alter table public.mc_payments enable row level security;

create policy "read own or demo" on public.orgs for select to anon, authenticated using (public.mc_can_read(id));
create policy "read own membership" on public.org_members for select to authenticated using (user_id = (select auth.uid()));
create policy "read own or demo" on public.mc_leads for select to anon, authenticated using (public.mc_can_read(org_id));
create policy "read own or demo" on public.mc_estimates for select to anon, authenticated using (public.mc_can_read(org_id));
create policy "read own or demo" on public.mc_appointments for select to anon, authenticated using (public.mc_can_read(org_id));
create policy "read own or demo" on public.mc_sync_runs for select to anon, authenticated using (public.mc_can_read(org_id));
create policy "read own or demo" on public.mc_events for select to anon, authenticated using (public.mc_can_read(org_id));
create policy "read own or demo" on public.mc_payments for select to anon, authenticated using (public.mc_can_read(org_id));

-- Formatting helpers
create or replace function public.mc_money(v numeric)
returns text language sql immutable set search_path = '' as $$
  select case
    when v is null then '$0'
    when abs(v) >= 1000000 then '$' || trim(to_char(v / 1000000.0, 'FM990.0')) || 'M'
    when abs(v) >= 10000 then '$' || round(v / 1000.0)::text || 'K'
    else '$' || trim(to_char(round(v), 'FM999,999'))
  end;
$$;

create or replace function public.mc_ago(t timestamptz)
returns text language sql stable set search_path = '' as $$
  select case
    when t is null then ''
    when now() - t < interval '60 seconds' then 'now'
    when now() - t < interval '60 minutes' then floor(extract(epoch from now() - t) / 60)::int || 'm'
    when now() - t < interval '24 hours' then floor(extract(epoch from now() - t) / 3600)::int || 'h'
    else floor(extract(epoch from now() - t) / 86400)::int || 'd'
  end;
$$;

create or replace function public.mc_esc(t text)
returns text language sql immutable set search_path = '' as $$
  select replace(replace(replace(coalesce(t, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;');
$$;
