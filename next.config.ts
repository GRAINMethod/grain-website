import type { NextConfig } from "next";

/*
  The marketing site is Johnny's hand-built HTML in /public, served as-is.
  Clean URLs map onto those files. Next.js runs underneath for /api routes
  and the Mission Control dashboard.
*/
const PAGES = ["method", "pricing", "calculator", "dashboard", "apply", "privacy", "terms", "security"];

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async rewrites() {
    return {
      beforeFiles: [
        { source: "/", destination: "/index.html" },
        ...PAGES.map((p) => ({ source: `/${p}`, destination: `/${p}.html` })),
      ],
      afterFiles: [],
      fallback: [],
    };
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "X-Frame-Options", value: "SAMEORIGIN" },
        ],
      },
    ];
  },
};

export default nextConfig;
