import type { ReactNode } from "react";
import "./hq.css";

export const metadata = { title: "GRAIN HQ", robots: { index: false, follow: false } };

export default function HqLayout({ children }: { children: ReactNode }) {
  return (
    <>
      <link rel="preconnect" href="https://fonts.googleapis.com" />
      <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&family=Fraunces:ital,wght@1,400;1,500&family=JetBrains+Mono:wght@500;600;700&display=swap" />
      {children}
    </>
  );
}
