import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

/*
  Every form on the site posts here.
  1. Saves the lead to Supabase (public.submit_lead, insert-only, RLS on).
  2. Forwards it to LEAD_WEBHOOK_URL if set (GoHighLevel inbound webhook, Make, Slack).
  3. Emails it through Resend if RESEND_API_KEY is set (to LEAD_NOTIFY_EMAIL).
  A lead counts as received if any one of those works.
*/

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const KINDS = new Set(["leak_check", "after_hours_report", "numbers", "contact"]);
const LABEL: Record<string, string> = {
  leak_check: "Leak Check request",
  after_hours_report: "After-Hours Report signup",
  numbers: "Numbers text",
  contact: "Message",
};

const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://emmgtxumhaqfbcjzddpa.supabase.co";
const SUPABASE_KEY =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "sb_publishable_f6-MchoNCazpEvscPeaGzA_xdBiIhrJ";

const clip = (v: unknown, n = 300) => (typeof v === "string" ? v.trim().slice(0, n) : "");
const fail = (error: string, status = 400) => NextResponse.json({ ok: false, error }, { status });

type Lead = Record<string, string | boolean | Record<string, string>>;

export async function POST(req: Request) {
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail("That didn't come through. Please send the form again.");
  }

  // Honeypot: real people never see this field.
  if (clip(body.company_site)) return NextResponse.json({ ok: true });

  const kind = clip(body.kind, 40);
  if (!KINDS.has(kind)) return fail("Unknown form.");

  const email = clip(body.email, 200).toLowerCase();
  const phone = clip(body.phone, 40);
  const name = clip(body.name, 120);
  const shop = clip(body.shop, 160);

  if (email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return fail("Check the email address.");
  if (phone && phone.replace(/\D/g, "").length < 10) return fail("Check the phone number. It needs 10 digits.");
  if (!email && !phone) return fail("Add a phone number or email so we can reach you.");
  if (kind === "leak_check" && (!name || !shop)) return fail("Add your name and your shop's name.");

  const utmIn = (body.utm && typeof body.utm === "object" ? body.utm : {}) as Record<string, unknown>;
  const utm: Record<string, string> = {};
  for (const k of ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "gclid", "fbclid", "landing"]) {
    const v = clip(utmIn[k], 200);
    if (v) utm[k] = v;
  }

  const lead: Lead = {
    kind,
    name,
    shop,
    email,
    phone,
    trade: clip(body.trade, 60),
    area: clip(body.area, 160),
    website: clip(body.website, 300),
    estimates_band: clip(body.estimates_band, 60),
    software: clip(body.software, 120),
    best_time: clip(body.best_time, 120),
    shop_phone: clip(body.shop_phone, 40),
    wants_test: body.wants_test === true,
    message: clip(body.message, 2000),
    sms_consent: body.sms_consent === true,
    sms_consent_text: body.sms_consent === true ? clip(body.sms_consent_text, 600) : "",
    source_page: clip(body.source_page, 300),
    referrer: clip(body.referrer, 500),
    utm,
    user_agent: clip(req.headers.get("user-agent"), 400),
  };

  const [saved, forwarded, emailed] = await Promise.all([save(lead), forward(lead), notify(lead)]);

  if (!saved && !forwarded && !emailed) {
    return fail("We couldn't save that just now. Email johnny@grainmethod.com and we'll take it from there.", 502);
  }
  return NextResponse.json({ ok: true });
}

async function save(lead: Lead) {
  try {
    const sb = createClient(SUPABASE_URL, SUPABASE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error } = await sb.rpc("submit_lead", { payload: lead });
    if (error) {
      console.error("[leads] submit_lead failed:", error.message);
      return false;
    }
    return true;
  } catch (e) {
    console.error("[leads] supabase error:", e);
    return false;
  }
}

async function forward(lead: Lead) {
  const url = process.env.LEAD_WEBHOOK_URL;
  if (!url) return false;
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...lead, label: LABEL[String(lead.kind)], received_at: new Date().toISOString() }),
      signal: AbortSignal.timeout(5000),
    });
    return res.ok;
  } catch (e) {
    console.error("[leads] webhook error:", e);
    return false;
  }
}

async function notify(lead: Lead) {
  const key = process.env.RESEND_API_KEY;
  if (!key) return false;
  const to = process.env.LEAD_NOTIFY_EMAIL ?? "johnny@grainmethod.com";
  const from = process.env.LEAD_FROM_EMAIL ?? "GRAIN site <onboarding@resend.dev>";
  const lines = Object.entries(lead)
    .filter(([k, v]) => v !== "" && v !== false && k !== "user_agent" && !(typeof v === "object" && !Object.keys(v).length))
    .map(([k, v]) => `${k}: ${typeof v === "object" ? JSON.stringify(v) : String(v)}`);
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: [to],
        subject: `New ${LABEL[String(lead.kind)]}: ${lead.shop || lead.name || lead.email}`,
        text: lines.join("\n"),
        reply_to: lead.email || undefined,
      }),
      signal: AbortSignal.timeout(5000),
    });
    return res.ok;
  } catch (e) {
    console.error("[leads] email error:", e);
    return false;
  }
}
