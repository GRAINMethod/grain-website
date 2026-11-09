import { CtaBand, PageHeader } from "@/components/blocks/Common";
import { FounderCard } from "@/components/home/HomeSections";
import { TRADES } from "@/content/offer";
import { pageMeta } from "@/lib/meta";

export const metadata = pageMeta(
  "/about",
  "About GRAIN",
  "GRAIN is run by Johnny Dibb in Nashville. We answer calls, book jobs and turn old estimates back into work for home service shops."
);

const WAYS = [
  {
    title: "One shop per trade per area",
    body: "We won't work for the shop down the street. Your setup, your scripts and your results stay yours.",
  },
  {
    title: "No made-up numbers",
    body: "Examples on this site are labeled as examples. Results show up only with the owner's written permission.",
  },
  {
    title: "Conditions next to every promise",
    body: "If a guarantee needs something from you, it says so right beside it.",
  },
  {
    title: "Fix the leak first",
    body: "More leads only help once the ones you have get answered. Ads come later, if you want them.",
  },
];

export default function About() {
  return (
    <>
      <PageHeader
        title="About GRAIN"
        lede="GRAIN is run by Johnny Dibb in Nashville. We answer calls, book jobs and turn old estimates back into work for home service shops."
      />

      <section className="py-20 sm:py-24">
        <div className="wrap grid items-start gap-12 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-5">
            <FounderCard />
          </div>
          <div className="space-y-5 text-[1.1rem] text-ink-soft lg:col-span-7">
            <p>
              I&apos;m Johnny Dibb. Before GRAIN, I sold advertising to home service shops at Nextdoor. Good marketing
              makes the phone ring. What happens after it rings decides whether the shop gets paid.
            </p>
            <p>
              So GRAIN works on what happens after: your calls answered and booked, your estimates followed up, and the
              old estimates in your drawer turned back into jobs. It&apos;s done for you, and it&apos;s run here in
              Nashville.
            </p>
            <p>You&apos;ll deal with me directly. If something isn&apos;t working, you&apos;ll hear it from me first.</p>
            <p className="pt-2 font-display text-[1.4rem] text-ink">Johnny Dibb, founder</p>
          </div>
        </div>
      </section>

      <section className="border-y border-line bg-paper/70 py-20 sm:py-24">
        <div className="wrap">
          <h2 className="max-w-[14ch] text-h2">How we work</h2>
          <div className="mt-12 grid gap-10 sm:grid-cols-2">
            {WAYS.map((w) => (
              <div key={w.title} className="border-t-2 border-ink pt-5">
                <h3 className="text-h3">{w.title}</h3>
                <p className="mt-2.5 max-w-md text-ink-soft">{w.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section id="who" className="py-20 sm:py-24">
        <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-5">
            <h2 className="max-w-[12ch] text-h2">Who we work with</h2>
            <p className="mt-6 max-w-md text-lede text-ink-soft">
              Home service shops doing $1M to $10M a year, where most jobs start with a quote. Based in Nashville,
              working with shops across the US.
            </p>
          </div>
          <div className="lg:col-span-7">
            <ul className="grid grid-cols-2 gap-x-8 border-t border-line">
              {TRADES.map((t) => (
                <li key={t} className="border-b border-line py-3.5 font-display text-[clamp(1.15rem,1rem+0.6vw,1.45rem)]">
                  {t}
                </li>
              ))}
            </ul>
            <p className="mt-8 max-w-xl text-ink-soft">
              The Payback Guarantee needs $1.5M or more in unsold estimates from the last 24 months. Shops below that
              still get the Start Guarantee and the call promise.
            </p>
          </div>
        </div>
      </section>

      <CtaBand />
    </>
  );
}
