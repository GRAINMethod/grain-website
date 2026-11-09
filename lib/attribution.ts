/* First-touch attribution, kept for the visit so a form on page 3 still knows the ad that started it. */

const KEY = "grain_attr";
const UTM_KEYS = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "gclid", "fbclid"];

type Attr = { utm: Record<string, string>; landing: string; referrer: string };

export function captureAttribution() {
  try {
    const p = new URLSearchParams(window.location.search);
    const utm: Record<string, string> = {};
    UTM_KEYS.forEach((k) => {
      const v = p.get(k);
      if (v) utm[k] = v.slice(0, 200);
    });
    const existing = sessionStorage.getItem(KEY);
    if (existing && !Object.keys(utm).length) return;
    const attr: Attr = {
      utm,
      landing: window.location.pathname,
      referrer: document.referrer.slice(0, 500),
    };
    sessionStorage.setItem(KEY, JSON.stringify(attr));
  } catch {
    /* storage can be blocked; forms still work */
  }
}

export function attribution() {
  let attr: Attr = { utm: {}, landing: "", referrer: "" };
  try {
    attr = { ...attr, ...JSON.parse(sessionStorage.getItem(KEY) || "{}") };
  } catch {
    /* ignore */
  }
  return {
    utm: attr.landing ? { ...attr.utm, landing: attr.landing } : attr.utm,
    referrer: attr.referrer || document.referrer,
    source_page: window.location.pathname,
  };
}
