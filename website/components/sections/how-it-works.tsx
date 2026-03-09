"use client";

import { FadeIn, StaggerContainer, StaggerItem } from "@/components/animate";

export function HowItWorks() {
  return (
    <section id="how-it-works" className="py-24 md:py-32">
      <div className="max-w-[1120px] mx-auto px-6">
        {/* Divider */}
        <div className="section-divider mb-24 md:mb-32" />

        <FadeIn className="text-center mb-16 md:mb-20">
          <p className="text-flame text-[13px] font-semibold tracking-wide uppercase mb-5">
            How It Works
          </p>
          <h2 className="font-[family-name:var(--font-serif)] text-[2rem] md:text-[2.75rem] leading-[1.08] text-ink mb-4">
            Three Steps to
            <br />
            Better Nutrition
          </h2>
          <p className="text-stone text-[15px] max-w-[420px] mx-auto leading-[1.75]">
            Nourish your body, fuel your life — one smart choice at a time.
          </p>
        </FadeIn>

        <StaggerContainer className="grid grid-cols-1 md:grid-cols-3 gap-5" stagger={0.12}>
          {[
            {
              step: "01",
              title: "Snap Your Meal",
              desc: "Open Fuel, tap the camera, and snap a photo of your food. Our AI identifies every item on your plate — no manual searching required.",
            },
            {
              step: "02",
              title: "AI Analyzes Instantly",
              desc: "Fuel breaks down calories, protein, carbs, fat, and micronutrients in seconds — calibrated against 600+ foods in our USDA-backed database.",
            },
            {
              step: "03",
              title: "Uncover Gaps",
              desc: "See your eating patterns over days and weeks. Fuel reveals vitamins, minerals, and nutrients you're consistently missing — not just macros.",
            },
          ].map((item) => (
            <StaggerItem key={item.step}>
              <div className="bg-cloud/50 rounded-[20px] p-8 md:p-10 h-full hover:bg-cloud transition-colors duration-300">
                <div className="text-[11px] font-semibold text-flame tracking-[0.15em] uppercase mb-6">
                  Step {item.step}
                </div>
                <h3 className="font-[family-name:var(--font-serif)] text-[1.2rem] text-ink mb-3 leading-snug">
                  {item.title}
                </h3>
                <p className="text-stone text-[14px] leading-[1.7]">
                  {item.desc}
                </p>
              </div>
            </StaggerItem>
          ))}
        </StaggerContainer>
      </div>
    </section>
  );
}
