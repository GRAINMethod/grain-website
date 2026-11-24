-- Almanac (Nov 23, 2026): the team's prices, policies and how-tos in one place they can ask.
-- It answers only from documents marked approved, and says which one it used. Editing an approved
-- document puts it back in draft until the owner approves it again. These are the same documents
-- the voice agent answers callers from.
-- Also (Johnny, Nov 23): the sample accounts move to the new prices. Greenhouse $3,997 a month and
-- $2,500 setup; each added location $2,497 a month and $1,500 setup.

create table public.almanac_docs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  topic text not null default 'General' check (char_length(btrim(topic)) between 1 and 40),
  title text not null check (char_length(btrim(title)) between 1 and 140),
  body text not null check (char_length(btrim(body)) between 1 and 6000),
  status text not null default 'draft' check (status in ('draft', 'approved', 'retired')),
  source text check (source is null or char_length(source) <= 140),
  approved_by text check (approved_by is null or char_length(approved_by) <= 140),
  approved_at timestamptz,
  is_sample boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  fts tsvector generated always as (
    setweight(to_tsvector('english'::regconfig, coalesce(topic, '') || ' ' || coalesce(title, '')), 'A')
    || setweight(to_tsvector('english'::regconfig, coalesce(body, '')), 'B')) stored
);
create index almanac_docs_org on public.almanac_docs (org_id, status);
create index almanac_docs_fts on public.almanac_docs using gin (fts);

create table public.almanac_questions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  asked_by uuid references auth.users(id) on delete set null,
  question text not null check (char_length(btrim(question)) between 2 and 300),
  answer text check (answer is null or char_length(answer) <= 2000),
  answered boolean not null default false,
  doc_ids uuid[] not null default '{}',
  mode text not null default 'match' check (mode in ('model', 'match', 'sample')),
  is_sample boolean not null default false,
  resolved_doc_id uuid references public.almanac_docs(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);
create index almanac_questions_org on public.almanac_questions (org_id, created_at desc);
create index almanac_questions_open on public.almanac_questions (org_id) where not answered and resolved_at is null;
create index almanac_questions_asked_by on public.almanac_questions (asked_by);
create index almanac_questions_resolved_doc on public.almanac_questions (resolved_doc_id);

alter table public.almanac_docs enable row level security;
alter table public.almanac_questions enable row level security;

-- Clients (and anyone, on the sample accounts) can read approved documents. Staff write.
-- Questions are read and written only through the functions below, or by staff in HQ.
create policy "read approved own or demo" on public.almanac_docs for select to anon
  using (status = 'approved' and public.mc_can_read(org_id));
create policy "read approved own, or staff" on public.almanac_docs for select to authenticated
  using ((status = 'approved' and public.mc_can_read(org_id)) or (select public.is_staff()));
create policy "staff insert" on public.almanac_docs for insert to authenticated with check ((select public.is_staff()));
create policy "staff update" on public.almanac_docs for update to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));
create policy "staff delete" on public.almanac_docs for delete to authenticated using ((select public.is_staff()));
create policy "staff all" on public.almanac_questions for all to authenticated using ((select public.is_staff())) with check ((select public.is_staff()));

create or replace function public.almanac_docs_before_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.topic := btrim(new.topic); new.title := btrim(new.title); new.body := btrim(new.body);
  new.updated_at := now();
  -- Changed after the owner approved it: back to draft until it's approved again.
  if tg_op = 'UPDATE' and old.status = 'approved' and new.status = 'approved'
     and (new.body is distinct from old.body or new.title is distinct from old.title or new.topic is distinct from old.topic)
     and new.approved_at is not distinct from old.approved_at then
    new.status := 'draft';
  end if;
  if new.status = 'approved' then
    new.approved_at := coalesce(new.approved_at, now());
  else
    new.approved_at := null;
  end if;
  return new;
end $$;
create trigger almanac_docs_before_write before insert or update on public.almanac_docs
  for each row execute function public.almanac_docs_before_write();

-- The words in a question, the way the search index stores them.
create or replace function ops_private.almanac_terms(p_q text)
returns text[] language sql immutable set search_path = '' as $$
  select coalesce(array_agg(distinct t.lexeme), '{}')
  from unnest(to_tsvector('english'::regconfig, left(coalesce(p_q, ''), 300))) t;
