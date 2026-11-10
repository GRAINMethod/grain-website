-- GRAIN ops backend, part 1b: additions on top of ops_core. Additive only.

-- ---------------------------------------------------------------------------
-- Industries beyond the ten trades. The site invites them to apply, so the
-- pipeline should not throw them out as "trade not served".
-- ---------------------------------------------------------------------------
alter table public.prospects drop constraint prospects_trade_check;
alter table public.prospects add constraint prospects_trade_check check (trade is null or trade in (
  'hvac','plumbing','roofing','electrical','remodeling','painting','fencing','pools','landscaping','garage_doors',
  'health_fitness','real_estate','tech','other'));

-- An after-hours test can be picked up by someone who is not the owner.
alter table public.prospect_touches drop constraint prospect_touches_outcome_check;
alter table public.prospect_touches add constraint prospect_touches_outcome_check check (outcome in (
  'no_answer','voicemail','answered_live','conversation','audit_booked','not_interested','follow_up'));

-- A touch updates the prospect. An after-hours test also records its result, so the score moves on its own,
-- and it does not count as "contacted": it is research, not outreach.
create or replace function public.prospect_touches_after_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.prospects set
    touch_count = touch_count + 1,
    last_touch_at = greatest(coalesce(last_touch_at, new.at), new.at),
    conversation_at = case when new.outcome in ('conversation','audit_booked') then coalesce(conversation_at, new.at) else conversation_at end,
    after_hours_result = case when new.channel = 'after_hours_test' and new.outcome in ('no_answer','voicemail','answered_live')
                              then new.outcome else after_hours_result end,
    stage = case
      when stage in ('won','lost') then stage
      when new.outcome = 'not_interested' then 'lost'
      when new.outcome = 'audit_booked' and stage in ('sourced','qualified','contacted','conversation','nurture') then 'audit_booked'
      when new.outcome = 'conversation' and stage in ('sourced','qualified','contacted','nurture') then 'conversation'
      when new.channel = 'after_hours_test' then stage
      when stage in ('sourced','qualified') then 'contacted'
      else stage end
  where id = new.prospect_id;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Website leads: into the pipeline, and an alert for the 5-minute call rule.
-- Neither step can fail the lead insert.
-- ---------------------------------------------------------------------------
create or replace function public.leads_to_prospect()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  raw text := lower(replace(coalesce(new.trade, ''), '-', '_'));
  t text; band text; rev text; rev_band text; loc text;
  v_name text := coalesce(nullif(trim(new.shop), ''), nullif(trim(new.name), ''), new.email, new.phone, 'Website lead');
begin
  begin
    t := case
      when raw in ('hvac','plumbing','roofing','electrical','remodeling','painting','fencing','pools','landscaping','garage_doors',
                   'health_fitness','real_estate','tech') then raw
      when raw = '' then null
      else 'other' end;
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
        nullif('Industry: ' || coalesce(new.trade, ''), 'Industry: '),
        nullif('Software: ' || coalesce(new.software, ''), 'Software: '),
        nullif('Best time: ' || coalesce(new.best_time, ''), 'Best time: '),
        nullif(new.message, ''))
    );
  exception when others then
    raise warning 'leads_to_prospect skipped: %', sqlerrm;
  end;

  begin
    insert into public.outbox (audience, channel, kind, to_addr, body, dedupe_key)
    values ('internal', 'slack', 'new_lead', '#new-leads',
            'New website lead: ' || left(v_name, 120)
              || coalesce(' · ' || nullif(new.trade, ''), '')
              || E'\n' || coalesce(nullif(left(regexp_replace(coalesce(new.message, ''), '\s+', ' ', 'g'), 240), ''), 'No message.')
              || E'\nCall within 5 minutes: ' || coalesce(nullif(new.phone, ''), nullif(new.email, ''), 'no contact given'),
            'lead:' || new.id)
    on conflict (dedupe_key) do nothing;
    perform ops_private.send_due();
  exception when others then
    raise warning 'lead alert skipped: %', sqlerrm;
  end;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Start Guarantee clock pauses. Only the client's late inputs pause the 14 days.
-- ---------------------------------------------------------------------------
create table public.onboarding_pauses (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  input text not null check (input in ('estimates','forwarding','approval')),
  note text
);
create index onboarding_pauses_org on public.onboarding_pauses (org_id, started_at);
create unique index onboarding_pauses_one_open on public.onboarding_pauses (org_id) where ended_at is null;

-- ---------------------------------------------------------------------------
-- Client log: call quality scores, incidents and notes, one line each.
-- ---------------------------------------------------------------------------
create table public.client_log (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  at timestamptz not null default now(),
  kind text not null check (kind in ('note','call_qa','incident')),
  score numeric(4,1) check (score is null or (score >= 0 and score <= 10)),
  minutes int check (minutes is null or minutes >= 0),
  body text not null,
  by_user uuid references auth.users(id) on delete set null
);
create index client_log_org on public.client_log (org_id, at desc);
create index client_log_by_user on public.client_log (by_user) where by_user is not null;

-- ---------------------------------------------------------------------------
-- Dashboard access for clients: staff adds an email, and that person is linked
-- to the client the first time they sign in with it.
-- ---------------------------------------------------------------------------
create table public.org_invites (
  org_id uuid not null references public.orgs(id) on delete cascade,
  email text not null check (email = lower(email) and position('@' in email) > 1),
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  primary key (org_id, email)
);
create index org_invites_email on public.org_invites (email);

alter table public.onboarding_pauses enable row level security;
alter table public.client_log enable row level security;
alter table public.org_invites enable row level security;

create policy "read own or demo" on public.onboarding_pauses for select to authenticated using (public.mc_can_read(org_id));
create policy "staff insert" on public.onboarding_pauses for insert to authenticated with check ((select public.is_staff()));
create policy "staff update" on public.onboarding_pauses for update to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff delete" on public.onboarding_pauses for delete to authenticated using ((select public.is_staff()));
create policy "staff all" on public.client_log for all to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff all" on public.org_invites for all to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));

revoke all on function public.prospect_touches_after_insert() from public, anon, authenticated;
revoke all on function public.leads_to_prospect() from public, anon, authenticated;
