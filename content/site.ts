/*
  Site settings. Anything Johnny still has to supply is an env var, so the
  page shows nothing broken until it's set:
    NEXT_PUBLIC_GRAIN_PHONE     GRAIN's 615 number, digits only (turns on "Text me your numbers")
    NEXT_PUBLIC_BOOKING_URL     GoHighLevel calendar link (adds "Pick a time" after the form)
*/

const phoneDigits = (process.env.NEXT_PUBLIC_GRAIN_PHONE ?? "").replace(/\D/g, "");

export const SITE = {
  name: "GRAIN Method",
  url: "https://www.grainmethod.com",
  tagline: "PLANT · NURTURE · SCALE",
  email: "johnny@grainmethod.com",
  city: "Nashville, Tennessee",
  legalName: "GRAIN Method",
  ga4: "G-T5DP2CY8NW",
  founder: "Johnny Dibb",
  phone: phoneDigits.length === 10 ? phoneDigits : "",
  bookingUrl: process.env.NEXT_PUBLIC_BOOKING_URL ?? "",
  lastUpdatedLegal: "November 9, 2026",
} as const;

export const phonePretty = (d: string) =>
  d ? `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}` : "";

export const smsNumbersHref = (d: string) =>
  d
    ? `sms:+1${d}?&body=${encodeURIComponent(
        "My numbers: about ___ calls a week, ___ estimates a month, about $___ in unsold estimates from the last 2 years. Shop: ___"
      )}`
    : "";

export const NAV_LINKS = [
  { href: "/how-it-works", label: "How it works" },
  { href: "/guarantees", label: "Guarantees" },
  { href: "/pricing", label: "Pricing" },
  { href: "/faq", label: "FAQ" },
  { href: "/about", label: "About" },
] as const;

export const HOME_SECTIONS = [
  { id: "leak", label: "The leak" },
  { id: "how", label: "How it works" },
  { id: "guarantees", label: "Guarantees" },
  { id: "math", label: "The math" },
  { id: "price", label: "Price" },
  { id: "who", label: "Who it's for" },
  { id: "proof", label: "Proof" },
  { id: "about", label: "About" },
  { id: "faq", label: "FAQ" },
  { id: "start", label: "Leak Check" },
] as const;
