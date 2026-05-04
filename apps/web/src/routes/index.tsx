import { createFileRoute } from "@tanstack/react-router";
import { ArrowRight, CalendarDays, Check, CircleDot, LineChart, Sparkles } from "lucide-react";

import InlineWaitlistForm from "@/components/inline-waitlist-form";

export const Route = createFileRoute("/")({
  component: HomeComponent,
});

const principles = [
  {
    label: "Capture",
    title: "Build an evidence trail",
    body: "Every focus session and calendar block is recorded as raw evidence. Turn scattered fragments into a single record for your accountability review.",
  },
  {
    label: "Score",
    title: "Quantify your productivity",
    body: "We turn subjective sessions into objective numbers. Track focus, energy, and discipline beside the work that actually produced them.",
  },
  {
    label: "Reflect",
    title: "Remain accountable to reality",
    body: "Numbers don't have an ego. See which types of days compound, which ones drain you, and exactly where your schedule is lying to you.",
  },
];

const sampleRows = [
  { time: "09:00", title: "Deep work block", score: "8.4", tone: "bg-[#9cebd6]" },
  { time: "11:30", title: "Product sync", score: "6.8", tone: "bg-[#f2aa64]" },
  { time: "14:00", title: "Implementation pass", score: "8.9", tone: "bg-[#5fd4bc]" },
  { time: "16:30", title: "Review and reset", score: "7.2", tone: "bg-[#d9ef59]" },
];

