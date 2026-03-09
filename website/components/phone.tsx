"use client";

import type { ReactNode } from "react";

export function Phone({
  children,
  className = "",
  small = false,
}: {
  children: ReactNode;
  className?: string;
  small?: boolean;
}) {
  const outer = small
    ? "w-[175px] h-[355px] rounded-[32px] p-[2.5px]"
    : "w-[230px] h-[470px] rounded-[42px] p-[3px]";
  const inner = small ? "rounded-[30px]" : "rounded-[39px]";
  const notch = small
    ? "w-[56px] h-[16px] top-[6px]"
    : "w-[72px] h-[20px] top-[8px]";

  return (
    <div
      className={`${outer} bg-[#1d1d1f] shadow-[0_16px_48px_rgba(28,25,23,0.12)] ${className}`}
    >
      <div className={`w-full h-full ${inner} bg-black overflow-hidden relative`}>
        <div
          className={`absolute ${notch} left-1/2 -translate-x-1/2 bg-black rounded-full z-20`}
        />
        <div className={`${inner} h-full bg-warm-white overflow-hidden`}>
          {children}
        </div>
      </div>
    </div>
  );
}

export function PhoneScreen({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={`pt-7 px-3 pb-3 h-full ${className}`}>{children}</div>
  );
}
