import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  const production = process.env.VERCEL_ENV === "production";
  return {
    rules: production ? [{ userAgent: "*", allow: "/", disallow: "/api/" }] : [{ userAgent: "*", disallow: "/" }],
    sitemap: "https://www.grainmethod.com/sitemap.xml",
  };
}
