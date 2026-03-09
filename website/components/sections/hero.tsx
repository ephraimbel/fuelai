"use client";

import { FadeIn, FadeInScale } from "@/components/animate";
import { motion } from "framer-motion";
import Image from "next/image";

const ease = [0.25, 0.1, 0.25, 1] as const;

const FOOD_IMAGE =
  "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=900&h=900&fit=crop&crop=center&q=90";

function MacroTag({ label, value, color, className = "", delay = 0 }: {
  label: string;
  value: string;
  color: string;
  className?: string;
  delay?: number;
}) {
  return (
    <motion.div
      className={`absolute bg-white rounded-2xl px-4 py-3 flex items-center gap-3 shadow-[0_4px_24px_rgba(28,25,23,0.08)] z-10 select-none ${className}`}
      initial={{ opacity: 0, scale: 0.9 }}
      whileInView={{ opacity: 1, scale: 1 }}
      viewport={{ once: true }}
      transition={{ duration: 0.6, ease, delay: 0.8 + delay * 0.12 }}
    >
      <div
        className="w-8 h-8 rounded-[10px] flex items-center justify-center"
        style={{ backgroundColor: `${color}14` }}
      >
        <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: color }} />
      </div>
      <div className="flex flex-col">
        <span className="text-[11px] text-stone font-medium leading-none mb-0.5">{label}</span>
        <span className="text-[15px] font-bold text-ink leading-none">{value}</span>
      </div>
    </motion.div>
  );
}

