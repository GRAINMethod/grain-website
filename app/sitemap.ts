import type { MetadataRoute } from "next";

const BASE = "https://www.grainmethod.com";
const PATHS = ["", "/how-it-works", "/guarantees", "/pricing", "/leak-check", "/after-hours-report", "/faq", "/about", "/privacy", "/terms", "/sms-terms"];

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date("2026-11-09");
  return PATHS.map((p) => ({
    url: `${BASE}${p}`,
    lastModified: now,
    changeFrequency: p === "" ? "weekly" : "monthly",
    priority: p === "" ? 1 : p === "/leak-check" ? 0.9 : 0.6,
  }));
}
