"use client";

/*
  GRAIN HQ: the morning cockpit. Staff only.
  Everything here runs as the signed-in user. The database decides what they can see and do
  (row level security plus staff-checked functions), so there is no secret key in this app.
*/
import { useCallback, useEffect, useState } from "react";
import { browserClient } from "@/lib/supabase";

/* eslint-disable @typescript-eslint/no-explicit-any */
type Row = Record<string, any>;

const STAGES = ["sourced", "qualified", "contacted", "conversation", "audit_booked", "audit_held", "proposal", "won", "lost", "nurture"];
const TRADES = ["hvac", "plumbing", "roofing", "electrical", "remodeling", "painting", "fencing", "pools", "landscaping", "garage_doors", "health_fitness", "real_estate", "auto", "tech", "other"];
const CHANNELS = ["call", "sms", "email", "linkedin", "loom", "in_person", "after_hours_test"];
const OUTCOMES = ["no_answer", "voicemail", "conversation", "audit_booked", "follow_up", "not_interested"];
const TABS = ["Today", "Pipeline", "Clients", "Updates", "System"] as const;

const nice = (s?: string | null) => (s ? s.replace(/_/g, " ") : "");
const when = (t?: string | null) =>
  t ? new Date(t).toLocaleString("en-US", { timeZone: "America/Chicago", month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }) : "";
const day = (t?: string | null) => (t ? new Date(t).toLocaleDateString("en-US", { timeZone: "America/Chicago", month: "short", day: "numeric" }) : "");
const money = (n?: number | null) => "$" + Math.round(Number(n ?? 0)).toLocaleString("en-US");
const pct = (r?: number | null) => (r == null ? "none yet" : (Number(r) * 100).toFixed(1) + "%");

