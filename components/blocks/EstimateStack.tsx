/*
  The hero: three old estimates from the drawer. On load, a stamp lands on
  the top one. It is the only motion on the page that nobody asked for.
*/
export function EstimateStack() {
  return (
    <figure className="relative mx-auto w-full max-w-[430px] lg:mr-0">
      <div className="relative h-[408px] sm:h-[430px]">
        <div aria-hidden className="slip slip-carbon absolute top-0 right-0 left-[22%] h-[300px] rotate-[5deg] px-5 py-4">
          <div className="flex flex-col items-end gap-1">
            <span className="typed text-[0.72rem] text-muted">No. 2301, Jan 9</span>
            <span className="typed text-[0.95rem]">$4,800.00</span>
          </div>
        </div>

        <div aria-hidden className="slip absolute top-7 right-[22%] left-0 h-[300px] -rotate-[5deg] px-5 py-4">
          <div className="flex flex-col items-start gap-1">
            <span className="typed text-[0.72rem] text-muted">No. 2388, Feb 27</span>
            <span className="typed text-[0.95rem]">$2,150.00</span>
          </div>
        </div>

        <div className="slip slip-nudge absolute top-[4.5rem] right-[3%] left-[5%] -rotate-1 px-6 pt-5 pb-6">
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="field-label">Estimate</p>
              <p className="mt-1 font-display text-[1.45rem] leading-tight">Your shop</p>
            </div>
            <p className="typed pt-0.5 text-[0.75rem] text-muted">No. 2417</p>
          </div>

          <hr className="rule-dash my-4" />

          <dl className="grid grid-cols-[1fr_auto] gap-x-6 gap-y-3.5">
            <div>
              <dt className="field-label">Customer</dt>
              <dd className="typed mt-1 text-[0.92rem]">R. Alvarez</dd>
            </div>
            <div>
              <dt className="field-label">Date</dt>
              <dd className="typed mt-1 text-[0.92rem]">Mar 14</dd>
            </div>
            <div className="col-span-2">
              <dt className="field-label">Job</dt>
              <dd className="typed mt-1 text-[0.92rem]">Heat pump replacement, 3 ton</dd>
            </div>
            <div className="col-span-2">
              <dt className="field-label">Amount</dt>
              <dd className="typed mt-1 text-[1.65rem] leading-none">$11,400.00</dd>
            </div>
          </dl>

          <hr className="rule-dash my-4" />

          <div>
            <span className="field-label">Follow-up</span>
            <span className="typed mt-1 block text-[0.82rem] text-rust">None since Mar 14</span>
          </div>

          <div className="pointer-events-none absolute right-4 bottom-[1.1rem] sm:right-6">
            <span className="stamp stamp-land">
              <span className="text-[1.15rem] font-extrabold tracking-[0.08em] sm:text-[1.3rem]">Revived</span>
              <span className="text-[0.62rem] font-bold tracking-[0.06em] sm:text-[0.66rem]">Booked Tue 8:00 am</span>
            </span>
          </div>
        </div>
      </div>
      <figcaption className="mt-3 text-[0.9rem] text-muted">
        Example estimates. The customers and amounts are made up.
      </figcaption>
    </figure>
  );
}
