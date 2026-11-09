import Link from "next/link";
import { PageHeader } from "@/components/blocks/Common";
import { SITE } from "@/content/site";
import { pageMeta } from "@/lib/meta";

export const metadata = pageMeta(
  "/privacy",
  "Privacy policy",
  "What GRAIN Method collects, how we use it, who we share it with and how we protect it."
);

export default function Privacy() {
  return (
    <>
      <PageHeader title="Privacy policy" lede={`Last updated ${SITE.lastUpdatedLegal}.`} />
      <section className="py-14 sm:py-20">
        <div className="wrap">
          <div className="prose-grain">
            <p>
              This policy explains what {SITE.legalName} (&ldquo;GRAIN,&rdquo; &ldquo;we&rdquo;) collects when you use
              grainmethod.com, contact us or work with us, and what we do with it. Questions go to{" "}
              <a href={`mailto:${SITE.email}`}>{SITE.email}</a>.
            </p>

            <h2>What we collect</h2>
            <ul>
              <li>
                <strong>What you give us.</strong> Your name, shop name, phone, email, trade, service area, website,
                rough estimate numbers and anything you write in a form, email or text.
              </li>
              <li>
                <strong>Calls and texts with us.</strong> When you call or text GRAIN, we keep a record of the
                conversation, and calls may be recorded so we can follow up correctly.
              </li>
              <li>
                <strong>How you use the site.</strong> Pages visited, the link or ad that brought you here, device and
                browser type. We use Google Analytics, which sets cookies, and our hosting provider keeps standard server
                logs.
              </li>
            </ul>

            <h2>If your shop is a client</h2>
            <p>
              To run your service, we handle information about your customers: calls, texts, estimates, appointments
              and job records. We use it only to provide the service to you, under your service agreement. We
              don&apos;t sell it, and we don&apos;t use it to market anything to your customers on anyone else&apos;s
              behalf.
            </p>

            <h2>How we use it</h2>
            <ul>
              <li>To reply to you and set up your Leak Check or After-Hours Test</li>
              <li>To provide and improve the service for clients</li>
              <li>To send the texts and emails you asked for</li>
              <li>To understand which pages and ads bring people to the site</li>
              <li>To meet legal obligations and protect against fraud or abuse</li>
            </ul>

            <h2>Text messages</h2>
            <p>
              If you opt in to texts, we use your number to text you about the thing you asked for, such as scheduling
              a Leak Check. Message frequency varies. Message and data rates may apply. Reply STOP to opt out at any
              time, or HELP for help. See our <Link href="/sms-terms">SMS terms</Link>.
            </p>
            <p>
              <strong>
                We do not sell or share your mobile number or your text-message opt-in with third parties or affiliates
                for their marketing or promotional purposes.
              </strong>{" "}
              Text messaging opt-in data and consent are excluded from every kind of sharing described in this policy.
            </p>

            <h2>Who we share it with</h2>
            <p>
              We share information only with companies that help us run GRAIN, such as hosting, database, phone and
              text-message carriers, email and analytics providers, under contracts that limit how they can use it. We
              may also share information when the law requires it, to protect our rights or someone&apos;s safety, or
              as part of a merger or sale of the business. We don&apos;t sell personal information.
            </p>

            <h2>How long we keep it</h2>
            <p>
              We keep information as long as we need it for the reasons above or as the law requires, then delete it or
              strip out what identifies you. You can ask us to delete your information at any time.
            </p>

            <h2>Your choices</h2>
            <ul>
              <li>Reply STOP to any text to stop texts.</li>
              <li>Use the unsubscribe link in any marketing email.</li>
              <li>
                Email <a href={`mailto:${SITE.email}`}>{SITE.email}</a> to see, correct or delete what we have about
                you.
              </li>
              <li>You can block or delete cookies in your browser settings.</li>
            </ul>

            <h2 id="security">How we protect it</h2>
            <p>
              Everything on grainmethod.com travels over an encrypted connection. Client and lead data is stored with
              established cloud providers, access is limited to the people who need it to do the work, and we review
              who has access. No system is perfectly secure, but if we learn of a breach that affects your information,
              we&apos;ll tell you as the law requires.
            </p>

            <h2>Children</h2>
            <p>GRAIN is for businesses. We don&apos;t knowingly collect information from anyone under 18.</p>

            <h2>Changes</h2>
            <p>
              If we change this policy, we&apos;ll update the date at the top. Big changes will be called out on this
              page.
            </p>

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