function HomeComponent() {
  return (
    <main className="min-h-screen bg-[#061512] text-white [background-image:linear-gradient(rgba(255,255,255,0.035)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.035)_1px,transparent_1px)] [background-size:64px_64px]">
      <section className="relative px-5 pb-20 pt-24 md:px-8 md:pb-28 md:pt-32">
        <div className="mx-auto max-w-7xl">
          <div className="relative z-10 mx-auto max-w-5xl text-center">
            <div className="mx-auto mb-7 inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-4 py-2 text-[11px] font-semibold uppercase tracking-normal text-white/58 backdrop-blur-xl">
              <CircleDot className="size-3 text-[#9cebd6]" />
              Numbers for accountability and productivity
            </div>

            <h1 className="mx-auto max-w-5xl font-serif text-[3.15rem] leading-[0.9] tracking-normal text-white sm:text-[5rem] md:text-[6.65rem]">
              Stay accountable to the way you actually work.
            </h1>

            <p className="mx-auto mt-7 max-w-[43rem] text-[1.05rem] leading-8 text-white/62 md:text-[1.22rem] md:leading-9">
              Intent turns scheduled time and reviewed focus sessions into hard data.
              It exists to help you remain accountable and track exactly how productive you are,
              closing the loop between intention and reality.
            </p>

            <div id="waitlist" className="mx-auto mt-11 flex max-w-[35rem] justify-center">
              <InlineWaitlistForm
                align="center"
                caption="Early access is focused on people who already use calendar blocking and reflection."
              />
            </div>

            <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
              <a
                href="/demo"
                className="inline-flex h-11 items-center gap-2 rounded-full border border-[#9cebd6]/40 bg-[#9cebd6]/10 px-5 text-sm font-semibold text-[#c9fff0] transition-colors hover:bg-[#9cebd6]/16"
              >
                Explore demo
                <ArrowRight className="size-4" />
              </a>
              <a
                href="/dashboard"
                className="inline-flex h-11 items-center rounded-full border border-white/10 bg-white/[0.035] px-5 text-sm font-semibold text-white/70 transition-colors hover:bg-white/[0.07] hover:text-white"
              >
                Use my real data
              </a>
            </div>
          </div>

          <ProductSignalPreview />
        </div>
      </section>

      <section className="border-y border-white/8 bg-white/[0.025] px-5 py-14 md:px-8">
        <div className="mx-auto grid max-w-7xl gap-8 md:grid-cols-[0.8fr_1.2fr] md:items-end">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-normal text-[#9cebd6]">
              Motivation
            </p>
            <h2 className="mt-4 max-w-xl font-serif text-[2.55rem] leading-[0.95] tracking-normal text-white md:text-[3.45rem]">
              Accountability requires objective numbers.
            </h2>
          </div>
          <p className="max-w-2xl text-lg leading-8 text-white/58">
            Intent is not about calendar visibility—it's about using metrics to remain accountable.
            When you track how productive you actually are, you can stop arguing with vibes and start
            making decisions based on the evidence of your own output.
          </p>
        </div>
      </section>

      <section className="px-5 py-16 md:px-8 md:py-20">
        <div className="mx-auto max-w-7xl">
          <div className="grid gap-4 md:grid-cols-3">
            {principles.map((principle) => (
              <article
                key={principle.title}
                className="rounded-lg border border-white/9 bg-white/[0.035] p-6 shadow-[0_22px_80px_-60px_rgba(20,184,166,0.55)] backdrop-blur-xl md:p-7"
              >
                <p className="text-[11px] font-semibold uppercase tracking-normal text-[#9cebd6]/80">
                  {principle.label}
                </p>
                <h3 className="mt-5 font-serif text-[1.75rem] leading-[1.02] text-white">
                  {principle.title}
                </h3>
                <p className="mt-4 text-sm leading-7 text-white/55">{principle.body}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="px-5 pb-20 md:px-8 md:pb-24">
        <div className="mx-auto max-w-7xl rounded-lg border border-[#9cebd6]/16 bg-[linear-gradient(135deg,_rgba(20,184,166,0.13),_rgba(255,255,255,0.03))] p-6 text-center shadow-[0_30px_120px_-75px_rgba(156,235,214,0.65)] backdrop-blur-xl md:p-10">
          <p className="mx-auto inline-flex items-center gap-2 text-[11px] font-semibold uppercase tracking-normal text-[#9cebd6]">
            <Sparkles className="size-3.5" />
            Early access
          </p>
          <h2 className="mx-auto mt-4 max-w-3xl font-serif text-[2.45rem] leading-[0.95] text-white md:text-[3.4rem]">
            Build a feedback loop around the way you actually spend time.
          </h2>
          <p className="mx-auto mt-5 max-w-2xl text-base leading-8 text-white/58">
            Join the waitlist or inspect the public demo with realistic data before connecting your own calendar.
          </p>
          <div className="mx-auto mt-9 flex max-w-[35rem] justify-center">
            <InlineWaitlistForm align="center" caption="No spam. Just an invite when the next cohort opens." />
          </div>
        </div>
      </section>
    </main>
  );
}

function ProductSignalPreview() {
  return (
    <div className="relative z-10 mx-auto mt-16 max-w-5xl overflow-hidden rounded-lg border border-white/10 bg-[#081b18]/88 p-4 shadow-[0_40px_160px_-95px_rgba(156,235,214,0.9)] backdrop-blur-xl md:mt-20 md:p-5">
      <div className="grid gap-4 lg:grid-cols-[0.95fr_1.05fr]">
        <div className="rounded-lg border border-white/8 bg-white/[0.035] p-5">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-normal text-white/42">
                Today
              </p>
              <h2 className="mt-2 font-serif text-3xl text-white">Intent ledger</h2>
            </div>
            <CalendarDays className="size-6 text-[#9cebd6]" />
          </div>

          <div className="mt-7 space-y-3">
            {sampleRows.map((row) => (
              <div
                key={`${row.time}:${row.title}`}
                className="grid grid-cols-[3.4rem_1fr_auto] items-center gap-3 rounded-lg border border-white/7 bg-[#061512]/62 px-4 py-3"
              >
                <span className="font-mono text-xs text-white/38">{row.time}</span>
                <div className="min-w-0">
                  <p className="truncate text-sm font-semibold text-white/86">{row.title}</p>
                  <div className="mt-2 h-1.5 rounded-full bg-white/7">
                    <div className={`h-full rounded-full ${row.tone}`} style={{ width: `${Number(row.score) * 10}%` }} />
                  </div>
                </div>
                <span className="rounded-full bg-white/7 px-2.5 py-1 text-xs font-semibold text-white/70">
                  {row.score}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="grid gap-4">
          <div className="rounded-lg border border-white/8 bg-white/[0.035] p-5">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-normal text-white/42">
                  Composite score
                </p>
                <p className="mt-2 font-serif text-5xl font-semibold text-[#9cebd6]">7.8</p>
              </div>
              <LineChart className="size-7 text-[#9cebd6]" />
            </div>
            <div className="mt-6 grid grid-cols-3 gap-2">
              {["Focus", "Energy", "Intent"].map((label, index) => (
                <div key={label} className="rounded-lg bg-[#061512]/62 p-3">
                  <p className="text-[10px] uppercase tracking-normal text-white/36">{label}</p>
                  <p className="mt-2 text-lg font-semibold text-white">
                    {[8.4, 7.1, 8.0][index]}
                  </p>
                </div>
              ))}
            </div>
          </div>

          <div className="rounded-lg border border-white/8 bg-white/[0.035] p-5">
            <p className="text-[11px] font-semibold uppercase tracking-normal text-white/42">
              What changed
            </p>
            <div className="mt-5 space-y-3">
              {[
                "Strategy mornings score 18% higher than afternoon planning.",
                "Context switching is the strongest predictor of low energy.",
                "Two-hour focus blocks are producing the best purpose scores.",
              ].map((item) => (
                <div key={item} className="flex gap-3 text-sm leading-6 text-white/62">
                  <Check className="mt-1 size-4 shrink-0 text-[#9cebd6]" />
                  <span>{item}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
