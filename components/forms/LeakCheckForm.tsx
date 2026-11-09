"use client";

import Link from "next/link";
import { useState } from "react";
import { TRADES } from "@/content/offer";
import { SITE } from "@/content/site";
import { attribution } from "@/lib/attribution";

declare global {
  interface Window {
    gtag?: (...args: unknown[]) => void;
  }
}

export const SMS_CONSENT_TEXT =
  "Text me about my Leak Check. Message frequency varies. Message and data rates may apply. Reply STOP to opt out, HELP for help. Consent isn't required to get a Leak Check.";

type State = "idle" | "sending" | "sent" | "error";

export function LeakCheckForm({ compact = false }: { compact?: boolean }) {
  const [state, setState] = useState<State>("idle");
  const [error, setError] = useState("");

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const data: Record<string, unknown> = Object.fromEntries(fd.entries());
    data.sms_consent = fd.get("sms_consent") === "on";
    if (data.sms_consent) data.sms_consent_text = SMS_CONSENT_TEXT;
    setState("sending");
    setError("");
    try {
      const res = await fetch("/api/leads", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...data, kind: "leak_check", ...attribution() }),
      });
      const json = await res.json().catch(() => ({}));
      if (!res.ok || !json.ok) {
        throw new Error(json.error || `That didn't send. Try again, or email ${SITE.email}.`);
      }
      setState("sent");
      window.gtag?.("event", "generate_lead", { form: "leak_check", compact });
    } catch (err) {
      setState("error");
      setError((err as Error).message);
    }
  }

  if (state === "sent") {
    return (
      <div role="status" className="py-2">
        <p className="font-display text-[2rem] leading-tight">You&apos;re on the list.</p>
        <p className="mt-3 max-w-md text-ink-soft">
          Johnny will reach out within one business day to set up your Leak Check. Before the call, we&apos;ll run
          your shop&apos;s After-Hours Test.
        </p>
        {SITE.bookingUrl && (
          <a className="btn btn-ink mt-6" href={SITE.bookingUrl}>
            Pick a time now
          </a>
        )}
        <p className="mt-5 text-[0.92rem] text-muted">
          Questions before then? <a className="link" href={`mailto:${SITE.email}`}>{SITE.email}</a>
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} className="relative">
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="field">
          <span>Your name</span>
          <input className="input" name="name" autoComplete="name" required maxLength={120} />
        </label>
        <label className="field">
          <span>Shop name</span>
          <input className="input" name="shop" autoComplete="organization" required maxLength={160} />
        </label>
        <label className="field">
          <span>Mobile phone</span>
          <input className="input" name="phone" type="tel" inputMode="tel" autoComplete="tel" required maxLength={40} />
        </label>
        <label className="field">
          <span>
            Email {compact && <small>(optional)</small>}
          </span>
          <input className="input" name="email" type="email" autoComplete="email" required={!compact} maxLength={200} />
        </label>
        <label className="field">
          <span>Trade</span>
          <select className="input" name="trade" required defaultValue="">
            <option value="" disabled>
              Pick one
            </option>
            {TRADES.map((t) => (
              <option key={t}>{t}</option>
            ))}
            <option>Other</option>
          </select>
        </label>
        <label className="field">
          <span>
            Where you work {compact && <small>(optional)</small>}
          </span>
          <input className="input" name="area" placeholder="Nashville and Franklin" required={!compact} maxLength={160} />
        </label>
      </div>

      {!compact && (
        <>
          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            <label className="field">
              <span>
                Unsold estimates, last 24 months <small>(a guess is fine)</small>
              </span>
              <select className="input" name="estimates_band" defaultValue="">
                <option value="">Not sure</option>
                <option>Under $500K</option>
                <option>$500K to $1.5M</option>
                <option>$1.5M to $3M</option>
                <option>$3M to $5M</option>
                <option>Over $5M</option>
              </select>
            </label>
            <label className="field">
              <span>
                Job software <small>(optional)</small>
              </span>
              <input className="input" name="software" placeholder="What you write estimates in" maxLength={120} />
            </label>
            <label className="field">
              <span>
                Website <small>(optional)</small>
              </span>
              <input className="input" name="website" inputMode="url" placeholder="yourshop.com" maxLength={300} />
            </label>
            <label className="field">
              <span>
                Best time to talk <small>(optional)</small>
              </span>
              <select className="input" name="best_time" defaultValue="">
                <option value="">Anytime</option>
                <option>Mornings</option>
                <option>Afternoons</option>
                <option>Evenings</option>
              </select>
            </label>
          </div>
          <label className="field mt-4">
            <span>
              Anything we should know? <small>(optional)</small>
            </span>
            <textarea className="input min-h-28" name="message" maxLength={2000} />
          </label>
        </>
      )}

      <label className="mt-5 flex gap-3 text-[0.85rem] leading-relaxed text-ink-soft">
        <input type="checkbox" name="sms_consent" className="mt-1 h-4 w-4 shrink-0 accent-moss-ink" />
        <span>
          {SMS_CONSENT_TEXT} See our{" "}
          <Link className="link font-medium" href="/sms-terms">
            SMS terms
          </Link>{" "}
          and{" "}
          <Link className="link font-medium" href="/privacy">
            Privacy policy
          </Link>
          .
        </span>
      </label>

      <div aria-hidden="true" className="absolute -left-[9999px] h-px w-px overflow-hidden">
        <label>
          Leave this empty
          <input type="text" name="company_site" tabIndex={-1} autoComplete="off" />
        </label>
      </div>

      <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-5">
        <button type="submit" className="btn btn-ink" disabled={state === "sending"}>
          {state === "sending" ? "Sending..." : "Get my free Leak Check"}
        </button>
        <p className="text-[0.9rem] text-muted">We&apos;ll reach out within one business day.</p>
      </div>
      {state === "error" && (
        <p role="alert" className="mt-4 rounded-lg bg-rust/10 px-4 py-3 text-[0.95rem] text-rust">
          {error}
        </p>
      )}
    </form>
  );
}
