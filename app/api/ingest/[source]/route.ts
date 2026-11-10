import { NextResponse } from "next/server";
import { serverClient } from "@/lib/supabase";

/*
  Webhook intake for client activity.
    POST /api/ingest/retell   Retell's own webhook (we use the call_analyzed event)
    POST /api/ingest/ghl      a GoHighLevel "Custom Webhook" action posting the GRAIN shape below

  Send the ingest key as the x-grain-key header, or ?key=... when the sender cannot set headers (Retell).
  The key is created and shown in GRAIN HQ, System. It is checked inside the database.

  GRAIN shape: { "type": "call|lead|appointment|estimate|followup|sync", "id": "<unique id>", "org": "<GHL location id or client slug>", ...fields }
    call         at, response_seconds, answered, after_hours, booked, job_type, area, est_value, source, handoff
    lead         at, channel (form|sms), source, job_type, area, est_value, response_seconds
    appointment  at, source (respond|followup|revival), scheduled_for, value, job_type
    estimate     estimate_no, amount, sent_at, status (open|won|lost), won_via (followup|revival|direct), won_at, completed_paid_at, paid_amount, job_type, frozen
    followup     at, estimate_no, channel, day, job_type, revival (true for old-estimate messages)
    sync         at, records, latency_ms, ok, system
  Anything else is stored and shown in HQ as unprocessed. Sending the same id twice is safe.
*/
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Json = Record<string, unknown>;
const str = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim().slice(0, 200) : undefined);
const iso = (ms: unknown) => (typeof ms === "number" && ms > 0 ? new Date(ms).toISOString() : undefined);

function fromRetell(body: Json): { skip?: string; type?: string; id?: string; org?: string; payload?: Json } {
  const call = (body.call ?? {}) as Json;
  if (body.event !== "call_analyzed") return { skip: `ignored ${String(body.event ?? "event")}` };
  const analysis = ((call.call_analysis as Json | undefined)?.custom_analysis_data ?? {}) as Json;
  const meta = (call.metadata ?? {}) as Json;
  const inbound = call.direction !== "outbound";
  const answered = !["dial_no_answer", "dial_busy", "dial_failed"].includes(String(call.disconnection_reason ?? ""));
  const base: Json = { at: iso(call.start_timestamp), job_type: str(analysis.job_type), area: str(analysis.area) };
  if (!inbound) {
    return { type: "followup", id: `${call.call_id}`, org: str(call.agent_id),
      payload: { ...base, channel: "call", estimate_no: str(meta.estimate_no), revival: meta.revival === true } };
  }
  return { type: "call", id: `${call.call_id}`, org: str(call.agent_id),
    payload: { ...base, answered, booked: analysis.booked === true, handoff: analysis.handoff === true,
      response_seconds: typeof meta.response_seconds === "number" ? meta.response_seconds : undefined,
      est_value: typeof analysis.est_value === "number" ? analysis.est_value : undefined, source: str(meta.source) } };
}

export async function POST(req: Request, ctx: { params: Promise<{ source: string }> }) {
  const { source } = await ctx.params;
  if (source !== "ghl" && source !== "retell") return NextResponse.json({ error: "not_found" }, { status: 404 });
  const key = req.headers.get("x-grain-key") ?? new URL(req.url).searchParams.get("key");
  if (!key) return NextResponse.json({ error: "not_allowed" }, { status: 401 });

  let body: Json;
  try { body = (await req.json()) as Json; } catch { return NextResponse.json({ error: "bad_json" }, { status: 400 }); }
  if (!body || typeof body !== "object") return NextResponse.json({ error: "bad_json" }, { status: 400 });

  let type: string | undefined, id: string | undefined, org: string | undefined, payload: Json;
  if (source === "retell" && body.event) {
    const m = fromRetell(body);
    if (m.skip) return NextResponse.json({ ok: true, note: m.skip });
    ({ type, id, org } = m); payload = m.payload ?? {};
  } else {
    const { type: t, id: i, org: o, ...rest } = body;
    type = str(t); id = str(i); org = str(o); payload = rest;
  }
  if (!id || id === "undefined") return NextResponse.json({ error: "missing_id" }, { status: 400 });

  const { data, error } = await serverClient().rpc("ops_ingest", {
    p_key: key, p_source: source, p_external_id: id, p_event_type: type ?? null, p_org_ref: org ?? null, p_payload: payload,
  });
  if (error) {
    const denied = error.code === "42501";
    return NextResponse.json({ error: denied ? "not_allowed" : "unavailable" }, { status: denied ? 401 : 503 });
  }
  return NextResponse.json(data);
}
