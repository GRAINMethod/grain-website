import { GUARANTEES } from "@/content/offer";

function Box() {
  return (
    <svg viewBox="0 0 18 18" className="mt-[0.2rem] h-[1.05rem] w-[1.05rem] shrink-0" aria-hidden="true">
      <rect x="1" y="1" width="16" height="16" rx="3" className="fill-none stroke-moss" strokeWidth="1.5" />
      <path d="M4.5 9.4 7.6 12.3 13.6 5.8" className="fill-none stroke-moss-light" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

/* Promise on the left, conditions on the right. Same row, same size type. */
export function GuaranteeRows({ withIds = false }: { withIds?: boolean }) {
  return (
    <div className="divide-y divide-line-ink border-y border-line-ink">
      {GUARANTEES.map((g) => (
        <div key={g.id} id={withIds ? g.id : undefined} className="grid gap-7 py-10 lg:grid-cols-12 lg:gap-12 lg:py-12">
          <div className="lg:col-span-7">
            <p className="text-[0.95rem] font-semibold text-moss-light">{g.name}</p>
            <h3 className="mt-3 text-[clamp(1.9rem,1.25rem+2vw,2.9rem)] leading-[1.04] font-[480] tracking-[-0.015em]">
              {g.promise}
            </h3>
            <p className="mt-4 max-w-xl text-[1.05rem] text-cream/80">{g.detail}</p>
          </div>
          <div className="lg:col-span-5 lg:pt-1">
            <p className="text-[0.9rem] font-semibold text-cream/60">What it needs</p>
            <ul className="mt-3 space-y-2.5">
              {g.conditions.map((c) => (
                <li key={c} className="flex gap-3 text-[1rem] text-cream/90">
                  <Box />
                  <span>{c}</span>
                </li>
              ))}
            </ul>
            {g.note && <p className="mt-4 text-[0.95rem] text-cream/60">{g.note}</p>}
          </div>
        </div>
      ))}
    </div>
  );
}
