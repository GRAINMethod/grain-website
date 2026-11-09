import Link from "next/link";
import { Logo } from "./Logo";
import { SITE } from "@/content/site";

const COLS = [
  {
    title: "How GRAIN works",
    links: [
      { href: "/how-it-works", label: "How it works" },
      { href: "/guarantees", label: "Guarantees" },
      { href: "/pricing", label: "Pricing" },
      { href: "/faq", label: "FAQ" },
    ],
  },
  {
    title: "Start here",
    links: [
      { href: "/leak-check", label: "Free Leak Check" },
      { href: "/after-hours-report", label: "After-Hours Report" },
      { href: "/about", label: "About GRAIN" },
    ],
  },
  {
    title: "Fine print",
    links: [
      { href: "/privacy", label: "Privacy" },
      { href: "/terms", label: "Terms" },
      { href: "/sms-terms", label: "SMS terms" },
    ],
  },
];

export function Footer() {
  return (
    <footer className="border-t border-line">
      <div className="wrap grid gap-10 py-14 md:grid-cols-[1.5fr_1fr_1fr_1fr]">
        <div className="max-w-xs">
          <Link href="/" className="flex items-center gap-2.5" aria-label="GRAIN Method, home">
            <Logo className="h-9 w-9" />
            <span className="wordmark">GRAIN</span>
          </Link>
          <p className="mt-3 text-[0.7rem] font-semibold tracking-[0.18em] text-muted">{SITE.tagline}</p>
          <p className="mt-5 text-[0.95rem] text-ink-soft">
            Calls answered, jobs booked and old estimates turned back into work for home service shops.
          </p>
          <p className="mt-4 text-[0.95rem]">
            <a className="link" href={`mailto:${SITE.email}`}>{SITE.email}</a>
          </p>
        </div>
        {COLS.map((c) => (
          <div key={c.title}>
            <h2 className="font-sans text-[0.95rem] font-semibold text-ink">{c.title}</h2>
            <ul className="mt-4 space-y-2.5 text-[0.95rem] text-ink-soft">
              {c.links.map((l) => (
                <li key={l.href}>
                  <Link href={l.href} className="hover:text-ink hover:underline">
                    {l.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="border-t border-line">
        <div className="wrap flex flex-col gap-2 py-6 text-sm text-muted sm:flex-row sm:items-center sm:justify-between">
          <p>© 2026 {SITE.legalName}. {SITE.city}.</p>
          <p>Examples on this site are labeled. They are illustrations, not results.</p>
        </div>
      </div>
    </footer>
  );
}
