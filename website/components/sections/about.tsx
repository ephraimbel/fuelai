"use client";

import { FadeIn, FadeInScale, StaggerContainer, StaggerItem } from "@/components/animate";
import Image from "next/image";

export function About() {
  return (
    <section id="about" className="py-24 md:py-32 bg-cloud/40">
      <div className="max-w-[1120px] mx-auto px-6">
        <div className="flex flex-col md:flex-row items-center gap-12 md:gap-20">
          <div className="flex-1">
            <FadeIn>
              <p className="text-flame text-[13px] font-semibold tracking-wide uppercase mb-5">
                About Fuel
              </p>
            </FadeIn>
            <FadeIn delay={0.08}>
              <h2 className="font-[family-name:var(--font-serif)] text-[2rem] md:text-[2.75rem] leading-[1.08] text-ink mb-6">
                <em className="text-flame not-italic font-[family-name:var(--font-serif)] italic">Uncover</em> Nutritional
                <br />
                Gaps In Your Diet
              </h2>
            </FadeIn>
            <FadeIn delay={0.16}>
              <p className="text-stone text-[15px] leading-[1.75] mb-4">
                Most calorie trackers stop at counting. They log what you eat,
                but they don&apos;t tell you what your body is missing. Fuel goes
                further — analyzing your meals to uncover deficiencies in fiber,
                sugar, sodium, and other key nutrients your diet may be lacking.
              </p>
            </FadeIn>
            <FadeIn delay={0.24}>
              <p className="text-stone text-[15px] leading-[1.75]">
                Every analysis includes confidence levels, serving assumptions,
                and health insights — so you know exactly how reliable the data
                is. It&apos;s not just about tracking — it&apos;s about
                optimizing what you eat.
              </p>
            </FadeIn>
          </div>

          <FadeInScale delay={0.15} className="flex-shrink-0">
            <div className="grid grid-cols-2 gap-3 w-[280px] md:w-[340px]">
              {[
                { src: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=340&h=340&fit=crop&q=75", alt: "Fresh salad", radius: "rounded-bl-[48px]" },
                { src: "https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=340&h=340&fit=crop&q=75", alt: "Healthy breakfast", radius: "rounded-br-[48px]" },
                { src: "https://images.unsplash.com/photo-1547592180-85f173990554?w=340&h=340&fit=crop&q=75", alt: "Fruits and vegetables", radius: "rounded-tl-[48px]" },
                { src: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=340&h=340&fit=crop&q=75", alt: "Grilled dish", radius: "rounded-tr-[48px]" },
              ].map((img) => (
                <div key={img.alt} className={`aspect-square rounded-[20px] ${img.radius} overflow-hidden relative`}>
                  <Image src={img.src} alt={img.alt} fill className="object-cover" sizes="170px" />
                </div>
              ))}
            </div>
          </FadeInScale>
        </div>

        <StaggerContainer className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-20" stagger={0.1}>
          {[
            { num: "600+", label: "USDA-Calibrated Foods" },
            { num: "<3s", label: "Photo Analysis" },
            { num: "24/7", label: "AI Nutritionist Chat" },
            { num: "RAG", label: "On-Device Search" },
          ].map((s) => (
            <StaggerItem key={s.label}>
              <div className="bg-warm-white rounded-[20px] py-8 px-4 text-center">
                <div className="font-[family-name:var(--font-serif)] text-[1.8rem] md:text-[2.2rem] text-flame mb-1 leading-none">
                  {s.num}
                </div>
                <div className="text-stone text-[12px] font-medium mt-2">{s.label}</div>
              </div>
            </StaggerItem>
          ))}
        </StaggerContainer>
      </div>
    </section>
  );
}
