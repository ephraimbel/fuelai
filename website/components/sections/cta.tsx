"use client";

import { FadeIn } from "@/components/animate";

export function CTA() {
  return (
    <section className="py-24 md:py-32">
      <div className="max-w-[900px] mx-auto px-6 text-center">
        <FadeIn>
          <p className="text-flame text-[13px] font-semibold tracking-wide uppercase mb-5">
            Get Started
          </p>
          <h2 className="font-[family-name:var(--font-serif)] text-[2rem] md:text-[2.75rem] text-ink mb-4 leading-[1.08]">
            Start Tracking Smarter
          </h2>
          <p className="text-stone text-[15px] md:text-[16px] max-w-md mx-auto mb-10 leading-[1.75]">
            Snap a photo, get instant AI analysis, and finally understand
            what your body needs — not just what you ate.
          </p>
          <a
            href="#"
            className="inline-flex items-center gap-3 bg-ink text-warm-white px-7 py-4 rounded-2xl hover:bg-ink-soft transition-colors duration-200"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" className="opacity-90">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
            </svg>
            <div className="text-left">
              <div className="text-[9px] opacity-50 leading-none font-normal">Download on the</div>
              <div className="text-[15px] font-semibold leading-tight">App Store</div>
            </div>
          </a>
        </FadeIn>
      </div>
    </section>
  );
}
