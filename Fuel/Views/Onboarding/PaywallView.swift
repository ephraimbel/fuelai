import SwiftUI
import StoreKit
import AuthenticationServices

struct PaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var selectedPlan: String = Constants.yearlyProductID
    @State private var isSigningIn = false
    @State private var isRestoring = false
    @State private var showSpinWheel = false

    let onComplete: () -> Void

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("FlameIcon", "AI Nutrition Coach", "Personalized advice powered by AI"),
        ("camera.fill", "Unlimited Scans", "Snap and log meals without limits"),
        ("chart.bar.doc.horizontal.fill", "Weekly Reports", "AI-powered insights every week"),
        ("bolt.fill", "Priority Analysis", "Faster, more detailed food breakdowns"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: FuelSpacing.xs) {
                HStack(spacing: 0) {
                    Text("fuel")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                    Text("+")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundStyle(FuelColors.flame)
                }

                Text("Start your free trial")
                    .font(FuelType.stat)
                    .foregroundStyle(FuelColors.ink)

                Text("Try fuel+ free for 3 days")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
            }
            .staggeredAppear(index: 0)

            Spacer().frame(height: FuelSpacing.lg)

            // Trial timeline
            HStack(spacing: 0) {
                trialStep(label: "Today", detail: "Full access", isActive: true)
                dottedLine()
                trialStep(label: "Day 2", detail: "Reminder", isActive: false)
                dottedLine()
                trialStep(label: "Day 3", detail: "Trial ends", isActive: false)
            }
            .padding(.horizontal, FuelSpacing.xl)
            .staggeredAppear(index: 1)

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
            .staggeredAppear(index: 2)

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
                            .background(FuelColors.flame)

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
                                        .background(FuelColors.flame)
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
                PlanCard(
                    name: "Weekly",
                    price: weeklyPriceText,
                    id: Constants.weeklyProductID,
                    selected: $selectedPlan
                )
            }
            .padding(.horizontal, FuelSpacing.xl)
            .staggeredAppear(index: 3)

            Spacer().frame(height: FuelSpacing.md)

            // CTA
            VStack(spacing: FuelSpacing.sm) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    FuelHaptics.shared.send()
                    handleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))

                Text("Cancel anytime. We'll remind you before your trial ends.")
                    .font(FuelType.micro)
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, FuelSpacing.xl)
            .staggeredAppear(index: 4)

            if isSigningIn {
                ProgressView()
                    .tint(FuelColors.ink)
            }

            // Subscription disclosure (Apple Guideline 3.1.2)
            Text("Payment will be charged to your Apple ID account at the confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your Account Settings on the App Store after purchase.")
                .font(.system(size: 10))
                .foregroundStyle(FuelColors.fog)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FuelSpacing.xl)

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

            // Restore + Continue free
            HStack(spacing: FuelSpacing.xl) {
                Button {
                    isRestoring = true
                    Task {
                        try? await subscriptionService.restorePurchases()
                        await MainActor.run {
                            isRestoring = false
                            if subscriptionService.isPremium {
                                onComplete()
                            }
                        }
                    }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .tint(FuelColors.stone)
                    } else {
                        Text("Restore Purchases")
                            .font(FuelType.label)
                            .foregroundStyle(FuelColors.stone)
                    }
                }
                .disabled(isRestoring)

                Button {
                    showSpinWheel = true
                } label: {
                    Text("Continue for free")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)
                        .underline()
                }
            }
            .padding(.vertical, FuelSpacing.md)
        }
        .fullScreenCover(isPresented: $showSpinWheel) {
            SpinWheelView(
                onClaim: onComplete,
                onDismiss: onComplete
            )
        }
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

    // MARK: - Trial Timeline

    private func trialStep(label: String, detail: String, isActive: Bool) -> some View {
        VStack(spacing: FuelSpacing.xs) {
            Circle()
                .fill(isActive ? FuelColors.flame : FuelColors.stone)
                .frame(width: 10, height: 10)
            Text(label)
                .font(FuelType.label)
                .foregroundStyle(isActive ? FuelColors.ink : FuelColors.stone)
            Text(detail)
                .font(FuelType.micro)
                .foregroundStyle(FuelColors.stone)
        }
        .frame(maxWidth: .infinity)
    }

    private func dottedLine() -> some View {
        Line()
            .stroke(FuelColors.fog, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .offset(y: -10)
    }

    // MARK: - Auth

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            isSigningIn = true
            Task {
                do {
                    let profile = try await appState.authService?.signInWithApple(credential: credential)
                    // Activate RAG BEFORE dismissing — so API key is ready when user scans
                    await appState.aiService?.activateRAG()
                    await MainActor.run {
                        appState.userProfile = profile
                        appState.isAuthenticated = true
                    }
                    // Purchase the selected plan after sign-in
                    if let product = subscriptionService.products.first(where: { $0.id == selectedPlan }) {
                        let success = try await subscriptionService.purchase(product)
                        await MainActor.run {
                            isSigningIn = false
                            if success {
                                onComplete()
                            }
                        }
                    } else {
                        await MainActor.run {
                            isSigningIn = false
                            onComplete()
                        }
                    }
                } catch {
                    await MainActor.run {
                        appState.errorMessage = "Sign in failed. Please try again."
                        appState.showingError = true
                        isSigningIn = false
                    }
                }
            }
        case .failure:
            break
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
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
                                .background(FuelColors.flame)
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

// MARK: - Line Shape

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}
