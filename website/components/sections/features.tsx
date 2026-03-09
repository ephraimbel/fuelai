"use client";

import { FadeIn } from "@/components/animate";
import { Phone, PhoneScreen } from "@/components/phone";
import Image from "next/image";

function FeatureRow({
  title,
  desc,
  children,
  reverse = false,
  delay = 0,
}: {
  title: string;
  desc: string;
  children: React.ReactNode;
  reverse?: boolean;
  delay?: number;
}) {
  return (
    <FadeIn delay={delay}>
      <div
        className={`flex flex-col ${
          reverse ? "md:flex-row-reverse" : "md:flex-row"
        } items-center gap-12 md:gap-20`}
      >
        <div className="flex-1 max-w-md">
          <h3 className="font-[family-name:var(--font-serif)] text-[1.5rem] md:text-[2rem] text-ink mb-4 leading-[1.15]">
            {title}
          </h3>
          <p className="text-stone text-[15px] leading-[1.75]">{desc}</p>
        </div>
        <div className="flex-shrink-0">{children}</div>
      </div>
    </FadeIn>
  );
}

function MacroDot({ color, label, value }: { color: string; label: string; value: string }) {
  return (
    <div className="flex items-center gap-1.5 text-[10px]">
      <div className="w-[6px] h-[6px] rounded-full" style={{ background: color }} />
      <span className="text-stone">{label}</span>
      <span className="font-bold text-ink ml-0.5">{value}</span>
    </div>
  );
}

