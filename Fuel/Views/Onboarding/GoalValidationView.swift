import SwiftUI

struct GoalValidationView: View {
    let goalType: GoalType
    let currentWeightKg: Double
    let targetWeightKg: Double
    var unitSystem: UnitSystem = .imperial
    let onContinue: () -> Void

    @State private var appeared = false
    @State private var timerTask: Task<Void, Never>?

    private var isMetric: Bool { unitSystem == .metric }

    private var weightDiffDisplay: String {
        if isMetric {
            let diff = abs(currentWeightKg - targetWeightKg)
            return "\(String(format: "%.1f", diff)) kg"
        } else {
            let diff = Int(abs(currentWeightKg - targetWeightKg) * 2.20462)
            return "\(diff) lbs"
        }
    }

    private var weeklyChange: Double {
        CalorieCalculator.weeklyChangeKg(calorieDeficit: goalType.calorieAdjustment)
    }

    private var weeks: Int {
        CalorieCalculator.weeksToGoal(currentKg: currentWeightKg, targetKg: targetWeightKg, weeklyChangeKg: weeklyChange)
    }

    private var isWeightChange: Bool {
        Int(currentWeightKg) != Int(targetWeightKg)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FuelSpacing.sm) {
                (Text("Your goal is ")
                    .foregroundColor(FuelColors.ink) +
                 Text("achievable")
                    .foregroundColor(FuelColors.flame))
                    .font(FuelType.title)
                Text(subtitle)
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.lg)
            .staggeredAppear(index: 0)

            Spacer()

            // Animated checkmark with flame gradient circle
            ZStack {
                Circle()
                    .fill(FuelColors.flameGradient)
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(FuelColors.onDark)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(FuelAnimation.spring.delay(0.3), value: appeared)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .animation(FuelAnimation.spring.delay(0.1), value: appeared)
            .staggeredAppear(index: 1)

            Spacer().frame(height: FuelSpacing.xxl)

            // Detail rows
            VStack(spacing: 0) {
                if isWeightChange {
                    detailRow(
                        icon: "scalemass.fill",
                        text: weightSummary,
                        index: 2
                    )
                    Divider().foregroundStyle(FuelColors.mist).padding(.leading, 48)

                    detailRow(
                        icon: "calendar",
                        text: timelineSummary,
                        index: 3
                    )
                    Divider().foregroundStyle(FuelColors.mist).padding(.leading, 48)
                } else {
                    detailRow(
                        icon: "scalemass.fill",
                        text: "Stay consistent at your current weight",
                        index: 2
                    )
                    Divider().foregroundStyle(FuelColors.mist).padding(.leading, 48)
                }

                detailRow(
                    icon: "person.2.fill",
                    text: "93% of users with similar goals succeed",
                    index: isWeightChange ? 4 : 3
                )
            }
            .padding(FuelSpacing.lg)
            .background(FuelColors.cloud)
            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
            .padding(.horizontal, FuelSpacing.xl)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
            }
            .buttonStyle(.fuelPrimary)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.bottom, FuelSpacing.lg)
        }
        .onAppear {
            appeared = true
            timerTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                FuelSounds.shared.chime()
            }
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    // MARK: - Helpers

    private var subtitle: String {
        switch goalType {
        case .lose, .toneUp:
            return "A steady, sustainable approach to reach your target"
        case .maintain:
            return "Consistency is the key to long-term health"
        case .gain, .bulk:
            return "We'll help you build up at a healthy pace"
        case .athlete:
            return "Fueling your body for peak performance"
        }
    }

    private var weightSummary: String {
        let verb = currentWeightKg > targetWeightKg ? "Lose" : "Gain"
        return "\(verb) \(weightDiffDisplay) at a healthy pace"
    }

    private var timelineSummary: String {
        if weeks <= 4 {
            return "Estimated timeline: ~\(weeks) weeks"
        } else {
            let months = max(1, weeks / 4)
            return "Estimated timeline: ~\(months) month\(months == 1 ? "" : "s")"
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, text: String, index: Int) -> some View {
        HStack(spacing: FuelSpacing.md) {
            Image(systemName: icon)
                .font(FuelType.iconSm)
                .foregroundStyle(FuelColors.flame)
                .frame(width: 28, height: 28)
                .background(FuelColors.flame.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: FuelRadius.sm))

            Text(text)
                .font(FuelType.body)
                .foregroundStyle(FuelColors.ink)

            Spacer()
        }
        .padding(.vertical, FuelSpacing.sm)
        .staggeredAppear(index: index)
    }
}