$$;

-- Everything the answer may use: the org's approved documents, best match first, with how many
-- of the question's words each one contains. Up to 40 documents go to the model whole; past 40,
-- only the ones that match.
create or replace function public.almanac_context(p_slug text, p_q text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  o public.orgs; terms text[] := ops_private.almanac_terms(p_q); tq tsquery; n int; docs jsonb; samples jsonb := '[]'::jsonb;
begin
  select * into o from public.orgs where slug = p_slug;
  if not found or not public.mc_can_read(o.id) then return null; end if;
  if cardinality(terms) > 0 then
    tq := to_tsquery('simple'::regconfig, (select string_agg(quote_literal(t) || ':*', ' | ') from unnest(terms) t));
  end if;
  select count(*) into n from public.almanac_docs where org_id = o.id and status = 'approved';
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', d.id, 'topic', d.topic, 'title', d.title, 'body', d.body,
           'approved_by', d.approved_by, 'approved_at', d.approved_at,
           'rank', round(d.rank::numeric, 4), 'hits', d.hits) order by d.rank desc, d.title), '[]'::jsonb)
  into docs
  from (
    select x.id, x.topic, x.title, x.body, x.approved_by, x.approved_at,
           case when tq is null then 0 else ts_rank_cd(x.fts, tq) end as rank,
           (select count(*) from unnest(terms) t where x.fts @@ to_tsquery('simple'::regconfig, quote_literal(t) || ':*')) as hits
    from public.almanac_docs x
    where x.org_id = o.id and x.status = 'approved' and (n <= 40 or (tq is not null and x.fts @@ tq))
    order by rank desc, x.title
    limit 40) d;
  if o.is_demo then
    select coalesce(jsonb_agg(jsonb_build_object(
             'q', p.question, 'answer', p.answer, 'answered', p.answered,
             'doc_ids', (select coalesce(jsonb_agg(x.id), '[]'::jsonb) from public.almanac_docs x
                         where x.org_id = o.id and x.status = 'approved' and x.title = any(p.doc_titles))) order by p.sort), '[]'::jsonb)
    into samples from ops_private.almanac_demo_questions p where p.slug = o.slug;
  end if;
  return jsonb_build_object(
    'org', jsonb_build_object('slug', o.slug, 'name', o.name, 'is_demo', o.is_demo, 'trade', o.trade, 'area', o.service_area),
    'total', n, 'terms', cardinality(terms), 'docs', docs, 'samples', samples);
end $$;

-- A team member asked. Keep the question; when it isn't in the Almanac, put it on GRAIN's list.
create or replace function public.almanac_log(p_slug text, p_question text, p_answer text, p_answered boolean, p_doc_ids uuid[], p_mode text)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare o public.orgs; qid uuid; waiting int; ok boolean := coalesce(p_answered, false); qtext text := left(btrim(coalesce(p_question, '')), 300);
begin
  select * into o from public.orgs where slug = p_slug;
  -- Sample accounts and GRAIN staff testing it are never kept.
  if not found or not public.mc_can_read(o.id) or o.is_demo or public.is_staff() or char_length(qtext) < 2 then return null; end if;
  insert into public.almanac_questions (org_id, asked_by, question, answer, answered, doc_ids, mode)
  values (o.id, (select auth.uid()), qtext, left(p_answer, 2000), ok,
          coalesce((select array_agg(d) from unnest(coalesce(p_doc_ids, '{}'::uuid[])) d
                    where exists (select 1 from public.almanac_docs x where x.id = d and x.org_id = o.id)), '{}'::uuid[]),
          case when p_mode in ('model', 'match') then p_mode else 'match' end)
  returning id into qid;
  insert into public.mc_events (org_id, at, engine, title, detail, status)
  values (o.id, now(), 'I', 'Almanac', case when ok then 'Answered: ' else 'Not in it yet: ' end || left(qtext, 90),
          case when ok then 'qualified' else 'live' end);
  if not ok then
    select count(*) into waiting from public.almanac_questions x where x.org_id = o.id and not x.answered and x.resolved_at is null;
    update public.ops_tasks set note = waiting || ' waiting. Latest: "' || left(qtext, 120) || '"'
    where org_id = o.id and kind = 'almanac' and done_at is null;
    if not found then
      insert into public.ops_tasks (title, kind, due_at, org_id, auto_key, note)
      values ('Almanac: add answers for ' || o.name, 'almanac', now() + interval '1 day', o.id,
              'almanac:' || o.id || ':' || floor(extract(epoch from now()))::bigint,
              waiting || ' waiting. Latest: "' || left(qtext, 120) || '"');
    end if;
  end if;
  return qid;
