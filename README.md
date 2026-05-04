# GRAIN Method — Website v3

**Last updated:** May 2026
**Status:** Production-ready.

---

## What's new in v3

- Dark hero on homepage (ink background, moss accents)
- Three pricing tiers: Greenhouse ($1,997/mo), Orchard ($4,997/mo), Estate (custom)
- Plain-language sweep: removed "infrastructure," "operators," "scales" jargon
- New CTA wording: "See Your Numbers" instead of "Calculate Your Gap"
- Apply form: warmer success message, clearer field labels
- Organic SVG section divider on homepage (sprout illustration)
- Transparent nav over dark hero, solid nav after scroll

---

## Files

```
grain-site-v3/
├── index.html       (homepage, dark hero)
├── method.html      (the GRAIN process explained)
├── pricing.html     (three tiers)
├── calculator.html  (interactive lead-loss calculator)
├── apply.html       (audit application form)
├── styles.css       (all shared styles)
└── README.md        (this file)
```

---

## Before deploying — three things to replace

Open each HTML file and find/replace these placeholders:

### 1. Google Analytics ID
Find: `G-XXXXXXXXXX`
Replace with your real GA4 ID (set up at analytics.google.com)

### 2. Calendly URL
Find: `YOUR-CALENDLY-URL`
Replace with your real Calendly link (e.g., `johnny-grainmethod/audit`)

### 3. Formspree form ID (apply.html only)
Find: `FORMSPREE_ID_HERE`
Replace with your Formspree form ID (sign up at formspree.io, free tier works)

---

## Deployment to Vercel via GitHub

If you already have the v2 site deployed, this is the path:

1. Download v3: drag the entire `grain-site-v3` folder out of Claude
2. Open Cursor, navigate to your existing `grain-website` folder
3. Replace the v2 files with the v3 files (drag in, overwrite when prompted)
4. Open Cursor's Source Control panel (left sidebar, branching icon)
5. Stage all changes (click the + next to "Changes")
6. Commit message: `v3 final — dark hero, three tiers, copy polish`
7. Click commit, then Push (sync changes button)
8. Vercel auto-deploys in ~30 seconds

If Vercel isn't already connected:
- Go to vercel.com → Add New → Project
- Import your GitHub repo
- Click Deploy
- Add custom domain (grainmethod.com) under Settings → Domains
- Update DNS:
  - A record: `@` → `76.76.21.21`
  - CNAME: `www` → `cname.vercel-dns.com`

---

## Brand Reference

**Colors:**
- Ink: `#1C2420`
- Cream: `#F0ECDF`
- Paper: `#F7F4EA`
- Moss: `#9AAF7A`
- Moss Deep: `#667B4A`
- Moss Light: `#BFD0A2`

**Type:**
- Inter (body, headlines)
- Fraunces italic (accent words)
- JetBrains Mono (eyebrows, labels, stats)

**Voice rules:**
- Plain English, no industry jargon
- No competitor mentions
- No scarcity tactics
- No emojis
- No exclamation marks
- Use the word an owner would use in their kitchen explaining this to their spouse

---

## What's NOT on the website that's part of the business

These exist in the SOP and audit script, but not on the public site:

- Founding client pricing ($1,500 setup / $1,497/mo) — internal close lever for first 3-5 clients only
- GRAIN Audit Pro ($2,500) — fallback for prospects who fail Greenhouse fit on the audit call
- Referral program ($500 + $500 with milestone bonuses)
- Prepay discount ladder (10/15/20% off for 3/6/12-month prepay)

---

## Three-tier reference

**Greenhouse** — single location, $500K-$3M, 30-150 leads/mo
$2,500 setup + $1,997/month · 7-day deployment · monthly review

**Orchard** — multi-trade or $3M-$10M, 150-500 leads/mo
$5,000 setup + $4,997/month · 14-day deployment · weekly review

**Estate** — multi-location, $10M+, 3+ locations, 500+ leads/mo
Custom pricing · 30-day deployment · dedicated team

All three include the 5-jobs-in-60-days guarantee, 60-second response standard, and 90-day quote follow-up.