export default function HQ() {
  const sb = browserClient();
  const [phase, setPhase] = useState<"loading" | "ready" | "denied" | "setup">("loading");
  const [d, setD] = useState<Row | null>(null);
  const [tab, setTab] = useState<(typeof TABS)[number]>("Today");
  const [msg, setMsg] = useState("");
  const [uid, setUid] = useState<string | null>(null);

  const load = useCallback(async () => {
    const { data: s } = await sb.auth.getSession();
    if (!s.session) { window.location.replace("/login"); return; }
    setUid(s.session.user.id);
    const { data, error } = await sb.rpc("hq_overview");
    if (error) { setPhase(error.code === "42501" ? "denied" : "setup"); return; }
    setD(data); setPhase("ready");
  }, [sb]);

  useEffect(() => { void load(); }, [load]);

  /** Run one change, show what happened, reload the numbers. */
  const run = async (label: string, fn: () => PromiseLike<{ error: any }>) => {
    setMsg("");
    const { error } = await fn();
    setMsg(error ? `${label} did not save: ${error.message}` : `${label} saved.`);
    await load();
  };

  if (phase === "loading") return <main className="hq"><p className="hq-muted">Loading HQ.</p></main>;
  if (phase === "denied" || phase === "setup")
    return (
      <main className="hq hq-login">
        <a className="hq-brand" href="/">GRAIN</a>
        <h1>{phase === "denied" ? <>Not on the <em>staff list.</em></> : <>Almost <em>ready.</em></>}</h1>
        <p>{phase === "denied"
          ? "This email is signed in but is not on the GRAIN staff list."
          : "HQ is built, but the database functions behind it are not switched on yet."}</p>
        <button className="hq-btn ghost" onClick={async () => { await sb.auth.signOut(); window.location.replace("/login"); }}>Sign out</button>
      </main>
    );

  const o = d as Row;
  const wk = o.week as Row;
  const goal = o.goal as Row;
  const prospects = (o.prospects ?? []) as Row[];
  const clients = (o.clients ?? []) as Row[];
  const callFirst = prospects.filter((p) => !p.disqualified_reason && p.stage !== "nurture").slice(0, 8);

  return (
    <main className="hq">
      <header className="hq-top">
        <a className="hq-brand" href="/">GRAIN <span>HQ</span></a>
        <span className="hq-top-right">
          <span className="hq-date">{new Date(o.now).toLocaleDateString("en-US", { timeZone: "America/Chicago", weekday: "long", month: "short", day: "numeric" })}</span>
          <button className="hq-signout" onClick={async () => { await sb.auth.signOut(); window.location.replace("/login"); }}>Sign out</button>
        </span>
      </header>

      <section className="hq-score">
        <Meter label="Touches this week" n={wk.touches} lo={40} hi={60} />
        <Meter label="Owner conversations" n={wk.conversations} lo={8} hi={12} />
        <Meter label="Audits held" n={wk.audits_held} lo={2} hi={3} />
        <Meter label="Clients live" n={goal.clients_live} lo={5} hi={5} note="goal: 5 by Dec 31" />
      </section>

      <nav className="hq-tabs">
        {TABS.map((t) => <button key={t} className={t === tab ? "on" : ""} onClick={() => setTab(t)}>{t}</button>)}
      </nav>
      {msg && <p className={msg.includes("did not") ? "hq-error" : "hq-ok"}>{msg}</p>}

      {tab === "Today" && (
        <>
          <Card title="Due today" count={o.tasks.length}>
            {o.tasks.length === 0 && <p className="hq-muted">Nothing due. Go make calls.</p>}
            {o.tasks.map((t: Row) => (
              <label key={t.id} className={"hq-check" + (t.overdue ? " late" : "")}>
                <input type="checkbox" onChange={() => run("Task", () => sb.from("ops_tasks").update({ done_at: new Date().toISOString() }).eq("id", t.id))} />
                <span>{t.title}{t.org ? ` · ${t.org}` : ""}<small>{t.due_at ? when(t.due_at) : "no date"}{t.note ? ` · ${t.note}` : ""}</small></span>
              </label>
            ))}
            <AddTask onAdd={(title, due) => run("Task", () => sb.from("ops_tasks").insert({ title, due_at: due ? `${due} 17:00 America/Chicago` : null }))} />
          </Card>
          <Card title="Call first" count={callFirst.length}>
            {callFirst.length === 0 && <p className="hq-muted">No prospects yet. Add them in Pipeline.</p>}
            {callFirst.map((p) => <Prospect key={p.id} p={p} uid={uid} sb={sb} run={run} compact />)}
          </Card>
          {o.upcoming.length > 0 && (
            <Card title="Coming up" count={o.upcoming.length}>
              {o.upcoming.map((t: Row) => <p key={t.id} className="hq-line">{day(t.due_at)} · {t.title}{t.org ? ` · ${t.org}` : ""}</p>)}
            </Card>
          )}
        </>
      )}

      {tab === "Pipeline" && (
        <>
          <div className="hq-chips">
            {STAGES.map((s) => <span key={s} className="hq-chip">{nice(s)} <b>{o.pipeline[s] ?? 0}</b></span>)}
          </div>
          <AddProspect onAdd={(row) => run("Prospect", () => sb.from("prospects").insert(row))} />
          <Card title="Active prospects" count={prospects.length}>
            {prospects.length === 0 && <p className="hq-muted">Empty. Website leads land here on their own. Add the rest above.</p>}
            {prospects.map((p) => <Prospect key={p.id} p={p} uid={uid} sb={sb} run={run} />)}
          </Card>
        </>
      )}

      {tab === "Clients" && (
        <>
          {clients.length === 0 && <Card title="Clients"><p className="hq-muted">No clients yet. Mark a prospect won in Pipeline and onboarding starts here.</p></Card>}
          {clients.map((c) => <Client key={c.id} c={c} sb={sb} run={run} />)}
        </>
      )}

      {tab === "Updates" && (
        <Card title="Outbox" count={o.outbox.length}>
          <button className="hq-btn ghost" onClick={() => run("Today's updates", () => sb.rpc("hq_run_daily"))}>Build today&apos;s updates now</button>
          <p className="hq-muted">Slack messages send once a channel is connected in System. Texts and emails wait here until GoHighLevel is connected.</p>
          {o.outbox.map((m: Row) => (
            <div key={m.id} className="hq-msg">
              <div className="hq-msg-head"><span className={"hq-pill " + m.status}>{m.status}</span> {m.kind.replace(/_/g, " ")} · {m.channel} {m.to_addr ?? "no address"} · {when(m.scheduled_for)}</div>
              <pre>{m.body}</pre>
              {m.error && <small className="hq-error">{m.error}</small>}
            </div>
          ))}
        </Card>
      )}

      {tab === "System" && <System o={o} sb={sb} run={run} />}
    </main>
  );
}

