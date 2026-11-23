#!/usr/bin/env python3
"""
Builds one page per home service trade: public/home-services/<slug>.html

The shell (head, nav, footer, Ask GRAIN, styles) comes from public/home-services.html,
so a change there carries over the next time this runs. Each trade's words live in TRADES below.
Every number on a page needs a named source (AGENTS.md).

    python3 scripts/build-trade-pages.py
"""
import html
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBLIC = ROOT / "public"
SITE = "https://www.grainmethod.com"

# Shared stats with named sources (the same ones the homepage uses)
STAT_UNANSWERED = ("1 in 3", "calls to home service shops goes unanswered. Owners guessed they answered 97%.", "Service Direct, call performance study")
STAT_SPEED = ("21&times;", "more likely to qualify a lead you answer in 5 minutes instead of 30.", "MIT and InsideSales.com, Lead Response Management study")
STAT_LSA = ("56%", "of Local Services Ads leads never turn into a booked job.", "SearchLight, home services benchmark, Feb 2026")

AREAS = "Nashville, Franklin, Brentwood, Murfreesboro, Hendersonville, Mt. Juliet and the rest of Middle Tennessee"

TRADES = [
    {
        "slug": "hvac", "who": "HVAC companies", "name": "HVAC", "lower": "HVAC", "apply": "hvac", "calc": "hvac",
        "h1": ("More HVAC calls.", "Every one answered."),
        "lede": "We get your shop found on Google and in AI search, answer every no-heat and no-cool call in under a minute, book it, follow up every replacement estimate for 90 days and turn two years of old system quotes into jobs. Done for you, live in 14 days.",
        "desc": "For Nashville HVAC shops: more leads from Google and reviews, every no-heat and no-cool call answered in under 60 seconds and booked, every replacement estimate followed up, old estimates turned into jobs. Done for you. $0 up front.",
        "night_h2": ("The 9 pm no-cool call,", "handled."),
        "night": [
            ("9:12 PM", "A homeowner calls", "It's 94 degrees and the AC quit. Your office closed at 5."),
            ("9:12 PM", "Answered in 9 seconds", "By a voice agent trained on your services, prices and service area."),
            ("9:15 PM", "Booked for 8 am", "On your calendar with the details your tech needs. If it can't wait, your on-call tech gets the call."),
            ("Next day", "The replacement quote gets followed up", "Day 1, 3, 7, 14, 30, 60 and 90, until it's a yes or a no."),
            ("All year", "Old system quotes come back", "Two years of unsold estimates, worked into jobs. You pay 10% only on jobs completed and paid."),
        ],
        "search": "AC repair near me",
        "respond": "No-heat and no-cool calls answered in under 60 seconds, day or night. A gas smell or CO alarm gets safety steps first, then your on-call tech.",
        "estimates": "replacement and repair",
        "old": "system quotes and lapsed maintenance customers",
        "stat": ("$11,500", "is about what a full HVAC system replacement runs. One revived quote can pay for months of GRAIN.", "ConsumerAffairs, May 2026"),
        "software": "ServiceTitan, Housecall Pro, Jobber and FieldEdge",
        "faq": [
            ("Can it handle no-heat and no-cool emergencies?", "Yes. It books the visit and sends true emergencies to your on-call tech. On a gas smell or a CO alarm it tells the caller to get out and call 911 or the gas company first."),
            ("Do you work with ServiceTitan?", "Yes. ServiceTitan only lets outside tools book through its certified apps, so where it allows we book straight in, and where it doesn't, jobs land on a calendar your office confirms. We'll check yours on the audit."),
            ("What about maintenance plan customers?", "Lapsed maintenance customers go on the list we work in month one, along with two years of unsold estimates."),
        ],
    },
    {
        "slug": "plumbing", "who": "plumbers", "name": "Plumbing", "lower": "plumbing", "apply": "plumbing", "calc": "plumbing",
        "h1": ("More plumbing calls.", "Every one answered."),
        "lede": "We get your shop found when pipes burst, answer every call in under a minute day or night, book it, follow up every water heater and repipe estimate for 90 days and turn your old quotes into jobs. Done for you, live in 14 days.",
        "desc": "For Nashville plumbing shops: more leads from Google and reviews, every emergency call answered in under 60 seconds and booked, every water heater and repipe estimate followed up, old estimates turned into jobs. Done for you. $0 up front.",
        "night_h2": ("The 2 am burst pipe,", "handled."),
        "night": [
            ("2:06 AM", "A homeowner calls", "Water's coming through the ceiling. Your office opens at 7."),
            ("2:06 AM", "Answered in 8 seconds", "It walks them through shutting off the water and books the job."),
            ("2:09 AM", "Your on-call plumber gets it", "With the address and what's wrong, before they've finished mopping."),
            ("Next day", "The water heater quote gets followed up", "Day 1, 3, 7, 14, 30, 60 and 90, until it's a yes or a no."),
            ("All year", "Old estimates come back", "Repipes, water heaters and sewer lines you quoted and never closed, worked into jobs."),
        ],
        "search": "emergency plumber near me",
        "respond": "Emergency calls answered in under 60 seconds, 24/7, and sent to your on-call plumber. Routine calls get booked into your open slots.",
        "estimates": "water heater, repipe and sewer",
        "old": "repipe, water heater and sewer quotes",
        "stat": ("$3,319", "is the average sewer line job, and a water heater install runs about $1,400.", "Angi, Aug 2026; Fixr, Jan 2026"),
        "software": "ServiceTitan, Housecall Pro, Jobber and FieldEdge",
        "faq": [
            ("Can it handle after-hours emergencies?", "Yes. It answers at 2 am the same way it answers at 2 pm, books the job and sends real emergencies to whoever is on call."),
            ("Is it worth it for small service calls?", "The drain call is how you meet the customer who needs a water heater next year. Answering it fast is how you keep them."),
            ("Will it follow up on big quotes?", "Every estimate gets 90 days of text and email follow-up, until it's a yes or a no. If they say call me in March, we call in March."),
        ],
    },
    {
        "slug": "roofing", "who": "roofers", "name": "Roofing", "lower": "roofing", "apply": "roofing", "calc": "roofing",
        "h1": ("More roofing leads.", "Every one answered."),
        "lede": "We get you found when storms roll through, answer every call in under a minute even the day after a hailstorm, book the inspection, follow up every estimate while the homeowner waits on insurance, and turn old quotes into jobs. Done for you, live in 14 days.",
        "desc": "For Nashville roofers: more leads from Google and reviews, every storm call answered in under 60 seconds and booked, every estimate followed up through the insurance wait, old quotes turned into jobs. Done for you. $0 up front.",
        "night_h2": ("The day after the hailstorm,", "handled."),
        "night": [
            ("7:40 AM", "The phones light up", "Hail hit three neighborhoods overnight. Everyone wants an inspection."),
            ("All day", "Every call answered", "No hold music, no voicemail. Each caller gets an inspection time."),
            ("Same day", "Inspections on your calendar", "With the address and what the homeowner saw, ready for your crew."),
            ("Next weeks", "Estimates followed up", "While they wait on insurance, they keep hearing from you, not the storm chaser."),
            ("All year", "Old estimates come back", "Roofs you quoted and never sold, worked into jobs."),
        ],
        "search": "roof repair near me",
        "respond": "Every call answered in under 60 seconds, even when a storm sends a week of calls in a day. Leaks and tarps go to your on-call crew.",
        "estimates": "replacement and repair",
        "old": "roof quotes you never sold",
        "stat": ("$17,631", "was the average roof replacement in 2025. One revived estimate can pay for months of GRAIN.", "Verisk"),
        "software": "JobNimbus, AccuLynx, ServiceTitan and Jobber",
        "faq": [
            ("What happens after a big storm?", "Every caller gets answered and booked, whether it's 20 calls or 200. You see them all on your calendar and in your dashboard."),
            ("Do you handle insurance claims?", "No. Your team handles the claim. We keep the homeowner warm while it moves and book the next step when they're ready."),
            ("Do you work with JobNimbus and AccuLynx?", "Yes, and most other roofing software. Where it takes outside bookings, jobs go straight in. Where it doesn't, they land on a calendar your office confirms."),
        ],
    },
    {
        "slug": "electrical", "who": "electricians", "name": "Electrical", "lower": "electrical", "apply": "electrical", "calc": "electrical",
        "h1": ("More electrical calls.", "Every one answered."),
        "lede": "We get you found for panel upgrades, EV chargers and repairs, answer every call in under a minute, book it, follow up every estimate for 90 days and turn old quotes into jobs. Done for you, live in 14 days.",
        "desc": "For Nashville electricians: more leads from Google and reviews, every call answered in under 60 seconds and booked, every panel, EV charger and generator estimate followed up, old quotes turned into jobs. Done for you. $0 up front.",
        "night_h2": ("The Sunday breaker call,", "handled."),
        "night": [
            ("4:20 PM Sun", "A homeowner calls", "Half the house lost power and the breaker won't reset."),
            ("4:20 PM", "Answered in 9 seconds", "Booked, or sent straight to your on-call electrician if it can't wait."),
            ("Monday", "Your tech quotes the panel", "The old panel needs replacing, and they want an EV charger too."),
            ("Next 90 days", "The quote gets followed up", "Until it's a yes or a no. Call me after tax season gets a follow-up then."),
            ("All year", "Old estimates come back", "Panels, EV chargers and generators you quoted and never installed."),
        ],
        "search": "electrician near me",
        "respond": "Every call answered in under 60 seconds, 24/7. Burning smells and sparking outlets get the safety steps you set, then your on-call electrician.",
        "estimates": "panel, EV charger and generator",
        "old": "panel, charger and generator quotes",
        "stat": ("$1,342", "is the average cost to replace a home electrical panel. Bigger upgrades with rewiring run far higher.", "Angi 2026 data, via NerdWallet"),
        "software": "ServiceTitan, Housecall Pro and Jobber",
        "faq": [
            ("Can it handle emergencies?", "Yes. It gives the safety steps you set, books the visit, and sends anything urgent to your on-call electrician right away."),
            ("Will it follow up on EV charger and generator quotes?", "Every estimate gets 90 days of text and email follow-up, until it's a yes or a no."),
            ("Do I have to change software?", "Usually not. We work with ServiceTitan, Housecall Pro, Jobber and most others, and check yours on the audit."),
        ],
    },
    {
        "slug": "remodeling", "who": "remodelers", "name": "Remodeling", "lower": "remodeling", "apply": "remodeling", "calc": "remodeling",
        "h1": ("More remodeling leads.", "Every one followed up."),
        "lede": "We get you found for kitchens, baths and additions, answer every inquiry in under a minute, book the consult and follow up for 90 days while they decide. Then we turn your old proposals into projects. Done for you, live in 14 days.",
        "desc": "For Nashville remodelers: more leads from Google and reviews, every inquiry answered in under 60 seconds and booked for a consult, every proposal followed up for 90 days, old proposals turned into projects. Done for you. $0 up front.",
        "night_h2": ("The Saturday kitchen inquiry,", "handled."),
        "night": [
            ("Sat 11 AM", "A form comes in", "They want a new kitchen and they're getting three bids."),
            ("11:01 AM", "Answered in under a minute", "A text back, then a call, and a consult on your calendar."),
            ("Next week", "Your proposal goes out", "You do the design visit and send the number."),
            ("Next 90 days", "It gets followed up", "Day 1, 3, 7, 14, 30, 60 and 90. Long decisions don't go cold."),
            ("All year", "Old proposals come back", "Projects you bid and never closed, worked back into signed jobs."),
        ],
        "search": "kitchen remodel near me",
        "respond": "Every call, text and form answered in under 60 seconds, so you're the first bid they talk to, not the third.",
        "estimates": "remodel",
        "old": "proposals you never closed",
        "stat": ("$27,000", "is about what the average kitchen remodel costs. One revived proposal can pay for months of GRAIN.", "Angi, via NerdWallet, Jan 2026"),
        "software": "Buildertrend, JobTread, Houzz Pro and Jobber",
        "faq": [
            ("Our sales cycle is months long. Does this still work?", "That's where it helps most. Every proposal gets 90 days of follow-up, and if they say call me after the holidays, we call after the holidays."),
            ("Will it book design consults?", "Yes. It answers, asks the questions you'd ask, and puts the consult on your calendar."),
            ("Do you work with Buildertrend?", "Yes, and most other remodeling software. We'll check yours on the audit."),
        ],
    },
    {
        "slug": "painting", "who": "painters", "name": "Painting", "lower": "painting", "apply": "painting", "calc": "painting",
        "h1": ("More painting leads.", "Every estimate followed up."),
        "lede": "We get you found for interior and exterior jobs, answer every inquiry in under a minute, book the estimate, follow up every bid for 90 days and turn last year's unsold bids into this year's jobs. Done for you, live in 14 days.",
        "desc": "For Nashville painters: more leads from Google and reviews, every inquiry answered in under 60 seconds and booked, every bid followed up for 90 days, last year's unsold bids worked again. Done for you. $0 up front.",
        "night_h2": ("The spring bid rush,", "handled."),
        "night": [
            ("March", "Everyone wants a bid at once", "Exterior season is coming and your crews are already booked."),
            ("Same minute", "Every inquiry answered", "A text back and an estimate time, even while you're on a ladder."),
            ("That week", "You send the bid", "They're comparing you with two other painters."),
            ("Next 90 days", "Yours gets followed up", "Until it's a yes or a no."),
            ("Next spring", "Last year's bids come back", "Every exterior you quoted and didn't paint, worked again before the season."),
        ],
        "search": "house painters near me",
        "respond": "Every call, text and form answered in under 60 seconds, so the estimate gets booked before they call the next painter.",
        "estimates": "interior and exterior",
        "old": "bids you never painted",
        "stat": ("$3,177", "is the average cost to paint a house exterior.", "Angi, 2026 data"),
        "software": "Jobber, Housecall Pro, PaintScout and DripJobs",
        "faq": [
            ("We're booked solid in season. Why more leads?", "Booked solid is when bids go cold. We keep following up so next month and next season fill up too."),
            ("Do small interior jobs get the same treatment?", "Yes. Every inquiry gets answered and every estimate followed up, whatever the size."),
            ("Do I have to change software?", "Usually not. We work with Jobber, Housecall Pro and most others, and check yours on the audit."),
        ],
    },
    {
        "slug": "fencing", "who": "fence companies", "name": "Fencing", "lower": "fence", "apply": "fencing", "calc": "fencing",
        "h1": ("More fence leads.", "Every estimate followed up."),
        "lede": "We get you found when people search for a fence company, answer every call in under a minute, book the estimate, follow up while they wait on HOA approval and turn old bids into jobs. Done for you, live in 14 days.",
        "desc": "For Nashville fence companies: more leads from Google and reviews, every call answered in under 60 seconds and booked, every bid followed up through HOA approval, old bids turned into jobs. Done for you. $0 up front.",
        "night_h2": ("The HOA waiting game,", "handled."),
        "night": [
            ("Monday", "A homeowner wants a privacy fence", "They found you on Google and filled out the form."),
            ("Same minute", "Answered and booked", "An estimate on your calendar with the address and what they want."),
            ("That week", "You send the bid", "Then it waits on the HOA."),
            ("Next 90 days", "It gets followed up", "Our HOA meets in March gets a follow-up in March."),
            ("All year", "Old bids come back", "Fences you quoted and never built, worked into jobs."),
        ],
        "search": "fence company near me",
        "respond": "Every call, text and form answered in under 60 seconds, and the estimate booked before they call the next company on the list.",
        "estimates": "fence",
        "old": "fence bids you never built",
        "stat": ("$2,000&ndash;$5,000", "is what a typical fence job runs.", "NerdWallet"),
        "software": "Jobber, Housecall Pro and JobNimbus",
        "faq": [
            ("Our jobs wait on HOAs and permits. Does follow-up still help?", "That's when it helps most. The follow-up runs for 90 days and picks the date they give you, so the job doesn't slip away while it waits."),
            ("Do you do commercial fence leads too?", "Yes. Any lead that starts with a call, text or form gets the same answer and follow-up."),
            ("Do I have to change software?", "Usually not. We work with Jobber, Housecall Pro and most others, and check yours on the audit."),
        ],
    },
    {
        "slug": "pools", "who": "pool companies", "name": "Pools", "lower": "pool", "apply": "pools", "calc": "pool",
        "h1": ("More pool leads.", "Every one answered."),
        "lede": "We get you found for builds, service and repairs, answer every call in under a minute during the opening rush, book it, follow up every build and remodel quote for 90 days and turn old quotes into jobs. Done for you, live in 14 days.",
        "desc": "For Nashville pool companies: more leads from Google and reviews, every call answered in under 60 seconds through the opening rush, every build and remodel quote followed up, old quotes turned into jobs. Done for you. $0 up front.",
        "night_h2": ("The opening-season rush,", "handled."),
        "night": [
            ("April", "The phones don't stop", "Everyone wants their pool opened the same two weeks."),
            ("Every call", "Answered in under a minute", "Booked on your calendar with the pool and equipment details."),
            ("That week", "The remodel quote goes out", "New plaster, a heater and an automation system."),
            ("Next 90 days", "It gets followed up", "Until it's a yes or a no."),
            ("All year", "Old quotes come back", "Builds and remodels you quoted and never sold."),
        ],
        "search": "pool company near me",
        "respond": "Every call, text and form answered in under 60 seconds, even in the opening rush, with green-pool emergencies flagged for your team.",
        "estimates": "build, remodel and equipment",
        "old": "build and remodel quotes",
        "stat": ("$66,000", "is about what the average inground pool costs. One revived build quote can pay for a year of GRAIN.", "Angi, via NerdWallet"),
        "software": "Skimmer, Pool Brain, Jobber and Buildertrend",
        "faq": [
            ("We do service routes and builds. Does it handle both?", "Yes. Service calls get booked into your schedule, and build and remodel quotes get 90 days of follow-up."),
            ("What about the off-season?", "That's when old quotes get worked, so next season's builds are lined up before spring."),
            ("Do I have to change software?", "Usually not. We work with Skimmer, Jobber and most others, and check yours on the audit."),
        ],
    },
    {
        "slug": "landscaping", "who": "landscapers", "name": "Landscaping", "lower": "landscaping", "apply": "landscaping", "calc": "landscaping",
        "h1": ("More landscaping leads.", "Every one answered."),
        "lede": "We get you found for design, hardscape and maintenance, answer every call in under a minute during the spring rush, book the estimate, follow up every bid for 90 days and turn last season's bids into this season's jobs. Done for you, live in 14 days.",
        "desc": "For Nashville landscapers: more leads from Google and reviews, every call answered in under 60 seconds through the spring rush, every bid followed up for 90 days, last season's bids worked again. Done for you. $0 up front.",
        "night_h2": ("The first warm weekend,", "handled."),
        "night": [
            ("Saturday", "Twenty people want a quote", "The first warm weekend of spring, and your crews are out."),
            ("Every inquiry", "Answered in under a minute", "Calls, texts and forms, with an estimate on your calendar."),
            ("That week", "Your bid goes out", "A patio, new beds and a maintenance plan."),
            ("Next 90 days", "It gets followed up", "Until it's a yes or a no."),
            ("Next season", "Last year's bids come back", "Projects you quoted and didn't win, worked again before spring."),
        ],
        "search": "landscaping company near me",
        "respond": "Every call, text and form answered in under 60 seconds, even on the busiest Saturday in April.",
        "estimates": "design, hardscape and maintenance",
        "old": "bids you didn't win",
        "stat": ("$3,650", "is about what the average landscaping project costs.", "Angi, via NerdWallet, Feb 2026"),
        "software": "Aspire, LMN, Jobber and Service Autopilot",
        "faq": [
            ("We sell maintenance contracts and projects. Does it handle both?", "Yes. Maintenance inquiries get booked and followed up like any estimate, and so do design and hardscape bids."),
            ("Leads come in waves. Can it keep up?", "Yes. It answers 20 calls at once the same way it answers one."),
            ("Do I have to change software?", "Usually not. We work with Aspire, LMN, Jobber and most others, and check yours on the audit."),
        ],
    },
    {
        "slug": "garage-doors", "who": "garage door companies", "name": "Garage doors", "lower": "garage door", "apply": "garage-doors", "calc": "garage-doors",
        "h1": ("More garage door calls.", "Every one answered."),
        "lede": "We get you found when a spring snaps, answer every call in under a minute, book the same-day repair, follow up every new door quote for 90 days and turn old quotes into jobs. Done for you, live in 14 days.",
        "desc": "For Nashville garage door companies: more leads from Google and reviews, every call answered in under 60 seconds and booked, every new door quote followed up, old quotes turned into jobs. Done for you. $0 up front.",
        "night_h2": ("The 6 am broken spring,", "handled."),
        "night": [
            ("6:05 AM", "A homeowner calls", "The spring snapped and the car's stuck inside."),
            ("6:05 AM", "Answered in 8 seconds", "Booked for the first open slot, with the door details your tech needs."),
            ("Same day", "Your tech fixes it", "And quotes a new door while they're there."),
            ("Next 90 days", "The new door quote gets followed up", "Until it's a yes or a no."),
            ("All year", "Old quotes come back", "Doors and openers you quoted and never installed."),
        ],
        "search": "garage door repair near me",
        "respond": "Every call answered in under 60 seconds, so the same-day repair goes to you, not whoever answers next.",
        "estimates": "new door and opener",
        "old": "door and opener quotes",
        "stat": ("$250", "is the average cost to replace a garage door spring. The shop that answers first gets the job.", "Angi, 2026 data"),
        "software": "ServiceTitan, Housecall Pro and Jobber",
        "faq": [
            ("Most of our calls are same-day repairs. Does it book those?", "Yes. It books the first open slot and sends anything that can't wait to your on-call tech."),
            ("Do you handle commercial doors?", "Yes. Any lead that starts with a call, text or form gets the same answer and follow-up."),
            ("Do I have to change software?", "Usually not. We work with ServiceTitan, Housecall Pro, Jobber and most others, and check yours on the audit."),
        ],
    },
]


