import SwiftUI
import StoreKit

enum UpgradeReason {
    case scanLimit
    case chatLimit
    case aiDescribe

    var title: String {
        switch self {
        case .scanLimit: return "You've used all your free scans"
        case .chatLimit: return "You've used all your free chats"
        case .aiDescribe: return "AI Describe is a Pro feature"
        }
    }

    var subtitle: String {
        switch self {
        case .scanLimit: return "Upgrade to fuel+ for unlimited meal scans and more"
        case .chatLimit: return "Upgrade to fuel+ for unlimited AI chat and more"
        case .aiDescribe: return "Upgrade to fuel+ for AI-powered meal descriptions and more"
        }
    }
}

struct UpgradePaywallView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: String = Constants.yearlyProductID
    @State private var isPurchasing = false

    let reason: UpgradeReason

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("FlameIcon", "AI Nutrition Coach", "Personalized advice powered by AI"),
        ("camera.fill", "Unlimited Scans", "Snap and log meals without limits"),
        ("chart.bar.doc.horizontal.fill", "Weekly Reports", "AI-powered insights every week"),
        ("bolt.fill", "Priority Analysis", "Faster, more detailed food breakdowns"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(FuelColors.fog)
                .frame(width: 36, height: 5)
                .padding(.top, FuelSpacing.md)

            Spacer().frame(height: FuelSpacing.xl)

            // Header
            VStack(spacing: FuelSpacing.xs) {
                HStack(spacing: 0) {
                    Text("fuel")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                    Text("+")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(FuelColors.flame)
                }

                Text(reason.title)
                    .font(FuelType.stat)
                    .foregroundStyle(FuelColors.ink)
                    .multilineTextAlignment(.center)

                Text(reason.subtitle)
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, FuelSpacing.xl)
            .staggeredAppear(index: 0)

            Spacer().frame(height: FuelSpacing.lg)

            // Feature list
            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: FuelSpacing.md) {
                        Group {
                            if feature.icon == "FlameIcon" {
                                Image("FlameIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: feature.icon)
                                    .font(FuelType.iconMd)
                                    .foregroundStyle(FuelColors.flame)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(FuelColors.flame.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.sm))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(FuelType.cardTitle)
                                .foregroundStyle(FuelColors.ink)
                            Text(feature.subtitle)
                                .font(FuelType.caption)
                                .foregroundStyle(FuelColors.stone)
                        }

                        Spacer()
                    }
                    .padding(.vertical, FuelSpacing.sm + 2)

                    if index < features.count - 1 {
                        Divider().foregroundStyle(FuelColors.mist)
                    }
                }
            }
            .padding(.horizontal, FuelSpacing.lg)
            .padding(.vertical, FuelSpacing.xs)
            .background(FuelColors.cloud)
            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
            .padding(.horizontal, FuelSpacing.xl)
            .staggeredAppear(index: 1)

            Spacer()

            // Plan cards
            VStack(spacing: FuelSpacing.sm) {
                // Yearly — hero card with free trial
                Button {
                    withAnimation(FuelAnimation.snappy) { selectedPlan = Constants.yearlyProductID }
                    FuelHaptics.shared.tap()
                } label: {
                    let isSelected = selectedPlan == Constants.yearlyProductID
                    VStack(spacing: 0) {
                        // "BEST VALUE" top ribbon
                        Text("BEST VALUE")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(FuelColors.onDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(FuelColors.buttonFill)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: FuelSpacing.sm) {
                                    Text("Yearly")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(FuelColors.ink)
                                    Text("Save 77%")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(FuelColors.onDark)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(FuelColors.buttonFill)
                                        .clipShape(Capsule())
                                }
                                Text(yearlyPriceText)
                                    .font(.system(size: 13))
                                    .foregroundStyle(FuelColors.stone)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(yearlyMonthlyPrice)
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundStyle(FuelColors.flame)
                                Text("/mo")
                                    .font(.system(size: 12))
                                    .foregroundStyle(FuelColors.stone)
                            }
                        }
                        .padding(FuelSpacing.lg)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: FuelRadius.card)
                            .fill(FuelColors.white)
                            .shadow(color: isSelected ? FuelColors.flame.opacity(0.25) : FuelColors.shadow.opacity(0.08), radius: isSelected ? 12 : 4, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FuelRadius.card)
                            .stroke(isSelected ? FuelColors.flame : FuelColors.mist, lineWidth: isSelected ? 2 : 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
                    .scaleEffect(isSelected ? 1.02 : 1.0)
                    .animation(FuelAnimation.snappy, value: isSelected)
                }

                // Weekly — simple card
                UpgradePlanCard(
                    name: "Weekly",
                    price: weeklyPriceText,
                    id: Constants.weeklyProductID,
                    selected: $selectedPlan
                )
            }
            .padding(.horizontal, FuelSpacing.xl)
            .staggeredAppear(index: 2)

            Spacer().frame(height: FuelSpacing.md)

            // CTA
            VStack(spacing: FuelSpacing.sm) {
                Button {
                    purchaseSelected()
                } label: {
                    HStack(spacing: FuelSpacing.sm) {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Start Free Trial")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FuelColors.buttonFill)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                }
                .disabled(isPurchasing)
                .pressable()

                Text("Cancel anytime. We'll remind you before your trial ends.")
                    .font(FuelType.micro)
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, FuelSpacing.xl)
            .staggeredAppear(index: 3)

            // Subscription disclosure (Apple Guideline 3.1.2)
            Text("Payment will be charged to your Apple ID account at the confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your Account Settings on the App Store after purchase.")
                .font(.system(size: 10))
                .foregroundStyle(FuelColors.fog)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FuelSpacing.xl)
                .padding(.top, FuelSpacing.xs)

            // Legal links
            HStack(spacing: FuelSpacing.lg) {
                Button {
                    UIApplication.shared.open(Constants.termsURL)
                } label: {
                    Text("Terms of Use")
                        .font(.system(size: 10))
                        .foregroundStyle(FuelColors.stone)
                        .underline()
                }
                Button {
                    UIApplication.shared.open(Constants.privacyURL)
                } label: {
                    Text("Privacy Policy")
                        .font(.system(size: 10))
                        .foregroundStyle(FuelColors.stone)
                        .underline()
                }
            }
            .padding(.top, FuelSpacing.xs)

            // Bottom actions
            HStack(spacing: FuelSpacing.xl) {
                Button {
                    Task {
                        try? await subscriptionService.restorePurchases()
                        if subscriptionService.isPremium {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Restore Purchases")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)
                        .underline()
                }
            }
            .padding(.vertical, FuelSpacing.md)
        }
        .background(FuelColors.white)
        .task {
            try? await subscriptionService.loadProducts()
        }
    }

    private var yearlyProduct: Product? {
        subscriptionService.products.first { $0.id == Constants.yearlyProductID }
    }

    private var weeklyProduct: Product? {
        subscriptionService.products.first { $0.id == Constants.weeklyProductID }
    }

    private var yearlyPriceText: String {
        if let product = yearlyProduct {
            return "3-day free trial, then \(product.displayPrice)/year"
        }
        return "3-day free trial, then $59.99/year"
    }

    private var yearlyMonthlyPrice: String {
        if let product = yearlyProduct {
            let monthly = product.price / 12
            let formatted = product.priceFormatStyle.format(monthly)
            return formatted
        }
        return "$5.00"
    }

    private var weeklyPriceText: String {
        if let product = weeklyProduct {
            return "\(product.displayPrice)/week"
        }
        return "$4.99/week"
    }

    private func purchaseSelected() {
        guard let product = subscriptionService.products.first(where: {
            $0.id == selectedPlan
        }) else { return }

        isPurchasing = true
        Task {
            do {
                let success = try await subscriptionService.purchase(product)
                await MainActor.run {
                    isPurchasing = false
                    if success { dismiss() }
                }
            } catch {
                await MainActor.run { isPurchasing = false }
            }
        }
    }
}

