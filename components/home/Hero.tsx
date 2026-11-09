import Link from "next/link";
import { EstimateStack } from "@/components/blocks/EstimateStack";
import { SITE, smsNumbersHref } from "@/content/site";

export function Hero() {
  const textHref = smsNumbersHref(SITE.phone);
  return (
    <section className="relative overflow-x-clip">
      <div className="wrap grid items-center gap-12 pt-10 pb-16 sm:pt-14 lg:grid-cols-12 lg:gap-8 lg:pt-16 lg:pb-24">
        <div className="lg:col-span-7">
          <h1 className="max-w-[13ch] text-hero">Your old estimates are worth more than your ads.</h1>
          <p className="mt-7 max-w-[35rem] text-lede text-ink-soft">
            GRAIN answers every call and text in under a minute, books the job, follows up on every estimate and works
            the old ones you gave up on. Live in 14 days.
          </p>
          <div className="mt-9 flex flex-col gap-3 sm:flex-row sm:items-center">
            <Link href="/leak-check" className="btn btn-ink">
              Get my free Leak Check
            </Link>
            {textHref ? (
              <a href={textHref} className="btn btn-line">
                Text me your numbers
              </a>
            ) : (
              <a href="#math" className="btn btn-line">
                See the math
              </a>
            )}
          </div>
          <p className="mt-6 max-w-[35rem] text-[0.95rem] text-muted">
            $0 until it&apos;s live. 5 founding spots through Dec 31. Based in Nashville.
          </p>
        </div>
        <div className="lg:col-span-5">
          <EstimateStack />
        </div>
      </div>
    </section>
  );
}
