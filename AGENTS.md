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

The mark (greenhouse with a plant): the plant stands on the floor and never reaches into the floor line (Johnny's call, Nov 10, 2026). In the SVG the plant group comes first and the house outline is drawn on top of it; the stem starts at the floor's top edge, half the outline stroke above the floor line (`M 0 -9` for the 18-wide outline, `M 0 -11` for the 22-wide dashboard peak logo); there is no soil mound. The same mark is the favicon, the nav and footer logo, the Method network hub and the dashboard peak logo.

## The v7 offer (canon lives in Notion: GRAIN HQ, Pricing and Growth)

- Greenhouse (one location): standard $3,997/mo (raised from $2,997 on Nov 23, 2026; Johnny's call: never undercut the value). Shown on the site as "$3,997 / month" with "Founding rate $1,997 / month · sign by Dec 31 and keep it as long as you stay" (founding clients keep the rate as long as they stay; the footer says "Founding rate · sign by Dec 31"). $2,500 setup, $0 until it's live (setup + month one charged at go-live), plus 10% of revived jobs, only on jobs completed and paid. Never write "first 5 shops" or "spots left" on the site.
- Orchard (2 to 9 locations): first location at Greenhouse pricing, each added location $2,497/mo + $1,500 setup. Shown "from $6,494".
- Estate (10+ locations): about $2,497 per location on one contract, the same as an added Orchard location, so ten locations never cost less than nine. Shown "from $24,970".
- Orchard and Estate stay on the pricing page as anchors. Greenhouse sits in the center with the "Recommended" badge.
- Annual prepay: two months free (monthly/annual toggle on the pricing page). The annual figure is the monthly price × 10 ÷ 12, rounded down.
- Guarantees, always shown with their conditions: Start Guarantee ($0 until live, live in 14 days or month one free), call promise (99% answered in 60 seconds or that month free), Payback Guarantee ($1.5M+ unsold estimates; monthly pauses at day 90 until revived jobs cover what's paid; refund the difference at day 180).
- Greenhouse is the full, all-included offer (Johnny's call, Nov 18, 2026): all five engines, with Generate inside it. Roots (Google profile, the same details on every listing, a service or FAQ page a month, AI search checks), Fertilizer (a review request after every job, a reply to every review, a referral ask), Compost (old-estimate revival, 10% of revived jobs) and Almanac (the team's knowledge base, Nov 23) are included in every tier and are never sold as add-ons.
- Engines first, garden names inside them (Johnny's calls, Nov 19, 2026): the five engines are the only top-level things. Roots and Fertilizer sit inside Generate, Almanac inside Integrate, Compost inside Nurture, never as their own cards or as tags beside an engine. Inside an engine they're a label: the name, a colon, then plainly what we do ("Roots: We set up and keep up your Google profile..."). Never work a garden name into a sentence ("Roots gets you found"). Sunlight is the exception because it's an add-on.
- Sunlight is the only add-on (Johnny, Nov 23, 2026): $997/mo or 15% of ad spend, whichever is higher; Google and Facebook ads; "When your schedule's full, we turn the ads down"; most shops add it around day 60. The homepage (`#growth`), the pricing page (`#addons`) and the Method page show it the same way: "Need more leads? We run the ads too." beside the `.ads-list`. No add-on cards and no "Included in every plan" row (showing only Generate and Nurture there was confusing); the homepage says "Everything above comes with every plan." Almanac (the team's prices, policies and how-tos in one place they can ask, on the same knowledge base the voice agent answers from) is included in every plan as a label inside Integrate, never sold. Pollination and Pruning are parked; keep them off the site.
- Generate covers every way GRAIN brings leads (Johnny, Nov 23): getting found on Google and in AI search (Roots), quote forms and tap-to-call on the client's site, reviews and referrals (Fertilizer), and ads if they want them (Sunlight, the add-on). Automate includes callbacks: "call me back after the holidays" on a call or email becomes a follow-up on that day. Integrate includes the Greenhouse Dashboard, which shows all five engines plus ads, and Almanac.
- One client per trade per area (home services: one shop per trade per service area). Never two direct competitors in the same area.
- 14-day deployment, shown as 4 milestones. Never "7 days", never the old 5-jobs guarantee.
- Home services trades: HVAC, Plumbing, Roofing, Electrical, Remodeling, Painting, Fencing, Pools, Landscaping, Garage doors.

## Voice

- The site speaks to home service owners (decided Nov 10, 2026): one industry until there is a client in another. Premium and human. Say both halves in one breath (Johnny, Nov 23, 2026): more leads, and none of them lost. GRAIN brings leads (Generate is in every plan) and makes sure each one is answered, booked and followed up. Never lead gen alone (that reads as one more agency) and never answering alone (that reads as a $29 app). Ads (Sunlight) still come second, once every call is being answered.
- Home services words: "shop", "trade", "jobs", "estimates". `/industries` is built but unlinked and `noindex` (not in the nav or footer). It lists five tested verticals: home services, med spas and dental, auto repair and collision, real estate and property management, multi-location groups. Link a row back in only when GRAIN has a client there, with their result. The footer keeps one quiet line: "Not in home services? Apply and we'll tell you if it fits."
- No buzzwords and no invented product names for the sales call: it's a "free audit", not a "Leak Check". Short sentences, fewer words.
- Write it the way Johnny would say it to an owner (Nov 19, 2026): what we do, how we do it, and the problem it fixes. Owners don't care about the terminology. Ask GRAIN answers especially: spoken, plain, no lists of brand names. Ask GRAIN doesn't say GRAIN only works with home services: any business that takes calls, texts or forms and gives quotes may fit.
- The owner line (Nov 18, 2026): "Every lead gets answered and booked, every estimate gets followed up, your old estimates turn into jobs, and when you need more leads, I bring those too. Done for you, here in Nashville." Say "leads", not "calls". Proposed Nov 23, waiting on Johnny: "I get you more leads and make sure none slip through. Every one gets answered and booked, every estimate gets followed up, and your old estimates turn into jobs. Done for you, here in Nashville." The homepage headline stays "Your leads are seeds. We build the greenhouse." (Johnny's call, Nov 23), with the plain subhead under it, then the five-step "What we do" flow in G-R-A-I-N order, lead gen first. Say "estimate", not "quote".
- The dashboard is the **Greenhouse Dashboard** (it used to be Mission Control).
- No competitor names on the site.

## Rules

- Anything that looks like live data must be real or labeled ("Sample data", "Example", "Illustration"). No made-up results. Stats need a named source on the page.
- Forms post to `/api/leads` (saves to Supabase `public.leads` via the insert-only `submit_lead` function, optional `LEAD_WEBHOOK_URL` and Resend email). The apply form pre-selects a trade from `?trade=`.
- Booking buttons call `openCalendly()`, which goes to `BOOKING_URL` (GoHighLevel calendar, set in each page) or falls back to `/apply`.
- Internal links use clean URLs (`/pricing`, `/method`, `/` for home), never `pricing.html`. A button that says "pricing" goes to the top of `/pricing`, not to a section halfway down it.
- No em dashes in new client-facing copy.
- Never commit secrets. The Supabase service role key never goes in the repo or a `NEXT_PUBLIC_` variable.

## The backend (Supabase project `emmgtxumhaqfbcjzddpa`)

How GRAIN runs is written down in Notion: GRAIN HQ, Operations (nine short SOPs). The database is the record those SOPs run on.

- **Pipeline:** `prospects`, `prospect_touches`. A website form (`leads`) lands in the pipeline by trigger and queues a "call within 5 minutes" alert. Prospects score 0 to 100 on write (`prospect_score`); 60+ with no disqualifier is qualified. One client per trade per area is enforced as an auto-disqualifier.
- **Demand scoring (Nov 18, 2026):** `prospects` carries `main_service`, `searches_monthly`, `map_rank`, `top3_avg_reviews`, `avg_ticket`, `close_rate`, `market_demand_monthly`, `missed_monthly`, `biggest_gap`, `demand_tier` (A, B, C), `opener`, `demand_source` (`clay` keeps the Clay totals; `hq` and `audit` are computed by the trigger from the main service). The 0 to 100 score is unchanged; HQ works the list by tier, then missed $, then score. `hq_import_prospects(jsonb)` takes the Clay export (parsed in HQ by `lib/demand.ts`), matching by phone or name and city. The math lives in two places that must agree: `prospects_before_write` and `lib/demand.ts` (3% of searches, 45% book, rank shares 100/25/5/0%).
- **Clients:** `orgs` (status onboarding, live, paused, churned), `onboarding_template` and `onboarding_tasks` (signing day, then M1 to M4, due dates from kickoff), `onboarding_pauses` (the 14-day clock), `client_log`, `client_daily_metrics`, `mc_*` (leads, estimates, appointments, events, payments).
- **Messages:** everything GRAIN would send lands in `outbox` first. Slack posts send only once a webhook is saved in HQ, System. Texts and emails wait there until GoHighLevel is connected.
- **Schedule:** one `pg_cron` job, `grain-ops-tick`, every 15 minutes. Central time: daily numbers at 00:15, the HQ digest at 07:00, client updates at 07:30, the Monday scorecard, and on the 1st the call-promise check and the 10% share invoice task.
- **Intake:** `POST /api/ingest/ghl` and `/api/ingest/retell` with the ingest key from HQ, System. The event shape is documented at the top of that route. Bookings are counted from `appointment` events (the calendar is the truth).
- **Dashboard feed:** `GET /api/mc/<slug>` calls `mc_view`. The two sample orgs (`is_demo`) are public and labeled "Sample data" on the page. A real client's dashboard is `/dashboard?org=<slug>` and needs their sign-in.
- **Ads (Nov 23, 2026):** `orgs.sunlight` marks accounts whose ads GRAIN runs; `mc_ad_spend` holds spend and clicks per day and channel ('Google Local Services', 'Google Search', 'Facebook', matching `mc_leads.source`). `ops_private.mc_ads` builds the 30-day table (spend, leads, booked, cost per booked job) that `mc_view` puts under `engines.G.ads`; the page renders it under the Generate chart. On the sample orgs a trigger adds each paid lead's cost to the day's spend. Real spend comes from Google Ads and Meta once those connections exist.
- **Almanac (Nov 23, 2026):** `almanac_docs` holds each client's prices, policies and how-tos (topic, title, body, status draft/approved/retired, who approved it). Only approved documents are ever used, and editing an approved one puts it back in draft (trigger) until it's approved again. `POST /api/almanac/<slug>` answers a team member's question from `almanac_context` (the approved documents, best match first): with `ANTHROPIC_API_KEY` set, Claude Haiku writes a short answer and must cite the documents it used; without it, the page shows the best-matching passage labeled as the closest match. `almanac_log` keeps client questions in `almanac_questions`; the ones it couldn't answer open an HQ task ("Almanac: add answers for ...") that closes when the last one is handled in HQ, Almanac. Sample accounts answer their sample questions from `ops_private.almanac_demo_*`, never store visitors' questions, and only use the model with `ALMANAC_DEMO_MODEL=1`. `mc_view` puts the summary under `engines.I.almanac`; the dashboard renders it in the Integrate panel. The same documents are the voice agent's knowledge base (loaded into Retell once it's connected).
- **Access:** sign-in is a link by email, never a password. `staff` is the allowlist; a session opened with a password never counts (`session_proves_inbox`). Every table has row level security. Logic lives in `ops_private` (not exposed); `public` functions are thin wrappers that check the caller.
- **Changing the database:** apply through the Supabase MCP, then mirror the change in `supabase/migrations/` so the files always describe what is live. No service role key in this repo or in a `NEXT_PUBLIC_` variable.

## History

Commit `1323c9b` is the June 2026 v5 site as it was. The `v7-site` branch is a light-theme rebuild that was rejected; don't merge it. `v7-refresh` is Johnny's v5 design with v7 facts, the industries pages and the copy pass.
