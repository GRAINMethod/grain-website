import Link from "next/link";
import { CtaBand, FaqList, PageHeader } from "@/components/blocks/Common";
import { GrainEstimate } from "@/components/blocks/GrainEstimate";
import { RevivalTape } from "@/components/blocks/RevivalTape";
import { FAQS } from "@/content/faq";
import { pageMeta } from "@/lib/meta";

export const metadata = pageMeta(
  "/pricing",
  "Pricing",
  "Founding price: $1,500 setup, $1,497 a month and 10% of revived jobs, only on jobs completed and paid. $0 until it's live."
);

const INCLUDED = [
  "Calls and texts answered in under a minute, day and night",
  "Jobs booked on your calendar",
  "Estimate follow-up by text and email until it's a yes or a no",
  "Your last 24 months of unsold estimates worked as a revival campaign",
  "Connected to your phone line and job software",
  "Setup, scripts and tuning, done for you",
  "A monthly report and a reconciliation call",
  "The Start Guarantee, the call promise and, if you qualify, the Payback Guarantee",
];

const BILLING = [
  { when: "When you sign", what: "$0" },
  { when: "When you go live", what: "$2,997: the $1,500 setup plus your first month" },
  { when: "Each month after", what: "$1,497, plus 10% of revived jobs completed and paid that month" },
  { when: "After 90 days", what: "Month to month with 30 days' notice" },
];

const PRICE_FAQS = FAQS.filter((f) =>
  ["How does the 10% work?", "How long is the contract?", "Do you run ads?", "What if it doesn't work?"].includes(f.q)
);

export default function Pricing() {
  return (
    <>
      <PageHeader
        title="One price. $0 until it's live."
        lede="Founding price for the first 5 shops, through December 31, 2026. After that, the monthly goes to $2,997 for new shops."
      />

      <section className="py-20 sm:py-24">
        <div className="wrap grid items-start gap-14 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-7">
            <GrainEstimate />
          </div>
          <div className="lg:col-span-5">
            <h2 className="text-h3">What&apos;s included</h2>
            <ul className="mt-5 divide-y divide-line border-y border-line">
              {INCLUDED.map((i) => (
                <li key={i} className="flex gap-3 py-3.5 text-ink-soft">
                  <span className="mt-[0.55rem] h-2 w-2 shrink-0 rounded-full bg-moss-ink" aria-hidden="true" />
                  {i}
                </li>
              ))}
            </ul>
            <Link href="/leak-check" className="btn btn-ink mt-8">
              Get my free Leak Check
            </Link>
          </div>
        </div>
      </section>

      <section className="border-y border-line bg-paper/70 py-20 sm:py-24">
        <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-5">
            <h2 className="max-w-[12ch] text-h2">How billing works</h2>
            <p className="mt-6 max-w-md text-lede text-ink-soft">Card or ACH on file. Nothing is charged before go-live.</p>
          </div>
          <dl className="divide-y divide-line border-y border-line lg:col-span-7">
            {BILLING.map((b) => (
              <div key={b.when} className="grid gap-1 py-4 sm:grid-cols-[11rem_1fr] sm:gap-6">
                <dt className="typed text-[0.9rem] text-moss-ink">{b.when}</dt>
                <dd className="text-ink">{b.what}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>

      <section className="py-20 sm:py-24">
        <div className="wrap grid gap-12 md:grid-cols-3">
          <div>
            <h2 className="text-h3">The 10%</h2>
            <p className="mt-3 text-ink-soft">
              On day 1 we freeze the list of your unsold estimates. When one turns into a job that&apos;s booked within
              90 days and completed and paid, we get 10% of that job. No cap, and nothing on new calls.
            </p>
          </div>
          <div>
            <h2 className="text-h3">Founding terms</h2>
            <p className="mt-3 text-ink-soft">
              The first 5 shops, through Dec 31, get this price. In return, a founding shop gives us a case study, a
              testimonial, logo rights and 2 reference calls. After 5 case studies, new shops pay $2,997 a month, same
              10%.
            </p>
          </div>
          <div>
            <h2 className="text-h3">Later, if you want more calls</h2>
            <p className="mt-3 text-ink-soft">
              We fix the leak first. At the day-60 review we can take over your Google ads for $750 a month or 15% of
              ad spend, whichever is higher. You pay Google directly. Reviews and local search help are available once
              you&apos;re live.
            </p>
          </div>
        </div>
      </section>

      <section id="math" className="border-t border-line py-20 sm:py-24">
        <div className="wrap grid items-center gap-14 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-6">
            <h2 className="max-w-[14ch] text-h2">What your old estimates could be worth</h2>
            <p className="mt-6 max-w-lg text-lede text-ink-soft">
              An example at 0.5%, not a promise. Your real number comes from your own estimates on the Leak Check.
            </p>
          </div>
          <div className="lg:col-span-6">
            <RevivalTape />
          </div>
        </div>
      </section>

      <section className="border-t border-line py-20 sm:py-24">
        <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
          <h2 className="max-w-[10ch] text-h2 lg:col-span-4">Price questions</h2>
          <div className="lg:col-span-8">
            <FaqList items={PRICE_FAQS} />
          </div>
        </div>
      </section>

      <CtaBand />
    </>
  );
}
