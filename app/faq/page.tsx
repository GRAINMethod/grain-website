import { CtaBand, FaqList, PageHeader } from "@/components/blocks/Common";
import { FAQS } from "@/content/faq";
import { SITE } from "@/content/site";
import { pageMeta } from "@/lib/meta";

export const metadata = pageMeta(
  "/faq",
  "Questions owners ask",
  "Straight answers on how GRAIN works, what it costs, the guarantees and what we need from you."
);

export default function Faq() {
  return (
    <>
      <PageHeader title="Questions owners ask" lede="Straight answers. If yours isn't here, email Johnny.">
        <p className="mt-6">
          <a className="link" href={`mailto:${SITE.email}`}>{SITE.email}</a>
        </p>
      </PageHeader>
      <section className="py-16 sm:py-20">
        <div className="wrap">
          <div className="max-w-4xl">
            <FaqList items={FAQS} />
          </div>
        </div>
      </section>
      <CtaBand />
    </>
  );
}
