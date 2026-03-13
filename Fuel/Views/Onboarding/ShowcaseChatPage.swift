import SwiftUI

struct ShowcaseChatPage: View {
    let onContinue: () -> Void
    @State private var appeared = false
    @State private var showFrame = false
    @State private var animCycle = 0

    // Animation states
    @State private var showUserBubble = false
    @State private var showThinking = false
    @State private var showReply = false
    @State private var revealedChars = 0
    @State private var showChips = false

    private let replyText = "You're at 92g today — aim for 30g more at dinner to hit your 125g goal. Try grilled salmon or a Greek yogurt bowl."

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FuelSpacing.sm) {
                (Text("Your ")
                    .foregroundColor(FuelColors.ink) +
                 Text("AI coach.")
                    .foregroundColor(FuelColors.flame))
                    .font(FuelType.title)
                    .multilineTextAlignment(.center)

                Text("Get personalized nutrition advice\npowered by AI that knows your goals")
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
                ZStack {
                    FuelColors.white

                    // Flame gradient from top (matches real ChatView)
                    LinearGradient(
                        stops: [
                            .init(color: FuelColors.flame.opacity(0.18), location: 0),
                            .init(color: FuelColors.flame.opacity(0.10), location: 0.12),
                            .init(color: FuelColors.flame.opacity(0.03), location: 0.30),
                            .init(color: Color.clear, location: 0.45),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )

                    VStack(spacing: 0) {
                        // Header (matches real ChatView toolbar)
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(FuelColors.stone)
                            Spacer()
                            Image("FuelLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 16)
                            Text("AI")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FuelColors.ink)
                            Spacer()
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(FuelColors.stone)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 50)
                        .padding(.bottom, 4)

                        // Messages
                        VStack(alignment: .leading, spacing: 8) {
                            Spacer().frame(height: 2)

                            // User bubble
                            if showUserBubble {
                                HStack {
                                    Spacer(minLength: 30)
                                    Text("Am I getting enough protein?")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(FuelColors.ink)
                                        )
                                }
                                .padding(.horizontal, 10)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }

                            // Thinking
                            if showThinking && !showReply {
                                HStack(spacing: 5) {
                                    ShowcaseChatDots()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(FuelColors.white)
                                        .shadow(color: FuelColors.shadow.opacity(0.05), radius: 3, y: 1)
                                )
                                .padding(.horizontal, 10)
                                .transition(.opacity)
                            }

                            // AI reply with flame avatar
                            if showReply {
                                HStack(alignment: .top, spacing: 6) {
                                    Image("FlameIcon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                        .padding(.top, 1)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("fuel AI")
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundStyle(FuelColors.stone)

                                        Text(String(replyText.prefix(revealedChars)))
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(FuelColors.ink)
                                            .lineSpacing(2.5)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 8)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(FuelColors.white)
                                        .shadow(color: FuelColors.shadow.opacity(0.05), radius: 3, y: 1)
                                )
                                .padding(.horizontal, 10)
                                .transition(.opacity)
                            }

                            // Suggestion chips (matches real ChatView)
                            if showChips {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 5) {
                                        chatChip("fork.knife", "High-protein meals")
                                        chatChip("chart.bar.fill", "Today's summary")
                                        chatChip("eye", "Spot patterns")
                                    }
                                    .padding(.horizontal, 10)
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            Spacer()
                        }

                        // Input bar (matches real ChatView)
                        HStack(spacing: 6) {
                            Text("Ask anything...")
                                .font(.system(size: 10.5))
                                .foregroundStyle(FuelColors.stone)
                            Spacer()
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(FuelColors.fog)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(FuelColors.white)
                                .shadow(color: FuelColors.shadow.opacity(0.06), radius: 4, y: 1)
                        )
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    }
                }
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

    // MARK: - Looping Animation

    private func runLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                // Reset
                showUserBubble = false
                showThinking = false
                showReply = false
                revealedChars = 0
                showChips = false

                try? await Task.sleep(for: .seconds(0.6))

                withAnimation(FuelAnimation.spring) { showUserBubble = true }
                try? await Task.sleep(for: .seconds(0.5))

                withAnimation(FuelAnimation.spring) { showThinking = true }
                try? await Task.sleep(for: .seconds(0.9))

                withAnimation(FuelAnimation.spring) { showReply = true }

                // Typewriter
                for i in 1...replyText.count {
                    try? await Task.sleep(for: .milliseconds(18))
                    revealedChars = i
                }

                try? await Task.sleep(for: .seconds(0.25))
                withAnimation(FuelAnimation.spring) { showChips = true }

                // Hold
                try? await Task.sleep(for: .seconds(2.5))

                // Fade out
                withAnimation(FuelAnimation.spring) {
                    showUserBubble = false
                    showReply = false
                    showChips = false
                }
                try? await Task.sleep(for: .seconds(0.4))

                animCycle += 1
            }
        }
    }

    private func chatChip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 7, weight: .medium))
            Text(text)
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundStyle(FuelColors.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(FuelColors.white)
                .shadow(color: FuelColors.shadow.opacity(0.05), radius: 2, y: 1)
        )
        .overlay(Capsule().stroke(FuelColors.fog.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - Thinking Dots

private struct ShowcaseChatDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(FuelColors.stone.opacity(0.5))
                        .frame(width: 4, height: 4)
                        .offset(y: CGFloat(sin((t + Double(i) * 0.25) * .pi * 2) * 2.5))
                }
            }
        }
    }
}
