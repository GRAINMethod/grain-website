import Link from "next/link";

export default function NotFound() {
  return (
    <section className="py-24 sm:py-32">
      <div className="wrap">
        <p className="typed text-[0.9rem] text-rust">404</p>
        <h1 className="mt-3 max-w-[14ch] text-[clamp(2.5rem,1.4rem+3.8vw,4.4rem)] leading-[1.02] tracking-[-0.022em]">
          This page went unanswered.
        </h1>
        <p className="mt-6 max-w-lg text-lede text-ink-soft">
          The link may be old, or the page moved when the site was rebuilt. These will get you where you were going.
        </p>
        <div className="mt-9 flex flex-col gap-3 sm:flex-row">
          <Link href="/" className="btn btn-ink">
            Go to the homepage
          </Link>
          <Link href="/leak-check" className="btn btn-line">
            Get my free Leak Check
          </Link>
        </div>
      </div>
    </section>
  );
}
