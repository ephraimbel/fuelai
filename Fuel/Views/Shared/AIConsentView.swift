import SwiftUI

/// Apple App Store Guideline 5.1.2(i) — AI Data Sharing Consent Dialog.
/// Shown before the first food photo or text analysis.
struct AIConsentView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(FuelColors.fog)
                .frame(width: 36, height: 5)
                .padding(.top, FuelSpacing.md)

            ScrollView {
                VStack(spacing: FuelSpacing.lg) {
                    Spacer().frame(height: FuelSpacing.lg)

                    // Icon
                    Image("FlameIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)

                    // Title
                    VStack(spacing: FuelSpacing.xs) {
                        Text("Fuel AI")
                            .font(FuelType.title)
                            .foregroundStyle(FuelColors.ink)
                        Text("Smart Nutrition Analysis")
                            .font(FuelType.body)
                            .foregroundStyle(FuelColors.stone)
                    }
                    .multilineTextAlignment(.center)

                    // Description
                    VStack(spacing: FuelSpacing.md) {
                        infoRow(
                            icon: "camera.fill",
                            title: "How it works",
                            detail: "Snap a photo of your food and Fuel's AI instantly identifies every item, estimates portions, and calculates detailed nutrition."
                        )

                        infoRow(
                            icon: "lock.shield.fill",
                            title: "Your data is safe",
                            detail: "Photos are analyzed securely and never stored on our servers. Only the nutritional breakdown is saved to your account."
                        )

                        infoRow(
                            icon: "chart.bar.fill",
                            title: "Accurate nutrition data",
                            detail: "Fuel's AI is calibrated against USDA data and thousands of foods to give you reliable nutritional breakdowns."
                        )
                    }
                    .padding(.horizontal, FuelSpacing.sm)

                    // Security badge
                    HStack(spacing: FuelSpacing.sm) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(FuelType.iconSm)
                            .foregroundStyle(FuelColors.success)
                        Text("End-to-end encrypted")
                            .font(FuelType.caption)
                            .foregroundStyle(FuelColors.stone)
                        Text("  ·  ")
                            .foregroundStyle(FuelColors.fog)
                        Image(systemName: "trash.slash.fill")
                            .font(FuelType.iconSm)
                            .foregroundStyle(FuelColors.success)
                        Text("Photos never stored")
                            .font(FuelType.caption)
                            .foregroundStyle(FuelColors.stone)
                    }
                    .padding(FuelSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(FuelColors.cloud)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
                    .padding(.horizontal, FuelSpacing.sm)
                }
                .padding(.horizontal, FuelSpacing.lg)
            }

            // Action buttons
            VStack(spacing: FuelSpacing.sm) {
                Button {
                    AIConsentManager.grantConsent()
                    onAccept()
                } label: {
                    Text("Enable Fuel AI")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(FuelColors.buttonFill)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                }

                Button {
                    onDecline()
                } label: {
                    Text("Not now")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)
                }
                .padding(.bottom, FuelSpacing.sm)
            }
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.md)
        }
        .background(FuelColors.white)
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: FuelSpacing.md) {
            Image(systemName: icon)
                .font(FuelType.iconMd)
                .foregroundStyle(FuelColors.flame)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.ink)
                Text(detail)
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.stone)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
