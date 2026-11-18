/*
  Demand scoring, the same math as the database trigger (supabase/migrations/20261118000100_demand_scoring.sql),
  the GRAIN Audit Demand Map sheet and Notion: Operations, 1. Find and qualify leads.

  demand $ a month = searches x 3% (leads for a top-3 shop) x 45% (book) x close rate x average ticket
  share he catches by map rank: 1 to 3 = 100%, 4 to 10 = 25%, 11 to 20 = 5%, not in the top 20 = 0%
  missed $ a month = demand x (1 - share)

  3% and the rank shares are planning assumptions. Change them here and in the trigger together.
*/

export const CAPTURE = 0.03;
export const BOOK = 0.45;

export function rankShare(rank: number | null): number {
  if (rank == null) return 0;
  if (rank <= 3) return 1;
  if (rank <= 10) return 0.25;
  if (rank <= 20) return 0.05;
  return 0;
}

export function serviceDemand(searches: number, ticket: number, closeRate: number | null, rank: number | null) {
  const demand = searches * CAPTURE * BOOK * (closeRate ?? 1) * ticket;
  return { demand, missed: demand * (1 - rankShare(rank)) };
}

/** Minimal CSV parser: quoted fields, escaped quotes, commas and newlines inside quotes. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let quoted = false;
  const s = text.replace(/^﻿/, "");
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (quoted) {
      if (c === '"' && s[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && s[i + 1] === "\n") i++;
      row.push(field); field = "";
      if (row.some((x) => x.trim() !== "")) rows.push(row);
      row = [];
    } else field += c;
  }
  row.push(field);
  if (row.some((x) => x.trim() !== "")) rows.push(row);
  return rows;
}

const num = (v?: string): number | null => {
  if (v == null) return null;
  const t = v.replace(/[$,\s]/g, "");
  if (t === "") return null;
  const pct = t.endsWith("%");
  const n = Number(pct ? t.slice(0, -1) : t);
  if (!Number.isFinite(n)) return null;
  return pct ? n / 100 : n;
};
const yes = (v?: string): boolean | null => {
  const t = (v ?? "").trim().toLowerCase();
  if (["yes", "y", "true", "1"].includes(t)) return true;
  if (["no", "n", "false", "0"].includes(t)) return false;
  return null;
};
const band = (v?: string): string | null => {
  const t = (v ?? "").toLowerCase().replace(/\s/g, "");
  if (!t) return null;
  if (/^(under|<)\$?500k/.test(t)) return "under_500k";
  if (/500k.*1m/.test(t) || /^(under|<)\$?1m/.test(t)) return "under_1m";
  if (/1m.*3m/.test(t)) return "1m_3m";
  if (/3m.*10m/.test(t)) return "3m_10m";
  if (/10m/.test(t)) return "10m_plus";
  return "unknown";
};

export type ImportRow = Record<string, string | number | boolean | null>;

/**
 * Turns the Clay demand table export (grain-clay-demand-table.csv headers) into rows for hq_import_prospects.
 * Per-service columns (Service 1..3, Searches S1..3, Map rank S1..3, Ticket S1..3, Close rate S1..3) are summed
 * into demand and missed $; the service with the most missed $ becomes the main service and biggest gap.
 * If Clay already filled "Market demand $ a month" and "Missed $ a month", those totals win.
 */
export function clayRows(csv: string): { rows: ImportRow[]; problems: string[] } {
  const table = parseCsv(csv);
  if (table.length < 2) return { rows: [], problems: ["The file has no rows under the header."] };
  const head = table[0].map((h) => h.trim().toLowerCase());
  const col = (name: string) => head.indexOf(name.toLowerCase());
  const problems: string[] = [];
  if (col("shop") < 0 && col("business name") < 0) problems.push('No "Shop" column. Use the Clay template headers.');
  const rows: ImportRow[] = [];
  for (const r of table.slice(1)) {
    const g = (name: string) => { const i = col(name); return i >= 0 ? (r[i] ?? "").trim() : ""; };
    const name = g("shop") || g("business name");
    if (!name) continue;
    const services = [1, 2, 3].map((k) => {
      const service = g(`service ${k}`);
      const searches = num(g(`searches s${k}`));
      const rank = num(g(`map rank s${k}`));
      const ticket = num(g(`ticket s${k}`));
      const close = num(g(`close rate s${k}`));
      if (!service || searches == null || ticket == null) return null;
      const { demand, missed } = serviceDemand(searches, ticket, close, rank);
      return { service, searches, rank, ticket, close, demand, missed };
    }).filter((x): x is NonNullable<typeof x> => x !== null);
    const top = services.slice().sort((a, b) => b.missed - a.missed)[0];
    const clayDemand = num(g("market demand $ a month"));
    const clayMissed = num(g("missed $ a month"));
    const demand = clayDemand ?? (services.length ? services.reduce((s, x) => s + x.demand, 0) : null);
    const missed = clayMissed ?? (services.length ? services.reduce((s, x) => s + x.missed, 0) : null);
    rows.push({
      business_name: name,
      phone: g("phone") || null,
      website: g("website") || null,
      city: g("suburb") || g("city") || null,
      service_area: g("suburb") || g("city") || null,
      trade: g("trade") || null,
      owner_name: g("owner name") || null,
      owner_phone: g("owner cell") || g("owner phone") || null,
      owner_email: g("owner email") || null,
      revenue_band: band(g("revenue band")),
      google_reviews: num(g("review count")),
      runs_ads: yes(g("runs google ads or lsa")),
      top3_avg_reviews: num(g("top-3 avg reviews")),
      main_service: top?.service ?? (g("biggest gap") || null),
      searches_monthly: top?.searches ?? null,
      map_rank: top?.rank ?? null,
      avg_ticket: top?.ticket ?? null,
      close_rate: top?.close ?? null,
      market_demand_monthly: demand != null ? Math.round(demand * 100) / 100 : null,
      missed_monthly: missed != null ? Math.round(missed * 100) / 100 : null,
      biggest_gap: g("biggest gap") || top?.service || null,
      opener: g("opener") || null,
      notes: [g("reviews about no answer") ? `${g("reviews about no answer")} reviews mention no answer` : "",
              yes(g("hiring csr or dispatcher")) ? "Hiring a CSR or dispatcher" : ""].filter(Boolean).join(". ") || null,
    });
  }
  if (rows.length === 0 && problems.length === 0) problems.push("No shops found in the file.");
  return { rows, problems };
}
