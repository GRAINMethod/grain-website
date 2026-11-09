export type Faq = { q: string; a: string; link?: { href: string; label: string } };

/* The first five show on the homepage. All of them show on /faq. */
export const FAQS: Faq[] = [
  {
    q: "Is this an answering service?",
    a: "No. An answering service takes a message. GRAIN books the job and turns old estimates into paid work.",
  },
  {
    q: "Do I have to change software?",
    a: "Usually not. We connect to what you use and confirm it on the Leak Check.",
  },
  {
    q: "What if it doesn't work?",
    a: "Then you don't pay for it. If revived jobs haven't covered what you've paid by day 90, your monthly pauses. Still short at day 180, we refund the difference.",
    link: { href: "/guarantees#payback", label: "Read the Payback Guarantee" },
  },
  {
    q: "What do you need from me?",
    a: "One 60-minute kickoff, your old estimates exported, and test calls approved.",
  },
  {
    q: "How does the 10% work?",
    a: "On day 1 we freeze the list of your unsold estimates. When one of them turns into a job that's booked within 90 days and completed and paid, we get 10% of that job. No cap, and nothing on new calls.",
  },
  {
    q: "Who answers my phone?",
    a: "An AI voice agent we set up for your shop: your services, prices, service area and calendar. You listen to the test calls and approve them before anything goes live, and you decide which calls go to your team.",
  },
  {
    q: "What does it cost?",
    a: "Founding price: $1,500 setup, $1,497 a month, and 10% of revived jobs, only on jobs completed and paid. $0 when you sign. $2,997 when you go live.",
    link: { href: "/pricing", label: "See pricing" },
  },
  {
    q: "How long is the contract?",
    a: "90 days, then month to month with 30 days' notice.",
  },
  {
    q: "What's a Leak Check?",
    a: "A free 30-minute call. We look at how fast your shop answers, how your estimates get followed up and what your unsold estimates are worth. You keep the numbers whether you hire us or not.",
    link: { href: "/leak-check", label: "Get a Leak Check" },
  },
  {
    q: "What's the After-Hours Test?",
    a: "We call your shop after hours the way a homeowner would and send you what happened. It's free.",
    link: { href: "/after-hours-report", label: "Get your shop tested" },
  },
  {
    q: "What happens to my office staff?",
    a: "Your team keeps doing what they do. GRAIN picks up the calls they can't get to and does the follow-up nobody has time for.",
  },
  {
    q: "Do you run ads?",
    a: "Not to start. We fix the leak first. Once you're live, we can manage Google ads for $750 a month or 15% of ad spend, whichever is higher. You pay Google directly.",
  },
  {
    q: "Where do you work?",
    a: "We're based in Nashville and work with shops across the US. One shop per trade per area, so we never work for the shop down the street.",
  },
  {
    q: "Is my customers' information safe?",
    a: "We use your customer data only to run your service, and we don't sell it.",
    link: { href: "/privacy#security", label: "How we protect data" },
  },
];
