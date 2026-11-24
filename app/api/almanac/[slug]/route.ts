import { NextResponse } from "next/server";
import { serverClient } from "@/lib/supabase";
import { bestMatch, cleanQ, demoAllowed, modelAnswer, modelRoute, norm, type Ctx, type Doc, type Result } from "@/lib/almanac";

/*
  Almanac: someone on the team asks, and the answer comes only from documents the owner approved.

  POST /api/almanac/<slug>   body: { "question": "..." }
    Sample accounts are public. A client's own Almanac needs their sign-in (Authorization: Bearer <token>).
  Returns { answered, match, answer, sources: [{ title, topic, approved_by, approved_at }], mode, demo }
    mode "model":  Claude wrote the answer from the approved documents.
    mode "match":  no model reachable: the passage that matches best. match is "full" when it holds every
                   word of the question, "partial" when it only comes close (the page labels it the closest match).
    mode "sample": one of the sample questions on a sample account.
  It never answers from anywhere else. On client accounts every question is kept, and the ones it
  can't answer go on GRAIN's task list in HQ (almanac_log). Questions on the sample accounts are not kept.

  How Claude is reached (Vercel's AI Gateway with the deployment's own token, no key needed) and the
  limits on the sample accounts are in lib/almanac.ts.
*/
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const SLUG = /^[a-z0-9][a-z0-9-]{1,62}$/;
const HEADERS = { "Cache-Control": "no-store", "X-Robots-Tag": "noindex" };

function token(req: Request): string | null {
  const h = req.headers.get("authorization") ?? "";
  return h.toLowerCase().startsWith("bearer ") ? h.slice(7).trim() || null : null;
}

export async function POST(req: Request, ctx: { params: Promise<{ slug: string }> }) {
  const { slug } = await ctx.params;
  if (!SLUG.test(slug)) return NextResponse.json({ error: "not_found" }, { status: 404, headers: HEADERS });
  const body = await req.json().catch(() => null);
  const question = cleanQ(body?.question);
  if (question.length < 2) return NextResponse.json({ error: "empty" }, { status: 400, headers: HEADERS });

  const tok = token(req);
  const sb = serverClient(tok);
  const { data, error } = await sb.rpc("almanac_context", { p_slug: slug, p_q: question });
  if (error) return NextResponse.json({ error: "unavailable" }, { status: 503, headers: HEADERS });
  if (!data) return NextResponse.json({ error: "not_found" }, { status: 404, headers: HEADERS });
  const c = data as Ctx;

  let r: Result | null = null;
  if (c.org.is_demo) {
    const hit = (c.samples ?? []).find((s) => norm(s.q) === norm(question));
    if (hit) r = { answered: hit.answered, match: hit.answered ? "full" : "none", answer: hit.answer ?? "", ids: hit.doc_ids ?? [], mode: "sample" };
  }
  if (!r) {
    const route = modelRoute(req.headers);
    if (route && (!c.org.is_demo || demoAllowed(req.headers))) r = await modelAnswer(question, c, route);
  }
  if (!r) r = bestMatch(c);
  // One line per question in the runtime logs, never the question itself.
  console.info(`almanac: ${slug} ${r.mode} ${r.answered ? "answered" : r.match === "partial" ? "closest match" : "not answered"}`);

  // Client accounts keep every question. What the Almanac couldn't answer goes on GRAIN's list.
  if (!c.org.is_demo && tok) {
    await sb.rpc("almanac_log", {
      p_slug: slug, p_question: question, p_answer: r.answer || null,
      p_answered: r.answered, p_doc_ids: r.ids, p_mode: r.mode === "sample" ? "match" : r.mode,
    });
  }

  const byId = new Map(c.docs.map((d) => [d.id, d]));
  const sources = r.ids.map((id) => byId.get(id)).filter((d): d is Doc => Boolean(d))
    .map((d) => ({ title: d.title, topic: d.topic, approved_by: d.approved_by, approved_at: d.approved_at }));
  return NextResponse.json(
    { answered: r.answered, match: r.match, answer: r.answer, sources, mode: r.mode, demo: c.org.is_demo },
    { headers: HEADERS },
  );
}
