import Link from "next/link";
import { PageHeader } from "@/components/blocks/Common";
import { SITE } from "@/content/site";
import { pageMeta } from "@/lib/meta";

export const metadata = pageMeta("/terms", "Terms of use", "The terms for using grainmethod.com.");

export default function Terms() {
  return (
    <>
      <PageHeader title="Terms of use" lede={`Last updated ${SITE.lastUpdatedLegal}.`} />
      <section className="py-14 sm:py-20">
        <div className="wrap">
          <div className="prose-grain">
            <p>
              These terms cover your use of grainmethod.com, run by {SITE.legalName} (&ldquo;GRAIN,&rdquo;
              &ldquo;we&rdquo;). By using the site, you agree to them. If you hire GRAIN, your signed service agreement
              governs the service itself.
            </p>

            <h2>What the site is for</h2>
            <p>
              The site explains what GRAIN does and lets you request a Leak Check, the After-Hours Report or a reply
              from us. Don&apos;t use it to break the law, send spam, try to get into systems you aren&apos;t allowed
              into, or interfere with how it works.
            </p>

            <h2>Examples and estimates</h2>
            <p>
              Examples on this site, including sample estimates, call logs and the revival math, are labeled and are
              illustrations only. They are not results, forecasts or promises. What your shop earns depends on your
              estimates, your customers, your market and how your team follows through.
            </p>

            <h2>Guarantees</h2>
            <p>
              The Start Guarantee, the call promise and the Payback Guarantee apply only to clients with a signed
              service agreement, under the conditions on our <Link href="/guarantees">guarantees page</Link> and in that
              agreement. If the two ever differ, the agreement wins.
            </p>

            <h2>Our content</h2>
            <p>
              The GRAIN name, logo, text and design of this site belong to us. You may share links to it, but
              don&apos;t copy or reuse it in a way that suggests you are GRAIN or that we endorse you.
            </p>

            <h2>Other sites</h2>
            <p>Links to other sites are for convenience. We don&apos;t control them and aren&apos;t responsible for them.</p>

            <h2>No warranties</h2>
            <p>
              We work to keep the site accurate and running, but it&apos;s provided &ldquo;as is,&rdquo; without
              warranties of any kind, to the fullest extent the law allows.
            </p>

            <h2>Limit of liability</h2>
            <p>
              To the fullest extent the law allows, GRAIN isn&apos;t liable for indirect, incidental or consequential
              damages from your use of the site. This section doesn&apos;t limit anything in a signed service
              agreement.
            </p>

            <h2>Governing law</h2>
            <p>
              These terms are governed by the laws of the State of Tennessee. Any dispute about the site will be handled
              in the state or federal courts in Davidson County, Tennessee.
            </p>

            <h2>Changes</h2>
            <p>If we change these terms, we&apos;ll update the date at the top.</p>

            <h2>Contact</h2>
            <p>
              {SITE.legalName}, {SITE.city}. <a href={`mailto:${SITE.email}`}>{SITE.email}</a>
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