end $$;

-- Staff answered a waiting question (usually by adding a document). When none are left, the HQ task closes.
create or replace function public.hq_almanac_resolve(p_question uuid, p_doc uuid default null)
returns int language plpgsql volatile security definer set search_path = '' as $$
declare org uuid; remaining int;
begin
  if not public.is_staff() then raise exception 'staff only' using errcode = '42501'; end if;
  update public.almanac_questions q set resolved_at = now(),
         resolved_doc_id = (select x.id from public.almanac_docs x where x.id = p_doc and x.org_id = q.org_id)
  where q.id = p_question and q.resolved_at is null
  returning q.org_id into org;
  if org is null then return null; end if;
  select count(*) into remaining from public.almanac_questions x where x.org_id = org and not x.answered and x.resolved_at is null;
  if remaining = 0 then
    update public.ops_tasks set done_at = now() where org_id = org and kind = 'almanac' and done_at is null;
  end if;
  return remaining;
end $$;

-- The Almanac block on the dashboard's Integrate panel.
create or replace function ops_private.mc_almanac(p_org uuid)
returns jsonb language sql stable set search_path = '' as $$
  with d as (select * from public.almanac_docs where org_id = p_org and status = 'approved'),
       q as (select * from public.almanac_questions where org_id = p_org)
  select jsonb_build_object(
    'docs', (select count(*) from d),
    'topics', coalesce((select jsonb_agg(t.topic order by t.n desc, t.topic) from (select topic, count(*) n from d group by topic) t), '[]'::jsonb),
    'updated', (select to_char(max(updated_at) at time zone 'America/Chicago', 'Mon FMDD') from d),
    'approved_by', (select approved_by from d where approved_by is not null order by approved_at desc nulls last limit 1),
    'asked_30', (select count(*) from q where created_at >= now() - interval '30 days'),
    'answered_30', (select count(*) from q where answered and created_at >= now() - interval '30 days'),
    'recent', coalesce((select jsonb_agg(jsonb_build_object('q', r.question, 'answered', r.answered, 'ago', public.mc_ago(r.created_at)) order by r.created_at desc)
                        from (select question, answered, created_at from q where created_at <= now() order by created_at desc limit 5) r), '[]'::jsonb),
    'waiting', (select count(*) from q where not answered and resolved_at is null),
    'suggest', coalesce((select jsonb_agg(s.question order by s.created_at desc)
                         from (select question, created_at from (select distinct on (lower(question)) question, created_at from q
                                                                 where answered and created_at <= now() order by lower(question), created_at desc) z
                               order by created_at desc limit 4) s), '[]'::jsonb));
$$;

-- Sample Almanac for the two sample accounts (labeled "Sample data" on the page).
create table ops_private.almanac_demo_docs (
  slug text not null, sort int not null, topic text not null, title text not null, body text not null,
  primary key (slug, sort));
create table ops_private.almanac_demo_questions (
  slug text not null, sort int not null, question text not null, answer text, answered boolean not null,
  doc_titles text[] not null default '{}', primary key (slug, sort));
alter table ops_private.almanac_demo_docs enable row level security;
alter table ops_private.almanac_demo_questions enable row level security;
revoke all on ops_private.almanac_demo_docs, ops_private.almanac_demo_questions from public, anon, authenticated;

