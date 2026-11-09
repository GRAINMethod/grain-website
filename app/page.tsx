import type { Metadata } from "next";
import { Hero } from "@/components/home/Hero";
import { SectionNav } from "@/components/site/SectionNav";
import {
  AboutSection,
  FaqSection,
  GuaranteesSection,
  LeakSection,
  MathSection,
  PriceSection,
  ProofSection,
  StartSection,
  StepsSection,
  WhoSection,
} from "@/components/home/HomeSections";
import { HOME_SECTIONS } from "@/content/site";

export const metadata: Metadata = {
  alternates: { canonical: "/" },
};

/* The homepage runs through a short version of every page, in order. */
export default function Home() {
  return (
    <>
      <Hero />
      <SectionNav items={HOME_SECTIONS} />
      <LeakSection />
      <StepsSection />
      <GuaranteesSection />
      <MathSection />
      <PriceSection />
      <WhoSection />
      <ProofSection />
      <AboutSection />
      <FaqSection />
      <StartSection />
    </>
  );
}
