import type { ReactNode } from "react";

export function LegalLayout({
  title,
  updated,
  children,
}: {
  title: string;
  updated?: string;
  children: ReactNode;
}) {
  return (
    <article className="pt-28 pb-20 md:pt-36 md:pb-28">
      <div className="max-w-[680px] mx-auto px-6">
        <h1 className="font-[family-name:var(--font-serif)] text-3xl md:text-4xl text-ink mb-2">
          {title}
        </h1>
        {updated && (
          <p className="text-sm text-stone mb-10">Last updated: {updated}</p>
        )}
        <div className="prose-fuel">{children}</div>
      </div>
    </article>
  );
}