insert into ops_private.almanac_demo_docs (slug, sort, topic, title, body) values
  ('hollow-creek-hvac', 10, 'Prices', 'Diagnostic and service call fee', 'A diagnostic visit is $89 during business hours (Monday to Friday, 7am to 6pm). It''s waived if the customer approves the repair on the same visit. Nights, weekends and holidays: $149. Comfort Club members never pay a diagnostic fee.'),
  ('hollow-creek-hvac', 20, 'Prices', 'Tune-ups', 'Furnace or AC tune-up: $129. A second system at the same house: $99. Comfort Club members get two tune-ups a year included, one for heating and one for cooling. Tune-ups are booked on weekdays only, 8am to 4pm.'),
  ('hollow-creek-hvac', 30, 'Memberships', 'Comfort Club membership', '$18.95 a month or $199 a year, per system. It includes two tune-ups a year, no diagnostic or after-hours fees, 15% off repairs, and booking ahead of non-members. Members can cancel any time; the current month isn''t refunded.'),
  ('hollow-creek-hvac', 40, 'Policies', 'After-hours and weekend calls', 'Calls after 6pm, on weekends and on holidays go to the on-call tech for no heat, no cooling, water leaking from the unit, or a burning smell. Everything else is booked for the next business morning. The after-hours diagnostic is $149. Comfort Club members don''t pay it.'),
  ('hollow-creek-hvac', 50, 'Policies', 'No-heat calls in winter', 'Same day if it''s under 60 degrees inside, or if anyone at home is over 70, under 2, or sick. Otherwise, the first slot the next morning. Space heater safety: 3 feet from anything that can burn, and never on an extension cord.'),
  ('hollow-creek-hvac', 60, 'Safety', 'Gas smell or carbon monoxide alarm', 'Tell the caller to leave the house now, leave the door open behind them, and call 911 or the gas company from outside. Don''t book it as a normal call, and don''t tell them to flip any switches. Then page the on-call tech.'),
  ('hollow-creek-hvac', 70, 'Service area', 'Where we work', 'Nashville, Brentwood, Franklin, Nolensville, Bellevue, Antioch and Mt. Juliet. Murfreesboro, Clarksville and Gallatin are outside our area. For anywhere outside the area, take their details and tell them the office will call back by noon the next business day.'),
  ('hollow-creek-hvac', 80, 'Financing', 'Financing', 'Financing is for replacements over $3,000. The comfort advisor gets approval in about 5 minutes on the tablet at the estimate: 0% for 18 months or low monthly payments up to 10 years, on approved credit. Never quote a monthly payment on the phone.'),
  ('hollow-creek-hvac', 90, 'How-tos', 'Replacement estimates', 'Free in-home estimate, about 90 minutes, and the homeowner has to be there. The advisor gives three options: good, better and best. Every estimate is good for 30 days and gets follow-up texts and emails for 90 days.'),
  ('hollow-creek-hvac', 100, 'Warranty', 'Warranty', 'New equipment has a 10-year parts warranty when it''s registered within 60 days, and we register it for the customer. Labor: 2 years on replacements, 1 year on repairs. Warranty visits have no diagnostic fee.'),
  ('hollow-creek-hvac', 110, 'Prices', 'Discounts', '10% off repairs, up to $200, for military, first responders and teachers. It doesn''t stack with the Comfort Club discount; use whichever is bigger. There''s no other discount to offer on the phone.'),
  ('hollow-creek-hvac', 120, 'How-tos', 'Thermostats and filters', 'We''ll install a thermostat the customer bought at our standard labor rate, $149 for most. The thermostat itself isn''t under our warranty. We replace filters free during tune-ups; between visits, 1-inch filters every 1 to 3 months.'),
  ('hollow-creek-hvac', 130, 'Policies', 'Payment', 'Card, check or ACH when the job is done. Replacements: 25% deposit when they sign, the rest on completion. Property managers get invoices due in 15 days.'),
  ('hollow-creek-hvac', 140, 'Policies', 'Rescheduling and no-shows', 'Customers can move an appointment for free up to 2 hours before the arrival window. If the tech arrives and nobody''s home, the $89 diagnostic still applies, unless they''re a Comfort Club member.'),
  ('ridgeline-home-services', 10, 'Service area', 'Our three locations', 'Murfreesboro covers Rutherford County. Lebanon covers Wilson County, including Mt. Juliet. Gallatin covers Sumner County, including Hendersonville. Book with the location that covers the address; calls from Davidson County go to Lebanon.'),
  ('ridgeline-home-services', 20, 'Prices', 'Service call fees', 'Heating and cooling diagnostic: $89. Plumbing service call: $79. Both are waived when the customer approves the repair on the same visit. Nights, weekends and holidays add $100. Home Plan members don''t pay service call fees.'),
  ('ridgeline-home-services', 30, 'Prices', 'Water heaters', '40 or 50-gallon gas tank, installed: from $1,650. Tankless: from $3,900. Same-day install when the call comes in before noon and that location has the unit in stock.'),
  ('ridgeline-home-services', 40, 'Prices', 'Drain cleaning', 'Main line clearing: $249. Kitchen or bathroom sink: $149. Camera inspection: $189, waived if we do the repair.'),
  ('ridgeline-home-services', 50, 'Memberships', 'Ridgeline Home Plan', '$24.95 a month per home. Two heating and cooling tune-ups a year, a yearly plumbing inspection, no service call fees and 15% off repairs. Members book ahead of everyone else.'),
  ('ridgeline-home-services', 60, 'Safety', 'Emergencies', 'Gas smell or carbon monoxide alarm: tell them to leave and call 911 or the gas company from outside, then page the on-call tech. Water pouring from a pipe: walk them to the main water shutoff, usually where the line comes into the house, and page the on-call plumber.'),
  ('ridgeline-home-services', 70, 'Policies', 'After-hours calls', 'Each location''s on-call tech takes no heat, no cooling, active leaks, sewage backups, and no hot water when there''s a baby or someone over 70 at home. Everything else books for the next morning.'),
  ('ridgeline-home-services', 80, 'Financing', 'Financing', 'Financing is for jobs over $2,500: 0% for 12 months or low monthly payments, on approved credit. The tech or advisor applies with the customer on site. Never quote a monthly payment on the phone.'),
  ('ridgeline-home-services', 90, 'Warranty', 'Warranty', 'Parts follow the manufacturer''s warranty, and we register new equipment for the customer. Labor: 2 years on installs, 1 year on repairs. Warranty visits have no service call fee.'),
  ('ridgeline-home-services', 100, 'How-tos', 'Estimates for replacements', 'Free in-home estimates for heating and cooling systems and water heaters over $3,000. Estimates are good for 30 days and get follow-up texts and emails for 90 days.'),
  ('ridgeline-home-services', 110, 'Policies', 'Payment and deposits', 'Card, check or ACH at the end of the job. Jobs over $5,000 need a 30% deposit to get on the schedule.'),
  ('ridgeline-home-services', 120, 'Policies', 'Customers who call another location', 'Any location can help a customer. The job stays with the location that wrote the estimate, and follow-up comes from that location''s number.');

