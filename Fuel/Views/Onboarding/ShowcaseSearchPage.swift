import SwiftUI

struct ShowcaseSearchPage: View {
    let onContinue: () -> Void
    @State private var appeared = false
    @State private var showFrame = false
    @State private var animCycle = 0

    // Animation states
    @State private var revealedChars = 0
    @State private var showResult1 = false
    @State private var showResult2 = false
    @State private var showResult3 = false
    @State private var showButton = false

    private let searchText = "Steak with sweet potato"

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FuelSpacing.sm) {
                (Text("Search ")
                    .foregroundColor(FuelColors.ink) +
                 Text("anything.")
                    .foregroundColor(FuelColors.flame))
                    .font(FuelType.title)
                    .multilineTextAlignment(.center)

                Text("Describe any meal in your own words\nAI finds the exact nutrition instantly")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.xxl)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(FuelAnimation.spring.delay(0.0), value: appeared)

            Spacer()

            ShowcasePhoneFrame {
                VStack(spacing: 0) {
                    // Remaining macros card (matches real SearchLogView)
                    HStack(spacing: 10) {
                        VStack(spacing: 1) {
                            Text("1,280")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(FuelColors.flame)
                            Text("cal left")
                                .font(.system(size: 6.5))
                                .foregroundStyle(FuelColors.stone)
                        }
                        Rectangle().fill(FuelColors.mist).frame(width: 0.5, height: 18)
                        VStack(spacing: 1) {
                            Text("58g")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(FuelColors.protein)
                            Text("protein")
                                .font(.system(size: 6.5))
                                .foregroundStyle(FuelColors.stone)
                        }
                        VStack(spacing: 1) {
                            Text("142g")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(FuelColors.carbs)
                            Text("carbs")
                                .font(.system(size: 6.5))
                                .foregroundStyle(FuelColors.stone)
                        }
                        VStack(spacing: 1) {
                            Text("38g")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(FuelColors.fat)
                            Text("fat")
                                .font(.system(size: 6.5))
                                .foregroundStyle(FuelColors.stone)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(FuelColors.cloud))
                    .padding(.horizontal, 8)
                    .padding(.top, 52)

                    // AI Search bar (matches real AISearchBar with shimmer border)
                    ShowcaseAISearchBar(
                        text: String(searchText.prefix(revealedChars)),
                        showCursor: revealedChars > 0 && revealedChars < searchText.count
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    // Autocomplete results (matches real: magnifying glass + name + cal/serving + arrow)
                    if showResult1 {
                        VStack(spacing: 0) {
                            autocompleteRow(name: "NY Strip Steak 8oz", detail: "480 cal · 8 oz", isLast: false)
                            if showResult2 {
                                autocompleteRow(name: "Sweet Potato, baked", detail: "162 cal · 1 medium", isLast: false)
                            }
                            if showResult3 {
                                autocompleteRow(name: "Steak & Potato Dinner", detail: "720 cal · 1 plate", isLast: true)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(FuelColors.white)
                                .shadow(color: FuelColors.shadow.opacity(0.08), radius: 6, y: 3)
                        )
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                    }

                    Spacer()

                    // Analyze button (matches real)
                    if showButton {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Analyze with AI")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(FuelColors.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 8)
                        .padding(.bottom, 14)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                    }
                }
                .background(FuelColors.white)
            }
            .padding(.horizontal, 40)
            .opacity(showFrame ? 1 : 0)
            .scaleEffect(showFrame ? 1 : 0.95)
            .animation(FuelAnimation.spring.delay(0.2), value: showFrame)

            Spacer()

            Button {
                FuelHaptics.shared.tap()
                onContinue()
            } label: {
                Text("Continue")
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.onDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FuelSpacing.lg)
                    .background(FuelColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            }
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.bottom, FuelSpacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(FuelAnimation.spring.delay(0.8), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FuelColors.white)
        .onAppear {
            appeared = true
            showFrame = true
            runLoop()
        }
    }

    // MARK: - Autocomplete Row (matches real SearchLogView)

    private func autocompleteRow(name: String, detail: String, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 7))
                    .foregroundStyle(FuelColors.fog)
                    .frame(width: 10)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 9))
                        .foregroundStyle(FuelColors.ink)
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 7))
                        .foregroundStyle(FuelColors.stone)
                }

                Spacer()

                Image(systemName: "arrow.up.left")
                    .font(.system(size: 7))
                    .foregroundStyle(FuelColors.fog)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            if !isLast {
                Divider().padding(.leading, 29)
            }
        }
    }

    // MARK: - Looping Animation

    private func runLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                // Reset
                revealedChars = 0
                showResult1 = false
                showResult2 = false
                showResult3 = false
                showButton = false

                try? await Task.sleep(for: .seconds(0.5))

                // Typewriter
                for i in 1...searchText.count {
                    try? await Task.sleep(for: .milliseconds(38))
                    revealedChars = i
                }

                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(FuelAnimation.spring) { showResult1 = true }
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(FuelAnimation.spring) { showResult2 = true }
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(FuelAnimation.spring) { showResult3 = true }
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(FuelAnimation.spring) { showButton = true }

                // Hold
                try? await Task.sleep(for: .seconds(2.5))

                // Fade out
                withAnimation(FuelAnimation.spring) {
                    showResult1 = false
                    showResult2 = false
                    showResult3 = false
                    showButton = false
                }
                try? await Task.sleep(for: .seconds(0.4))

                animCycle += 1
            }
        }
    }
}

// MARK: - AI Search Bar (matches real AISearchBar with shimmer)

private struct ShowcaseAISearchBar: View {
    let text: String
    let showCursor: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let shimmerPhase = t.remainder(dividingBy: 4.0) / 4.0
            let shimmerX = shimmerPhase * 1.4 - 0.2

            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FuelColors.flame)

                Group {
                    if text.isEmpty {
                        Text("Describe what you ate...")
                            .foregroundStyle(FuelColors.stone)
                    } else {
                        Text(text)
                            .foregroundStyle(FuelColors.ink)
                        + Text(showCursor ? "|" : "")
                            .foregroundStyle(FuelColors.flame)
                    }
                }
                .font(.system(size: 9.5))
                .lineLimit(1)

                Spacer()

                if !text.isEmpty {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(FuelColors.fog)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(FuelColors.cloud))
            .overlay(
                // Gradient border (matches real)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                FuelColors.flame.opacity(0.25),
                                FuelColors.flame.opacity(0.4),
                                Color(hex: "#FF8040").opacity(0.3),
                                FuelColors.flame.opacity(0.25),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .overlay(
                // Shimmer sweep (matches real)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: max(0, shimmerX - 0.1)),
                                .init(color: .white.opacity(0.3), location: shimmerX),
                                .init(color: .clear, location: min(1, shimmerX + 0.1)),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
    }
}