function Meter({ label, n, lo, hi, note }: { label: string; n: number; lo: number; hi: number; note?: string }) {
  const state = n >= lo ? "good" : n >= lo / 2 ? "mid" : "low";
  return (
    <div className={"hq-meter " + state}>
      <div className="hq-meter-n">{n}</div>
      <div className="hq-meter-l">{label}</div>
      <div className="hq-meter-t">{note ?? (lo === hi ? `goal ${lo}` : `goal ${lo} to ${hi}`)}</div>
    </div>
  );
}

function Card({ title, count, children }: { title: string; count?: number; children: React.ReactNode }) {
  return (
    <section className="hq-card">
      <h2>{title}{count != null && <span>{count}</span>}</h2>
      {children}
    </section>
  );
}

function AddTask({ onAdd }: { onAdd: (title: string, due: string) => void }) {
  const [title, setTitle] = useState(""); const [due, setDue] = useState("");
  return (
    <form className="hq-inline" onSubmit={(e) => { e.preventDefault(); if (title.trim()) { onAdd(title.trim(), due); setTitle(""); } }}>
      <input placeholder="Add a task" value={title} onChange={(e) => setTitle(e.target.value)} />
      <input type="date" value={due} onChange={(e) => setDue(e.target.value)} aria-label="Due date" />
      <button className="hq-btn small">Add</button>
    </form>
  );
}

function AddProspect({ onAdd }: { onAdd: (row: Row) => void }) {
  const [open, setOpen] = useState(false);
  const submit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const f = new FormData(e.currentTarget); const v = (k: string) => (String(f.get(k) ?? "").trim() || null);
    onAdd({
      business_name: v("business_name"), trade: v("trade"), city: v("city"), service_area: v("city"), phone: v("phone"),
      owner_name: v("owner_name"), owner_phone: v("owner_phone"), owner_email: v("owner_email"), revenue_band: v("revenue_band") ?? "unknown",
      after_hours_result: v("after_hours_result") ?? "not_tested", callback_minutes: v("callback_minutes") ? Number(v("callback_minutes")) : null,
      est_unsold_band: v("est_unsold_band") ?? "unknown", runs_ads: f.get("runs_ads") === "on", google_reviews: v("google_reviews") ? Number(v("google_reviews")) : null,
      source: v("source") ?? "outbound", notes: v("notes"),
    });
    e.currentTarget.reset(); setOpen(false);
  };
  if (!open) return <button className="hq-btn" onClick={() => setOpen(true)}>Add a prospect</button>;
  return (
    <form className="hq-card hq-grid" onSubmit={submit}>
      <h2>New prospect</h2>
      <label>Business name<input name="business_name" required /></label>
      <label>Trade<select name="trade">{TRADES.map((t) => <option key={t} value={t}>{nice(t)}</option>)}</select></label>
      <label>City<input name="city" placeholder="Nashville" /></label>
      <label>Main phone<input name="phone" inputMode="tel" /></label>
      <label>Owner name<input name="owner_name" /></label>
      <label>Owner phone<input name="owner_phone" inputMode="tel" /></label>
      <label>Owner email<input name="owner_email" type="email" /></label>
      <label>Revenue<select name="revenue_band" defaultValue="unknown">
        <option value="unknown">Unknown</option><option value="under_500k">Under $500K</option><option value="under_1m">$500K to $1M</option>
        <option value="1m_3m">$1M to $3M</option><option value="3m_10m">$3M to $10M</option><option value="10m_plus">$10M+</option></select></label>
      <label>After-hours test<select name="after_hours_result" defaultValue="not_tested">
        <option value="not_tested">Not tested</option><option value="no_answer">No answer</option><option value="voicemail">Voicemail</option>
        <option value="callback">Called back</option><option value="answered_live">Answered live</option></select></label>
      <label>Callback minutes<input name="callback_minutes" inputMode="numeric" /></label>
      <label>Unsold estimates, 24 months<select name="est_unsold_band" defaultValue="unknown">
        <option value="unknown">Unknown</option><option value="under_500k">Under $500K</option><option value="500k_1_5m">$500K to $1.5M</option><option value="1_5m_plus">$1.5M+</option></select></label>
      <label>Google reviews<input name="google_reviews" inputMode="numeric" /></label>
      <label>Source<select name="source" defaultValue="outbound">{["outbound", "after_hours_test", "referral", "linkedin", "event", "website", "other"].map((s) => <option key={s} value={s}>{nice(s)}</option>)}</select></label>
      <label className="hq-tick"><input type="checkbox" name="runs_ads" /> Runs ads or Local Services</label>
      <label className="wide">Notes<textarea name="notes" rows={2} /></label>
      <div className="wide hq-row"><button className="hq-btn">Save prospect</button><button type="button" className="hq-btn ghost" onClick={() => setOpen(false)}>Cancel</button></div>
    </form>
  );
}

