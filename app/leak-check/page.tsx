import { LeakCheckForm } from "@/components/forms/LeakCheckForm";
import { SITE } from "@/content/site";
import { pageMeta } from "@/lib/meta";

export const metadata = pageMeta(
  "/leak-check",
  "Free Leak Check",
  "30 minutes with Johnny. See how fast your shop answers, how your estimates get followed up and what your unsold estimates are worth."
);

const GET = [
  "Your After-Hours Test result. We call your shop after hours, the way a homeowner would, before the call.",
  "How fast your shop answers, and where estimate follow-up stops.",
  "Your revival number: what your unsold estimates from the last 24 months add up to.",
  "A straight answer on whether GRAIN fits your shop. If it doesn't, we'll tell you.",
];

const NEXT = [
  "Johnny reaches out within one business day to set a time.",
  "We run your shop's After-Hours Test.",
  "A 30-minute call. You keep the numbers whether you hire us or not.",
];

export default function LeakCheck() {
  return (
    <section className="py-14 sm:py-20">
      <div className="wrap grid items-start gap-12 lg:grid-cols-12 lg:gap-x-10 lg:gap-y-12">
        <div className="lg:col-span-5 lg:row-start-1">
          <h1 className="max-w-[12ch] text-[clamp(2.5rem,1.4rem+3.8vw,4.4rem)] leading-[1.02] tracking-[-0.022em]">
            Get your free Leak Check
          </h1>
          <p className="mt-6 max-w-md text-lede text-ink-soft">
            30 minutes with Johnny. You&apos;ll see how fast your shop answers, how your estimates get followed up and
            what your unsold estimates are worth.
          </p>
        </div>

        <div className="lg:sticky lg:top-24 lg:col-span-7 lg:col-start-6 lg:row-span-2 lg:row-start-1">
          <div className="slip px-6 py-7 sm:px-9 sm:py-9">
            <LeakCheckForm />
          </div>
          <p className="mt-4 text-[0.95rem] text-muted">
            Rather email? <a className="link" href={`mailto:${SITE.email}`}>{SITE.email}</a>
          </p>
        </div>

        <div className="lg:col-span-5 lg:row-start-2">
          <h2 className="text-h3">What you&apos;ll get</h2>
          <ul className="mt-4 divide-y divide-line border-y border-line">
            {GET.map((g) => (
              <li key={g} className="py-3.5 text-ink-soft">
                {g}
              </li>
            ))}
          </ul>

          <h2 className="mt-12 text-h3">What happens next</h2>
          <ol className="mt-4 space-y-4">
            {NEXT.map((n, i) => (
              <li key={n} className="flex gap-4 text-ink-soft">
                <span className="font-display text-[1.6rem] leading-none text-ink">{i + 1}</span>
                <span className="pt-0.5">{n}</span>
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}
