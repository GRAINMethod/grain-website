# GRAIN Method Website — Deployment Guide

**This is the complete, production-ready GRAIN Method website. Five pages, shared CSS, premium design, ready to deploy.**

---

## WHAT'S IN THIS PACKAGE

| File | Purpose |
|---|---|
| `index.html` | Homepage — the response gap, three standards, calculator preview, CTA |
| `method.html` | The Method page — five stages, deployment timeline, data network effect, dashboard preview |
| `pricing.html` | Pricing page — single offer ($2,500 + $1,997/mo), what's included, FAQ |
| `calculator.html` | Interactive calculator — calculates revenue leak based on inputs |
| `apply.html` | Application page — form + Calendly booking |
| `styles.css` | Shared design system across all pages |
| `README.md` | This file |

**Total file size:** ~150KB. Loads in under 1 second on any decent connection.

---

## STEP 1: REPLACE THE PLACEHOLDERS

Before deploying, you need to replace 4 placeholders across the HTML files. Each appears in multiple pages.

**Use Find & Replace in your code editor (VS Code, Cursor, etc.) across all .html files:**

### 1. Google Analytics ID
**Find:** `G-XXXXXXXXXX`
**Replace with:** Your GA4 measurement ID
**Get it from:** analytics.google.com → Admin → Data Streams → Web stream → Measurement ID

### 2. Calendly URL
**Find:** `https://calendly.com/YOUR-CALENDLY-URL`
**Replace with:** Your full Calendly event URL (e.g., `https://calendly.com/johnny-grainmethod/audit`)
**Get it from:** calendly.com → your event → Share → copy link

### 3. Formspree Form ID (for the apply page)
**Find:** `FORMSPREE_ID_HERE`
**Replace with:** Your Formspree form endpoint
**Get it from:** formspree.io → your form → Integration → copy the endpoint ID
**Example:** If your endpoint is `https://formspree.io/f/abc123xyz`, replace with `abc123xyz`

### 4. Microsoft Clarity (optional, for heatmaps)
The Clarity script was removed for cleanliness. If you want it back, paste this into the `<head>` of each page after the GA script:
```html
<script>(function(c,l,a,r,i,t,y){c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/CLARITY_ID";y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);})(window,document,"clarity","script","CLARITY_ID");</script>
```

---

## STEP 2: SET UP THE THIRD-PARTY SERVICES

You need to set up these accounts before the website works fully.

### Google Analytics 4 (free, ~5 min)
1. Go to analytics.google.com
2. Create a property → Web stream
3. Copy the Measurement ID (starts with G-)
4. Replace `G-XXXXXXXXXX` in all HTML files

### Calendly (Standard plan, $10/mo, ~10 min)
1. Sign up at calendly.com
2. Create an event called "GRAIN Audit" — 30 minutes, Zoom link, your availability
3. Get the share link
4. Replace `YOUR-CALENDLY-URL` in all HTML files
5. Connect your Google Calendar so bookings sync

### Formspree (free for low volume, $10/mo for higher, ~5 min)
1. Sign up at formspree.io
2. Create a new form → name it "GRAIN Audit Applications"
3. Set up notifications to johnny@grainmethod.com
4. Copy your form ID
5. Replace `FORMSPREE_ID_HERE` in apply.html

### Google Workspace (already done, $6/mo)
You should already have johnny@grainmethod.com set up via Google Workspace. If not:
1. Sign up at workspace.google.com
2. Add grainmethod.com as the domain
3. Verify DNS records
4. Create johnny@grainmethod.com mailbox

---

## STEP 3: DEPLOY TO NETLIFY

Netlify is free and the simplest way to deploy this. Takes about 10 minutes.

### Option A: Drag and drop (fastest)
1. Go to app.netlify.com
2. Sign up with email or GitHub
3. Drag the entire `grain-site` folder onto the dashboard
4. Netlify will instantly deploy it at a random URL like `random-name-12345.netlify.app`
5. Click "Domain settings" → Add custom domain → grainmethod.com
6. Update your DNS records (Netlify will give you instructions)
7. Wait 5-30 min for DNS to propagate
8. Site is live at grainmethod.com