function Prospect({ p, uid, sb, run, compact }: { p: Row; uid: string | null; sb: any; run: (l: string, f: () => PromiseLike<{ error: any }>) => Promise<void>; compact?: boolean }) {
  const [open, setOpen] = useState(false);
  const touch = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const f = new FormData(e.currentTarget); const v = (k: string) => (String(f.get(k) ?? "").trim() || null);
    void run("Touch", async () => {
      const r = await sb.from("prospect_touches").insert({ prospect_id: p.id, channel: v("channel"), outcome: v("outcome"), note: v("note"), by_user: uid });
      if (r.error) return r;
      return sb.from("prospects").update({ next_action: v("next_action"), next_action_at: v("next_at") ? `${v("next_at")} 09:00 America/Chicago` : null }).eq("id", p.id);
    });
    setOpen(false);
  };
  const tel = p.owner_phone || p.phone;
  return (
    <div className={"hq-prospect" + (p.due ? " due" : "") + (p.disqualified_reason ? " dq" : "")}>
      <button className="hq-prospect-head" onClick={() => setOpen(!open)} aria-expanded={open}>
        <span className={"hq-score-pill" + (p.qualified ? " q" : "")}>{p.score}</span>
        <span className="hq-prospect-name">{p.business_name}<small>{[nice(p.trade), p.city, nice(p.stage)].filter(Boolean).join(" · ")}</small></span>
      </button>
      {p.next_action && <p className="hq-line">{p.next_action}{p.next_action_at ? ` · ${day(p.next_action_at)}` : ""}</p>}
      {p.disqualified_reason && <p className="hq-line hq-error">Out: {nice(p.disqualified_reason)}</p>}
      {tel && <a className="hq-btn small" href={`tel:${tel}`}>Call {p.owner_name ? p.owner_name.split(" ")[0] : "the shop"}</a>}
      {open && (
        <div className="hq-detail">
          {!compact && <p className="hq-muted">{[p.owner_name, p.owner_email, p.website, `${p.touch_count} touches`, p.last_touch_at ? `last ${day(p.last_touch_at)}` : null, `after hours: ${nice(p.after_hours_result) || "not tested"}`].filter(Boolean).join(" · ")}</p>}
          {p.notes && !compact && <pre>{p.notes}</pre>}
          <form className="hq-grid" onSubmit={touch}>
            <label>Channel<select name="channel">{CHANNELS.map((c) => <option key={c} value={c}>{nice(c)}</option>)}</select></label>
            <label>What happened<select name="outcome">{OUTCOMES.map((c) => <option key={c} value={c}>{nice(c)}</option>)}</select></label>
            <label className="wide">Note<input name="note" /></label>
            <label>Next step<input name="next_action" defaultValue={p.next_action ?? ""} /></label>
            <label>On<input type="date" name="next_at" /></label>
            <div className="wide hq-row"><button className="hq-btn small">Log touch</button></div>
          </form>
          <div className="hq-row">
            <select aria-label="Move stage" value={p.stage} onChange={(e) => run("Stage", () => sb.from("prospects").update({ stage: e.target.value }).eq("id", p.id))}>
              {STAGES.filter((s) => s !== "won").map((s) => <option key={s} value={s}>{nice(s)}</option>)}
            </select>
            <Won onWon={(tier, kickoff) => run("Client", () => sb.rpc("hq_win_prospect", { p_prospect: p.id, p_tier: tier, p_kickoff: kickoff ? `${kickoff} 09:00 America/Chicago` : null }))} />
          </div>
        </div>
      )}
    </div>
  );
}

