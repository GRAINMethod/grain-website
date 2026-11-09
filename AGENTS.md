# grainmethod.com: notes for Cursor, Claude Code and anyone editing this repo

GRAIN Method answers calls, books jobs, follows up on estimates and revives old estimates for home service shops. Founder: Johnny Dibb, Nashville. This repo is the public site. GRAIN HQ (Johnny's dashboard) and client Mission Control will live in this same Next.js app, on the same brand tokens.

## Stack

- Next.js 16 (App Router, Turbopack), React 19, TypeScript, Tailwind CSS v4
- Fonts self-hosted from npm: Fraunces (headlines), Inter (reading), JetBrains Mono (typed values)
- Vercel project `grain-website` (team grainmethods-projects). `main` deploys to www.grainmethod.com. Every other branch gets a preview.
- Supabase project `emmgtxumhaqfbcjzddpa` (org GRAIN Method). Website leads go to `public.leads` through `public.submit_lead()`.

```
npm install
npm run dev        # http://localhost:3000
npm run build      # must pass before you push
npm run typecheck
```

## Where things live

| What | Where |
| --- | --- |
| Prices, guarantees, steps, trades | `content/offer.ts` (one source, every page reads it) |
| FAQ | `content/faq.ts` |
| Email, phone, booking link, nav, homepage sections | `content/site.ts` |
| Brand tokens and shared component classes | `app/globals.css` |
| Paper artifacts (estimates, tape, GRAIN estimate, call log) | `components/blocks/` |
| Homepage sections | `components/home/` |
| Forms | `components/forms/` posting to `app/api/leads/route.ts` |

Canon changes start in Notion (GRAIN HQ, Pricing and Growth), then land in `content/offer.ts`.

## Brand rules

- Palette: ink #1C2420, cream #F0ECDF, paper #F7F4EA, moss #9AAF7A, moss-ink #55683F (text and links on cream), rust #A3322A (only for "nobody followed up" states).
- Fraunces for headlines and big numerals only. Inter for everything you read. JetBrains Mono only for typed values: amounts, times, estimate numbers, form entries.
- The visual idea is the shop's own paperwork: estimates, an adding-machine tape, a call log. `.slip`, `.tape`, `.stamp` in globals.css.
- One unprompted motion moment: the Revived stamp on the hero. Don't add fade-in-on-scroll effects. Respect `prefers-reduced-motion`.
- Pill shape is for buttons. Paper is near-square (3px). Panels are 22px.
- Numbered markers only for real sequences (the 3 steps, timelines).

## Copy rules (client-facing)

- Kitchen-table test: would an owner say it to their spouse at the kitchen table?
- No em dashes. No "Every X. Every Y." fragments. No competitor names, including job software brands.
- Banned words: infrastructure, operators, solutions, synergy, optimize, layer.
- No made-up numbers, reviews, testimonials or live counters. Examples are labeled as examples. Real results only with the owner's written permission.
- Guarantee conditions sit right next to the guarantee, at readable size (FTC 16 CFR 239).
- Buttons say what happens: "Get my free Leak Check", not "Submit".

## Forms and leads

`POST /api/leads` does three things and succeeds if any one works:
1. Saves to Supabase with the publishable key (`submit_lead` is insert-only, RLS is on, nobody can read leads with that key).
2. Forwards to `LEAD_WEBHOOK_URL` if set (GoHighLevel inbound webhook, Make or Slack).
3. Emails through Resend if `RESEND_API_KEY` is set (to `LEAD_NOTIFY_EMAIL`, default johnny@grainmethod.com).

## Environment variables (Vercel)

| Key | Needed | What |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | yes | Supabase API URL (falls back to the project URL) |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | yes | Supabase publishable key (safe to expose) |
| `NEXT_PUBLIC_GRAIN_PHONE` | when ready | GRAIN's 615 number, 10 digits. Turns on "Text me your numbers". |
| `NEXT_PUBLIC_BOOKING_URL` | when ready | GoHighLevel calendar link. Adds "Pick a time now" after the form. |
| `LEAD_WEBHOOK_URL` | optional | Where every lead gets forwarded |
| `RESEND_API_KEY`, `LEAD_NOTIFY_EMAIL`, `LEAD_FROM_EMAIL` | optional | Email alert per lead |

Never commit secrets. The Supabase service role key never goes in this repo or in a `NEXT_PUBLIC_` variable.

## History

The June 2026 static v5 site is retired. It lives in git history at commit `1323c9b`. Old `.html` URLs redirect in `next.config.ts`.
