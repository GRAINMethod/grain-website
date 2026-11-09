# grainmethod.com: notes for Cursor, Claude Code and anyone editing this repo

GRAIN Method: done-for-you lead response. Every inquiry answered in under 60 seconds, booked, followed up and revived. Home services is the first industry. Founder Johnny Dibb, Nashville.

## How the site is built

- **The marketing site is Johnny's hand-built HTML in `public/`.** Edit those files directly. Do not redesign or "port" them: the dark sections, animations, ticker, GRAIN letter engines, network diagram, Greenhouse Dashboard mockup, calculator and three-tier pricing are the brand.
- Pages: `index`, `method`, `industries`, `home-services`, `pricing`, `calculator`, `dashboard`, `apply`, `privacy`, `terms`, `security`. Clean URLs (`/pricing`, `/method`, ...) map onto the `.html` files through the `PAGES` list in `next.config.ts`. Add a page there when you add a file.
- Next.js 16 runs underneath for `/api/*` routes and, next, the real Greenhouse Dashboard (client login + GRAIN HQ), built on the same visual language (tokens below). The dashboard tables live in Supabase (`orgs`, `mc_*`); see `supabase/migrations/`.
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
- Add-ons on the site: Compost included; Roots $997/mo (90-day minimum); Fertilizer $997/mo (reviews + content); Sunlight $997/mo or 15% of ad spend (Google Local Services, Search, Meta). Pollination and Pruning are parked; keep them off the site.
- One client per trade per area (home services: one shop per trade per service area). Never two direct competitors in the same area.
- 14-day deployment, shown as 4 milestones. Never "7 days", never the old 5-jobs guarantee.
- Home services trades: HVAC, Plumbing, Roofing, Electrical, Remodeling, Painting, Fencing, Pools, Landscaping, Garage doors.

## Voice

- Master brand (homepage, method, footer, industries): broad, premium, human. Say "business" and "client". Lead with outcomes: answered, booked, followed up, revived.
- Industry pages speak their own dialect. Home services: "shop", "trade", "jobs", "estimates". Other industries get their own words on `/industries` before they get a page.
- No buzzwords and no invented product names for the sales call: it's a "free audit", not a "Leak Check". Short sentences, fewer words.
- The dashboard is the **Greenhouse Dashboard** (it used to be Mission Control).
- No competitor names on the site.

## Rules

- Anything that looks like live data must be real or labeled ("Sample data", "Example", "Illustration"). No made-up results. Stats need a named source on the page.
- Forms post to `/api/leads` (saves to Supabase `public.leads` via the insert-only `submit_lead` function, optional `LEAD_WEBHOOK_URL` and Resend email). The apply form pre-selects a trade from `?trade=`.
- Booking buttons call `openCalendly()`, which goes to `BOOKING_URL` (GoHighLevel calendar, set in each page) or falls back to `/apply`.
- No em dashes in new client-facing copy.
- Never commit secrets. The Supabase service role key never goes in the repo or a `NEXT_PUBLIC_` variable.

## History

Commit `1323c9b` is the June 2026 v5 site as it was. The `v7-site` branch is a light-theme rebuild that was rejected; don't merge it. `v7-refresh` is Johnny's v5 design with v7 facts, the industries pages and the copy pass.
