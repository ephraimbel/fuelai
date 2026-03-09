"use client";

import Link from "next/link";

export function Footer() {
  return (
    <footer className="bg-ink text-fog">
      <div className="max-w-[1120px] mx-auto px-6 pt-16 pb-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-10 mb-14">
          <div className="md:col-span-1">
            <Link
              href="/"
              className="flex items-center gap-2 mb-3"
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <defs>
                  <linearGradient id="flame-grad-footer" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stopColor="#FF4D00" />
                    <stop offset="100%" stopColor="#FF6B2B" />
                  </linearGradient>
                </defs>
                <path d="M12 23c-4.97 0-9-4.03-9-9 0-5.52 4.03-11 9-14 4.97 3 9 8.48 9 14 0 4.97-4.03 9-9 9z" fill="url(#flame-grad-footer)" />
                <path d="M12 23c-2.21 0-4-1.79-4-4 0-2.76 2-5.5 4-7 2 1.5 4 4.24 4 7 0 2.21-1.79 4-4 4z" fill="#FFB74D" />
              </svg>
              <span className="font-[family-name:var(--font-serif)] text-xl tracking-[3px] text-warm-white lowercase">fuel</span>
            </Link>
            <p className="text-sm leading-relaxed">
              AI-powered nutrition tracking that actually understands your food.
            </p>
          </div>

          <div>
            <h4 className="text-warm-white text-[11px] font-semibold uppercase tracking-[0.15em] mb-5">
              Product
            </h4>
            <div className="flex flex-col gap-3">
              <Link href="/#features" className="text-[13px] hover:text-warm-white transition-colors duration-200">Features</Link>
              <Link href="/#how-it-works" className="text-[13px] hover:text-warm-white transition-colors duration-200">How It Works</Link>
              <Link href="/#about" className="text-[13px] hover:text-warm-white transition-colors duration-200">About</Link>
            </div>
          </div>

          <div>
            <h4 className="text-warm-white text-[11px] font-semibold uppercase tracking-[0.15em] mb-5">
              Legal
            </h4>
            <div className="flex flex-col gap-3">
              <Link href="/privacy" className="text-[13px] hover:text-warm-white transition-colors duration-200">Privacy Policy</Link>
              <Link href="/terms" className="text-[13px] hover:text-warm-white transition-colors duration-200">Terms of Use</Link>
              <Link href="/support" className="text-[13px] hover:text-warm-white transition-colors duration-200">Support</Link>
            </div>
          </div>

          <div>
            <h4 className="text-warm-white text-[11px] font-semibold uppercase tracking-[0.15em] mb-5">
              Download
            </h4>
            <Link
              href="#"
              className="inline-flex items-center gap-2.5 bg-white/5 border border-white/10 text-warm-white px-4 py-2.5 rounded-xl text-sm hover:bg-white/10 transition-colors duration-200"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
              </svg>
              <div className="text-left">
                <div className="text-[9px] opacity-50 leading-none">Download on the</div>
                <div className="text-[13px] font-semibold leading-tight">App Store</div>
              </div>
            </Link>
          </div>
        </div>

        <div className="border-t border-white/8 pt-6 flex flex-col md:flex-row justify-between items-center gap-4">
          <p className="text-[12px]">&copy; 2025 Fuel. All rights reserved.</p>
          <div className="flex gap-6">
            <Link href="/privacy" className="text-[12px] hover:text-warm-white transition-colors duration-200">Privacy</Link>
            <Link href="/terms" className="text-[12px] hover:text-warm-white transition-colors duration-200">Terms</Link>
            <Link href="/support" className="text-[12px] hover:text-warm-white transition-colors duration-200">Support</Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
