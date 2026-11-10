-- GRAIN ops backend, part 1c: who counts as signed in, and inbound leads are never auto-rejected.

-- GRAIN sign-in is a link sent to the inbox, never a password. A session that was opened with a
-- password (or anonymously) has not proved it owns the inbox, so it never counts as staff or as a
-- client member, whatever the project's auth settings are.
create or replace function public.session_proves_inbox()
returns boolean language sql stable set search_path = '' as $$
  select (select auth.uid()) is not null
     and not exists (
       select 1
       from jsonb_array_elements(
              case when jsonb_typeof((select auth.jwt()) -> 'amr') = 'array' then (select auth.jwt()) -> 'amr' else '[]'::jsonb end) a
       where coalesce(a ->> 'method', a #>> '{}') in ('password', 'email/signup', 'anonymous'));
$$;
revoke all on function public.session_proves_inbox() from public, anon, authenticated;

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.session_proves_inbox() and exists (
    select 1
    from auth.users u
    join public.staff s on s.user_id = u.id or lower(s.email) = lower(u.email)
    where u.id = (select auth.uid()) and u.email_confirmed_at is not null);
$$;

create or replace function public.mc_can_read(p_org uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.orgs o where o.id = p_org and o.is_demo)
      or public.is_staff()
      or (public.session_proves_inbox()
          and exists (select 1 from public.org_members m where m.org_id = p_org and m.user_id = (select auth.uid())));
$$;

-- Someone who filled in the website form asked to talk, so a person decides, not a rule.
-- An industry we don't list only auto-rejects prospects we went looking for ourselves.
create or replace function public.prospect_auto_dq(p public.prospects)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when p.trade is not null and p.trade = 'other' and p.source <> 'website' then 'trade_not_served'
    when p.revenue_band = 'under_500k' and p.source <> 'website' then 'revenue_under_500k'
    when p.trade is not null and p.service_area is not null and exists (
      select 1 from public.orgs o
      where o.is_demo = false and o.status in ('onboarding','live')
        and o.trade = p.trade and lower(trim(o.service_area)) = lower(trim(p.service_area))
        and (p.org_id is null or o.id <> p.org_id)
    ) then 'conflict_existing_client'
    when p.touch_count >= 6 and p.conversation_at is null and p.stage not in ('won','lost') then 'no_conversation_after_6_touches'
    else null end;
$$;
revoke all on function public.prospect_auto_dq(public.prospects) from public, anon, authenticated;