function Won({ onWon }: { onWon: (tier: string, kickoff: string) => void }) {
  const [open, setOpen] = useState(false); const [tier, setTier] = useState("greenhouse"); const [kick, setKick] = useState("");
  if (!open) return <button className="hq-btn small" onClick={() => setOpen(true)}>Signed</button>;
  return (
    <span className="hq-row">
      <select value={tier} onChange={(e) => setTier(e.target.value)} aria-label="Tier"><option value="greenhouse">Greenhouse</option><option value="orchard">Orchard</option><option value="estate">Estate</option></select>
      <input type="date" value={kick} onChange={(e) => setKick(e.target.value)} aria-label="Kickoff date" />
      <button className="hq-btn small" onClick={() => onWon(tier, kick)}>Start onboarding</button>
    </span>
  );
}

function Client({ c, sb, run }: { c: Row; sb: any; run: (l: string, f: () => PromiseLike<{ error: any }>) => Promise<void> }) {
  const g = c.guarantees as Row; const ob = c.onboarding as Row; const w = c.last7 as Row;
  const [kick, setKick] = useState(""); const [total, setTotal] = useState(""); const [pay, setPay] = useState("");
  const rate = w.inbound_calls > 0 ? w.answered_60s / w.inbound_calls : null;
  return (
    <section className="hq-card">
      <h2>{c.name}<span>{c.tier} · {c.status}{c.day ? ` · day ${c.day} of 14` : ""}</span></h2>
      <div className="hq-chips">
        <span className={"hq-chip g-" + g.start.status}>Start: {nice(g.start.status)}{g.start.days_left != null ? ` · ${g.start.days_left} days left` : ""}</span>
        <span className={"hq-chip g-" + g.call_promise.status}>Calls this month: {pct(g.call_promise.rate)}</span>
        <span className={"hq-chip g-" + g.payback.status}>Payback: {nice(g.payback.status)}{g.payback.eligible ? ` · ${money(g.payback.revived_paid)} back vs ${money(g.payback.paid_to_grain)} paid` : ""}</span>
      </div>
      <p className="hq-line">Last 7 days: {w.inbound_calls} calls · {pct(rate)} inside 60s · {w.booked} booked · {money(w.revived_booked_value)} revived</p>
      {ob.total > 0 && (
        <>
          <div className="hq-bar"><i style={{ width: `${(ob.done / ob.total) * 100}%` }} /></div>
          <p className="hq-muted">Onboarding: {ob.done} of {ob.total} done</p>
          {ob.open.map((t: Row) => (
            <label key={t.id} className={"hq-check" + (t.overdue ? " late" : "")}>
              <input type="checkbox" onChange={() => run("Step", () => sb.from("onboarding_tasks").update({ done_at: new Date().toISOString() }).eq("id", t.id))} />
              <span>{t.milestone} · {t.title}<small>{t.owner === "client" ? "client" : "us"} · due {day(t.due_at)}</small></span>
            </label>
          ))}
        </>
      )}
      <div className="hq-grid">
        <label>Kickoff date<span className="hq-row"><input type="date" value={kick} onChange={(e) => setKick(e.target.value)} />
          <button className="hq-btn small" disabled={!kick} onClick={() => run("Kickoff", () => sb.rpc("ops_start_onboarding", { p_org: c.id, p_kickoff: `${kick} 09:00 America/Chicago` }))}>Set</button></span></label>
        <label>Unsold estimates frozen ($)<span className="hq-row"><input inputMode="numeric" value={total} placeholder={c.unsold_total ? String(c.unsold_total) : ""} onChange={(e) => setTotal(e.target.value)} />
          <button className="hq-btn small" disabled={!total} onClick={() => run("Estimate list", () => sb.from("orgs").update({ unsold_estimates_frozen_total: Number(total.replace(/[^0-9.]/g, "")) }).eq("id", c.id))}>Save</button></span></label>
        <label>Record a payment ($)<span className="hq-row"><input inputMode="numeric" value={pay} onChange={(e) => setPay(e.target.value)} />
          <button className="hq-btn small" disabled={!pay} onClick={() => run("Payment", () => sb.from("mc_payments").insert({ org_id: c.id, at: new Date().toISOString(), kind: "monthly", amount: Number(pay.replace(/[^0-9.]/g, "")) }))}>Add</button></span></label>
        <label>Daily update goes by<select value={c.comms_channel} onChange={(e) => run("Channel", () => sb.from("orgs").update({ comms_channel: e.target.value }).eq("id", c.id))}>
          <option value="none">Off</option><option value="sms">Text</option><option value="slack">Slack</option><option value="email">Email</option></select></label>
      </div>
      <div className="hq-row">
        {c.status !== "live" && <button className="hq-btn" onClick={() => run("Go-live", () => sb.rpc("ops_mark_live", { p_org: c.id }))}>Mark live now</button>}
        <a className="hq-btn ghost" href={`/dashboard?org=${c.slug}`}>Open their dashboard</a>
      </div>
    </section>
  );
}

