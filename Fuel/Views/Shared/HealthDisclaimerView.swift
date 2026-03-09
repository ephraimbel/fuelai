import SwiftUI

/// Health and AI disclaimers required by Apple App Store guidelines.
/// Accessible from Settings and shown during onboarding.
struct HealthDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FuelSpacing.lg) {
                // AI Accuracy
                disclaimerSection(
                    icon: "sparkles",
                    title: "Fuel AI Estimates",
                    body: "Fuel uses proprietary AI technology to analyze food photos and descriptions. Nutritional estimates are intelligent approximations and may not be exact. Always verify with packaging labels when available."
                )

                // Not Medical Advice
                disclaimerSection(
                    icon: "heart.text.square",
                    title: "Not Medical Advice",
                    body: "This app is not a medical device and does not provide medical advice, diagnosis, or treatment. Calorie and macronutrient estimates are approximations and may vary from actual values."
                )

                // Consult Professional
                disclaimerSection(
                    icon: "stethoscope",
                    title: "Consult a Professional",
                    body: "Consult a healthcare professional before making significant changes to your diet, especially if you have a medical condition, food allergies, or specific dietary needs."
                )

                // Data & Privacy
                disclaimerSection(
                    icon: "lock.shield.fill",
                    title: "Your Data",
                    body: "Food photos are analyzed in real time and never stored on our servers. Your meal logs and personal data are encrypted and stored securely. You can delete all your data at any time from Settings."
                )

                // How It Works
                disclaimerSection(
                    icon: "cpu",
                    title: "How Fuel AI Works",
                    body: "Fuel's AI identifies every food item in your photo, estimates portion sizes using visual cues, and calculates detailed nutrition using our database of thousands of foods calibrated against USDA data."
                )
            }
            .padding(FuelSpacing.xl)
        }
        .background(FuelColors.white)
        .navigationTitle("Health & AI Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.flame)
            }
        }
    }

    private func disclaimerSection(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: FuelSpacing.sm) {
            HStack(spacing: FuelSpacing.sm) {
                Image(systemName: icon)
                    .font(FuelType.iconMd)
                    .foregroundStyle(FuelColors.flame)
                Text(title)
                    .font(FuelType.section)
                    .foregroundStyle(FuelColors.ink)
            }
            Text(body)
                .font(FuelType.body)
                .foregroundStyle(FuelColors.stone)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FuelSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FuelColors.cloud)
        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
    }
}
