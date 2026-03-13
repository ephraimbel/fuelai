import SwiftUI

struct CalorieCardView: View {
    @Environment(AppState.self) private var appState
    @State private var animatedProgress: Double = 0
    @State private var previousCalories: Int = -1
    @State private var flameScale: CGFloat = 1.0
    @State private var cardScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0
    @State private var didTriggerOverheatNudge = false

    private let overheatThreshold = 125

    private var isOver: Bool {
        appState.caloriesConsumed > appState.calorieTarget
    }
    private var isOverheating: Bool {
        appState.caloriesConsumed >= appState.calorieTarget + overheatThreshold
    }
    private var isFull: Bool {
        appState.calorieProgress >= 1.0
    }
    private var displayNumber: Int {
        isOver ? appState.caloriesConsumed - appState.calorieTarget : appState.caloriesRemaining
    }

    var body: some View {
        VStack(spacing: FuelSpacing.lg) {
            // Top section: Remaining — Flame — Goal
            HStack(spacing: 0) {
                // Left: Remaining
                VStack(spacing: 4) {
                    Text("\(displayNumber)")
                        .font(.system(size: 26, weight: .bold, design: .serif).monospacedDigit())
                        .foregroundStyle(isOver ? FuelColors.over : FuelColors.ink)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: displayNumber)
                    Text(isOver ? "over" : "remaining")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isOver ? FuelColors.over.opacity(0.7) : FuelColors.stone)
                }
                .frame(maxWidth: .infinity)

                // Center: Flame
                FlameProgressView(
                    progress: animatedProgress,
                    isOver: isOver,
                    isOverheating: isOverheating,
                    isFull: isFull,
                    glowOpacity: glowOpacity,
                    size: 110
                )
                .scaleEffect(flameScale)
                .frame(maxWidth: .infinity)

                // Right: Goal
                VStack(spacing: 4) {
                    Text("\(appState.calorieTarget)")
                        .font(.system(size: 26, weight: .bold, design: .serif).monospacedDigit())
                        .foregroundStyle(FuelColors.ink)
                    Text("goal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FuelColors.stone)
                }
                .frame(maxWidth: .infinity)
            }

            // Divider
            Rectangle()
                .fill(FuelColors.mist)
                .frame(height: 0.5)

            // Macros + Micros — 2-column grid
            NutrientGridView()
        }
        .padding(FuelSpacing.lg)
        .frame(maxWidth: .infinity)
        .fuelCard()
        .scaleEffect(cardScale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appState.caloriesRemaining) calories remaining. \(appState.caloriesConsumed) eaten of \(appState.calorieTarget) target.")
        .onAppear {
            previousCalories = appState.caloriesConsumed
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                animatedProgress = appState.calorieProgress
            }
        }
        .onChange(of: appState.calorieProgress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
        .onChange(of: appState.caloriesConsumed) { oldValue, newValue in
            previousCalories = newValue
            guard newValue != oldValue else { return }

            // Card pulse
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                cardScale = 1.02
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    cardScale = 1.0
                }
            }

            // Flame bounce
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                flameScale = 1.15
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    flameScale = 1.0
                }
            }

            // Glow pulse
            withAnimation(.easeIn(duration: 0.2)) {
                glowOpacity = 1.0
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.easeOut(duration: 0.8)) {
                    glowOpacity = 0
                }
            }

            // Coach nudge when overheating threshold is crossed
            if newValue > oldValue, !didTriggerOverheatNudge, newValue >= appState.calorieTarget + overheatThreshold {
                didTriggerOverheatNudge = true
                triggerOverheatNudge()
            }
        }
    }

    // MARK: - Overheat Coach Nudge

    private func triggerOverheatNudge() {
        guard let profile = appState.userProfile else { return }

        let overAmount = appState.caloriesConsumed - appState.calorieTarget
        let nudgeMessages = [
            "You're \(overAmount) over today — no stress, one day doesn't define your progress. Tomorrow's a clean slate.",
            "Went \(overAmount) over your target. It happens! A short walk tonight can help offset some of it.",
            "\(overAmount) over today — your weekly average still matters more than any single day. Stay consistent.",
        ]

        let message = nudgeMessages.randomElement() ?? nudgeMessages[0]

        let nudge = ChatMessage(
            id: UUID(),
            userId: profile.id,
            role: .assistant,
            content: message,
            createdAt: Date()
        )

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(FuelAnimation.spring) {
                appState.chatMessages.append(nudge)
            }
            try? await appState.databaseService?.saveChatMessage(nudge)
        }
    }
}

