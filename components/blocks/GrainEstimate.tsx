import { Logo } from "@/components/site/Logo";
import { OFFER, money } from "@/content/offer";

/* The price, written the way a shop writes an estimate for a homeowner. */
export function GrainEstimate() {
  return (
    <div className="slip px-6 py-7 sm:px-9 sm:py-9">
      <div className="flex items-start justify-between gap-6">
        <div>
          <p className="field-label">Estimate for</p>
          <p className="mt-1 font-display text-[1.7rem] leading-tight">Your shop</p>
        </div>
        <div className="text-right">
          <p className="field-label">From</p>
          <p className="mt-1.5 flex items-center justify-end gap-2">
            <Logo className="h-5 w-5" />
            <span className="wordmark text-[0.9rem]">GRAIN</span>
          </p>
        </div>
      </div>

      <div className="mt-2 flex flex-wrap justify-between gap-x-6 gap-y-1">
        <p className="typed text-[0.78rem] text-muted">{OFFER.name}: the 14-day leak fix</p>
        <p className="typed text-[0.78rem] text-muted">Founding price, through {OFFER.foundingThroughShort}</p>
      </div>

      <hr className="rule-dash my-6" />

      <dl className="space-y-4">
        <Row label="Setup" value={money(OFFER.setup)} />
        <Row label="Monthly" value={`${money(OFFER.monthly)} a month`} />
        <Row
          label="Revival share"
          value={`${OFFER.sharePct}%`}
          sub="Of revived jobs, only on jobs completed and paid. No cap."
        />
      </dl>

      <hr className="rule-dash my-6" />

      <dl className="space-y-4">
        <Row label="Due when you sign" value={money(OFFER.dueAtSigning)} strong />
        <Row label="Due when you go live" value={money(OFFER.dueAtGoLive)} sub="Setup plus the first month" />
      </dl>

      <hr className="rule-dash my-6" />

      <p className="field-label">Terms</p>
      <p className="typed mt-1.5 text-[0.85rem] text-ink-soft">
        {OFFER.termDays} days, then month to month with {OFFER.noticeDays} days&apos; notice. Card or ACH on file.
      </p>
    </div>
  );
}

function Row({ label, value, sub, strong = false }: { label: string; value: string; sub?: string; strong?: boolean }) {
  return (
    <div className="flex items-baseline justify-between gap-6">
      <dt className="text-[1rem] text-ink-soft">
        {label}
        {sub && <span className="mt-0.5 block text-[0.85rem] text-muted">{sub}</span>}
      </dt>
      <dd className={`typed text-right whitespace-nowrap ${strong ? "text-[1.6rem] leading-none" : "text-[1.05rem]"}`}>{value}</dd>
    </div>
  );
}
