import type { Metadata, Viewport } from "next";
import Script from "next/script";
import "@fontsource-variable/inter";
import "@fontsource-variable/fraunces/full.css";
import "@fontsource-variable/jetbrains-mono";
import "./globals.css";
import { Nav } from "@/components/site/Nav";
import { Footer } from "@/components/site/Footer";
import { Attribution } from "@/components/site/Attribution";
import { SITE } from "@/content/site";

const DESCRIPTION =
  "GRAIN answers every call and text in under a minute, books the job, follows up on every estimate and works the old ones you gave up on. Live in 14 days. $0 until it's live.";

export const metadata: Metadata = {
  metadataBase: new URL(SITE.url),
  title: {
    default: "GRAIN Method | Your old estimates are worth more than your ads",
    template: "%s | GRAIN Method",
  },
  description: DESCRIPTION,
  applicationName: "GRAIN Method",
  openGraph: {
    type: "website",
    siteName: "GRAIN Method",
    title: "Your old estimates are worth more than your ads.",
    description: DESCRIPTION,
    url: SITE.url,
    locale: "en_US",
  },
  twitter: { card: "summary_large_image" },
};

export const viewport: Viewport = {
  themeColor: "#F0ECDF",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const analytics = process.env.VERCEL_ENV === "production";
  return (
    <html lang="en">
      <body>
        <a href="#main" className="skip">
          Skip to content
        </a>
        <Nav />
        <main id="main">{children}</main>
        <Footer />
        <Attribution />
        {analytics && (
          <>
            <Script src={`https://www.googletagmanager.com/gtag/js?id=${SITE.ga4}`} strategy="afterInteractive" />
            <Script id="ga4" strategy="afterInteractive">
              {`window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','${SITE.ga4}');`}
            </Script>
          </>
        )}
      </body>
    </html>
  );
}
