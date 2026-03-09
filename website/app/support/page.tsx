import { LegalLayout } from "@/components/legal-layout";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Support — Fuel",
  description: "Get help with the Fuel app. Contact support, browse FAQs, and find answers.",
};

export default function Support() {
  return (
    <LegalLayout title="Support" updated={undefined}>
      <p className="text-stone text-base mb-8">
        We&apos;re here to help you get the most out of Fuel.
      </p>

      <div className="grid gap-4 mb-12">
        {[
          {
            title: "Contact Us",
            desc: (
              <>
                For any questions, issues, or feedback, email us at{" "}
                <a href="mailto:support@fuelapp.ai">support@fuelapp.ai</a>. We typically respond
                within 24 hours.
              </>
            ),
          },
          {
            title: "Report a Bug",
            desc: "Found something that isn't working right? Send us a detailed description of the issue, including your device model and iOS version, and we'll investigate promptly.",
          },
          {
            title: "Account & Data",
            desc: "To request account deletion or data export, email us from the email address associated with your Fuel account. We will process your request within 5 business days.",
          },
        ].map((card) => (
          <div
            key={card.title}
            className="bg-cloud border border-mist/60 rounded-[18px] p-6"
          >
            <h3 className="font-[family-name:var(--font-serif)] text-lg text-ink mb-2">
              {card.title}
            </h3>
            <p className="text-stone text-sm leading-relaxed m-0">{card.desc}</p>
          </div>
        ))}
      </div>

      <h2>Frequently Asked Questions</h2>

      {[
        {
          q: "How does Fuel analyze my food?",
          a: "Fuel uses advanced AI to identify foods from photos and estimate nutritional content. We combine AI analysis with a database of 600+ foods calibrated against USDA data for accurate results.",
        },
        {
          q: "Is my food data private?",
          a: "Yes. Food photos are processed by AI for analysis and are not stored on our servers afterward. Your food logs are stored securely and are only accessible to you.",
        },
        {
          q: "How accurate is the calorie tracking?",
          a: "Fuel provides AI-estimated nutritional values calibrated against USDA data. While no food tracking app can be 100% precise, our AI aims for the closest possible estimate and provides confidence levels for each analysis.",
        },
        {
          q: "Can I use Fuel offline?",
          a: "Fuel includes an on-device food database for basic lookups without an internet connection. However, AI-powered photo analysis and the chat nutritionist require an active internet connection.",
        },
        {
          q: "How do I cancel my subscription?",
          a: "You can manage or cancel your subscription at any time through your iPhone's Settings > Apple ID > Subscriptions. Cancellation takes effect at the end of the current billing period.",
        },
        {
          q: "How do I delete my account?",
          a: "To delete your account and all associated data, email support@fuelapp.ai from the email address linked to your account. We will confirm deletion within 5 business days.",
        },
      ].map((faq) => (
        <div key={faq.q} className="mb-6">
          <h3 className="font-[family-name:var(--font-serif)] text-base text-ink mb-1.5">
            {faq.q}
          </h3>
          <p className="text-stone text-sm leading-relaxed">{faq.a}</p>
        </div>
      ))}
    </LegalLayout>
  );
}
