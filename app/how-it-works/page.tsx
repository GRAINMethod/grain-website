import Link from "next/link";
import { CallLog, CtaBand, PageHeader } from "@/components/blocks/Common";
import { pageMeta } from "@/lib/meta";

export const metadata = pageMeta(
  "/how-it-works",
  "How it works",
  "From a free Leak Check to live in 14 days: every step, what we do and what we need from you."
);

const LOOK = [
  "Your After-Hours Test: we call your shop after hours, the way a homeowner would, before the Leak Check.",
  "How fast calls, texts and web leads get answered today.",
  "How estimates get followed up, and where they stop.",
  "How many estimates went unsold in the last 24 months, and what they add up to.",
  "The phone and job software you use, so we know what we connect to.",
];

const BUILD = [
  { day: "You sign", title: "$0 due", body: "Pick a kickoff time. Nothing is charged until you're live." },
  {
    day: "Day 1",
    title: "Kickoff, 60 minutes",
    body: "Within 3 business days of signing. We go through your services, prices, service area, calendar and how you want calls handled. The same day, you export 24 months of estimates and we freeze the list the 10% runs on.",
  },
  {
    day: "Days 2 to 9",
    title: "We build it",
    body: "Answering, booking, estimate follow-up and the revival campaign, set up around your shop. You don't have to touch any of it.",
  },
  { day: "By day 10", title: "Call forwarding on", body: "We walk you through it with your phone provider. It takes a few minutes." },
  {
    day: "Days 10 to 13",
    title: "Test calls",
    body: "You listen to the test calls and approve them within 48 hours. Nothing goes live until you do.",
  },
  { day: "Day 14", title: "Live", body: "Calls and texts are answered and booked. $2,997 is charged: your setup plus the first month." },
];

const RUNS = [
  { title: "Calls and texts answered", body: "In under a minute, day and night. 99% of calls inside 60 seconds every month, or that month is free." },
  { title: "Jobs booked", body: "Straight onto your calendar, with the details your tech needs." },
  { title: "Estimates followed up", body: "By text and email until the homeowner gives you a yes or a no." },
  { title: "Old estimates worked", body: "The frozen list from day 1, worked as a revival campaign. Revived appointments land on your calendar." },
];

const AFTER = [
  {
    day: "Every month",
    title: "Report and reconciliation call",
    body: "Calls answered and how fast, jobs booked, estimates followed up, and old estimates revived with what they paid. On the call, we match it against your job software.",
  },
  {
    day: "Day 60",
    title: "Review",
    body: "What's working and what's next. If you want more calls, we can talk about running your Google ads.",
  },
  {
    day: "Day 90",
    title: "Payback check",
    body: "If you qualify and revived jobs haven't covered what you've paid, your monthly pauses until they do. From here you're month to month with 30 days' notice.",
  },
];

const NEED = [
  "One 60-minute kickoff",
  "24 months of estimates exported on day 1",
  "Call forwarding on by day 10",
  "Test calls approved within 48 hours",
  "Revived appointments run within 2 business days",
  "Jobs marked completed and paid in your job software",
  "30 minutes a month for the reconciliation call",
];

function Timeline({ items }: { items: { day: string; title: string; body: string }[] }) {
  return (
    <ol className="border-l-2 border-ink/15">
      {items.map((i) => (
        <li key={i.day + i.title} className="relative pb-9 pl-7 last:pb-0 sm:pl-9">
          <span className="absolute top-[0.45rem] -left-[7px] h-3 w-3 rounded-full border-2 border-cream bg-moss-ink" aria-hidden="true" />
          <p className="typed text-[0.85rem] text-moss-ink">{i.day}</p>
          <h3 className="mt-1 text-h3">{i.title}</h3>
          <p className="mt-2 max-w-xl text-ink-soft">{i.body}</p>
        </li>
      ))}
    </ol>
  );
}

export default function HowItWorks() {
  return (
    <>
      <PageHeader
        title="How GRAIN works"
        lede="From a free Leak Check to live in 14 days. Here's every step, what we do and what we need from you."
      />

      <section className="py-20 sm:py-24">
        <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-5">
            <p className="font-display text-[3.4rem] leading-none font-[420]">1</p>
            <h2 className="mt-4 text-h2">Leak Check</h2>
            <p className="typed mt-3 text-[0.9rem] text-moss-ink">Free, 30 minutes</p>
            <p className="mt-6 max-w-md text-lede text-ink-soft">
              We find where your shop loses jobs and count what your old estimates are worth. You keep the numbers
              whether you hire us or not.
            </p>
            <Link href="/leak-check" className="btn btn-ink mt-8">
              Get my free Leak Check
            </Link>
          </div>
          <div className="lg:col-span-7">
            <h3 className="text-h3">What we look at</h3>
            <ul className="mt-5 divide-y divide-line border-y border-line">
              {LOOK.map((l) => (
                <li key={l} className="py-4 text-ink-soft">
                  {l}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      <section className="border-y border-line bg-paper/70 py-20 sm:py-24">
        <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-5">
            <p className="font-display text-[3.4rem] leading-none font-[420]">2</p>
            <h2 className="mt-4 text-h2">Build</h2>
            <p className="typed mt-3 text-[0.9rem] text-moss-ink">14 days</p>
            <p className="mt-6 max-w-md text-lede text-ink-soft">
              Live in 14 days or month 1 is free. You approve the test calls before anything goes live.
            </p>
            <Link href="/guarantees#start" className="link mt-6 inline-block">
              Read the Start Guarantee
            </Link>
          </div>
          <div className="lg:col-span-7">
            <Timeline items={BUILD} />
          </div>
        </div>
      </section>

      <section className="py-20 sm:py-24">
        <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-5">
            <p className="font-display text-[3.4rem] leading-none font-[420]">3</p>
            <h2 className="mt-4 text-h2">Live</h2>
            <p className="typed mt-3 text-[0.9rem] text-moss-ink">Day 14 on</p>
            <ul className="mt-8 space-y-6">
              {RUNS.map((r) => (
                <li key={r.title}>
                  <h3 className="text-[1.2rem] font-[560]">{r.title}</h3>
                  <p className="mt-1.5 max-w-md text-ink-soft">{r.body}</p>
                </li>
              ))}
            </ul>
          </div>
          <div className="lg:col-span-7 lg:pt-24">
            <CallLog />
          </div>
        </div>
      </section>

      <section className="border-t border-line py-20 sm:py-24">
        <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-5">
            <h2 className="max-w-[12ch] text-h2">After you&apos;re live</h2>
            <p className="mt-6 max-w-md text-lede text-ink-soft">
              One report and one call a month, so you always know what GRAIN brought in.
            </p>
          </div>
          <div className="lg:col-span-7">
            <Timeline items={AFTER} />
          </div>
        </div>
      </section>

      <section className="border-t border-line bg-paper/70 py-20 sm:py-24">
        <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-5">
            <h2 className="max-w-[12ch] text-h2">What we need from you</h2>
            <p className="mt-6 max-w-md text-lede text-ink-soft">
              About two hours in the first two weeks, then 30 minutes a month.
            </p>
          </div>
          <ul className="grid gap-x-8 sm:grid-cols-2 lg:col-span-7">
            {NEED.map((n) => (
              <li key={n} className="flex gap-3 border-b border-line py-4 text-ink-soft">
                <span className="mt-[0.55rem] h-2 w-2 shrink-0 rounded-full bg-moss-ink" aria-hidden="true" />
                {n}
              </li>
            ))}
          </ul>
        </div>
      </section>

      <CtaBand />
    </>
  );
}
