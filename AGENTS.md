# grainmethod.com: notes for Cursor, Claude Code and anyone editing this repo

GRAIN Method: the done-for-you system between a business's leads and its booked revenue. Every call, text and form answered in under 60 seconds, qualified and booked; every quote followed up; old estimates revived; and, when the client wants more leads, the ads, reviews and search that bring them. It is not an answering service: every part is tied to a number the owner can see. Home services is the first industry. Founder Johnny Dibb, Nashville.

## How the site is built

- **The marketing site is Johnny's hand-built HTML in `public/`.** Edit those files directly. Do not redesign or "port" them: the dark sections, animations, ticker, GRAIN letter engines, network diagram (Method page only; Johnny moved the compounding section off the homepage), Greenhouse Dashboard mockup, calculator and three-tier pricing are the brand.
- Pages: `index`, `method`, `industries`, `home-services`, `pricing`, `calculator`, `dashboard`, `apply`, `privacy`, `terms`, `security`. Clean URLs (`/pricing`, `/method`, ...) map onto the `.html` files through the `PAGES` list in `next.config.ts`. Add a page there when you add a file.
- Next.js 16 runs underneath for `/api/*` routes, `/login` and `/hq` (GRAIN HQ, staff only), built on the same visual language (tokens below).
- Every page carries the same inline CSS tokens, nav, footer and `ASK_EXAMPLES` (Ask GRAIN answers). Change those in every file at once.
- Pricing cards size their numbers with container units (`cqi`) on `minmax(0, …)` grid tracks so long prices never push the Estate card off small laptops. Keep that if you touch `.tier-grid`.

```
npm install && npm run dev   # http://localhost:3000
npm run build                # must pass before you push
```

Vercel project `grain-website`: `main` deploys to www.grainmethod.com, other branches get previews.

## Brand tokens (from the pages' :root)

ink #1C2420 · ink-deeper #141A17 · ink-soft #2A332E · cream #F0ECDF · paper #F7F4EA · moss #9AAF7A · moss-light #BFD0A2 · moss-deep #667B4A · muted #6B6B62. Inter (heavy headlines), Fraunces italic (accents), JetBrains Mono (labels, data).

## The v7 offer (canon lives in Notion: GRAIN HQ, Pricing and Growth)

