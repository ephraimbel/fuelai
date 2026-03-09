import SwiftUI

/// Shown during onboarding before the paywall to comply with
/// Apple health app guidelines and AI disclosure requirements.
struct DisclaimerAcknowledgmentView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: FuelSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(FuelColors.flame.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(FuelColors.flame)
                }

                Text("Before you start")
                    .font(FuelType.title)
                    .foregroundStyle(FuelColors.ink)

                VStack(spacing: FuelSpacing.lg) {
                    bulletPoint(
                        icon: "sparkles",
                        text: "Fuel's AI analyzes your food photos and descriptions to estimate calories and nutrition. These are smart estimates and may vary from exact values."
                    )
                    bulletPoint(
                        icon: "heart.text.square",
                        text: "This app is not a medical device and does not provide medical advice. Consult a healthcare professional before making significant dietary changes."
                    )
                    bulletPoint(
                        icon: "lock.shield.fill",
                        text: "Your food photos are analyzed securely and never stored on our servers. All your personal data is encrypted and can be deleted at any time."
                    )
                }
            }
            .padding(.horizontal, FuelSpacing.xl)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("I Understand")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FuelColors.onDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FuelColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            }
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.bottom, FuelSpacing.xl)
        }
    }

    private func bulletPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: FuelSpacing.md) {
            Image(systemName: icon)
                .font(FuelType.iconMd)
                .foregroundStyle(FuelColors.flame)
                .frame(width: 24)

            Text(text)
                .font(FuelType.body)
                .foregroundStyle(FuelColors.stone)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