insert into ops_private.almanac_demo_questions (slug, sort, question, answer, answered, doc_titles) values
  ('hollow-creek-hvac', 10, 'Do members pay the after-hours fee?', 'No. Comfort Club members don''t pay a diagnostic or after-hours fee. Everyone else pays $149 for a night, weekend or holiday visit.', true, array['After-hours and weekend calls', 'Comfort Club membership']::text[]),
  ('hollow-creek-hvac', 20, 'How much is a tune-up for a second system?', '$99 when it''s at the same house as the first system. The first one is $129.', true, array['Tune-ups']::text[]),
  ('hollow-creek-hvac', 30, 'Can we install a thermostat the customer bought?', 'Yes, at our standard labor rate, $149 for most. The thermostat itself isn''t under our warranty.', true, array['Thermostats and filters']::text[]),
  ('hollow-creek-hvac', 40, 'Do we go out to Murfreesboro?', 'No, Murfreesboro is outside our area. Take their details and tell them the office will call back by noon the next business day.', true, array['Where we work']::text[]),
  ('hollow-creek-hvac', 50, 'Do we clean ductwork?', null, false, '{}'::text[]),
  ('hollow-creek-hvac', 60, 'Is there a fee if nobody''s home?', 'Yes. If the tech shows up and nobody''s home, the $89 diagnostic still applies, unless they''re a Comfort Club member.', true, array['Rescheduling and no-shows']::text[]),
  ('hollow-creek-hvac', 70, 'What do we tell someone who smells gas?', 'Tell them to leave the house now, leave the door open, and call 911 or the gas company from outside. Don''t book it as a normal call. Then page the on-call tech.', true, array['Gas smell or carbon monoxide alarm']::text[]),
  ('hollow-creek-hvac', 80, 'Can we quote a monthly payment on the phone?', 'No. Financing is for replacements over $3,000, and the comfort advisor gives payment options at the estimate, not on the phone.', true, array['Financing']::text[]),
  ('hollow-creek-hvac', 90, 'How long is an estimate good for?', '30 days. Every estimate also gets follow-up texts and emails for 90 days.', true, array['Replacement estimates']::text[]),
  ('hollow-creek-hvac', 100, 'Do we give a senior discount?', 'No. The only discount is 10% off repairs, up to $200, for military, first responders and teachers, and it doesn''t stack with the Comfort Club discount.', true, array['Discounts']::text[]),
  ('ridgeline-home-services', 10, 'Which location covers Mt. Juliet?', 'Lebanon. It covers Wilson County, including Mt. Juliet.', true, array['Our three locations']::text[]),
  ('ridgeline-home-services', 20, 'What do we charge to clear a main line?', '$249. A camera inspection is $189, and it''s waived if we do the repair.', true, array['Drain cleaning']::text[]),
  ('ridgeline-home-services', 30, 'Do Home Plan members pay the service call fee?', 'No. Ridgeline Home Plan members don''t pay service call fees, and they get 15% off repairs.', true, array['Ridgeline Home Plan', 'Service call fees']::text[]),
  ('ridgeline-home-services', 40, 'Can we put in a tankless water heater today?', 'Same day if the call came in before noon and that location has the unit in stock. Tankless starts at $3,900.', true, array['Water heaters']::text[]),
  ('ridgeline-home-services', 50, 'Do we install water softeners?', null, false, '{}'::text[]),
  ('ridgeline-home-services', 60, 'What''s the after-hours charge?', 'Nights, weekends and holidays add $100 to the service call fee. Home Plan members don''t pay service call fees.', true, array['Service call fees']::text[]),
  ('ridgeline-home-services', 70, 'A pipe burst. What do I tell them?', 'Walk them to the main water shutoff, usually where the line comes into the house, and page the on-call plumber.', true, array['Emergencies']::text[]),
  ('ridgeline-home-services', 80, 'Who follows up if they call a different location?', 'The location that wrote the estimate keeps the job, and follow-up comes from that location''s number.', true, array['Customers who call another location']::text[]),
  ('ridgeline-home-services', 90, 'Do we need a deposit on a $6,000 job?', 'Yes. Jobs over $5,000 need a 30% deposit to get on the schedule.', true, array['Payment and deposits']::text[]),
  ('ridgeline-home-services', 100, 'Is financing available on a $2,000 repair?', 'No. Financing starts at jobs over $2,500.', true, array['Financing']::text[]);

