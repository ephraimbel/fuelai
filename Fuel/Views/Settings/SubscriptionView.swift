import SwiftUI

struct SubscriptionView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: FuelSpacing.xl) {
            if subscriptionService.isPremium {
                // Premium active state
                Spacer()

                VStack(spacing: FuelSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(FuelColors.flame.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "flame.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(FuelColors.flame)
                    }

                    VStack(spacing: FuelSpacing.sm) {
                        HStack(spacing: 2) {
                            Text("fuel")
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundStyle(FuelColors.ink)
                            Text("+")
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundStyle(FuelColors.flame)
                        }

                        Text("You're on Premium")
                            .font(FuelType.body)
                            .foregroundStyle(FuelColors.stone)
                    }

                    VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                        PremiumFeature(icon: "camera.fill", text: "Unlimited meal scans")
                        PremiumFeature(icon: "sparkles", text: "AI nutrition coaching")
                        PremiumFeature(icon: "chart.bar.fill", text: "Advanced insights")
                        PremiumFeature(icon: "bell.fill", text: "Smart reminders")
                    }
                    .padding(FuelSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FuelColors.cloud)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
                }

                Spacer()
            } else {
                // Upgrade state
                Spacer()

                VStack(spacing: FuelSpacing.lg) {
                    HStack(spacing: 2) {
                        Text("fuel")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.ink)
                        Text("+")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.flame)
                    }

                    Text("Unlock everything")
                        .font(FuelType.body)
                        .foregroundStyle(FuelColors.stone)
                }

                VStack(spacing: FuelSpacing.md) {
                    ForEach(subscriptionService.products, id: \.id) { product in
                        Button {
                            Task {
                                _ = try? await subscriptionService.purchase(product)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.displayName)
                                        .font(FuelType.cardTitle)
                                        .foregroundStyle(FuelColors.ink)
                                    Text(product.description)
                                        .font(FuelType.caption)
                                        .foregroundStyle(FuelColors.stone)
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(FuelType.section)
                                    .foregroundStyle(FuelColors.ink)
                            }
                            .padding(FuelSpacing.lg)
                            .background(FuelColors.cloud)
                            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
                            .overlay(
                                RoundedRectangle(cornerRadius: FuelRadius.card)
                                    .stroke(FuelColors.mist, lineWidth: 0.5)
                            )
                        }
                    }
                }
                .padding(.horizontal, FuelSpacing.xl)

                Spacer()

                Button {
                    Task { try? await subscriptionService.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)
                }
                .padding(.bottom, FuelSpacing.lg)
            }
        }
        .padding(FuelSpacing.xl)
        .background(FuelColors.white)
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.ink)
            }
        }
        .task {
            try? await subscriptionService.loadProducts()
        }
    }
}

// MARK: - Premium Feature Row

private struct PremiumFeature: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: FuelSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FuelColors.flame)
                .frame(width: 20)

            Text(text)
                .font(FuelType.body)
                .foregroundStyle(FuelColors.ink)
        }
    }
}
