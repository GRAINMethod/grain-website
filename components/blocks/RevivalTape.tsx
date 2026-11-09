"use client";

import { useId, useState } from "react";
import { OFFER, money } from "@/content/offer";

const MIN = 250_000;
const MAX = 5_000_000;
const STEP = 50_000;

/* "The math" from the v7 spec, as an adding-machine tape. One input. */
export function RevivalTape() {
  const [value, setValue] = useState(1_500_000);
  const id = useId();
  const revived = value * OFFER.exampleRate;
  const share = revived * (OFFER.sharePct / 100);
  const yours = revived - share;
  const qualifies = value >= OFFER.paybackMin;
  const fill = ((value - MIN) / (MAX - MIN)) * 100;

  return (
    <div className="tape-wrap mx-auto w-full max-w-[460px]">
      <div className="tape px-6 pt-6 pb-7 sm:px-8">
        <p className="inline-flex rounded-full bg-rust/10 px-3 py-1 text-[0.82rem] font-semibold text-rust">
          Example, not a promise
        </p>

        <label htmlFor={id} className="mt-6 block text-[0.95rem] font-semibold text-ink">
          Unsold estimates, last 24 months
        </label>
        <output htmlFor={id} className="typed mt-1 block text-[2.4rem] leading-tight" aria-live="polite">
          {money(value)}
        </output>
        <input
          id={id}
          type="range"
          className="range mt-2"
          min={MIN}
          max={MAX}
          step={STEP}
          value={value}
          onChange={(e) => setValue(Number(e.target.value))}
          style={{ ["--fill" as string]: `${fill}%` }}
          aria-valuetext={money(value)}
        />
        <div className="typed flex justify-between text-[0.75rem] text-muted">
          <span>$250K</span>
          <span>$5M</span>
        </div>

        <dl className="typed mt-6 space-y-2.5 text-[0.95rem]">
          <div className="flex justify-between gap-4">
            <dt className="text-ink-soft">× 0.5% revived</dt>
            <dd>{money(revived)}</dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-ink-soft">GRAIN&apos;s 10%</dt>
            <dd>-{money(share)}</dd>
          </div>
          <div className="flex justify-between gap-4 border-t-2 border-double border-ink pt-3 text-[1.25rem]">
            <dt>Yours to keep</dt>
            <dd className="font-semibold">{money(yours)}</dd>
          </div>
        </dl>

        <p className={`mt-6 rounded-lg px-3.5 py-2.5 text-[0.92rem] ${qualifies ? "bg-moss-soft text-moss-deep" : "bg-ink/5 text-ink-soft"}`}>
          {qualifies
            ? "At this size, the Payback Guarantee applies."
            : "The Payback Guarantee starts at $1.5M. The Start Guarantee and the call promise still apply."}
        </p>
      </div>
    </div>
  );
}