-- One or two questions a day on each sample account, walking the list in order, kept for 31 days.
-- A question that wasn't in the Almanac gets handled the next day, the way GRAIN would.
create or replace function ops_private.almanac_demo_day(p_org uuid, p_day date)
returns void language plpgsql set search_path = '' as $$
declare o public.orgs; pool int; per int; i int; k int; p record; ts timestamptz; ids uuid[];
  d0 timestamptz := p_day::timestamp at time zone 'America/Chicago';
begin
  select * into o from public.orgs where id = p_org and is_demo;
  if not found then return; end if;
  select count(*) into pool from ops_private.almanac_demo_questions where slug = o.slug;
  if pool = 0 then return; end if;
  per := case when o.tier = 'greenhouse' then 1 else 2 end;
  for i in 0 .. per - 1 loop
    k := ((p_day - date '2026-01-01') * per + i) % pool;
    select * into p from ops_private.almanac_demo_questions where slug = o.slug order by sort offset k limit 1;
    ts := d0 + interval '8 hours' + (i * 5 + random() * 4) * interval '1 hour';
    select coalesce(array_agg(x.id), '{}'::uuid[]) into ids
    from public.almanac_docs x where x.org_id = o.id and x.status = 'approved' and x.title = any(p.doc_titles);
    insert into public.almanac_questions (org_id, question, answer, answered, doc_ids, mode, is_sample, created_at)
    values (o.id, p.question, p.answer, p.answered, ids, 'sample', true, ts);
    insert into public.mc_events (org_id, at, engine, title, detail, status)
    values (o.id, ts, 'I', 'Almanac', case when p.answered then 'Answered: ' else 'Not in it yet: ' end || p.question,
            case when p.answered then 'qualified' else 'live' end);
  end loop;
  update public.almanac_questions set resolved_at = created_at + interval '1 day'
  where org_id = o.id and is_sample and not answered and resolved_at is null and created_at < d0;
  delete from public.almanac_questions where org_id = o.id and is_sample and created_at < now() - interval '31 days';
