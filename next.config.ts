import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async redirects() {
    // The June 2026 static site used .html pages. Keep old links working.
    return [
      { source: "/index.html", destination: "/", permanent: true },
      { source: "/method.html", destination: "/how-it-works", permanent: true },
      { source: "/method", destination: "/how-it-works", permanent: true },
      { source: "/pricing.html", destination: "/pricing", permanent: true },
      { source: "/apply.html", destination: "/leak-check", permanent: true },
      { source: "/apply", destination: "/leak-check", permanent: true },
      { source: "/audit", destination: "/leak-check", permanent: true },
      { source: "/calculator.html", destination: "/#math", permanent: true },
      { source: "/dashboard.html", destination: "/how-it-works", permanent: true },
      { source: "/privacy.html", destination: "/privacy", permanent: true },
      { source: "/terms.html", destination: "/terms", permanent: true },
      { source: "/security.html", destination: "/privacy#security", permanent: true },
      { source: "/security", destination: "/privacy#security", permanent: true },
    ];
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "X-Frame-Options", value: "SAMEORIGIN" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
        ],
      },
    ];
  },
};

export default nextConfig;