export function Features() {
  return (
    <section id="features" className="py-24 md:py-32">
      <div className="max-w-[1120px] mx-auto px-6">
        {/* Divider */}
        <div className="section-divider mb-24 md:mb-32" />

        <FadeIn className="text-center mb-20 md:mb-28">
          <p className="text-flame text-[13px] font-semibold tracking-wide uppercase mb-5">
            Features
          </p>
          <h2 className="font-[family-name:var(--font-serif)] text-[2rem] md:text-[2.75rem] leading-[1.08] text-ink">
            Everything You Need to
            <br />
            <span className="text-flame">Eat Smarter</span>
          </h2>
        </FadeIn>

        <div className="space-y-24 md:space-y-32">
          {/* Feature 1: Snap & Track */}
          <FeatureRow
            title="Snap & Track"
            desc="Point your camera at any meal and Fuel instantly identifies every food item, estimates portions, and logs calories, macros, fiber, sugar, and sodium — all in under 3 seconds."
          >
            <Phone small>
              <PhoneScreen>
                <div className="flex justify-between items-center mb-3">
                  <span className="font-bold text-xs text-ink">Today</span>
                  <span className="text-stone text-[10px]">Mon, Mar 3</span>
                </div>
                <div className="flex justify-center mb-3">
                  <div className="relative w-[80px] h-[80px]">
                    <svg viewBox="0 0 100 100" className="w-full h-full">
                      <circle cx="50" cy="50" r="40" fill="none" stroke="#E8E2DC" strokeWidth="7" />
                      <circle cx="50" cy="50" r="40" fill="none" stroke="#FF4D00" strokeWidth="7" strokeDasharray="172 80" strokeLinecap="round" transform="rotate(-90 50 50)" />
                      <circle cx="50" cy="50" r="31" fill="none" stroke="#E8E2DC" strokeWidth="7" />
                      <circle cx="50" cy="50" r="31" fill="none" stroke="#22C55E" strokeWidth="7" strokeDasharray="130 65" strokeLinecap="round" transform="rotate(-90 50 50)" />
                    </svg>
                    <div className="absolute inset-0 flex flex-col items-center justify-center">
                      <span className="text-sm font-extrabold text-ink leading-none">1,240</span>
                      <span className="text-[8px] text-stone">of 2,100</span>
                    </div>
                  </div>
                </div>
                <div className="flex justify-around mb-3">
                  <MacroDot color="#8B5CF6" label="Protein" value="85g" />
                  <MacroDot color="#F59E0B" label="Carbs" value="120g" />
                  <MacroDot color="#3B82F6" label="Fat" value="45g" />
                </div>
                <div className="bg-flame-soft text-flame text-[9px] font-semibold text-center py-1.5 rounded-lg">
                  860 remaining
                </div>
              </PhoneScreen>
            </Phone>
          </FeatureRow>

          {/* Feature 2: AI Chat */}
          <FeatureRow
            title="AI Chat Nutritionist"
            desc="Got questions about your diet? Chat with Fuel's AI nutritionist 24/7. Ask about meal suggestions, nutrient timing, food swaps — it knows your history and personalizes every answer."
            reverse
            delay={0.05}
          >
            <Phone small>
              <PhoneScreen className="!pt-6 !px-2.5 flex flex-col gap-2">
                <div className="flex items-start gap-1.5">
                  <div className="w-5 h-5 rounded-full bg-flame flex items-center justify-center flex-shrink-0 mt-0.5">
                    <svg width="8" height="8" viewBox="0 0 24 24" fill="white"><path d="M12 23c-4.97 0-9-4.03-9-9 0-5.52 4.03-11 9-14 4.97 3 9 8.48 9 14 0 4.97-4.03 9-9 9z"/></svg>
                  </div>
                  <div className="bg-cloud rounded-2xl rounded-tl-sm px-3 py-2 max-w-[85%]">
                    <p className="text-[9px] text-ink leading-[1.5]">How can I help with your nutrition today?</p>
                  </div>
                </div>
                <div className="flex justify-end">
                  <div className="bg-gradient-to-br from-ink to-ink-soft rounded-2xl rounded-br-sm px-3 py-2 max-w-[85%]">
                    <p className="text-[9px] text-white leading-[1.5]">I&apos;m low on protein today. What should I eat?</p>
                  </div>
                </div>
                <div className="flex items-start gap-1.5">
                  <div className="w-5 h-5 rounded-full bg-flame flex items-center justify-center flex-shrink-0 mt-0.5">
                    <svg width="8" height="8" viewBox="0 0 24 24" fill="white"><path d="M12 23c-4.97 0-9-4.03-9-9 0-5.52 4.03-11 9-14 4.97 3 9 8.48 9 14 0 4.97-4.03 9-9 9z"/></svg>
                  </div>
                  <div className="bg-cloud rounded-2xl rounded-tl-sm px-3 py-2 max-w-[85%]">
                    <p className="text-[9px] text-ink leading-[1.5]">Based on your log, try grilled chicken (31g protein) or Greek yogurt (17g). Both would hit your 120g target!</p>
                  </div>
                </div>
                <div className="mt-auto flex gap-1.5 items-center bg-cloud rounded-full px-3 py-1.5">
                  <span className="text-[8px] text-fog flex-1">Ask anything...</span>
                  <div className="w-5 h-5 rounded-full bg-ink flex items-center justify-center">
                    <svg width="8" height="8" viewBox="0 0 24 24" fill="white"><path d="M2 21l21-9L2 3v7l15 2-15 2v7z"/></svg>
                  </div>
                </div>
              </PhoneScreen>
            </Phone>
          </FeatureRow>

          {/* Feature 3: Search & Barcode */}
          <FeatureRow
            title="Search or Scan Barcodes"
            desc="Don't have a photo? Type any food and Fuel's RAG-powered search finds it instantly from 600+ items with fuzzy matching. Or scan a barcode for packaged foods — exact data, zero effort."
            delay={0.05}
          >
            <Phone small>
              <PhoneScreen>
                <div className="flex justify-between items-center mb-3">
                  <span className="font-bold text-xs text-ink">Search</span>
                </div>
                <div className="bg-cloud rounded-xl px-3 py-2 mb-3 flex items-center gap-2">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#8C8279" strokeWidth="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
                  <span className="text-[10px] text-ink font-medium">grilled chicken</span>
                </div>
                {[
                  { name: "Grilled Chicken Breast", cal: "165 kcal", conf: "high", img: "https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=80&h=80&fit=crop&q=60" },
                  { name: "Chicken Caesar Salad", cal: "320 kcal", conf: "medium", img: "https://images.unsplash.com/photo-1512852939750-1305098529bf?w=80&h=80&fit=crop&q=60" },
                  { name: "Chicken Rice Bowl", cal: "480 kcal", conf: "high", img: "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=80&h=80&fit=crop&q=60" },
                ].map((item, i) => (
                  <div key={i} className="flex gap-2 bg-cloud rounded-xl p-2 mb-1.5 items-center">
                    <div className="w-9 h-9 rounded-[8px] overflow-hidden flex-shrink-0 relative">
                      <Image src={item.img} alt={item.name} fill className="object-cover" sizes="36px" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="text-[9px] font-semibold text-ink truncate">{item.name}</div>
                      <div className="flex gap-2 mt-0.5 items-center">
                        <span className="text-[8px] text-stone">{item.cal}</span>
                        <span className={`text-[7px] font-semibold px-1.5 py-0.5 rounded-full ${item.conf === "high" ? "bg-[#22C55E]/10 text-[#22C55E]" : "bg-[#F59E0B]/10 text-[#F59E0B]"}`}>{item.conf}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </PhoneScreen>
            </Phone>
          </FeatureRow>
        </div>
      </div>
    </section>
  );
}
