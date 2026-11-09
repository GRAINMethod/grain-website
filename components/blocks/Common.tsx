import Link from "next/link";
import type { Faq } from "@/content/faq";

export function FaqList({ items }: { items: Faq[] }) {
  return (
    <div className="divide-y divide-line border-y border-line">
      {items.map((f) => (
        <details key={f.q} className="faq">
          <summary className="flex items-start justify-between gap-6 py-5 font-display text-[1.3rem] leading-snug font-[520] text-ink">
            <span>{f.q}</span>
            <span className="sign mt-0.5 font-sans text-[1.6rem] leading-none font-light text-moss-ink" aria-hidden="true">
              +
            </span>
          </summary>
          <div className="max-w-2xl pr-10 pb-6 text-ink-soft">
            <p>{f.a}</p>
            {f.link && (
              <Link className="link mt-3 inline-block" href={f.link.href}>
                {f.link.label}
              </Link>
            )}
          </div>
        </details>
      ))}
    </div>
  );
}

export function PageHeader({
  title,
  lede,
  children,
}: {
  title: string;
  lede?: string;
  children?: React.ReactNode;
}) {
  return (
    <section className="border-b border-line">
      <div className="wrap pt-14 pb-14 sm:pt-20 sm:pb-20">
        <h1 className="max-w-[17ch] text-[clamp(2.5rem,1.4rem+3.8vw,4.6rem)] leading-[1.02] tracking-[-0.022em]">
          {title}
        </h1>
        {lede && <p className="mt-6 max-w-2xl text-lede text-ink-soft">{lede}</p>}
        {children}
      </div>
    </section>
  );
}

export function CtaBand({
  title = "Find your leak. It's free.",
  body = "30 minutes with Johnny. You keep the numbers whether you hire us or not.",
}: {
  title?: string;
  body?: string;
}) {
  return (
    <section className="on-ink bg-ink text-cream">
      <div className="wrap flex flex-col gap-8 py-16 sm:py-20 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <h2 className="max-w-[16ch] text-h2">{title}</h2>
          <p className="mt-5 max-w-xl text-lede text-cream/75">{body}</p>
        </div>
        <Link href="/leak-check" className="btn btn-moss shrink-0">
          Get my free Leak Check
        </Link>
      </div>
    </section>
  );
}

const LOG = [
  { t: "8:47 pm", kind: "Call", stat: "Answered in 0:31", note: "No heat. Booked Wed 8:00 am." },
  { t: "9:12 pm", kind: "Text", stat: "Answered in 0:44", note: "Water heater question. Sent to the office for the morning." },
  { t: "10:05 pm", kind: "Call", stat: "Answered in 0:22", note: "Furnace noise. Booked Thu 1:00 pm." },
  { t: "7:30 am", kind: "Follow-up", stat: "Estimate No. 2462", note: "Heat pump, $9,850. Homeowner replied: “Can you come Friday?”" },
  { t: "11:00 am", kind: "Revival", stat: "Estimate No. 2301", note: "Ductwork, $4,800, from January. Booked a second look." },
];

/* What a live night and morning looks like, as a call log. Labeled as an example. */
export function CallLog() {
  return (
    <figure>
      <div className="slip overflow-hidden">
        <div className="flex items-center justify-between border-b border-line px-5 py-3.5 sm:px-6">
          <p className="font-display text-[1.15rem]">Your shop, one night and morning</p>
          <p className="typed text-[0.75rem] text-muted">GRAIN log</p>
        </div>
        <ol className="divide-y divide-line/80">
          {LOG.map((r) => (
            <li key={r.t} className="grid grid-cols-[4.6rem_1fr] gap-x-4 gap-y-1 px-5 py-4 sm:grid-cols-[5rem_6.5rem_1fr] sm:px-6">
              <span className="typed text-[0.85rem] text-muted">{r.t}</span>
              <span className="text-[0.92rem] font-semibold">{r.kind}</span>
              <span className="col-start-2 sm:col-start-3">
                <span className="typed block text-[0.8rem] text-moss-ink">{r.stat}</span>
                <span className="block text-[0.95rem] text-ink-soft">{r.note}</span>
              </span>
            </li>
          ))}
        </ol>
      </div>
      <figcaption className="mt-3 text-[0.9rem] text-muted">Example log. Not real customers.</figcaption>
    </figure>
  );
}
