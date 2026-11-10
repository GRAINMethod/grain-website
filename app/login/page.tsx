"use client";

import { useEffect, useState } from "react";
import { browserClient } from "@/lib/supabase";
import "./login.css";

/** The greenhouse mark from grainmethod.com. `grow` animates the sprout in. */
function Mark({ size, grow }: { size: number; grow?: boolean }) {
  return (
    <svg className={grow ? "gl-mark grow" : "gl-mark"} width={size} height={size} viewBox="0 0 400 400" aria-hidden="true">
      <g transform="translate(90,75)">
        <path className="gl-house" d="M 110 10 L 210 90 L 210 230 L 10 230 L 10 90 Z" stroke="#F0ECDF" fill="none" strokeWidth="18" strokeLinejoin="miter" />
        <g transform="translate(110,230)">
          <path className="gl-stem" d="M 0 0 L 0 -115" stroke="#9AAF7A" strokeWidth="7" fill="none" strokeLinecap="round" />
          <path className="gl-leaf l1" d="M -2 -55 Q -32 -68 -42 -55 Q -36 -42 -2 -48 Z" fill="#BFD0A2" />
          <path className="gl-leaf l2" d="M 2 -80 Q 34 -93 44 -80 Q 38 -67 2 -73 Z" fill="#BFD0A2" />
          <path className="gl-leaf l3" d="M -1 -115 Q -18 -128 -22 -118 Q -14 -108 -1 -110 Z" fill="#BFD0A2" />
          <path className="gl-leaf l4" d="M 1 -115 Q 18 -128 22 -118 Q 14 -108 1 -110 Z" fill="#BFD0A2" />
          <path d="M -32 0 Q 0 -14 32 0 Z" fill="#F0ECDF" />
        </g>
      </g>
    </svg>
  );
}

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [state, setState] = useState<"idle" | "sending" | "sent" | "checking" | "nomatch">("checking");
  const [error, setError] = useState("");

  useEffect(() => {
    const sb = browserClient();
    let done = false;
    const route = async () => {
      if (done) return;
      const { data } = await sb.auth.getSession();
      if (!data.session) { setState((s) => (s === "checking" ? "idle" : s)); return; }
      done = true;
      const next = new URLSearchParams(window.location.search).get("next");
      const { data: who } = await sb.rpc("whoami");
      const orgs: string[] = who?.orgs ?? [];
      const wanted = next && next.startsWith("/dashboard?org=") ? next.slice("/dashboard?org=".length).split("&")[0] : null;
      if (who?.staff) window.location.replace(wanted ? `/dashboard?org=${wanted}` : "/hq");
      else if (wanted && orgs.includes(wanted)) window.location.replace(`/dashboard?org=${wanted}`);
      else if (orgs.length) window.location.replace(`/dashboard?org=${orgs[0]}`);
      else setState("nomatch");
    };
    const { data: sub } = sb.auth.onAuthStateChange(() => { void route(); });
    void route();
    return () => sub.subscription.unsubscribe();
  }, []);

  async function send(e: React.FormEvent) {
    e.preventDefault();
    setError(""); setState("sending");
    const next = new URLSearchParams(window.location.search).get("next");
    const { error: err } = await browserClient().auth.signInWithOtp({
      email: email.trim(),
      options: { emailRedirectTo: `${window.location.origin}/login${next ? `?next=${encodeURIComponent(next)}` : ""}` },
    });
    if (err) { setError("That didn't send. Check the address and try again in a minute."); setState("idle"); }
    else setState("sent");
  }

  return (
    <main className="gl">
      <div className="gl-grid" aria-hidden="true" />
      <div className="gl-glow" aria-hidden="true" />

      <section className="gl-brand">
        <a className="gl-logo" href="/" aria-label="GRAIN Method home">
          <Mark size={44} />
          <span>GRAIN</span>
        </a>
        <div className="gl-hero">
          <Mark size={168} grow />
          <p className="gl-eyebrow">The Greenhouse</p>
          <h2>Every lead, <em>planted.</em></h2>
          <ul className="gl-lines">
            <li><b>60s</b>Every call, text and form answered</li>
            <li><b>90d</b>Every estimate followed up</li>
            <li><b>24/7</b>Booked straight onto the calendar</li>
          </ul>
        </div>
        <p className="gl-foot">PLANT · NURTURE · SCALE</p>
      </section>

      <section className="gl-panel">
        <div className="gl-card">
          <p className="gl-eyebrow">Client and team sign-in</p>
          <h1>Sign <em>in.</em></h1>
          {state === "checking" && <p className="gl-muted">One second.</p>}
          {state === "sent" && (
            <div className="gl-sent">
              <p className="gl-sent-t">Check your inbox.</p>
              <p>We sent a sign-in link to <b>{email}</b>. Open it on this device.</p>
              <button className="gl-link" onClick={() => setState("idle")}>Use a different email</button>
            </div>
          )}
          {state === "nomatch" && (
            <>
              <p>You&apos;re signed in, but this email isn&apos;t linked to a GRAIN account yet. Text Johnny and he&apos;ll connect it.</p>
              <button className="gl-btn ghost" onClick={async () => { await browserClient().auth.signOut(); setState("idle"); }}>Use a different email</button>
            </>
          )}
          {(state === "idle" || state === "sending") && (
            <form onSubmit={send} className="gl-form">
              <label htmlFor="email">Work email</label>
              <input id="email" type="email" required autoComplete="email" inputMode="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@company.com" />
              <button className="gl-btn" disabled={state === "sending"}>{state === "sending" ? "Sending" : "Email me a sign-in link"} <span aria-hidden="true">→</span></button>
              {error && <p className="gl-error">{error}</p>}
              <p className="gl-muted">No password. The link signs you in.</p>
            </form>
          )}
        </div>
        <p className="gl-help">Not a client yet? <a href="/apply">Apply for your free audit</a></p>
      </section>
    </main>
  );
}
