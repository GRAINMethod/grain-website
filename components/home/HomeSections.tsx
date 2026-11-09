import Link from "next/link";
import { GuaranteeRows } from "@/components/blocks/GuaranteeRows";
import { RevivalTape } from "@/components/blocks/RevivalTape";
import { GrainEstimate } from "@/components/blocks/GrainEstimate";
import { FaqList } from "@/components/blocks/Common";
import { LeakCheckForm } from "@/components/forms/LeakCheckForm";
import { Logo } from "@/components/site/Logo";
import { STEPS, TRADES } from "@/content/offer";
import { FAQS } from "@/content/faq";
import { SITE } from "@/content/site";

const LEAKS = [
  {
    title: "Calls nobody picks up",
    body: "Nights, weekends, lunch, or the office is already on the phone. A homeowner with no heat calls the next shop on the list.",
    log: ["9:14 pm", "Missed call", "No answer"],
  },
  {
    title: "Estimates nobody chases",
    body: "You send the quote and wait. One follow-up, maybe two. Then it goes quiet and somebody else does the job.",
    log: ["Mar 14", "Estimate sent", "No reply"],
  },
  {
    title: "Old estimates in the drawer",
    body: "Two years of quotes that never closed. Those homeowners still need the work, and nobody has asked them again.",
    log: ["24 months", "Unsold estimates", "Never asked again"],
  },
];