function System({ o, sb, run }: { o: Row; sb: any; run: (l: string, f: () => PromiseLike<{ error: any }>) => Promise<void> }) {
  const s = o.system as Row;
  const [ch, setCh] = useState("#hq-daily"); const [url, setUrl] = useState(""); const [key, setKey] = useState("");
  const origin = typeof window === "undefined" ? "" : window.location.origin;
  return (
    <>
      <Card title="Slack">
        <p className="hq-line">{s.slack_channels.length ? `Connected: ${s.slack_channels.join(", ")}` : "Not connected. Messages wait in Updates."}</p>
        <form className="hq-grid" onSubmit={(e) => { e.preventDefault(); void run("Slack channel", () => sb.rpc("hq_set_slack_webhook", { p_channel: ch, p_url: url.trim() })); setUrl(""); }}>
          <label>Channel<select value={ch} onChange={(e) => setCh(e.target.value)}>{["default", "#hq-daily", "#new-leads", "#pipeline", "#onboarding", "#alerts", "#wins"].map((c) => <option key={c}>{c}</option>)}</select></label>
          <label className="wide">Incoming webhook address<input value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://hooks.slack.com/services/..." /></label>
          <div className="wide hq-row"><button className="hq-btn small" disabled={!url}>Connect</button></div>
        </form>
        <p className="hq-muted">One webhook saved as &quot;default&quot; is enough to start. Every internal message goes there with its channel name in front.</p>
      </Card>
      <Card title="Client data in">
        <p className="hq-line">Last event: {s.last_ingest_at ? when(s.last_ingest_at) : "none yet"} · waiting to be matched: {s.ingest_unprocessed}</p>
        {!key && <button className="hq-btn ghost" onClick={async () => { const { data } = await sb.rpc("hq_ingest_key"); setKey(data ?? ""); }}>Show webhook addresses</button>}
        {key && (<>
          <p className="hq-muted">Retell webhook address:</p><pre>{`${origin}/api/ingest/retell?key=${key}`}</pre>
          <p className="hq-muted">GoHighLevel custom webhook: post to this address with the header x-grain-key set to the key.</p><pre>{`${origin}/api/ingest/ghl\nx-grain-key: ${key}`}</pre>
        </>)}
      </Card>
      <Card title="Schedule">
        <p className="hq-line">Numbers last computed: {when(s.last_runs?.compute_daily) || "not yet"} · updates last built: {when(s.last_runs?.generate_updates) || "not yet"}</p>
        <p className="hq-line">Website leads, last 7 days: {s.website_leads_7d}</p>
        <p className="hq-line">Sample dashboards: {s.demo_orgs.map((d: string) => <a key={d} href={`/dashboard?org=${d}`}>{d} </a>)}</p>
      </Card>
    </>
  );
}
