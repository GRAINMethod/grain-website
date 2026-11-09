# grainmethod.com: notes for Cursor, Claude Code and anyone editing this repo

GRAIN Method: done-for-you lead response for home service businesses. Founder Johnny Dibb, Nashville.

## How the site is built

- **The marketing site is Johnny's hand-built HTML in `public/`.** Edit those files directly. Do not redesign or "port" them: the dark sections, animations, ticker, GRAIN letter engines, network diagram, Mission Control mockup, calculator and three-tier pricing are the brand.
- Clean URLs (`/pricing`, `/method`, ...) map onto the `.html` files in `next.config.ts`.
- Next.js 16 runs underneath for `/api/*` routes and, next, the real Mission Control dashboard (client login + GRAIN HQ), built on the same visual language (tokens below).
- Every page carries the same inline CSS tokens and the same `ASK_EXAMPLES` (Ask GRAIN answers). Change those in every file at once.

```
npm install && npm run dev   # http://localhost:3000
npm run build                # must pass before you push
```

Vercel project `grain-website`: `main` deploys to www.grainmethod.com, other branches get previews.

## Brand tokens (from the pages' :root)

ink #1C2420 · ink-deeper #141A17 · ink-soft #2A332E · cream #F0ECDF · paper #F7F4EA · moss #9AAF7A · moss-light #BFD0A2 · moss-deep #667B4A · muted #6B6B62. Inter (heavy headlines), Fraunces italic (accents), JetBrains Mono (labels, data).

## The v7 offer (canon lives in Notion: GRAIN HQ, Pricing and Growth)

- Greenhouse (one location): $1,500 setup + $1,497/mo + 10% of revived jobs, only on jobs completed and paid. $0 until it's live; setup + month one charged at go-live. Founding price for 5 shops through Dec 31, then $2,997/mo.
- Orchard (2 to 9 locations): first location at Greenhouse pricing, each added location $1,997/mo + $1,500 setup.
- Estate (10+ locations): about $1,497 per location on one contract.
- Annual prepay: two months free.
- Guarantees, always shown with their conditions: Start Guarantee ($0 until live, live in 14 days or month one free), call promise (99% answered in 60 seconds or that month free), Payback Guarantee ($1.5M+ unsold estimates; monthly pauses at day 90 until revived jobs cover what's paid; refund the difference at day 180).
- Add-ons: Compost included; Roots $997/mo; Fertilizer $297/mo; Sunlight $750/mo or 15% of spend; Pollination and Pruning on request.
- 14-day deployment. Never "7 days", never the old 5-jobs guarantee.

## Rules

- Anything that looks like live data must be real or labeled ("Sample data", "Example", "Illustration"). No made-up results.
- Forms post to `/api/leads` (saves to Supabase `public.leads` via the insert-only `submit_lead` function, optional `LEAD_WEBHOOK_URL` and Resend email).
- Booking buttons call `openCalendly()`, which goes to `BOOKING_URL` (GoHighLevel calendar, set in each page) or falls back to `/apply`.
- No em dashes in new client-facing copy.
- Never commit secrets.

## History

Commit `1323c9b` is the June 2026 v5 site as it was. The `v7-site` branch is a light-theme rebuild that was rejected; don't merge it.