### Option B: GitHub-based (better for ongoing updates)
1. Create a GitHub repository called `grain-website`
2. Push the entire `grain-site` folder to it
3. In Netlify, click "New site from Git" → connect to GitHub → select repo
4. Build command: leave empty
5. Publish directory: leave as default (root)
6. Deploy
7. Add custom domain (same as above)

**Future updates:** When you want to update the site, just push changes to GitHub. Netlify auto-deploys.

### DNS configuration
For grainmethod.com to work, in your domain registrar (probably Namecheap or wherever you bought it):
- A record: `@` → `75.2.60.5` (Netlify's IP)
- CNAME: `www` → `your-site.netlify.app`
- Wait 5-30 min for propagation

Netlify will give you exact instructions when you add the custom domain.

---

## STEP 4: TEST EVERYTHING BEFORE GOING LIVE

Once deployed, test these in order:

**Homepage (grainmethod.com):**
- [ ] Hero loads, animation plays
- [ ] All buttons clickable
- [ ] Calculator preview displays correctly
- [ ] "Apply for Audit" button opens Calendly popup
- [ ] Footer links work
- [ ] Mobile view looks clean (resize browser to test)

**Method page (grainmethod.com/method.html):**
- [ ] Five stages display in order
- [ ] Flywheel animation rotates
- [ ] Dashboard preview displays
- [ ] All CTAs work

**Pricing page (grainmethod.com/pricing.html):**
- [ ] Single offer card displays correctly
- [ ] Pricing math is right ($2,500 + $1,997)
- [ ] FAQ accordion expands when clicked
- [ ] CTA buttons work

**Calculator (grainmethod.com/calculator.html):**
- [ ] Sliders move
- [ ] Number updates as you slide
- [ ] Trade buttons change the calculation
- [ ] Default state shows reasonable numbers

**Apply (grainmethod.com/apply.html):**
- [ ] Form fields all work
- [ ] Submit button triggers Formspree
- [ ] Form success message displays
- [ ] You receive an email at johnny@grainmethod.com when form submitted
- [ ] Calendly button opens popup

---

## STEP 5: MONITOR AFTER LAUNCH

**Week 1:**
- Check GA4 daily for traffic patterns
- Check Formspree daily for applications
- Check Calendly daily for bookings
- Test the audit flow yourself end-to-end (submit a form, book a call)

**Ongoing:**
- Weekly review of GA4: which pages get traffic, where do people drop off?
- Update copy based on what you hear from prospects ("they keep asking X" → add to FAQ)
- Add case studies as you land clients

---

## WHAT THIS WEBSITE DOES NOT INCLUDE (THINGS TO ADD LATER)

The website is production-ready, but these things should be added as the business grows:

### Privacy Policy and Terms (legal requirement)
The footer links to /privacy and /terms but those pages don't exist yet. You need to create them:
- Use a tool like termly.io or iubenda.com (~$10-30/mo)
- They'll generate compliant Privacy Policy and Terms of Service
- Add the pages to the site as `privacy.html` and `terms.html`

### Real client logos in "Works With" section
Right now the logo grid uses styled text instead of actual SVG logos. This is intentional — you don't have permission to use the real ServiceTitan, Jobber, etc. logos until you're an official partner. Two options:
- **Option A:** Leave as styled text (looks clean, legally safe)
- **Option B:** Become an official partner with each platform (ServiceTitan, GHL, etc. have partner programs) and they'll provide official logos to use

### Case Studies pages
The footer doesn't link to any case studies yet. Once you have 1-2 paying clients with results:
1. Create `case-studies/[client-name].html` for each
2. Add a "Case Studies" link to the nav
3. Use the self-hosted case study template I created earlier (grain_self_hosted_case_study.md)

### About page
Deliberately not built. You don't have a story to tell yet. Once you have:
- 3+ paying clients with results
- A founder press feature
- A real "why we built this"

Then create `about.html`.

### Blog (eventually)
For SEO and content marketing. Not urgent. Build only after the website is converting paid traffic.

---

## DESIGN SYSTEM REFERENCE

In case you want to make changes yourself, here's the design system in use:

### Colors
```
--bg: #F0ECDF       /* main background, warm cream */
--paper: #F7F4EA    /* secondary surface, lighter cream */
--ink: #1C2420      /* primary text, near black */
--moss: #9AAF7A     /* primary accent, sage green */
--moss-deep: #667B4A /* deeper green for hover/emphasis */
--moss-light: #BFD0A2 /* lighter green for dark backgrounds */
```

### Fonts
- **Inter** — UI and body
- **Fraunces** — italic display accents
- **JetBrains Mono** — labels, metadata, technical text

### Spacing scale
Generous whitespace. Section padding: 100-160px. Container max-width: 1280px.

### Animations
- Scroll reveal: 0.75s cubic-bezier
- Hover transitions: 0.25s cubic-bezier
- One flagship animation: the flywheel on /method (60s rotation)

### Voice rules
- No competitor mentions
- No scarcity tactics
- No exclamation marks
- No emojis
- Declarative, not promotional
- Numbers always specific
- AI language only in FAQ (where customers ask about it)

---

## THINGS I COULDN'T DO IN THIS SESSION (THINGS YOU NEED TO DO)

Being honest about gaps:

### Can't do (require human action)
1. **Form an LLC.** Use LegalZoom or Northwest Registered Agent. ~$300. Required before you take a client.
2. **Get business insurance.** Professional liability (E&O). $400-1,200/year. Required before you take a client.
3. **Have a Tennessee attorney review the client agreement.** ~$300-800. Required before you take a client.
4. **Set up Stripe.** Get verified, link your business bank account. Required to accept payments.
5. **Set up your phone number.** Twilio number with Vapi voice agent (this is your "GRAIN-on-GRAIN" install).

### Can't do well (require visual designer)
1. **Real partner logos.** Need to be obtained through partner programs or licensed.
2. **Custom illustrations and renders.** Beyond what SVG can do simply.
3. **Photorealistic dashboard screenshots.** Once you have your own GHL dashboard running, take a real screenshot.
4. **Founder photo and brand photography.** When you have content to shoot.

### Could be improved later
1. **The hero animation could be more elaborate.** Right now it's a simple fade-up. Could be a multi-step storytelling animation.
2. **The flywheel could be more sophisticated.** It rotates but could pulse, glow, show data flowing.
3. **The mobile experience could be tested more rigorously.** I designed for mobile but you should test on actual devices.

---

## NEXT STEPS IN PRIORITY ORDER

Once the website is deployed:

### Week 1 — Foundation
- [ ] Form GRAIN Method LLC in Tennessee
- [ ] Get business insurance (E&O)
- [ ] Open business bank account
- [ ] Set up Stripe with the business entity
- [ ] Have an attorney review the client agreement
- [ ] Deploy this website to grainmethod.com

### Week 2 — Sales infrastructure
- [ ] Set up GoHighLevel Agency Pro account
- [ ] Set up Vapi voice agent (your own GRAIN-on-GRAIN install)
- [ ] Set up Apollo.io for lead lists
- [ ] Set up Instantly.ai for cold email
- [ ] Set up LinkedHelper for LinkedIn outreach

### Week 3 — Outreach launch
- [ ] Pull first 200 prospects from Apollo (Roofing, HVAC, Pest Control, Tennessee/Georgia/NC)
- [ ] Send first 50 cold emails / 15 LinkedIn requests / 35 cold calls per day
- [ ] Send the partnership pitch email to Hook Agency
- [ ] Track every conversation in your GHL CRM

### Week 4 — First closes
- [ ] Run audit calls with anyone who books
- [ ] Use the "48-Hour Proof" with hesitant prospects
- [ ] Close your first client
- [ ] Start delivering the 7-day deployment

---

## CONTACT FOR HELP

This is a complete, production-ready website. If something breaks during deployment:

**Common issues:**
- "Calendly button doesn't work" → You forgot to replace YOUR-CALENDLY-URL
- "Form doesn't submit" → You forgot to replace FORMSPREE_ID_HERE
- "Site looks weird on mobile" → Clear browser cache, try incognito
- "DNS not working" → Wait longer (can take up to 48 hours)
- "Domain doesn't connect" → Check DNS records match Netlify's instructions exactly

**If still stuck:** Take a screenshot of the issue and describe it specifically. Most deployment issues are fixable in under 5 minutes.

---

**Final note:** This website is the cleanest, most premium version of GRAIN yet. It's built for the buyer who values clarity over cleverness. Deploy it, send people to it, and let it work for you while you make the calls that bring in the first clients.

Now go make money.
