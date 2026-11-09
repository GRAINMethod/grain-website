import { CtaBand, PageHeader } from "@/components/blocks/Common";
import { GuaranteeRows } from "@/components/blocks/GuaranteeRows";
import { SITE } from "@/content/site";
import { pageMeta } from "@/lib/meta";

export const metadata = pageMeta(
  "/guarantees",
  "Guarantees",
  "The Start Guarantee, the call promise and the Payback Guarantee: what each one promises, what it needs from you and what happens if we miss."
);

const TERMS = [
  {
    id: "start-terms",
    name: "Start Guarantee",
    rows: [
      ["What it promises", "$0 until it's live. Live within 14 days of kickoff, or month 1 ($1,497) is free."],
      ["What “live” means", "Your calls and texts are answered and booked by GRAIN, and estimate follow-up is running."],
      ["When the clock starts", "At kickoff, which happens within 3 business days of signing. Day 1 is kickoff day."],
      ["What it needs", "24 months of estimates exported on day 1, call forwarding on by day 10, and test calls approved within 48 hours."],
      ["What pauses the clock", "A late input from your side. The clock pauses day for day until we have it."],
      ["Billing", "$0 at signing. $2,997 at go-live: the $1,500 setup plus the first month."],
    ],
  },
  {
    id: "calls-terms",
    name: "Call promise",
    rows: [
      ["What it promises", "At least 99% of calls answered within 60 seconds every month, day and night, or that month's fee is free."],
      ["How it's measured", "Every call forwarded to GRAIN in the calendar month. A call counts as answered when GRAIN picks up within 60 seconds."],
      ["What it needs", "Call forwarding stays on."],
      ["Who it covers", "Every client, from the day you go live."],
    ],
  },
  {
    id: "payback-terms",
    name: "Payback Guarantee",
    rows: [
      ["Who qualifies", "Shops with $1.5M or more in unsold estimates from the last 24 months, counted from the day-1 export."],
      ["What counts as a revived job", "A job from the frozen day-1 list that's booked within 90 days and marked completed and paid in your job software."],
      ["What “everything you've paid” means", "Your setup, your monthly fees and the 10% revival share."],
      ["Day 90", "If revived jobs haven't covered everything you've paid, your monthly pauses until they do."],
      ["Day 180", "If they still haven't, we refund the difference."],
      ["What it needs", "Revived appointments run within 2 business days, jobs marked completed and paid in your job software, and the monthly reconciliation call."],
    ],
  },
];

export default function Guarantees() {
  return (
    <>
      <PageHeader
        title="Three guarantees, in plain English"
        lede="Each promise, what it needs from you and what happens if we miss. Your service agreement carries the same terms."
      />

      <section className="on-ink bg-ink py-16 text-cream sm:py-20">
        <div className="wrap">
          <GuaranteeRows withIds />
        </div>
      </section>

      <section className="py-20 sm:py-24">
        <div className="wrap">
          <h2 className="max-w-[16ch] text-h2">The full terms</h2>
          <div className="mt-12 grid gap-14">
            {TERMS.map((t) => (
              <div key={t.id} id={t.id} className="grid gap-6 lg:grid-cols-12 lg:gap-10">
                <h3 className="text-h3 lg:col-span-4">{t.name}</h3>
                <dl className="divide-y divide-line border-y border-line lg:col-span-8">
                  {t.rows.map(([k, v]) => (
                    <div key={k} className="grid gap-1.5 py-4 sm:grid-cols-[13rem_1fr] sm:gap-6">
                      <dt className="font-semibold text-ink">{k}</dt>
                      <dd className="text-ink-soft">{v}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="border-t border-line bg-paper/70 py-20 sm:py-24">
        <div className="wrap grid gap-10 md:grid-cols-3">
          <div>
            <h3 className="text-h3">How you get it</h3>
            <p className="mt-3 text-ink-soft">
              We track all three on your monthly report. When one applies, it shows up on your next bill. If you think
              we missed one, email <a className="link" href={`mailto:${SITE.email}`}>{SITE.email}</a>.
            </p>
          </div>
          <div>
            <h3 className="text-h3">What we don&apos;t promise</h3>
            <p className="mt-3 text-ink-soft">
              A set number of jobs, a close rate or a Google ranking. Nobody can promise those honestly.
            </p>
          </div>
          <div>
            <h3 className="text-h3">The final word</h3>
            <p className="mt-3 text-ink-soft">
              Your service agreement. If this page and your agreement ever differ, the agreement wins.
            </p>
          </div>
        </div>
      </section>

      <CtaBand title="See if your shop qualifies." body="The Leak Check counts your unsold estimates, so you'll know which guarantees cover you before you sign." />
    </>
  );
}
