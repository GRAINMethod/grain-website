/*
  The v7 offer, in one place. Every page reads from here, so a price or
  guarantee change happens once. Canon lives in Notion: GRAIN HQ, Pricing and Growth.
*/

export const OFFER = {
  name: "Greenhouse",
  setup: 1500,
  monthly: 1497,
  dueAtSigning: 0,
  dueAtGoLive: 2997,
  sharePct: 10,
  liveDays: 14,
  answerPct: 99,
  answerSeconds: 60,
  termDays: 90,
  noticeDays: 30,
  foundingSpots: 5,
  foundingThrough: "December 31, 2026",
  foundingThroughShort: "Dec 31",
  priceAfterFounding: 2997,
  paybackMin: 1_500_000,
  exampleRate: 0.005,
  adsMonthly: 750,
  adsPct: 15,
} as const;

export const money = (n: number) =>
  "$" + Math.round(n).toLocaleString("en-US");

export const TRADES = [
  "HVAC",
  "Plumbing",
  "Roofing",
  "Electrical",
  "Garage doors",
  "Foundation",
  "Remodeling",
  "Pools",
  "Fencing",
  "Water treatment",
] as const;

export type Guarantee = {
  id: string;
  name: string;
  promise: string;
  detail: string;
  conditions: string[];
  note?: string;
};

export const GUARANTEES: Guarantee[] = [
  {
    id: "start",
    name: "Start Guarantee",
    promise: "$0 until it's live.",
    detail:
      "Live in 14 days or month 1 is free. You approve the test calls first.",
    conditions: [
      "Kickoff within 3 business days of signing",
      "24 months of estimates exported on day 1",
      "Call forwarding on by day 10",
      "Test calls approved within 48 hours",
    ],
    note: "Late inputs pause the clock.",
  },
  {
    id: "calls",
    name: "Call promise",
    promise: "99% of calls answered in 60 seconds.",
    detail:
      "Every month, day and night, or that month is free. This one covers every client.",
    conditions: ["Call forwarding stays on"],
  },
  {
    id: "payback",
    name: "Payback Guarantee",
    promise: "Your old estimates pay for it.",
    detail:
      "If revived jobs haven't covered everything you've paid by day 90, your monthly pauses until they do. Still short at day 180, we refund the difference.",
    conditions: [
      "$1.5M+ in unsold estimates from the last 24 months",
      "Revived appointments run within 2 business days",
      "Jobs marked completed and paid in your job software",
      "The monthly reconciliation call",
    ],
  },
];

export const STEPS = [
  {
    name: "Leak Check",
    when: "Free, 30 minutes",
    body: "We call your shop the way a homeowner would, look at how fast leads get answered and followed up, and count your unsold estimates. You leave with your numbers, whether you hire us or not.",
  },
  {
    name: "Build",
    when: "14 days",
    body: "One 60-minute kickoff and your old estimates exported. We set up the answering, booking and follow-up around your services, prices and calendar. You approve the test calls before anything goes live.",
  },
  {
    name: "Live",
    when: "Day 14 on",
    body: "Calls and texts answered in under a minute, day and night. Jobs booked on your calendar. Estimates followed up. Old estimates worked until they turn into jobs or a clear no.",
  },
] as const;