// MARK: - Nutrient Grid (macros + micros)

private struct NutrientGridView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let rows: [(left: NutrientData, right: NutrientData)] = [
            (
                NutrientData(label: "Protein", consumed: appState.proteinConsumed, target: Double(appState.proteinTarget), unit: "g", color: FuelColors.protein),
                NutrientData(label: "Carbs", consumed: appState.carbsConsumed, target: Double(appState.carbsTarget), unit: "g", color: FuelColors.carbs)
            ),
            (
                NutrientData(label: "Fat", consumed: appState.fatConsumed, target: Double(appState.fatTarget), unit: "g", color: FuelColors.fat),
                NutrientData(label: "Fiber", consumed: appState.fiberConsumed, target: appState.fiberTarget, unit: "g", color: FuelColors.success)
            ),
            (
                NutrientData(label: "Sodium", consumed: appState.sodiumConsumed, target: appState.sodiumTarget, unit: "mg", color: FuelColors.sodium, invertWarning: true),
                NutrientData(label: "Sugar", consumed: appState.sugarConsumed, target: appState.sugarTarget, unit: "g", color: FuelColors.sugar, invertWarning: true)
            ),
        ]

        VStack(spacing: FuelSpacing.lg) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: FuelSpacing.xl) {
                    NutrientBarRow(data: row.left)
                    NutrientBarRow(data: row.right)
                }
            }
        }
    }
}

private struct NutrientData {
    let label: String
    let consumed: Double
    let target: Double
    let unit: String
    let color: Color
    var invertWarning: Bool = false
}

private struct NutrientBarRow: View {
    let data: NutrientData

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard data.target > 0 else { return 0 }
        return data.consumed / data.target
    }

    private var isOver: Bool { data.consumed > data.target }

    private var barColor: Color {
        if data.invertWarning && isOver { return FuelColors.over }
        return data.color
    }

    private var valueText: String {
        if data.unit == "mg" && (data.consumed >= 1000 || data.target >= 1000) {
            let c = data.consumed >= 1000 ? String(format: "%.1fk", data.consumed / 1000) : "\(Int(data.consumed))"
            let t = data.target >= 1000 ? String(format: "%.1fk", data.target / 1000) : "\(Int(data.target))"
            return "\(c)/\(t) \(data.unit)"
        }
        return "\(Int(data.consumed))/\(Int(data.target))\(data.unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label + value
            HStack {
                Text(data.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FuelColors.ink)
                Spacer()
                Text(valueText)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(FuelColors.stone)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(data.color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * animatedProgress)))
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                animatedProgress = newValue
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(data.label): \(Int(data.consumed))\(data.unit) of \(Int(data.target))\(data.unit)")
    }
}

// MARK: - Flame Progress View

struct FlameProgressView: View {
    let progress: Double
    let isOver: Bool
    let isOverheating: Bool
    let isFull: Bool
    let glowOpacity: Double
    let size: CGFloat

    // Rich multi-stop gradient matching the logo's glossy orange
    private var fillGradient: LinearGradient {
        if isOver {
            return LinearGradient(
                stops: [
                    .init(color: Color(hex: "#C47800"), location: 0),
                    .init(color: Color(hex: "#E8920A"), location: 0.3),
                    .init(color: FuelColors.warning, location: 0.6),
                    .init(color: Color(hex: "#FBD569"), location: 0.85),
                    .init(color: Color(hex: "#FFF0C0"), location: 1.0),
                ],
                startPoint: .bottom, endPoint: .top
            )
        }
        return LinearGradient(
            stops: [
                .init(color: Color(hex: "#CC3600"), location: 0),
                .init(color: Color(hex: "#FF4D00"), location: 0.25),
                .init(color: Color(hex: "#FF6B2B"), location: 0.5),
                .init(color: Color(hex: "#FF8F4A"), location: 0.72),
                .init(color: Color(hex: "#FFBA80"), location: 0.9),
                .init(color: Color(hex: "#FFD6B0"), location: 1.0),
            ],
            startPoint: .bottom, endPoint: .top
        )
    }

