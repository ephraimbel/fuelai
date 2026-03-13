import SwiftUI

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var age: Int = 25
    @State private var sex: Sex = .male
    @State private var heightCm: Double = 175
    @State private var weightKg: Double = 75
    @State private var activityLevel: ActivityLevel = .moderate

    private var isMetric: Bool {
        appState.userProfile?.unitSystem == .metric
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FuelSpacing.lg) {
                // Age
                VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                    Text("Age")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)
                    Stepper(value: $age, in: 16...80) {
                        Text("\(age) years")
                            .font(FuelType.section)
                            .foregroundStyle(FuelColors.ink)
                    }
                }

                // Sex
                VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                    Text("Sex")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)
                    Picker("Sex", selection: $sex) {
                        Text("Male").tag(Sex.male)
                        Text("Female").tag(Sex.female)
                    }
                    .pickerStyle(.segmented)
                }

                // Height
                VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                    Text("Height")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)

                    if isMetric {
                        Stepper(value: $heightCm, in: 120...220, step: 1) {
                            Text("\(Int(heightCm)) cm")
                                .font(FuelType.section)
                                .foregroundStyle(FuelColors.ink)
                        }
                    } else {
                        let totalInches = Int(heightCm / 2.54)
                        let feet = totalInches / 12
                        let inches = totalInches % 12

                        Stepper(value: $heightCm, in: 120...220, step: 2.54) {
                            Text("\(feet)'\(inches)\"")
                                .font(FuelType.section)
                                .foregroundStyle(FuelColors.ink)
                        }
                    }
                }

                // Weight
                VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                    Text("Weight")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)

                    if isMetric {
                        Stepper(value: $weightKg, in: 30...200, step: 0.5) {
                            Text(String(format: "%.1f kg", weightKg))
                                .font(FuelType.section)
                                .foregroundStyle(FuelColors.ink)
                        }
                    } else {
                        let lbs = weightKg * 2.205
                        Stepper(value: $weightKg, in: 30...200, step: 0.45) {
                            Text("\(Int(lbs)) lbs")
                                .font(FuelType.section)
                                .foregroundStyle(FuelColors.ink)
                        }
                    }
                }

                // Activity Level
                VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                    Text("Activity Level")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)

                    VStack(spacing: FuelSpacing.xs) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            ActivityRow(
                                level: level,
                                isSelected: activityLevel == level
                            ) {
                                activityLevel = level
                                FuelHaptics.shared.tap()
                            }
                        }
                    }
                }
            }
            .padding(FuelSpacing.xl)
        }
        .background(FuelColors.pageBackground)
        .navigationTitle("Body & Activity")
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
                age = profile.age ?? 25
                sex = profile.sex ?? .male
                heightCm = profile.heightCm ?? 175
                weightKg = profile.weightKg ?? 75
                activityLevel = profile.activityLevel ?? .moderate
            }
        }
    }

    private func save() {
        guard var profile = appState.userProfile else {
            dismiss()
            return
        }
        profile.age = age
        profile.sex = sex
        profile.heightCm = heightCm
        profile.weightKg = weightKg
        profile.activityLevel = activityLevel

        // Recalculate calorie & macro targets based on updated body stats
        let goal = profile.goalType ?? .maintain
        let newCalories = CalorieCalculator.calculateTargetCalories(
            weightKg: weightKg, heightCm: heightCm, age: age,
            sex: sex, activityLevel: activityLevel, goalType: goal
        )
        let diet = profile.dietStyle ?? .standard
        let newMacros = CalorieCalculator.calculateMacros(
            targetCalories: newCalories, goalType: goal, weightKg: weightKg, dietStyle: diet
        )
        profile.targetCalories = newCalories
        profile.targetProtein = newMacros.protein
        profile.targetCarbs = newMacros.carbs
        profile.targetFat = newMacros.fat

        profile.updatedAt = Date()
        appState.userProfile = profile
        FuelHaptics.shared.tap()
        dismiss()
        Task {
            try? await appState.databaseService?.updateProfile(profile)
        }
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let level: ActivityLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FuelSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.ink)
                    Text(level.description)
                        .font(FuelType.caption)
                        .foregroundStyle(FuelColors.stone)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? FuelColors.ink : FuelColors.mist, lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(FuelColors.ink)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, FuelSpacing.lg)
            .padding(.vertical, FuelSpacing.md)
            .background(isSelected ? FuelColors.cloud : FuelColors.white)
            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: FuelRadius.md)
                    .stroke(isSelected ? FuelColors.mist : FuelColors.mist.opacity(0.5), lineWidth: 0.5)
            )
        }
        .animation(FuelAnimation.snappy, value: isSelected)
    }
}