def esc(s):
    return html.escape(s, quote=True)


def page(t, shell_head, shell_foot):
    slug, name, lower = t["slug"], t["name"], t["lower"]
    url = f"{SITE}/home-services/{slug}"
    title = f"Lead generation and call answering for {t['who']} in Nashville | GRAIN Method"
    head = shell_head
    head = re.sub(r"<title>.*?</title>", lambda m: f"<title>{esc(title)}</title>", head, count=1)
    head = head.replace(head[head.index('<meta name="description" content="'):head.index('>', head.index('<meta name="description" content="')) + 1],
                        f'<meta name="description" content="{esc(t["desc"])}">')
    head = head.replace(head[head.index('<meta property="og:title" content="'):head.index('>', head.index('<meta property="og:title" content="')) + 1],
                        f'<meta property="og:title" content="{esc(title)}">')
    head = head.replace(head[head.index('<meta property="og:description" content="'):head.index('>', head.index('<meta property="og:description" content="')) + 1],
                        f'<meta property="og:description" content="{esc(t["desc"])}">')
    head = head.replace('<meta property="og:url" content="https://www.grainmethod.com/home-services">',
                        f'<meta property="og:url" content="{url}">\n  <link rel="canonical" href="{url}">')
    head = head.replace("window.location.href=BOOKING_URL||'/apply';", f"window.location.href=BOOKING_URL||'/apply?trade={t['apply']}';")
    faq_ld = {
        "@context": "https://schema.org",
        "@graph": [
            {"@type": "Service", "name": f"{name} lead generation, answering and follow-up", "provider": {"@type": "Organization", "name": "GRAIN Method", "url": SITE},
             "areaServed": "Nashville, Tennessee", "url": url, "description": t["desc"]},
            {"@type": "FAQPage", "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in t["faq"]]},
        ],
    }
    head = head.replace("</head>", '<script type="application/ld+json">' + json.dumps(faq_ld) + "</script>\n</head>", 1)

    night = "\n".join(f'      <li><span class="wwd-n">{esc(a)}</span><strong>{esc(b)}</strong><span>{esc(c)}</span></li>' for a, b, c in t["night"])
    stats = [t["stat"], STAT_UNANSWERED, STAT_SPEED, STAT_LSA]
    leak = "\n".join(f'      <div class="leak-cell"><div class="leak-num">{n}</div><div class="leak-text">{x}</div><div class="leak-src">{esc(s)}</div></div>' for n, x, s in stats)
    faq = t["faq"] + [("What does it cost?", "Greenhouse is $2,997 a month, with a founding rate of $1,497 a month through Dec 31, plus $1,500 setup and 10% of revived jobs. Nothing is due up front: setup and month one are charged the day it goes live.")]
    faq_html = "\n".join(f"      <li><strong>{esc(q)}</strong><span>{esc(a)}</span></li>" for q, a in faq)
    others = "\n".join(f'      <a class="trade-pill" href="/home-services/{o["slug"]}">{esc(o["name"])}</a>' for o in TRADES if o["slug"] != slug)

    body = f"""<!-- ===== PAGE HERO ===== -->
<section class="page-hero">
  <div class="page-hero-inner">
    <div class="eyebrow reveal" style="justify-content:center;">Home services · {esc(name)} · Nashville</div>
    <h1 class="h-section reveal" data-delay="1">{esc(t["h1"][0])}<br><span class="italic-accent">{esc(t["h1"][1])}</span></h1>
    <p class="lede reveal" data-delay="2" style="margin: 0 auto;">{esc(t["lede"])}</p>
    <div class="hs-ctas reveal" data-delay="3">
      <a class="btn btn-primary" href="/apply?trade={t["apply"]}">Apply for your free audit <span class="btn-arrow">→</span></a>
      <a class="btn btn-secondary" href="/calculator?trade={t["calc"]}">Run your numbers <span class="btn-arrow">→</span></a>
    </div>
  </div>
</section>

<!-- ===== EXAMPLE ===== -->
<section class="section wwd-section">
  <div class="wrap">
    <div class="eyebrow reveal">A day with GRAIN · example</div>
    <h2 class="h-section reveal" data-delay="1">{esc(t["night_h2"][0])}<br><span class="italic-accent">{esc(t["night_h2"][1])}</span></h2>
    <ol class="wwd-flow reveal" data-delay="2">
{night}
    </ol>
    <p class="wwd-foot reveal" data-delay="3">You see every call, booking and dollar in your <a class="wwd-link" href="/dashboard"><strong>Greenhouse Dashboard</strong></a>. You run the jobs. We run the rest.</p>
  </div>
</section>

<!-- ===== WHAT WE DO ===== -->
<section class="section ads-section">
  <div class="wrap">
    <div class="ads-inner">
      <div>
        <div class="eyebrow reveal">What we do for {esc(lower)} shops</div>
        <h2 class="h-section reveal" data-delay="1">Five engines.<br><span class="italic-accent">One system.</span></h2>
        <p class="ads-lede reveal" data-delay="2">More leads coming in, and every one answered, booked and followed up. Done for you, on the tools you already use.</p>
        <a class="ind-link reveal" data-delay="3" href="/method">See how it works</a>
      </div>
      <ul class="ads-list reveal" data-delay="2">
        <li><strong>Generate</strong>Found when someone searches &ldquo;{esc(t["search"])}&rdquo; or asks ChatGPT who to call, more 5-star reviews after every job, quote forms that turn your website visitors into leads, and ads if you want them.</li>
        <li><strong>Respond</strong>{esc(t["respond"])}</li>
        <li><strong>Automate</strong>Every {esc(t["estimates"])} estimate followed up for 90 days by text and email. &ldquo;Call me after the holidays&rdquo; gets a follow-up on that day.</li>
        <li><strong>Integrate</strong>Works with {esc(t["software"])}. Bookings go straight in where your software allows, and it all shows up in your Greenhouse Dashboard.</li>
        <li><strong>Nurture</strong>Two years of {esc(t["old"])} worked back into jobs, again every quarter. You pay 10% only on those jobs, once they're done and paid.</li>
      </ul>
    </div>
  </div>
</section>

<!-- ===== THE LEAK (sourced) ===== -->
<section class="section leak-section">
  <div class="wrap">
    <div class="eyebrow reveal">The leak</div>
    <h2 class="h-section reveal" data-delay="1">You're already paying for<br><span class="italic-accent">the jobs you lose.</span></h2>
    <div class="leak-grid reveal" data-delay="2">
{leak}
    </div>
    <p class="leak-close reveal" data-delay="3">GRAIN answers every one of those calls in under 60 seconds, follows up every estimate, and works the old ones nobody called back.</p>
  </div>
</section>

<!-- ===== WHERE WE WORK ===== -->
<section class="section trades-section">
  <div class="wrap">
    <div class="eyebrow reveal">Nashville and Middle Tennessee</div>
    <h2 class="h-section reveal" data-delay="1">One {esc(lower)} shop<br><span class="italic-accent">per area.</span></h2>
    <p class="trades-note reveal" data-delay="2">We work with {esc(lower)} shops in {AREAS}. We take one per service area, so we're never helping the shop down the street win the same Google spots.</p>
  </div>
</section>

<!-- ===== QUESTIONS ===== -->
<section class="section">
  <div class="wrap">
    <div class="eyebrow reveal">Questions owners ask</div>
    <h2 class="h-section reveal" data-delay="1">Straight answers.</h2>
    <ul class="hs-faq reveal" data-delay="2">
{faq_html}
    </ul>
  </div>
</section>

<!-- ===== OTHER TRADES ===== -->
<section class="section trades-section">
  <div class="wrap">
    <div class="eyebrow reveal">Other trades we work with</div>
    <div class="trades-grid reveal" data-delay="1">
{others}
    </div>
  </div>
</section>

<!-- ===== FINAL CTA ===== -->
<section class="cta-band-method">
  <div class="cta-band-method-inner">
    <div class="eyebrow reveal" style="justify-content:center;">Start here</div>
    <h2 class="h-section reveal" data-delay="1">
      See your <span class="italic-accent">real numbers.</span>
    </h2>
    <p class="reveal" data-delay="2">
      Thirty minutes with the founder. We'll show you how many people search for {esc(lower)} work near you, how many of your calls go unanswered and what your old estimates are worth. Free, whether you sign or not.
    </p>
    <a class="btn btn-primary reveal" data-delay="3" href="/apply?trade={t["apply"]}">
      Apply for your free audit <span class="btn-arrow">→</span>
    </a>
  </div>
</section>

"""
    return head + body + shell_foot


def main():
    src = (PUBLIC / "home-services.html").read_text()
    a = src.index("<!-- ===== PAGE HERO ===== -->")
    b = src.index("<!-- ===== FOOTER ===== -->")
    shell_head, shell_foot = src[:a], src[b:]
    out = PUBLIC / "home-services"
    out.mkdir(exist_ok=True)
    for t in TRADES:
        (out / f"{t['slug']}.html").write_text(page(t, shell_head, shell_foot))
    print(f"built {len(TRADES)} trade pages in {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