export function Hero() {
  return (
    <section id="hero" className="pt-28 pb-8 md:pt-40 md:pb-16">
      <div className="max-w-[1120px] mx-auto px-6 text-center">
        <FadeIn delay={0.1} y={16}>
          <div className="inline-flex items-center gap-2 bg-flame-soft text-flame text-[13px] font-semibold px-5 py-2 rounded-full mb-8">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none">
              <path d="M12 23c-4.97 0-9-4.03-9-9 0-5.52 4.03-11 9-14 4.97 3 9 8.48 9 14 0 4.97-4.03 9-9 9z" fill="#FF4D00" />
              <path d="M12 23c-2.21 0-4-1.79-4-4 0-2.76 2-5.5 4-7 2 1.5 4 4.24 4 7 0 2.21-1.79 4-4 4z" fill="#FFB74D" />
            </svg>
            <span>AI-Powered Nutrition</span>
          </div>
        </FadeIn>

        <FadeIn delay={0.2} y={24}>
          <h1 className="font-[family-name:var(--font-serif)] text-[2.5rem] md:text-[3.75rem] leading-[1.06] text-ink mb-5 max-w-[600px] mx-auto">
            Know What You Eat.
            <br />
            <span className="text-flame">Know What You Need.</span>
          </h1>
        </FadeIn>

        <FadeIn delay={0.3}>
          <p className="text-stone text-[15px] md:text-[16px] max-w-[440px] mx-auto mb-10 leading-[1.75]">
            Fuel doesn&apos;t just count calories — it uncovers nutritional gaps
            your diet has been hiding. Powered by AI and 600+ USDA-calibrated foods.
          </p>
        </FadeIn>

        <FadeIn delay={0.4}>
          <a
            href="#"
            className="group inline-flex items-center gap-3 bg-ink text-warm-white px-7 py-4 rounded-2xl hover:bg-ink-soft transition-colors duration-200"
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

        {/* ===== HERO VISUAL ===== */}
        <FadeInScale delay={0.5} className="mt-16 md:mt-24">
          <div className="relative mx-auto w-full" style={{ maxWidth: 560, aspectRatio: "1 / 1" }}>

            {/* Circular plate with food */}
            <motion.div
              className="absolute inset-[6%] rounded-full overflow-hidden shadow-[0_40px_80px_rgba(28,25,23,0.12)]"
              initial={{ opacity: 0, scale: 0.95 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.8, ease, delay: 0.6 }}
            >
              <Image src={FOOD_IMAGE} alt="Healthy meal" fill className="object-cover" priority sizes="(max-width: 768px) 85vw, 500px" />
            </motion.div>

            {/* iPhone 15 Pro — centered on plate */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-10">
              <motion.div
                initial={{ y: 30, opacity: 0 }}
                whileInView={{ y: 0, opacity: 1 }}
                viewport={{ once: true }}
                transition={{ duration: 0.8, ease, delay: 0.7 }}
              >
                <div className="w-[160px] h-[328px] md:w-[200px] md:h-[410px] rounded-[34px] md:rounded-[42px] bg-[#1d1d1f] p-[2.5px] md:p-[3px] shadow-[0_40px_80px_rgba(0,0,0,0.3)]">
                  <div className="w-full h-full rounded-[32px] md:rounded-[39px] bg-black overflow-hidden relative flex flex-col">

                    {/* Dynamic Island */}
                    <div className="absolute top-[9px] md:top-[11px] left-1/2 -translate-x-1/2 w-[68px] md:w-[88px] h-[20px] md:h-[24px] bg-black rounded-full z-30" />

                    <div className="flex-1 flex flex-col m-[1.5px] md:m-[2px] rounded-[30px] md:rounded-[37px] overflow-hidden">

                      {/* Status bar */}
                      <div className="flex justify-between items-center px-5 pt-[13px] md:pt-[15px] pb-1 text-white/80 text-[9px] md:text-[10px] font-semibold bg-black/40 backdrop-blur-md relative z-20">
                        <span className="w-8 tabular-nums">9:41</span>
                        <div className="flex gap-[3px] items-center">
                          <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M1 9l2 2c4.97-4.97 13.03-4.97 18 0l2-2C16.93 2.93 7.08 2.93 1 9zm8 8l3 3 3-3c-1.65-1.66-4.34-1.66-6 0zm-4-4l2 2c2.76-2.76 7.24-2.76 10 0l2-2C15.14 9.14 8.87 9.14 5 13z"/></svg>
                          <svg width="13" height="10" viewBox="0 0 28 14" fill="currentColor"><rect x="0.5" y="1" width="22" height="12" rx="3" stroke="currentColor" strokeWidth="1.5" fill="none" opacity="0.35"/><rect x="3" y="3.5" width="15" height="7" rx="1.5" fill="currentColor"/><rect x="23.5" y="4.5" width="2.5" height="5" rx="1" fill="currentColor" opacity="0.4"/></svg>
                        </div>
                      </div>

                      {/* App header */}
                      <div className="flex justify-between items-center px-3.5 py-1.5 bg-black/30 backdrop-blur-md relative z-20">
                        <div className="w-6 h-6 rounded-full bg-white/10 flex items-center justify-center">
                          <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg>
                        </div>
                        <span className="font-[family-name:var(--font-serif)] text-white/80 text-[11px] md:text-[12px] tracking-[1.5px] lowercase">camera</span>
                        <div className="w-6 h-6 rounded-full bg-white/10 flex items-center justify-center">
                          <svg width="8" height="8" viewBox="0 0 24 24" fill="white" opacity="0.8"><path d="M7 2v11h3v9l7-12h-4l4-8z"/></svg>
                        </div>
                      </div>

                      {/* Camera view */}
                      <div className="flex-1 relative">
                        <Image src={FOOD_IMAGE} alt="Scanning meal" fill className="object-cover" priority sizes="210px" />

                        {/* Minimal scan frame */}
                        <div className="absolute top-[14%] left-[10%] w-[80%] h-[56%]">
                          {[
                            "top-0 left-0 border-t-2 border-l-2 rounded-tl",
                            "top-0 right-0 border-t-2 border-r-2 rounded-tr",
                            "bottom-0 left-0 border-b-2 border-l-2 rounded-bl",
                            "bottom-0 right-0 border-b-2 border-r-2 rounded-br",
                          ].map((c) => (
                            <div key={c} className={`absolute w-[16px] h-[16px] border-white/70 ${c}`} />
                          ))}
                        </div>
                      </div>

                      {/* Shutter */}
                      <div className="flex items-center justify-center gap-7 py-2.5 pb-4 md:py-3 md:pb-5 bg-black/60 backdrop-blur-xl relative z-20">
                        <div className="w-7 h-7 rounded-full bg-white/10 flex items-center justify-center">
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="white" opacity="0.7"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg>
                        </div>
                        <div className="w-[44px] h-[44px] md:w-[52px] md:h-[52px] rounded-full border-[2px] border-white/30 flex items-center justify-center">
                          <div className="w-[36px] h-[36px] md:w-[42px] md:h-[42px] rounded-full bg-white" />
                        </div>
                        <div className="w-7 h-7" />
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            </div>

            {/* Static macro tags — clean, no bobbing */}
            <MacroTag label="Calories" value="600 kcal" color="#FF4D00" className="top-[6%] left-[-2%] md:top-[8%] md:left-[0%]" delay={0} />
            <MacroTag label="Carbs" value="100g" color="#22C55E" className="top-[6%] right-[-2%] md:top-[8%] md:right-[0%]" delay={1} />
            <MacroTag label="Fat" value="30g" color="#3B82F6" className="bottom-[6%] left-[-2%] md:bottom-[8%] md:left-[0%]" delay={2} />
            <MacroTag label="Protein" value="100g" color="#FFA726" className="bottom-[6%] right-[-2%] md:bottom-[8%] md:right-[0%]" delay={3} />

            {/* Subtle connector lines — desktop only */}
            <svg className="absolute inset-0 w-full h-full z-[5] pointer-events-none hidden md:block opacity-40" viewBox="0 0 560 560" fill="none" preserveAspectRatio="xMidYMid meet">
              <path d="M90 80 Q 160 140 210 190" stroke="#D8D2CC" strokeWidth="1" strokeDasharray="4 4"/>
              <path d="M470 80 Q 400 140 350 190" stroke="#D8D2CC" strokeWidth="1" strokeDasharray="4 4"/>
              <path d="M90 480 Q 160 420 210 370" stroke="#D8D2CC" strokeWidth="1" strokeDasharray="4 4"/>
              <path d="M470 480 Q 400 420 350 370" stroke="#D8D2CC" strokeWidth="1" strokeDasharray="4 4"/>
            </svg>
          </div>
        </FadeInScale>
      </div>
    </section>
  );
}
