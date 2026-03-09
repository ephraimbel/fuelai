import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var step = 0
    @State private var goalType: GoalType = .maintain
    @State private var age: Int = 25
    @State private var sex: Sex = .male
    @State private var heightCm: Double = 175
    @State private var weightKg: Double = 75
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var targetWeightKg: Double = 70
    @State private var dietStyle: DietStyle = .standard
    @State private var mealsPerDay: Int = 3
    @State private var targetCalories: Int = 2000
    @State private var targetProtein: Int = 150
    @State private var targetCarbs: Int = 250
    @State private var targetFat: Int = 55

    private let totalSteps = 15

    // Steps where back button is hidden: Welcome (0), BuildingPlan (11), Disclaimer (13), Paywall (14)
    private var showBackButton: Bool {
        step > 0 && step != 11 && step != 13 && step < totalSteps - 1
    }

    // 11 visible dot steps (skip Welcome, BuildingPlan, Paywall)
    private var dotStep: Int {
        if step <= 10 { return step }
        if step == 12 { return 11 }
        return 0
    }

    private var showDots: Bool {
        step >= 1 && step <= 12 && step != 11
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation header
            HStack {
                if showBackButton {
                    Button {
                        FuelHaptics.shared.selection()
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FuelColors.ink)
                    }
                } else {
                    Color.clear.frame(width: 17, height: 17)
                }

                Spacer()

                if showDots {
                    HStack(spacing: FuelSpacing.xs) {
                        ForEach(1...11, id: \.self) { i in
                            Capsule()
                                .fill(i <= dotStep ? FuelColors.flame : FuelColors.mist)
                                .frame(width: i == dotStep ? 20 : 6, height: 6)
                                .animation(FuelAnimation.snappy, value: step)
                        }
                    }
                }

                Spacer()
                Color.clear.frame(width: 17, height: 17)
            }
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.vertical, FuelSpacing.sm)

            // Content
            ZStack(alignment: .top) {
                switch step {
                case 0:
                    WelcomeView(onContinue: { advance(to: 1) })
                case 1:
                    GoalSelectionView(selected: $goalType, onContinue: { advance(to: 2) })
                case 2:
                    SexSelectionView(selected: $sex, onContinue: { advance(to: 3) })
                case 3:
                    AgeSelectionView(age: $age, onContinue: { advance(to: 4) })
                case 4:
                    HeightSelectionView(heightCm: $heightCm, onContinue: { advance(to: 5) })
                case 5:
                    WeightSelectionView(weightKg: $weightKg, onContinue: { advance(to: 6) })
                case 6:
                    TargetWeightView(
                        targetWeightKg: $targetWeightKg,
                        currentWeightKg: weightKg,
                        goalType: goalType,
                        onContinue: { advance(to: 7) }
                    )
                case 7:
                    GoalValidationView(
                        goalType: goalType,
                        currentWeightKg: weightKg,
                        targetWeightKg: targetWeightKg,
                        onContinue: { advance(to: 8) }
                    )
                case 8:
                    ActivityLevelView(selected: $activityLevel, onContinue: { advance(to: 9) })
                case 9:
                    DietStyleView(selected: $dietStyle, onContinue: { advance(to: 10) })
                case 10:
                    MealFrequencyView(mealsPerDay: $mealsPerDay, onContinue: { advance(to: 11) })
                case 11:
                    BuildingPlanView(onContinue: {
                        withAnimation(FuelAnimation.spring) { step = 12 }
                    })
                case 12:
                    CalorieTargetView(
                        targetCalories: $targetCalories,
                        targetProtein: $targetProtein,
                        targetCarbs: $targetCarbs,
                        targetFat: $targetFat,
                        goalType: goalType,
                        age: age,
                        sex: sex,
                        heightCm: heightCm,
                        weightKg: weightKg,
                        activityLevel: activityLevel,
                        targetWeightKg: targetWeightKg,
                        dietStyle: dietStyle,
                        mealsPerDay: mealsPerDay,
                        onContinue: { advance(to: 13) }
                    )
                case 13:
                    DisclaimerAcknowledgmentView(onContinue: { advance(to: 14) })
                default:
                    PaywallView(onComplete: completeOnboarding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation

    private func advance(to nextStep: Int) {
        FuelHaptics.shared.tap()
        FuelSounds.shared.swoosh()
        withAnimation(FuelAnimation.spring) { step = nextStep }
    }

    private func goBack() {
        // Skip BuildingPlanView (11) — it auto-advances and would loop
        let target = step == 12 ? 10 : step - 1
        withAnimation(FuelAnimation.spring) { step = target }
    }

    // MARK: - Complete

    private func completeOnboarding() {
        var profile = appState.userProfile ?? UserProfile(
            id: UUID(),
            isPremium: false,
            streakCount: 0,
            longestStreak: 0,
            unitSystem: .imperial,
            createdAt: Date(),
            updatedAt: Date()
        )

        profile.age = age
        profile.sex = sex
        profile.heightCm = heightCm
        profile.weightKg = weightKg
        profile.activityLevel = activityLevel
        profile.goalType = goalType
        profile.targetWeightKg = targetWeightKg
        profile.dietStyle = dietStyle
        profile.mealsPerDay = mealsPerDay
        profile.targetCalories = targetCalories
        profile.targetProtein = targetProtein
        profile.targetCarbs = targetCarbs
        profile.targetFat = targetFat
        profile.updatedAt = Date()
        appState.userProfile = profile

        if appState.isAuthenticated {
            Task {
                try? await appState.databaseService?.updateProfile(profile)
            }
        }

        appState.hasCompletedOnboarding = true
    }
}
