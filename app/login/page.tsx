"use client";

import { useEffect, useState } from "react";
import { browserClient } from "@/lib/supabase";

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
    <main className="hq hq-login">
      <a className="hq-brand" href="/">GRAIN</a>
      <h1>Sign <em>in.</em></h1>
      {state === "checking" && <p className="hq-muted">One second.</p>}
      {state === "sent" && <p>Check {email} for a sign-in link. Open it on this device.</p>}
      {state === "nomatch" && (
        <>
          <p>You&apos;re signed in, but this email isn&apos;t linked to a GRAIN account yet. Text Johnny and he&apos;ll connect it.</p>
          <button className="hq-btn ghost" onClick={async () => { await browserClient().auth.signOut(); setState("idle"); }}>Use a different email</button>
        </>
      )}
      {(state === "idle" || state === "sending") && (
        <form onSubmit={send} className="hq-form">
          <label htmlFor="email">Email</label>
          <input id="email" type="email" required autoComplete="email" inputMode="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@company.com" />
          <button className="hq-btn" disabled={state === "sending"}>{state === "sending" ? "Sending" : "Email me a sign-in link"}</button>
          {error && <p className="hq-error">{error}</p>}
          <p className="hq-muted">No password. The link signs you in.</p>
        </form>
      )}
    </main>
  );
}
