type Props = { className?: string; tone?: "ink" | "cream" };

/* The GRAIN mark: a house outline with a sprout growing from the floor. */
export function Logo({ className = "", tone = "ink" }: Props) {
  const line = tone === "ink" ? "stroke-ink" : "stroke-cream";
  const base = tone === "ink" ? "fill-ink" : "fill-cream";
  const stem = tone === "ink" ? "stroke-moss-ink" : "stroke-moss";
  const leaf = tone === "ink" ? "fill-moss" : "fill-moss-light";
  return (
    <svg viewBox="-4 -4 228 248" className={className} aria-hidden="true" focusable="false">
      <path d="M110 10 L210 90 L210 230 L10 230 L10 90 Z" className={line} strokeWidth="16" fill="none" strokeLinejoin="miter" />
      <g transform="translate(110,230)">
        <path d="M0 0 L0 -115" className={stem} strokeWidth="6" strokeLinecap="round" fill="none" />
        <path d="M-2 -55 Q-32 -68 -42 -55 Q-36 -42 -2 -48 Z" className={leaf} />
        <path d="M2 -80 Q34 -93 44 -80 Q38 -67 2 -73 Z" className={leaf} />
        <path d="M-1 -115 Q-18 -128 -22 -118 Q-14 -108 -1 -110 Z" className={leaf} />
        <path d="M1 -115 Q18 -128 22 -118 Q14 -108 1 -110 Z" className={leaf} />
        <path d="M-32 0 Q0 -14 32 0 Z" className={base} />
      </g>
    </svg>
  );
}