end $$;

create or replace function ops_private.almanac_seed_demo()
returns void language plpgsql set search_path = '' as $$
declare o record; d int; today date := (now() at time zone 'America/Chicago')::date;
begin
  for o in select id, slug, live_at from public.orgs where is_demo loop
    delete from public.almanac_questions where org_id = o.id;
    delete from public.mc_events where org_id = o.id and engine = 'I' and title = 'Almanac';
    delete from public.almanac_docs where org_id = o.id;
    insert into public.almanac_docs (org_id, topic, title, body, status, source, approved_by, approved_at, is_sample)
    select o.id, x.topic, x.title, x.body, 'approved', 'Kickoff call and price sheet', 'The owner',
           coalesce(o.live_at, now()) - interval '4 days', true
    from ops_private.almanac_demo_docs x where x.slug = o.slug order by x.sort;
    for d in reverse 30 .. 1 loop
      perform ops_private.almanac_demo_day(o.id, today - d);
    end loop;
  end loop;
end $$;

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
    perform ops_private.almanac_demo_day(o.id, p_today - 1);
  end loop;
end $$;

create or replace function public.mc_view(p_slug text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  o public.orgs; t30 timestamptz := now() - interval '30 days';
  l record; b record; q record; rv record; s record;
  bg jsonb; br jsonb; ba jsonb; bi jsonb; bn jsonb; ads jsonb; alm jsonb;
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
  -- Same for Almanac
  begin
    alm := ops_private.mc_almanac(o.id);
  exception when others then
    alm := null;
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
          'almanac', alm,
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
    values (o.id, o.live_at, 'setup', case when o.tier = 'greenhouse' then 2500 else 5500 end);
    insert into public.mc_payments (org_id, at, kind, amount)
    select o.id, o.live_at + g * interval '30 days', 'monthly', case when o.tier = 'greenhouse' then 3997 else 8991 end
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
  perform ops_private.almanac_seed_demo();
  return 'ok';
end $$;

-- The sample accounts pay the new prices: setup $2,500 (+ $1,500 per added location), monthly $3,997 (+ $2,497 per added location).
update public.mc_payments p
set amount = case p.kind
               when 'setup' then 2500 + 1500 * (o.locations - 1)
               when 'monthly' then 3997 + 2497 * (o.locations - 1)
             end
from public.orgs o
where o.id = p.org_id and o.is_demo and p.kind in ('setup', 'monthly');

-- Onboarding: the Almanac is built from the kickoff and the owner approves it with the test calls.
insert into public.onboarding_template (milestone, milestone_title, day_from, day_to, sort, title, owner)
select 'M3', 'We build, you approve', 3, 6, 15, 'Almanac loaded from the kickoff: prices, policies, service area and how-tos (the voice agent''s knowledge base)', 'grain'
where not exists (select 1 from public.onboarding_template where milestone = 'M3' and sort = 15);
insert into public.onboarding_template (milestone, milestone_title, day_from, day_to, sort, title, owner)
select 'M3', 'We build, you approve', 7, 9, 75, 'Owner reads the Almanac and approves it. Only approved answers are ever given', 'client'
where not exists (select 1 from public.onboarding_template where milestone = 'M3' and sort = 75);

select ops_private.almanac_seed_demo();

revoke all on function public.almanac_docs_before_write() from public, anon, authenticated;
revoke all on function ops_private.almanac_terms(text), ops_private.mc_almanac(uuid), ops_private.almanac_seed_demo(),
  ops_private.almanac_demo_day(uuid, date), ops_private.demo_roll(date) from public, anon, authenticated;
revoke all on function public.almanac_context(text, text) from public;
grant execute on function public.almanac_context(text, text) to anon, authenticated;
revoke all on function public.almanac_log(text, text, text, boolean, uuid[], text) from public, anon;
grant execute on function public.almanac_log(text, text, text, boolean, uuid[], text) to authenticated;
revoke all on function public.hq_almanac_resolve(uuid, uuid) from public, anon;
grant execute on function public.hq_almanac_resolve(uuid, uuid) to authenticated;
revoke all on function public.mc_seed_demo() from public, anon, authenticated;
revoke all on function public.mc_view(text) from public;
grant execute on function public.mc_view(text) to anon, authenticated;