export function LeakSection() {
  return (
    <section id="leak" className="py-20 sm:py-28">
      <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
        <div className="lg:col-span-5">
          <h2 className="max-w-[13ch] text-h2">You&apos;re already paying for the jobs you lose.</h2>
          <p className="mt-6 max-w-md text-lede text-ink-soft">
            Your ads, your trucks and your name on the yard signs make the phone ring. The money leaks after that, in
            three places.
          </p>
          <Link href="/leak-check" className="link mt-8 inline-block">
            Find your leak with a free Leak Check
          </Link>
        </div>
        <ul className="divide-y divide-line border-y border-line lg:col-span-7">
          {LEAKS.map((l) => (
            <li key={l.title} className="grid gap-4 py-8 sm:grid-cols-[1fr_auto] sm:gap-10">
              <div>
                <h3 className="text-h3">{l.title}</h3>
                <p className="mt-2.5 max-w-md text-ink-soft">{l.body}</p>
              </div>
              <p className="typed flex gap-3 self-start rounded-md bg-paper px-3.5 py-2.5 text-[0.8rem] whitespace-nowrap shadow-[0_0_0_1px_rgba(28,36,32,.07)] sm:flex-col sm:gap-1 sm:text-right">
                <span className="text-muted">{l.log[0]}</span>
                <span>{l.log[1]}</span>
                <span className="text-rust">{l.log[2]}</span>
              </p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

export function StepsSection() {
  return (
    <section id="how" className="border-y border-line bg-paper/70 py-20 sm:py-28">
      <div className="wrap">
        <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <h2 className="max-w-[17ch] text-h2">Live in 14 days. You approve every test call first.</h2>
          <Link href="/how-it-works" className="link shrink-0">
            See the day-by-day plan
          </Link>
        </div>
        <ol className="mt-14 grid gap-12 md:grid-cols-3 md:gap-8">
          {STEPS.map((s, i) => (
            <li key={s.name} className="border-t-2 border-ink pt-6">
              <div className="flex items-baseline justify-between gap-4">
                <span className="font-display text-[3.4rem] leading-none font-[420]">{i + 1}</span>
                <span className="typed text-[0.85rem] text-moss-ink">{s.when}</span>
              </div>
              <h3 className="mt-5 text-h3">{s.name}</h3>
              <p className="mt-3 text-ink-soft">{s.body}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}

export function GuaranteesSection() {
  return (
    <section id="guarantees" className="on-ink bg-ink py-20 text-cream sm:py-28">
      <div className="wrap">
        <div className="grid gap-6 lg:grid-cols-12 lg:items-end">
          <h2 className="max-w-[15ch] text-h2 lg:col-span-7">Three guarantees, with the conditions right beside them.</h2>
          <p className="max-w-md text-lede text-cream/75 lg:col-span-5">
            No asterisks. Here&apos;s what we promise and what we need from you to keep it.
          </p>
        </div>
        <div className="mt-14">
          <GuaranteeRows />
        </div>
        <div className="mt-10 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <Link href="/guarantees" className="link">
            Read the full guarantee terms
          </Link>
          <p className="text-[0.95rem] text-cream/60">We don&apos;t promise a number of jobs or a Google ranking.</p>
        </div>
      </div>
    </section>
  );
}

export function MathSection() {
  return (
    <section id="math" className="py-20 sm:py-28">
      <div className="wrap grid items-center gap-14 lg:grid-cols-12 lg:gap-10">
        <div className="lg:col-span-6">
          <h2 className="max-w-[14ch] text-h2">What your old estimates could be worth</h2>
          <p className="mt-6 max-w-lg text-lede text-ink-soft">
            Slide to your shop&apos;s rough number. $1.5M in old estimates at 0.5% is $7,500 back.
          </p>
          <p className="mt-4 max-w-lg text-ink-soft">
            The 0.5% is an example rate, not a promise. Your real number comes from your own estimates on the Leak
            Check.
          </p>
          <Link href="/leak-check" className="link mt-8 inline-block">
            Get your real number
          </Link>
        </div>
        <div className="lg:col-span-6">
          <RevivalTape />
        </div>
      </div>
    </section>
  );
}

export function PriceSection() {
  return (
    <section id="price" className="border-t border-line py-20 sm:py-28">
      <div className="wrap grid items-start gap-14 lg:grid-cols-12 lg:gap-10">
        <div className="lg:sticky lg:top-36 lg:col-span-5">
          <h2 className="max-w-[12ch] text-h2">One price. $0 until it&apos;s live.</h2>
          <p className="mt-6 max-w-md text-lede text-ink-soft">
            Founding price for the first 5 shops, through Dec 31. After that, the monthly goes to $2,997 for new
            shops.
          </p>
          <ul className="mt-8 max-w-md space-y-3 text-ink-soft">
            <li className="border-l-2 border-moss pl-4">Nothing is due until your calls are live.</li>
            <li className="border-l-2 border-moss pl-4">The 10% is only on old estimates that turn into paid jobs.</li>
            <li className="border-l-2 border-moss pl-4">90 days, then month to month.</li>
          </ul>
          <Link href="/pricing" className="link mt-8 inline-block">
            See what&apos;s included
          </Link>
        </div>
        <div className="lg:col-span-7">
          <GrainEstimate />
        </div>
      </div>
    </section>
  );
}

export function WhoSection() {
  return (
    <section id="who" className="border-t border-line py-20 sm:py-28">
      <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
        <div className="lg:col-span-5">
          <h2 className="max-w-[12ch] text-h2">Built for shops that write estimates</h2>
          <p className="mt-6 max-w-md text-lede text-ink-soft">
            Home service shops doing $1M to $10M a year, where most jobs start with a quote.
          </p>
          <Link href="/about#who" className="link mt-8 inline-block">
            More on who we work with
          </Link>
        </div>
        <div className="lg:col-span-7">
          <ul className="grid grid-cols-2 gap-x-8 border-t border-line">
            {TRADES.map((t) => (
              <li key={t} className="border-b border-line py-3.5 font-display text-[clamp(1.15rem,1rem+0.6vw,1.45rem)]">
                {t}
              </li>
            ))}
          </ul>
          <div className="mt-10 grid gap-8 sm:grid-cols-2">
            <p className="text-ink-soft">
              <strong className="block font-semibold text-ink">One shop per trade per area.</strong>
              Once we work with you, we won&apos;t work with the shop down the street.
            </p>
            <p className="text-ink-soft">
              <strong className="block font-semibold text-ink">Under $1.5M in unsold estimates?</strong>
              You still get the Start Guarantee and the call promise. The Payback Guarantee starts at $1.5M.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}

export function ProofSection() {
  const items = [
    {
      title: "The After-Hours Test",
      body: "We call your shop after hours, the way a homeowner would, and send you what happened. Free.",
      href: "/after-hours-report",
      cta: "Get your shop tested",
    },
    {
      title: "Your own numbers",
      body: "The Leak Check shows how fast your shop answers and what your unsold estimates are worth.",
      href: "/leak-check",
      cta: "Get a Leak Check",
    },
    {
      title: "The founder, directly",
      body: "Johnny answers his own email. Ask him anything before you sign.",
      href: `mailto:${SITE.email}`,
      cta: SITE.email,
    },
  ];
  return (
    <section id="proof" className="border-y border-line bg-paper/70 py-20 sm:py-28">
      <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
        <div className="lg:col-span-5">
          <h2 className="max-w-[12ch] text-h2">We&apos;re new. So we prove it before you pay.</h2>
          <p className="mt-6 max-w-md text-lede text-ink-soft">
            No made-up reviews or fake live counters. When we have results, they&apos;ll be here with the owner&apos;s
            written permission.
          </p>
        </div>
        <ul className="divide-y divide-line border-y border-line lg:col-span-7">
          {items.map((i) => (
            <li key={i.title} className="py-8">
              <h3 className="text-h3">{i.title}</h3>
              <p className="mt-2.5 max-w-lg text-ink-soft">{i.body}</p>
              {i.href.startsWith("mailto:") ? (
                <a href={i.href} className="link mt-4 inline-block">
                  {i.cta}
                </a>
              ) : (
                <Link href={i.href} className="link mt-4 inline-block">
                  {i.cta}
                </Link>
              )}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

/* Johnny's business card. A headshot can sit beside it once there is one. */
export function FounderCard() {
  return (
    <div className="mx-auto w-full max-w-[400px] py-4 lg:mx-0">
      <div className="slip flex aspect-[1.75/1] -rotate-2 flex-col justify-between p-6 sm:p-7">
        <div className="flex items-start justify-between gap-4">
          <span className="flex items-center gap-2">
            <Logo className="h-7 w-7" />
            <span className="wordmark text-[0.95rem]">GRAIN</span>
          </span>
          <span className="pt-1 text-[0.56rem] font-semibold tracking-[0.18em] text-muted">{SITE.tagline}</span>
        </div>
        <div>
          <p className="font-display text-[1.75rem] leading-tight">{SITE.founder}</p>
          <p className="text-[0.92rem] text-ink-soft">Founder</p>
          <p className="typed mt-3 text-[0.78rem] leading-relaxed text-ink-soft">
            {SITE.email}
            <br />
            Nashville, Tennessee
          </p>
        </div>
      </div>
    </div>
  );
}

export function AboutSection() {
  return (
    <section id="about" className="py-20 sm:py-28">
      <div className="wrap grid items-center gap-12 lg:grid-cols-12 lg:gap-10">
        <div className="lg:col-span-4">
          <FounderCard />
        </div>
        <div className="lg:col-span-8">
          <h2 className="max-w-[16ch] text-h2">Run by Johnny Dibb, here in Nashville</h2>
          <p className="mt-6 max-w-2xl text-lede text-ink-soft">
            Before GRAIN, Johnny sold advertising to home service shops at Nextdoor. Good marketing makes the phone
            ring. Whether the shop gets paid depends on what happens after it rings.
          </p>
          <blockquote className="mt-10 max-w-2xl border-l-4 border-moss pl-6">
            <p className="font-display text-[clamp(1.35rem,1.1rem+0.9vw,1.85rem)] leading-snug">
              “Your marketing brings the calls. I make sure every one gets answered and booked, every estimate gets
              followed up, and your old estimates turn into jobs. Done for you, here in Nashville.”
            </p>
            <footer className="mt-4 text-[0.95rem] text-muted">Johnny Dibb, founder</footer>
          </blockquote>
          <Link href="/about" className="link mt-8 inline-block">
            More about GRAIN
          </Link>
        </div>
      </div>
    </section>
  );
}

export function FaqSection() {
  return (
    <section id="faq" className="border-t border-line py-20 sm:py-28">
      <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
        <div className="lg:col-span-4">
          <h2 className="max-w-[10ch] text-h2">Questions owners ask</h2>
          <Link href="/faq" className="link mt-8 inline-block">
            See all {FAQS.length} questions
          </Link>
        </div>
        <div className="lg:col-span-8">
          <FaqList items={FAQS.slice(0, 5)} />
        </div>
      </div>
    </section>
  );
}

export function StartSection() {
  return (
    <section id="start" className="on-ink bg-ink py-20 text-cream sm:py-28">
      <div className="wrap grid items-start gap-12 lg:grid-cols-12 lg:gap-10">
        <div className="lg:col-span-5">
          <h2 className="max-w-[11ch] text-h2">Find your leak. It&apos;s free.</h2>
          <p className="mt-6 max-w-md text-lede text-cream/80">
            30 minutes with Johnny. You&apos;ll see how fast your shop answers, how your estimates get followed up and
            what your unsold estimates are worth.
          </p>
          <p className="mt-4 max-w-md text-cream/70">You keep the numbers whether you hire us or not.</p>
          <p className="mt-8 text-cream/70">
            Rather email? <a className="link" href={`mailto:${SITE.email}`}>{SITE.email}</a>
          </p>
        </div>
        <div className="lg:col-span-7">
          <div className="on-paper rounded-[22px] bg-paper p-6 text-ink sm:p-9">
            <LeakCheckForm compact />
          </div>
        </div>
      </div>
    </section>
  );
}
