"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { Logo } from "./Logo";
import { NAV_LINKS, SITE } from "@/content/site";

export function Nav() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 4);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  useEffect(() => {
    document.body.style.overflow = open ? "hidden" : "";
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  return (
    <header
      data-solid={scrolled || open}
      className="sticky top-0 z-50 border-b border-transparent bg-cream/85 backdrop-blur-md transition-colors data-[solid=true]:border-line data-[solid=true]:bg-cream/95"
    >
      <div className="wrap flex h-16 items-center justify-between gap-4">
        <Link href="/" className="flex shrink-0 items-center gap-2.5" aria-label="GRAIN Method, home">
          <Logo className="h-8 w-8" />
          <span className="wordmark">GRAIN</span>
        </Link>

        <nav aria-label="Main" className="hidden lg:block">
          <ul className="flex items-center gap-7 text-[0.95rem] font-medium text-ink-soft">
            {NAV_LINKS.map((l) => (
              <li key={l.href}>
                <Link
                  href={l.href}
                  aria-current={pathname === l.href ? "page" : undefined}
                  className="decoration-moss-ink decoration-2 underline-offset-[6px] hover:text-ink aria-[current=page]:text-ink aria-[current=page]:underline"
                >
                  {l.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>

        <div className="flex items-center gap-2">
          <Link href="/leak-check" className="btn btn-ink px-3.5 py-2.5 text-[0.9rem] whitespace-nowrap sm:px-4 sm:text-[0.95rem]">
            <span className="sm:hidden">Free Leak Check</span>
            <span className="hidden sm:inline">Get my free Leak Check</span>
          </Link>
          <button
            type="button"
            className="rounded-full px-3 py-2.5 text-[0.95rem] font-semibold text-ink hover:bg-ink/5 lg:hidden"
            aria-expanded={open}
            aria-controls="mobile-menu"
            onClick={() => setOpen((o) => !o)}
          >
            {open ? "Close" : "Menu"}
          </button>
        </div>
      </div>

      {open && (
        <div id="mobile-menu" className="h-[calc(100dvh-4rem)] overflow-y-auto border-t border-line bg-cream lg:hidden">
          <nav aria-label="Mobile" className="wrap flex min-h-full flex-col py-6">
            <ul className="divide-y divide-line">
              <li>
                <Link href="/" className="block py-3.5 font-display text-[1.75rem] leading-tight">Home</Link>
              </li>
              {NAV_LINKS.map((l) => (
                <li key={l.href}>
                  <Link href={l.href} className="block py-3.5 font-display text-[1.75rem] leading-tight">
                    {l.label}
                  </Link>
                </li>
              ))}
              <li>
                <Link href="/after-hours-report" className="block py-3.5 font-display text-[1.75rem] leading-tight">
                  After-Hours Report
                </Link>
              </li>
            </ul>
            <Link href="/leak-check" className="btn btn-ink mt-8 w-full">
              Get my free Leak Check
            </Link>
            <p className="mt-5 text-[0.95rem] text-muted">
              Or email <a className="link" href={`mailto:${SITE.email}`}>{SITE.email}</a>
            </p>
          </nav>
        </div>
      )}
    </header>
  );
}
