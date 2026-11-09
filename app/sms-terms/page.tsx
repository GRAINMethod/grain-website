import Link from "next/link";
import { PageHeader } from "@/components/blocks/Common";
import { SITE } from "@/content/site";
import { pageMeta } from "@/lib/meta";

export const metadata = pageMeta(
  "/sms-terms",
  "SMS terms",
  "How GRAIN Method text messages work, how to opt in and how to stop them."
);

export default function SmsTerms() {
  return (
    <>
      <PageHeader title="SMS terms" lede={`Last updated ${SITE.lastUpdatedLegal}.`} />
      <section className="py-14 sm:py-20">
        <div className="wrap">
          <div className="prose-grain">
            <h2>The program</h2>
            <p>
              {SITE.legalName} sends text messages to home service business owners and staff who ask to hear from us.
              Messages cover scheduling and reminders for your Leak Check, your After-Hours Test result, and replies to
              questions you send us.
            </p>

            <h2>How you opt in</h2>
            <p>
              You opt in by checking the text-message box on a form on grainmethod.com, or by texting us first. Consent
              to receive texts is not a condition of any purchase or of getting a Leak Check.
            </p>

            <h2>What to expect</h2>
            <ul>
              <li>Message frequency varies with what you asked for.</li>
              <li>Message and data rates may apply.</li>
              <li>
                Reply <strong>STOP</strong> to cancel at any time. We&apos;ll send one message confirming you&apos;re
                unsubscribed, and then no more.
              </li>
              <li>
                Reply <strong>HELP</strong> for help, or email <a href={`mailto:${SITE.email}`}>{SITE.email}</a>.
              </li>
              <li>Carriers are not liable for delayed or undelivered messages.</li>
            </ul>

            <h2>Your number stays private</h2>
            <p>
              We do not sell or share your mobile number or your text-message opt-in with third parties or affiliates for
              their marketing or promotional purposes. See our <Link href="/privacy">Privacy policy</Link>.
            </p>

            <h2>Got a text from a shop that uses GRAIN?</h2>
            <p>
              Some home service shops use GRAIN to answer and follow up with their customers. Those texts are sent on
              the shop&apos;s behalf. Reply STOP to that message to stop texts from that shop, or contact the shop
              directly.
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