// MARK: - Plan Card

private struct UpgradePlanCard: View {
    let name: String
    let price: String
    var detail: String? = nil
    let id: String
    var badge: String? = nil
    @Binding var selected: String

    private var isSelected: Bool { selected == id }

    var body: some View {
        Button {
            withAnimation(FuelAnimation.snappy) { selected = id }
            FuelHaptics.shared.tap()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: FuelSpacing.sm) {
                        Text(name)
                            .font(FuelType.cardTitle)
                            .foregroundStyle(FuelColors.ink)
                        if let badge {
                            Text(badge)
                                .font(FuelType.micro)
                                .foregroundStyle(FuelColors.onDark)
                                .padding(.horizontal, FuelSpacing.sm)
                                .padding(.vertical, 2)
                                .background(FuelColors.buttonFill)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: FuelSpacing.sm) {
                        Text(price)
                            .font(FuelType.caption)
                            .foregroundStyle(FuelColors.stone)
                        if let detail {
                            Text(detail)
                                .font(FuelType.micro)
                                .foregroundStyle(FuelColors.flame)
                        }
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? FuelColors.ink : FuelColors.fog, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(FuelColors.ink)
                            .frame(width: 14, height: 14)
                            .transition(.scale)
                    }
                }
                .animation(FuelAnimation.snappy, value: isSelected)
            }
            .padding(FuelSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: FuelRadius.card)
                    .fill(FuelColors.cloud)
                    .stroke(isSelected ? FuelColors.ink : FuelColors.mist, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
    }
}