- Greenhouse (one location): standard $2,997/mo. Shown on the site as "$2,997 / month" with "Founding rate $1,497 / month through Dec 31". $1,500 setup, $0 until it's live (setup + month one charged at go-live), plus 10% of revived jobs, only on jobs completed and paid. Never write "first 5 shops" or "spots left" on the site.
- Orchard (2 to 9 locations): first location at Greenhouse pricing, each added location $1,997/mo + $1,500 setup. Shown "from $4,994".
- Estate (10+ locations): about $1,497 per location on one contract. Shown "from $14,970".
- Orchard and Estate stay on the pricing page as anchors. Greenhouse sits in the center with the "Recommended" badge.
- Annual prepay: two months free (monthly/annual toggle on the pricing page).
- Guarantees, always shown with their conditions: Start Guarantee ($0 until live, live in 14 days or month one free), call promise (99% answered in 60 seconds or that month free), Payback Guarantee ($1.5M+ unsold estimates; monthly pauses at day 90 until revived jobs cover what's paid; refund the difference at day 180).
- Growth add-ons, shown on the homepage (`#growth`) and the pricing page (`#addons`) with the same four cards, Sunlight first: Sunlight $997/mo or 15% of ad spend (Google Local Services, Search, Meta); Roots $997/mo (90-day minimum; Google profile, local SEO, AI answers); Fertilizer $997/mo (reviews, content, referral ask); Almanac, scoped on the audit (the team's pricing, policies and how-tos in one place they can ask). Compost (old-estimate revival) is included in every tier. Pollination and Pruning are parked; keep them off the site.
- One client per trade per area (home services: one shop per trade per service area). Never two direct competitors in the same area.
- 14-day deployment, shown as 4 milestones. Never "7 days", never the old 5-jobs guarantee.
- Home services trades: HVAC, Plumbing, Roofing, Electrical, Remodeling, Painting, Fencing, Pools, Landscaping, Garage doors.

## Voice

- The site speaks to home service owners (decided Nov 10, 2026): one industry until there is a client in another. Premium and human. Lead with outcomes: answered, booked, followed up, revived, then growth. Stop the leak first, more leads second, so GRAIN never reads as one more agency.
- Home services words: "shop", "trade", "jobs", "estimates". `/industries` is built but unlinked and `noindex` (not in the nav or footer). It lists five tested verticals: home services, med spas and dental, auto repair and collision, real estate and property management, multi-location groups. Link a row back in only when GRAIN has a client there, with their result. The footer keeps one quiet line: "Not in home services? Apply and we'll tell you if it fits."
- No buzzwords and no invented product names for the sales call: it's a "free audit", not a "Leak Check". Short sentences, fewer words.
- The dashboard is the **Greenhouse Dashboard** (it used to be Mission Control).
- No competitor names on the site.

## Rules

- Anything that looks like live data must be real or labeled ("Sample data", "Example", "Illustration"). No made-up results. Stats need a named source on the page.
- Forms post to `/api/leads` (saves to Supabase `public.leads` via the insert-only `submit_lead` function, optional `LEAD_WEBHOOK_URL` and Resend email). The apply form pre-selects a trade from `?trade=`.
- Booking buttons call `openCalendly()`, which goes to `BOOKING_URL` (GoHighLevel calendar, set in each page) or falls back to `/apply`.
- No em dashes in new client-facing copy.
- Never commit secrets. The Supabase service role key never goes in the repo or a `NEXT_PUBLIC_` variable.

## The backend (Supabase project `emmgtxumhaqfbcjzddpa`)

How GRAIN runs is written down in Notion: GRAIN HQ, Operations (nine short SOPs). The database is the record those SOPs run on.

- **Pipeline:** `prospects`, `prospect_touches`. A website form (`leads`) lands in the pipeline by trigger and queues a "call within 5 minutes" alert. Prospects score 0 to 100 on write (`prospect_score`); 60+ with no disqualifier is qualified. One client per trade per area is enforced as an auto-disqualifier.
- **Clients:** `orgs` (status onboarding, live, paused, churned), `onboarding_template` and `onboarding_tasks` (signing day, then M1 to M4, due dates from kickoff), `onboarding_pauses` (the 14-day clock), `client_log`, `client_daily_metrics`, `mc_*` (leads, estimates, appointments, events, payments).
- **Messages:** everything GRAIN would send lands in `outbox` first. Slack posts send only once a webhook is saved in HQ, System. Texts and emails wait there until GoHighLevel is connected.
- **Schedule:** one `pg_cron` job, `grain-ops-tick`, every 15 minutes. Central time: daily numbers at 00:15, the HQ digest at 07:00, client updates at 07:30, the Monday scorecard, and on the 1st the call-promise check and the 10% share invoice task.
- **Intake:** `POST /api/ingest/ghl` and `/api/ingest/retell` with the ingest key from HQ, System. The event shape is documented at the top of that route. Bookings are counted from `appointment` events (the calendar is the truth).
- **Dashboard feed:** `GET /api/mc/<slug>` calls `mc_view`. The two sample orgs (`is_demo`) are public and labeled "Sample data" on the page. A real client's dashboard is `/dashboard?org=<slug>` and needs their sign-in.
- **Access:** sign-in is a link by email, never a password. `staff` is the allowlist; a session opened with a password never counts (`session_proves_inbox`). Every table has row level security. Logic lives in `ops_private` (not exposed); `public` functions are thin wrappers that check the caller.
- **Changing the database:** apply through the Supabase MCP, then mirror the change in `supabase/migrations/` so the files always describe what is live. No service role key in this repo or in a `NEXT_PUBLIC_` variable.

## History

Commit `1323c9b` is the June 2026 v5 site as it was. The `v7-site` branch is a light-theme rebuild that was rejected; don't merge it. `v7-refresh` is Johnny's v5 design with v7 facts, the industries pages and the copy pass.
