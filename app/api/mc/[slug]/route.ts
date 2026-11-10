import { NextResponse } from "next/server";
import { serverClient } from "@/lib/supabase";

/*
  Greenhouse Dashboard feed.
  GET  /api/mc/<slug>  returns the dashboard data for one org.
       Sample orgs are public. A real client's data needs their sign-in (Authorization: Bearer <token>).
  POST /api/mc/<slug>  nudges a sample org so the page moves while someone watches. Does nothing for real clients.
*/
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const SLUG = /^[a-z0-9][a-z0-9-]{1,62}$/;

function token(req: Request): string | null {
  const h = req.headers.get("authorization") ?? "";
  return h.toLowerCase().startsWith("bearer ") ? h.slice(7).trim() || null : null;
}

export async function GET(req: Request, ctx: { params: Promise<{ slug: string }> }) {
  const { slug } = await ctx.params;
  if (!SLUG.test(slug)) return NextResponse.json({ error: "not_found" }, { status: 404 });
  const tok = token(req);
  const { data, error } = await serverClient(tok).rpc("mc_view", { p_slug: slug });
  if (error) return NextResponse.json({ error: "unavailable" }, { status: 503 });
  if (!data) return NextResponse.json({ error: "not_found" }, { status: 404 });
  const isDemo = Boolean(data?.org?.is_demo);
  return NextResponse.json(data, {
    headers: {
      "Cache-Control": isDemo && !tok ? "public, s-maxage=15, stale-while-revalidate=30" : "private, no-store",
      "X-Robots-Tag": "noindex",
    },
  });
}

export async function POST(_req: Request, ctx: { params: Promise<{ slug: string }> }) {
  const { slug } = await ctx.params;
  if (!SLUG.test(slug)) return NextResponse.json({ ok: false }, { status: 404 });
  const { data, error } = await serverClient().rpc("mc_demo_tick", { p_slug: slug });
  return NextResponse.json({ ok: !error, moved: Boolean(data) }, { headers: { "Cache-Control": "no-store" } });
}
