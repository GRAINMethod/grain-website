"use client";

import { useState } from "react";
import { SITE } from "@/content/site";
import { attribution } from "@/lib/attribution";

type State = "idle" | "sending" | "sent" | "error";

export function ReportForm() {
  const [state, setState] = useState<State>("idle");
  const [error, setError] = useState("");
  const [wantsTest, setWantsTest] = useState(true);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const data: Record<string, unknown> = Object.fromEntries(fd.entries());
    data.wants_test = fd.get("wants_test") === "on";
    setState("sending");
    setError("");
    try {
      const res = await fetch("/api/leads", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...data, kind: "after_hours_report", ...attribution() }),
      });
      const json = await res.json().catch(() => ({}));
      if (!res.ok || !json.ok) throw new Error(json.error || `That didn't send. Try again, or email ${SITE.email}.`);
      setState("sent");
      window.gtag?.("event", "generate_lead", { form: "after_hours_report" });
    } catch (err) {
      setState("error");
      setError((err as Error).message);
    }
  }

  if (state === "sent") {
    return (
      <div role="status">
        <p className="font-display text-[2rem] leading-tight">You&apos;re on the list.</p>
        <p className="mt-3 max-w-md text-ink-soft">
          The report goes to your inbox when it&apos;s out.
          {wantsTest && " We'll also call your shop after hours and email you what happened."}
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} className="relative">
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="field sm:col-span-2">
          <span>Email</span>
          <input className="input" name="email" type="email" autoComplete="email" required maxLength={200} />
        </label>
        <label className="field">
          <span>
            Shop name <small>(optional)</small>
          </span>
          <input className="input" name="shop" autoComplete="organization" maxLength={160} />
        </label>
        <label className="field">
          <span>
            Shop phone <small>(the number customers call)</small>
          </span>
          <input className="input" name="shop_phone" type="tel" inputMode="tel" maxLength={40} />
        </label>
      </div>
      <label className="mt-5 flex gap-3 text-[0.95rem] text-ink-soft">
        <input
          type="checkbox"
          name="wants_test"
          checked={wantsTest}
          onChange={(e) => setWantsTest(e.target.checked)}
          className="mt-1 h-4 w-4 shrink-0 accent-moss-ink"
        />
        <span>Test my shop too, and email me what happened.</span>
      </label>
      <div aria-hidden="true" className="absolute -left-[9999px] h-px w-px overflow-hidden">
        <input type="text" name="company_site" tabIndex={-1} autoComplete="off" />
      </div>
      <button type="submit" className="btn btn-ink mt-6" disabled={state === "sending"}>
        {state === "sending" ? "Sending..." : "Send me the report"}
      </button>
      {state === "error" && (
        <p role="alert" className="mt-4 rounded-lg bg-rust/10 px-4 py-3 text-[0.95rem] text-rust">
          {error}
        </p>
      )}
    </form>
  );
}
