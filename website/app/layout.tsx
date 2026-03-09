import type { Metadata } from "next";
import { DM_Serif_Display, Inter } from "next/font/google";
import "./globals.css";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";

const dmSerif = DM_Serif_Display({
  weight: "400",
  subsets: ["latin"],
  variable: "--font-serif",
  display: "swap",
});

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-sans",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Fuel — AI Calorie Tracking",
  description:
    "Fuel uses AI to make calorie tracking effortless. Snap a photo, chat with your AI nutritionist, and uncover nutritional gaps in your diet.",
  metadataBase: new URL("https://fuel-website.vercel.app"),
  openGraph: {
    title: "Fuel — AI Calorie Tracking",
    description:
      "Snap a photo, chat with AI, and uncover nutritional gaps in your diet.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${dmSerif.variable} ${inter.variable}`}>
      <body className="font-[family-name:var(--font-sans)] bg-warm-white text-ink min-h-screen">
        <Navbar />
        <main>{children}</main>
        <Footer />
      </body>
    </html>
  );
}
