"use client";

import { useEffect, useRef, useState } from "react";

type Item = { id: string; label: string };

/*
  The homepage runs through a short version of every page. This bar sticks
  under the main nav and shows where you are, so you can jump between them.
*/
export function SectionNav({ items }: { items: readonly Item[] }) {
  const [active, setActive] = useState<string>("");
  const rail = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const els = items
      .map((i) => document.getElementById(i.id))
      .filter((el): el is HTMLElement => Boolean(el));
    if (!els.length) return;
    const io = new IntersectionObserver(
      (entries) => {
        const hit = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0];
        if (hit) setActive(hit.target.id);
      },
      { rootMargin: "-40% 0px -55% 0px", threshold: 0 }
    );
    els.forEach((el) => io.observe(el));
    const onScroll = () => {
      if (window.scrollY < 200) setActive("");
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      io.disconnect();
      window.removeEventListener("scroll", onScroll);
    };
  }, [items]);

  useEffect(() => {
    const box = rail.current;
    if (!box || !active) return;
    const chip = box.querySelector<HTMLElement>(`[data-id="${active}"]`);
    if (!chip) return;
    const left = chip.offsetLeft - box.clientWidth / 2 + chip.clientWidth / 2;
    box.scrollTo({ left, behavior: "smooth" });
  }, [active]);

  return (
    <div className="sticky top-16 z-40 border-y border-line bg-cream/95 backdrop-blur-md">
      <div className="wrap">
        <div ref={rail} className="no-scrollbar -mx-1 flex gap-1 overflow-x-auto py-2">
          {items.map((i) => (
            <a
              key={i.id}
              href={`#${i.id}`}
              data-id={i.id}
              aria-current={active === i.id ? "true" : undefined}
              className="shrink-0 rounded-full px-3.5 py-1.5 text-[0.88rem] font-medium whitespace-nowrap text-ink-soft transition-colors hover:bg-ink/5 hover:text-ink aria-[current=true]:bg-ink aria-[current=true]:text-cream"
            >
              {i.label}
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}