    // Glossy highlight overlay
    private var glossGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0), location: 0),
                .init(color: .white.opacity(0), location: 0.4),
                .init(color: .white.opacity(0.18), location: 0.55),
                .init(color: .white.opacity(0.35), location: 0.7),
                .init(color: .white.opacity(0.12), location: 0.85),
                .init(color: .white.opacity(0), location: 1.0),
            ],
            startPoint: UnitPoint(x: 0.7, y: 1.0),
            endPoint: UnitPoint(x: 0.3, y: 0.0)
        )
    }

    private func fillMask(breathe: CGFloat = 0) -> some View {
        let clamped = min(max(progress, 0), 1.0)
        let empty = 1.0 - clamped
        return LinearGradient(
            stops: [
                .init(color: .clear, location: max(0, empty - 0.08)),
                .init(color: .white.opacity(0.4), location: max(0, empty - 0.02)),
                .init(color: .white, location: min(1.0, empty + 0.04)),
                .init(color: .white, location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .frame(width: size + 4, height: size + 4)
        .offset(y: breathe)
    }

    private func flameAura(t: Double) -> some View {
        let speed: Double = isOverheating ? 3.0 : 1.8
        let pulse = sin(t * speed) * 0.5 + 0.5
        let baseColor: Color = isOverheating ? FuelColors.over : (isOver ? FuelColors.warning : FuelColors.flame)
        let intensity: Double = isOverheating ? 0.22 : 0.14
        let outerIntensity: Double = isOverheating ? 0.10 : 0.06
        return ZStack {
            RadialGradient(
                colors: [
                    baseColor.opacity(intensity + pulse * 0.08),
                    baseColor.opacity(outerIntensity + pulse * 0.04),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.55),
                startRadius: size * 0.1,
                endRadius: size * (isOverheating ? 0.9 : 0.75)
            )
            .scaleEffect(1.0 + pulse * (isOverheating ? 0.08 : 0.04))

            if isOverheating {
                Circle()
                    .stroke(FuelColors.over.opacity(0.08 + pulse * 0.06), lineWidth: 1.5)
                    .frame(width: size * (1.1 + pulse * 0.15), height: size * (1.1 + pulse * 0.15))
                Circle()
                    .stroke(FuelColors.over.opacity(0.04 + (1 - pulse) * 0.04), lineWidth: 1)
                    .frame(width: size * (1.3 + (1 - pulse) * 0.1), height: size * (1.3 + (1 - pulse) * 0.1))
            }
        }
        .frame(width: size * 1.8, height: size * 1.8)
    }

    private var overheatGradient: [Gradient.Stop] {
        [
            .init(color: Color(hex: "#991100"), location: 0),
            .init(color: Color(hex: "#CC2200"), location: 0.25),
            .init(color: FuelColors.over, location: 0.5),
            .init(color: Color(hex: "#FF6B4A"), location: 0.75),
            .init(color: Color(hex: "#FFAA80"), location: 1.0),
        ]
    }

    var body: some View {
        if isFull {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let speed1: Double = isOverheating ? 4.0 : 2.5
                let speed2: Double = isOverheating ? 6.0 : 3.8
                let p1 = sin(t * speed1) * 0.5 + 0.5
                let p2 = sin(t * speed2 + 1.0) * 0.5 + 0.5

                let gradientStops: [Gradient.Stop] = isOverheating
                    ? overheatGradient
                    : (isOver
                        ? [
                            .init(color: Color(hex: "#C47800"), location: 0),
                            .init(color: Color(hex: "#E8920A"), location: 0.3),
                            .init(color: FuelColors.warning, location: 0.6),
                            .init(color: Color(hex: "#FBD569"), location: 0.85),
                            .init(color: Color(hex: "#FFF0C0"), location: 1.0),
                        ]
                        : [
                            .init(color: Color(hex: "#CC3600"), location: 0),
                            .init(color: Color(hex: "#FF4D00"), location: 0.25),
                            .init(color: Color(hex: "#FF6B2B"), location: 0.5),
                            .init(color: Color(hex: "#FF8F4A"), location: 0.72),
                            .init(color: Color(hex: "#FFBA80"), location: 0.9),
                        ])

                let accentColor: Color = isOverheating ? FuelColors.over : (isOver ? FuelColors.warning : FuelColors.flame)

                ZStack {
                    flameAura(t: t)

                    // Soft outer glow
                    Image(systemName: "flame.fill")
                        .font(.system(size: size + 8, weight: .thin))
                        .foregroundStyle(accentColor.opacity(isOverheating ? (0.18 + p1 * 0.12) : (0.12 + p1 * 0.06)))
                        .blur(radius: isOverheating ? 16 : 12)

                    // Main flame body with rich gradient
                    Image(systemName: "flame.fill")
                        .font(.system(size: size, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(stops: gradientStops, startPoint: UnitPoint(x: 0.5, y: 1.0), endPoint: UnitPoint(x: 0.5, y: -0.05))
                        )
                        .scaleEffect(
                            x: 1.0 + sin(t * (isOverheating ? 5.0 : 3.0)) * (isOverheating ? 0.03 : 0.015),
                            y: 1.0 + cos(t * (isOverheating ? 3.5 : 2.2)) * (isOverheating ? 0.04 : 0.02),
                            anchor: .bottom
                        )
                        .rotationEffect(.degrees(isOverheating ? sin(t * 4.0) * 1.5 : 0))

                    // Glossy highlight layer
                    Image(systemName: "flame.fill")
                        .font(.system(size: size, weight: .thin))
                        .foregroundStyle(glossGradient)
                        .scaleEffect(
                            x: 1.0 + sin(t * (isOverheating ? 5.0 : 3.0)) * (isOverheating ? 0.03 : 0.015),
                            y: 1.0 + cos(t * (isOverheating ? 3.5 : 2.2)) * (isOverheating ? 0.04 : 0.02),
                            anchor: .bottom
                        )
                        .rotationEffect(.degrees(isOverheating ? sin(t * 4.0) * 1.5 : 0))

                    // Inner core glow — warm bright center
                    Image(systemName: "flame.fill")
                        .font(.system(size: size * (isOverheating ? 0.48 : 0.42), weight: .thin))
                        .foregroundStyle(
                            RadialGradient(
                                stops: [
                                    .init(color: (isOverheating ? Color(hex: "#FFCC88") : Color(hex: "#FFFAF0"))
                                        .opacity(isOverheating ? (0.45 + p2 * 0.15) : (0.4 + p2 * 0.12)), location: 0),
                                    .init(color: (isOverheating ? Color(hex: "#FFAA66") : Color(hex: "#FFE8CC"))
                                        .opacity(isOverheating ? (0.2 + p2 * 0.08) : (0.15 + p2 * 0.06)), location: 0.5),
                                    .init(color: Color.clear, location: 1.0),
                                ],
                                center: UnitPoint(x: 0.5, y: 0.55),
                                startRadius: 0,
                                endRadius: size * (isOverheating ? 0.3 : 0.25)
                            )
                        )
                        .offset(y: size * 0.12)

                    // Outline stroke for definition
                    Image(systemName: "flame")
                        .font(.system(size: size, weight: .thin))
                        .foregroundStyle(accentColor.opacity(isOverheating ? (0.25 + p1 * 0.12) : (0.15 + p1 * 0.06)))
                }
                .frame(width: size + 12, height: size + 12)
            }
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let breathe = sin(t * 1.5) * 0.8

                ZStack {
                    flameAura(t: t)
                        .opacity(progress > 0 ? 1 : 0)

                    // Empty state background — subtle mist
                    Image(systemName: "flame.fill")
                        .font(.system(size: size, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FuelColors.mist.opacity(0.7), FuelColors.mist],
                                startPoint: .bottom, endPoint: .top
                            )
                        )

                    // Fill with rich glossy gradient
                    Image(systemName: "flame.fill")
                        .font(.system(size: size, weight: .thin))
                        .foregroundStyle(fillGradient)
                        .mask(fillMask(breathe: breathe))

                    // Glossy highlight on fill
                    Image(systemName: "flame.fill")
                        .font(.system(size: size, weight: .thin))
                        .foregroundStyle(glossGradient)
                        .mask(fillMask(breathe: breathe))

                    // Log pulse glow
                    Image(systemName: "flame.fill")
                        .font(.system(size: size + 4, weight: .thin))
                        .foregroundStyle(
                            (isOver ? FuelColors.warning : FuelColors.flame)
                                .opacity(0.3 * glowOpacity)
                        )
                        .blur(radius: 8)
                        .scaleEffect(1.0 + glowOpacity * 0.06)

                    // Outline for definition
                    Image(systemName: "flame")
                        .font(.system(size: size, weight: .thin))
                        .foregroundStyle(
                            (isOver ? FuelColors.warning : FuelColors.flame)
                                .opacity(progress > 0 ? 0.18 : 0.08)
                        )
                }
                .frame(width: size + 12, height: size + 12)
            }
        }
    }
}
