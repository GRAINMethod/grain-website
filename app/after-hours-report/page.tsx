import { CtaBand } from "@/components/blocks/Common";
import { ReportForm } from "@/components/forms/ReportForm";
import { pageMeta } from "@/lib/meta";

export const metadata = pageMeta(
  "/after-hours-report",
  "The Nashville After-Hours Report",
  "We're calling 50 Nashville home service shops after hours and writing down what happens. Get the report, and your own shop's result."
);

const TRACK = [
  { q: "Did anyone pick up?", a: "A person, an answering service, a voice agent, or nobody." },
  { q: "How long did it take?", a: "Seconds from the first ring to a real answer." },
  { q: "Could you leave a message?", a: "Voicemail, a full mailbox, or no way to leave one." },
  { q: "Did anyone get back to you?", a: "A call or text back, and how long it took." },
  { q: "Could you book?", a: "Whether a homeowner with a problem could get on the calendar that night." },
];

export default function AfterHoursReport() {
  return (
    <>
      <section className="py-14 sm:py-20">
        <div className="wrap grid items-start gap-14 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-6">
            <h1 className="max-w-[14ch] text-[clamp(2.5rem,1.4rem+3.8vw,4.4rem)] leading-[1.02] tracking-[-0.022em]">
              The Nashville After-Hours Report
            </h1>
            <p className="mt-6 max-w-lg text-lede text-ink-soft">
              We&apos;re calling 50 Nashville home service shops after hours, the way a homeowner with a problem would,
              and writing down what happens. The report comes out in early December.
            </p>
            <p className="mt-4 max-w-lg text-ink-soft">
              Shops aren&apos;t named in the public report. Any shop can get its own result.
            </p>
          </div>
          <div className="lg:col-span-6">
            <div className="slip px-6 py-7 sm:px-9 sm:py-9">
              <h2 className="text-h3">Get the report, and your own result</h2>
              <p className="mt-2 mb-6 text-ink-soft">Free. We email it when it&apos;s out.</p>
              <ReportForm />
            </div>
          </div>
        </div>
      </section>

      <section className="border-t border-line bg-paper/70 py-20 sm:py-24">
        <div className="wrap grid gap-12 lg:grid-cols-12 lg:gap-10">
          <div className="lg:col-span-5">
            <h2 className="max-w-[12ch] text-h2">What we write down on every call</h2>
          </div>
          <dl className="divide-y divide-line border-y border-line lg:col-span-7">
            {TRACK.map((t) => (
              <div key={t.q} className="py-5">
                <dt className="text-h3">{t.q}</dt>
                <dd className="mt-1.5 text-ink-soft">{t.a}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>

      <CtaBand
        title="Don't want to wait for the report?"
        body="The Leak Check includes your shop's After-Hours Test, plus what your old estimates are worth."
      />
    </>
  );
}
