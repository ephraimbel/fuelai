import { LegalLayout } from "@/components/legal-layout";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy — Fuel",
  description: "Learn how Fuel collects, uses, and protects your personal information.",
};

export default function Privacy() {
  return (
    <LegalLayout title="Privacy Policy" updated="March 5, 2025">
      <p>
        Fuel (&ldquo;we,&rdquo; &ldquo;our,&rdquo; or &ldquo;us&rdquo;) is committed to protecting
        your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your
        information when you use the Fuel mobile application (the &ldquo;App&rdquo;).
      </p>

      <h2>1. Information We Collect</h2>
      <p>
        <strong>Account Information:</strong> When you create an account, we collect your email
        address and authentication credentials. We use Supabase for secure authentication.
      </p>
      <p>
        <strong>Food & Nutrition Data:</strong> When you log meals — through text, photo, or barcode
        scanning — we process this information to provide nutritional analysis. Photos are analyzed
        by AI and are not stored on our servers after processing.
      </p>
      <p>
        <strong>Usage Data:</strong> We collect anonymized usage analytics to improve the App,
        including features used, session duration, and crash reports.
      </p>
      <p>
        <strong>Device Information:</strong> We may collect device type, operating system version,
        and unique device identifiers for app functionality and troubleshooting.
      </p>

      <h2>2. How We Use Your Information</h2>
      <ul>
        <li>To provide, maintain, and improve the App&apos;s functionality</li>
        <li>To analyze your meals and provide AI-powered nutritional insights</li>
        <li>To personalize your experience and provide relevant recommendations</li>
        <li>To communicate with you about updates, support, and service-related notices</li>
        <li>To detect, prevent, and address technical issues</li>
      </ul>

      <h2>3. AI Processing</h2>
      <p>
        Fuel uses AI (powered by Anthropic&apos;s Claude) to analyze food photos and provide
        nutritional information. Food photos are sent to our AI service for analysis and are not
        retained after processing. We also maintain an on-device food database for faster,
        offline-capable lookups.
      </p>

      <h2>4. Data Storage & Security</h2>
      <p>
        Your data is stored securely using Supabase, which provides enterprise-grade security
        including encryption at rest and in transit. We implement appropriate technical and
        organizational measures to protect your personal information.
      </p>

      <h2>5. Third-Party Services</h2>
      <ul>
        <li><strong>Supabase:</strong> Authentication and data storage</li>
        <li><strong>Anthropic (Claude AI):</strong> Food photo analysis and nutritional insights</li>
        <li><strong>Apple App Store:</strong> App distribution and in-app purchases</li>
      </ul>

      <h2>6. Data Retention</h2>
      <p>
        We retain your account data for as long as your account is active. Food logs and nutritional
        data are retained to provide you with historical tracking and insights. You can request
        deletion of your account and all associated data at any time.
      </p>

      <h2>7. Your Rights</h2>
      <ul>
        <li>Access the personal data we hold about you</li>
        <li>Request correction of inaccurate data</li>
        <li>Request deletion of your data</li>
        <li>Export your data in a portable format</li>
        <li>Opt out of non-essential data collection</li>
      </ul>

      <h2>8. Children&apos;s Privacy</h2>
      <p>
        The App is not intended for children under the age of 13. We do not knowingly collect
        personal information from children under 13.
      </p>

      <h2>9. Changes to This Policy</h2>
      <p>
        We may update this Privacy Policy from time to time. We will notify you of any changes by
        posting the new Privacy Policy on this page and updating the &ldquo;Last updated&rdquo; date.
      </p>

      <h2>10. Contact Us</h2>
      <p>
        If you have questions about this Privacy Policy, please contact us at{" "}
        <a href="mailto:support@fuelapp.ai">support@fuelapp.ai</a>.
      </p>
    </LegalLayout>
  );
}
