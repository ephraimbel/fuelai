import { LegalLayout } from "@/components/legal-layout";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Use — Fuel",
  description: "Read the terms and conditions for using the Fuel app.",
};

export default function Terms() {
  return (
    <LegalLayout title="Terms of Use" updated="March 5, 2025">
      <p>
        Please read these Terms of Use (&ldquo;Terms&rdquo;) carefully before using the Fuel mobile
        application (the &ldquo;App&rdquo;) operated by Fuel (&ldquo;we,&rdquo; &ldquo;our,&rdquo;
        or &ldquo;us&rdquo;).
      </p>

      <h2>1. Acceptance of Terms</h2>
      <p>
        By downloading, installing, or using the App, you agree to be bound by these Terms. If you
        do not agree, do not use the App.
      </p>

      <h2>2. Description of Service</h2>
      <p>
        Fuel is an AI-powered calorie and nutrition tracking application. The App allows you to log
        meals via photo, text, or barcode scanning, receive AI-generated nutritional analysis, chat
        with an AI nutritionist, and track your dietary patterns over time.
      </p>

      <h2>3. Account Registration</h2>
      <p>
        To use certain features of the App, you must create an account. You are responsible for
        maintaining the confidentiality of your account credentials and for all activities that occur
        under your account.
      </p>

      <h2>4. Health Disclaimer</h2>
      <p>
        <strong>Fuel is not a medical device and does not provide medical advice.</strong> The
        nutritional information, meal suggestions, and dietary insights provided by the App are for
        informational and educational purposes only. They are not intended to be a substitute for
        professional medical advice, diagnosis, or treatment.
      </p>
      <p>
        Always consult a qualified healthcare provider or registered dietitian before making
        significant changes to your diet. AI-generated nutritional estimates may not be 100%
        accurate.
      </p>

      <h2>5. Acceptable Use</h2>
      <ul>
        <li>Do not use the App for any unlawful purpose</li>
        <li>Do not attempt to gain unauthorized access to the App or its systems</li>
        <li>Do not interfere with or disrupt the App&apos;s functionality</li>
        <li>Do not reverse engineer, decompile, or disassemble any part of the App</li>
        <li>Do not use the App to transmit harmful or inappropriate content</li>
        <li>Do not create multiple accounts or share your account credentials</li>
      </ul>

      <h2>6. Intellectual Property</h2>
      <p>
        The App, including its design, features, content, and underlying technology, is owned by
        Fuel and is protected by intellectual property laws. You are granted a limited,
        non-exclusive, non-transferable license to use the App for personal, non-commercial
        purposes.
      </p>

      <h2>7. User Content</h2>
      <p>
        You retain ownership of any content you submit to the App. By submitting content, you grant
        us a limited license to process and analyze it for the purpose of providing the App&apos;s
        services.
      </p>

      <h2>8. Subscriptions & Payments</h2>
      <p>
        Some features may require a paid subscription. Subscriptions are billed through Apple&apos;s
        App Store and are subject to Apple&apos;s terms. You can manage or cancel your subscription
        through your App Store account settings.
      </p>

      <h2>9. Limitation of Liability</h2>
      <p>
        To the fullest extent permitted by law, Fuel shall not be liable for any indirect,
        incidental, special, consequential, or punitive damages arising out of your use of the App.
      </p>

      <h2>10. Termination</h2>
      <p>
        We reserve the right to suspend or terminate your access to the App at any time for conduct
        that violates these Terms.
      </p>

      <h2>11. Changes to Terms</h2>
      <p>
        We may update these Terms from time to time. Continued use of the App after changes
        constitutes acceptance of the updated Terms.
      </p>

      <h2>12. Governing Law</h2>
      <p>
        These Terms shall be governed by the laws of the United States, without regard to conflict
        of law principles.
      </p>

      <h2>13. Contact Us</h2>
      <p>
        Questions about these Terms? Contact us at{" "}
        <a href="mailto:support@fuelapp.ai">support@fuelapp.ai</a>.
      </p>
    </LegalLayout>
  );
}
