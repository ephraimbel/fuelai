import SwiftUI

struct EditGoalsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var targetCalories: Int = 2000
    @State private var targetProtein: Int = 150
    @State private var targetCarbs: Int = 250
    @State private var targetFat: Int = 55
    @State private var waterGoalMl: Int = 2500
    @State private var goalType: GoalType = .maintain
    @State private var isMetric: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: FuelSpacing.xl) {
                // Goal type — grid since 6 items don't fit segmented
                VStack(alignment: .leading, spacing: FuelSpacing.md) {
                    Text("Goal")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: FuelSpacing.sm),
                        GridItem(.flexible(), spacing: FuelSpacing.sm),
                        GridItem(.flexible(), spacing: FuelSpacing.sm),
                    ], spacing: FuelSpacing.sm) {
                        ForEach(GoalType.allCases, id: \.self) { goal in
                            GoalChip(goal: goal, isSelected: goalType == goal) {
                                goalType = goal
                                FuelHaptics.shared.tap()
                            }
                        }
                    }
                }

                // Recalculate button
                Button {
                    recalculate()
                    FuelHaptics.shared.tap()
                } label: {
                    HStack(spacing: FuelSpacing.sm) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(FuelType.iconXs)
                        Text("Recalculate from profile")
                            .font(FuelType.caption)
                    }
                    .foregroundStyle(FuelColors.flame)
                    .padding(.vertical, FuelSpacing.sm)
                    .padding(.horizontal, FuelSpacing.md)
                    .background(FuelColors.flame.opacity(0.08))
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Calories
                MacroStepper(
                    label: "Daily Calories",
                    value: $targetCalories,
                    range: 1200...5000,
                    step: 50,
                    unit: "cal",
                    color: FuelColors.flame
                )

                // Macros
                MacroStepper(
                    label: "Protein",
                    value: $targetProtein,
                    range: 50...400,
                    step: 5,
                    unit: "g",
                    color: FuelColors.protein
                )

                MacroStepper(
                    label: "Carbs",
                    value: $targetCarbs,
                    range: 50...500,
                    step: 5,
                    unit: "g",
                    color: FuelColors.carbs
                )

                MacroStepper(
                    label: "Fat",
                    value: $targetFat,
                    range: 20...200,
                    step: 5,
                    unit: "g",
                    color: FuelColors.fat
                )

                // Water goal
                MacroStepper(
                    label: "Water Goal",
                    value: $waterGoalMl,
                    range: isMetric ? 1000...5000 : 34...170,
                    step: isMetric ? 250 : 8,
                    unit: isMetric ? "ml" : "oz",
                    color: FuelColors.water
                )

                // Macro calorie breakdown
                macroBreakdown
            }
            .padding(FuelSpacing.xl)
        }
        .background(FuelColors.pageBackground)
        .navigationTitle("Daily Target")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .font(FuelType.label)
                    .foregroundStyle(FuelColors.ink)
            }
        }
        .onAppear {
            if let profile = appState.userProfile {
                isMetric = profile.unitSystem == .metric
                targetCalories = profile.targetCalories ?? 2000
                targetProtein = profile.targetProtein ?? 150
                targetCarbs = profile.targetCarbs ?? 250
                targetFat = profile.targetFat ?? 55
                goalType = profile.goalType ?? .maintain
                let goalMl = profile.waterGoalMl ?? Constants.defaultWaterGoalMl
                waterGoalMl = isMetric ? goalMl : Int(round(Double(goalMl) / 29.5735))
            }
        }
        .onChange(of: goalType) { _, _ in
            recalculate()
        }
    }

    // MARK: - Macro Breakdown

    private var macroBreakdown: some View {
        let proteinCal = targetProtein * 4
        let carbsCal = targetCarbs * 4
        let fatCal = targetFat * 9
        let total = proteinCal + carbsCal + fatCal

        return VStack(spacing: FuelSpacing.sm) {
            HStack {
                Text("Macro calories")
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.stone)
                Spacer()
                Text("\(total) cal")
                    .font(FuelType.caption)
                    .foregroundStyle(total > targetCalories + 100 ? FuelColors.over : FuelColors.stone)
            }

            // Stacked bar
            GeometryReader { geo in
                let w = geo.size.width
                let pW = total > 0 ? w * CGFloat(proteinCal) / CGFloat(total) : 0
                let cW = total > 0 ? w * CGFloat(carbsCal) / CGFloat(total) : 0
                let fW = total > 0 ? w * CGFloat(fatCal) / CGFloat(total) : 0

                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(FuelColors.protein)
                        .frame(width: pW)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(FuelColors.carbs)
                        .frame(width: cW)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(FuelColors.fat)
                        .frame(width: fW)
                }
            }
            .frame(height: 6)

            HStack(spacing: FuelSpacing.lg) {
                MacroLabel(label: "Protein", pct: total > 0 ? proteinCal * 100 / total : 0, color: FuelColors.protein)
                MacroLabel(label: "Carbs", pct: total > 0 ? carbsCal * 100 / total : 0, color: FuelColors.carbs)
                MacroLabel(label: "Fat", pct: total > 0 ? fatCal * 100 / total : 0, color: FuelColors.fat)
                Spacer()
            }
        }
        .padding(FuelSpacing.lg)
        .background(FuelColors.cloud)
        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
    }

    // MARK: - Actions

    private func recalculate() {
        guard let profile = appState.userProfile else { return }
        let weight = max(30, profile.weightKg ?? 75)
        let height = max(120, profile.heightCm ?? 175)
        let age = max(16, profile.age ?? 25)
        let sex = profile.sex ?? .male
        let activity = profile.activityLevel ?? .moderate

        targetCalories = CalorieCalculator.calculateTargetCalories(
            weightKg: weight, heightCm: height, age: age,
            sex: sex, activityLevel: activity, goalType: goalType
        )
        let diet = profile.dietStyle ?? .standard
        let macros = CalorieCalculator.calculateMacros(
            targetCalories: targetCalories, goalType: goalType, weightKg: weight, dietStyle: diet
        )
        targetProtein = macros.protein
        targetCarbs = macros.carbs
        targetFat = macros.fat
    }

    private func save() {
        guard var profile = appState.userProfile else {
            dismiss()
            return
        }
        profile.goalType = goalType
        profile.targetCalories = targetCalories
        profile.targetProtein = targetProtein
        profile.targetCarbs = targetCarbs
        profile.targetFat = targetFat
        // Round to nearest 50ml to prevent precision drift from oz↔ml conversion
        let rawMl = isMetric ? waterGoalMl : Int(Double(waterGoalMl) * 29.5735)
        profile.waterGoalMl = ((rawMl + 25) / 50) * 50
        profile.updatedAt = Date()
        appState.userProfile = profile
        FuelHaptics.shared.tap()
        dismiss()
        Task {
            try? await appState.databaseService?.updateProfile(profile)
        }
    }
}

// MARK: - Goal Chip

private struct GoalChip: View {
    let goal: GoalType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: goal.iconName)
                    .font(FuelType.iconMd)

                Text(goal.displayName)
                    .font(FuelType.micro)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FuelSpacing.md)
            .foregroundStyle(isSelected ? FuelColors.onDark : FuelColors.ink)
            .background(isSelected ? FuelColors.ink : FuelColors.cloud)
            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: FuelRadius.md)
                    .stroke(isSelected ? .clear : FuelColors.mist, lineWidth: 0.5)
            )
        }
        .animation(FuelAnimation.snappy, value: isSelected)
    }
}

// MARK: - Macro Stepper

private struct MacroStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.sm) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(FuelType.label)
                    .foregroundStyle(FuelColors.stone)
            }
            Stepper(value: $value, in: range, step: step) {
                Text("\(value) \(unit)")
                    .font(FuelType.section)
                    .foregroundStyle(FuelColors.ink)
            }
        }
    }
}

// MARK: - Macro Label

private struct MacroLabel: View {
    let label: String
    let pct: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) \(pct)%")
                .font(FuelType.micro)
                .foregroundStyle(FuelColors.stone)
        }
    }
}
