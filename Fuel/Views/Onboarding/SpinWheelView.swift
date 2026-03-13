import SwiftUI
import StoreKit

struct SpinWheelView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    let onClaim: () -> Void
    let onDismiss: () -> Void

    @State private var currentRotation: Double = 0
    @State private var hasSpun = false
    @State private var showResult = false
    @State private var showConfetti = false
    @State private var wheelScale: CGFloat = 0.6

    private let segments: [(label: String, color: Color)] = [
        ("10% OFF", FuelColors.cloud),
        ("25% OFF", FuelColors.mist),
        ("15% OFF", FuelColors.cloud),
        ("60% OFF", FuelColors.cloud),
        ("20% OFF", FuelColors.mist),
        ("30% OFF", FuelColors.cloud),
    ]

    var body: some View {
        ZStack {
            FuelColors.white
                .ignoresSafeArea()

            VStack(spacing: FuelSpacing.xl) {
                Spacer()

                if !showResult {
                    // Title
                    VStack(spacing: FuelSpacing.sm) {
                        Text("Wait!")
                            .font(FuelType.title)
                            .foregroundStyle(FuelColors.ink)

                        Text("Spin for a special deal")
                            .font(FuelType.body)
                            .foregroundStyle(FuelColors.stone)
                    }
                }

                // Wheel
                ZStack {
                    // Wheel segments
                    ZStack {
                        ForEach(0..<segments.count, id: \.self) { i in
                            let start = Angle.degrees(Double(i) * 60)
                            let end = Angle.degrees(Double(i + 1) * 60)

                            PieSlice(startAngle: start, endAngle: end)
                                .fill(segments[i].color)

                            PieSlice(startAngle: start, endAngle: end)
                                .stroke(FuelColors.ink, lineWidth: 3)

                            // Segment label
                            segmentLabel(segments[i].label, index: i)
                        }
                    }
                    .frame(width: 280, height: 280)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(FuelColors.ink, lineWidth: 3))
                    .rotationEffect(.degrees(currentRotation))

                    // Center button
                    if !hasSpun {
                        Button {
                            spin()
                        } label: {
                            Circle()
                                .fill(FuelColors.ink)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Text("SPIN")
                                        .font(FuelType.cardTitle)
                                        .foregroundStyle(FuelColors.cloud)
                                )
                                .shadow(color: FuelColors.shadow.opacity(0.2), radius: 4, y: 2)
                        }
                    } else {
                        Circle()
                            .fill(FuelColors.ink)
                            .frame(width: 44, height: 44)
                    }

                    // Pointer at 12 o'clock
                    Triangle()
                        .fill(FuelColors.flame)
                        .frame(width: 24, height: 20)
                        .offset(y: -150)
                }
                .scaleEffect(wheelScale)

                // Result card
                if showResult {
                    resultCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
            .padding(.horizontal, FuelSpacing.xl)

            // Confetti
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                wheelScale = 1.0
            }
        }
    }

    // MARK: - Segment Label

    private func segmentLabel(_ text: String, index: Int) -> some View {
        let midAngle = Double(index) * 60 + 30
        let labelRadius: CGFloat = 100
        let radians = midAngle * .pi / 180

        return Text(text)
            .font(FuelType.label)
            .foregroundStyle(FuelColors.ink)
            .fontWeight(.semibold)
            .rotationEffect(.degrees(midAngle))
            .offset(
                x: labelRadius * CGFloat(sin(radians)),
                y: -labelRadius * CGFloat(cos(radians))
            )
    }

    // MARK: - Result Card

    private var discountedProduct: Product? {
        subscriptionService.products.first { $0.id == Constants.discountedWeeklyProductID }
    }

    private var regularProduct: Product? {
        subscriptionService.products.first { $0.id == Constants.weeklyProductID }
    }

    private var resultCard: some View {
        VStack(spacing: FuelSpacing.lg) {
            Text("You won 60% off!")
                .font(FuelType.title)
                .foregroundStyle(FuelColors.ink)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(discountedProduct?.displayPrice ?? "$1.99")
                    .font(FuelType.hero)
                    .foregroundStyle(FuelColors.flame)
                Text("/wk")
                    .font(FuelType.stat)
                    .foregroundStyle(FuelColors.stone)
            }

            Text("\(regularProduct?.displayPrice ?? "$4.99")/wk")
                .font(FuelType.body)
                .foregroundStyle(FuelColors.stone)
                .strikethrough()

            Button {
                FuelHaptics.shared.tap()
                onClaim()
            } label: {
                Text("Claim Your Deal")
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.onDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FuelColors.flame)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            }

            Text("This offer expires when you leave this page.")
                .font(FuelType.micro)
                .foregroundStyle(FuelColors.stone)
                .multilineTextAlignment(.center)

            Button {
                onDismiss()
            } label: {
                Text("No thanks")
                    .font(FuelType.label)
                    .foregroundStyle(FuelColors.stone)
                    .underline()
            }
        }
        .padding(FuelSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.card)
                .fill(FuelColors.cloud)
        )
    }

    // MARK: - Spin Logic

    private func spin() {
        guard !hasSpun else { return }
        hasSpun = true
        FuelHaptics.shared.tap()

        // Segment 3 center = 210° (index 3 × 60 + 30)
        // We spin clockwise, pointer at top (0°)
        // To land pointer on segment 3: wheel must rotate so 210° aligns with 0°
        // That means rotating 360° - 210° = 150° to land, plus full rotations
        let jitter = Double.random(in: -20...20)
        let finalAngle = 1800 + 150 + jitter

        // Fire haptic ticks
        fireHapticTicks()

        withAnimation(.timingCurve(0.12, 0.7, 0.2, 1.0, duration: 3.5)) {
            currentRotation = finalAngle
        }

        // Show result after spin completes
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_600_000_000)
            showConfetti = true
            FuelHaptics.shared.goalHit()
            FuelSounds.shared.celebration()

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showResult = true
            }
        }
    }

    private func fireHapticTicks() {
        let tickCount = 20
        let totalDuration: Double = 3.5

        for i in 0..<tickCount {
            // Exponentially increasing intervals (ticks slow down)
            let progress = Double(i) / Double(tickCount - 1)
            let delay = totalDuration * pow(progress, 2.2)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                FuelHaptics.shared.selection()
                FuelSounds.shared.tick()
            }
        }
    }
}

// MARK: - Shapes

private struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle - .degrees(90),
            endAngle: endAngle - .degrees(90),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
