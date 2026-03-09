"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { motion, AnimatePresence } from "framer-motion";

export function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 30);
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const links = [
    { label: "How it works", href: "/#how-it-works" },
    { label: "Features", href: "/#features" },
    { label: "About", href: "/#about" },
  ];

  return (
    <motion.nav
      initial={{ y: -20, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, ease: [0.25, 0.1, 0.25, 1] }}
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled
          ? "bg-warm-white/90 backdrop-blur-xl shadow-[0_1px_0_rgba(28,25,23,0.06)]"
          : ""
      }`}
    >
      <div className="max-w-[1120px] mx-auto px-6 flex items-center justify-between h-[64px]">
        <Link
          href="/"
          className="flex items-center gap-2"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
            <defs>
              <linearGradient id="flame-grad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#FF4D00" />
                <stop offset="100%" stopColor="#FF6B2B" />
              </linearGradient>
            </defs>
            <path d="M12 23c-4.97 0-9-4.03-9-9 0-5.52 4.03-11 9-14 4.97 3 9 8.48 9 14 0 4.97-4.03 9-9 9z" fill="url(#flame-grad)" />
            <path d="M12 23c-2.21 0-4-1.79-4-4 0-2.76 2-5.5 4-7 2 1.5 4 4.24 4 7 0 2.21-1.79 4-4 4z" fill="#FFB74D" />
          </svg>
          <span className="font-[family-name:var(--font-serif)] text-[1.15rem] tracking-[3px] text-ink lowercase">fuel</span>
        </Link>

        {/* Desktop */}
        <div className="hidden md:flex items-center gap-10">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className="text-stone text-[13px] font-medium hover:text-ink transition-colors duration-200"
            >
              {l.label}
            </Link>
          ))}
        </div>

        <Link
          href="#"
          className="hidden md:inline-flex items-center gap-2 bg-ink text-warm-white text-[13px] font-medium px-5 py-2.5 rounded-full hover:bg-ink-soft transition-colors duration-200"
        >
          Download
        </Link>

        {/* Mobile hamburger */}
        <button
          onClick={() => setMenuOpen(!menuOpen)}
          className="md:hidden flex flex-col gap-[5px] p-2 -mr-2"
          aria-label="Menu"
        >
          <motion.span
            animate={menuOpen ? { rotate: 45, y: 7 } : { rotate: 0, y: 0 }}
            transition={{ duration: 0.2 }}
            className="block w-[18px] h-[1.5px] bg-ink origin-center"
          />
          <motion.span
            animate={menuOpen ? { opacity: 0 } : { opacity: 1 }}
            transition={{ duration: 0.15 }}
            className="block w-[18px] h-[1.5px] bg-ink"
          />
          <motion.span
            animate={menuOpen ? { rotate: -45, y: -7 } : { rotate: 0, y: 0 }}
            transition={{ duration: 0.2 }}
            className="block w-[18px] h-[1.5px] bg-ink origin-center"
          />
        </button>
      </div>

      {/* Mobile menu */}
      <AnimatePresence>
        {menuOpen && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.25, ease: [0.25, 0.1, 0.25, 1] }}
            className="md:hidden overflow-hidden bg-warm-white/98 backdrop-blur-xl border-t border-mist/30"
          >
            <div className="px-6 pb-6 pt-3 flex flex-col gap-1">
              {links.map((l) => (
                <Link
                  key={l.href}
                  href={l.href}
                  onClick={() => setMenuOpen(false)}
                  className="block text-stone text-[14px] font-medium hover:text-ink transition-colors py-2.5"
                >
                  {l.label}
                </Link>
              ))}
              <div className="pt-3">
                <Link
                  href="#"
                  className="inline-flex justify-center w-full bg-ink text-warm-white text-[13px] font-medium px-5 py-2.5 rounded-full"
                >
                  Download
                </Link>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.nav>
  );
}
