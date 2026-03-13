import SwiftUI
import Charts

struct CalorieTargetView: View {
    @Binding var targetCalories: Int
    @Binding var targetProtein: Int
    @Binding var targetCarbs: Int
    @Binding var targetFat: Int
    let goalType: GoalType
    let age: Int
    let sex: Sex
    let heightCm: Double
    let weightKg: Double
    let activityLevel: ActivityLevel
    let targetWeightKg: Double
    let dietStyle: DietStyle
    let mealsPerDay: Int
    var unitSystem: UnitSystem = .imperial
    let onContinue: () -> Void

    @State private var displayedCalories: Int = 0
    @State private var showConfetti = false
    @State private var chartProgress: CGFloat = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var countUpTask: Task<Void, Never>?

    private var isMetric: Bool { unitSystem == .metric }

    private var tdee: Int {
        CalorieCalculator.calculateTDEE(
            weightKg: weightKg, heightCm: heightCm,
            age: age, sex: sex, activityLevel: activityLevel
        )
    }

    private var deficit: Int {
        tdee - targetCalories
    }

    private var hasWeightChange: Bool {
        Int(targetWeightKg) != Int(weightKg)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        Spacer().frame(height: FuelSpacing.xl)
                        calorieEditor
                        Spacer().frame(height: FuelSpacing.xxl)
                        macroBreakdown
                        Spacer().frame(height: FuelSpacing.lg)
                        if hasWeightChange {
                            weightChart
                            Spacer().frame(height: FuelSpacing.lg)
                        }
                        planDetails
                        Spacer().frame(height: FuelSpacing.lg)
                    }
                }
                .scrollIndicators(.hidden)

                Button(action: onContinue) {
                    Text("Start Tracking")
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.onDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.lg)
                        .background(FuelColors.flameGradient)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                }
                .pressable()
                .padding(.horizontal, FuelSpacing.xl)
                .padding(.bottom, FuelSpacing.lg)
            }

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            targetCalories = CalorieCalculator.calculateTargetCalories(
                weightKg: weightKg, heightCm: heightCm, age: age,
                sex: sex, activityLevel: activityLevel, goalType: goalType
            )
            updateMacros()
            animateCountUp()
            timerTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                showConfetti = true
                FuelHaptics.shared.logSuccess()
                FuelSounds.shared.celebration()
            }
        }
        .onDisappear {
            timerTask?.cancel()
            countUpTask?.cancel()
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.sm) {
            Text("Your personalized plan")
                .font(FuelType.title)
                .foregroundStyle(FuelColors.ink)
            Text(planSubtitle)
                .font(FuelType.body)
                .foregroundStyle(FuelColors.stone)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FuelSpacing.xl)
        .padding(.top, FuelSpacing.lg)
    }

    private var calorieEditor: some View {
        VStack(spacing: FuelSpacing.sm) {
            HStack(spacing: FuelSpacing.lg) {
                Button {
                    targetCalories = max(1200, targetCalories - 50)
                    updateMacros()
                    displayedCalories = targetCalories
                    FuelHaptics.shared.tap()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(FuelColors.mist)
                }

                Text("\(displayedCalories)")
                    .font(.system(size: 56, weight: .bold, design: .serif))
                    .foregroundStyle(FuelColors.ink)
                    .contentTransition(.numericText())

                Button {
                    targetCalories = min(5000, targetCalories + 50)
                    updateMacros()
                    displayedCalories = targetCalories
                    FuelHaptics.shared.tap()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(FuelColors.mist)
                }
            }

            Text("calories per day")
                .font(FuelType.body)
                .foregroundStyle(FuelColors.stone)

            if deficit != 0 {
                Text(contextLabel)
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.flame)
                    .padding(.top, FuelSpacing.xs)
            }
        }
        .staggeredAppear(index: 0)
    }

    private var macroBreakdown: some View {
        HStack(spacing: FuelSpacing.lg) {
            MacroPreview(label: "Protein", value: "\(targetProtein)g", color: FuelColors.protein)
                .staggeredAppear(index: 1)
            MacroPreview(label: "Carbs", value: "\(targetCarbs)g", color: FuelColors.carbs)
                .staggeredAppear(index: 2)
            MacroPreview(label: "Fat", value: "\(targetFat)g", color: FuelColors.fat)
                .staggeredAppear(index: 3)
        }
        .padding(.horizontal, FuelSpacing.xl)
    }

    @ViewBuilder
    private var weightChart: some View {
        let data = projectedWeightData()
        let allWeights = data.map(\.weight)
        let minW = allWeights.min() ?? 0
        let maxW = allWeights.max() ?? 0
        let range = maxW - minW
        // Ensure enough visible range so the curve always looks dramatic
        let minRange: Double = isMetric ? 5 : 10
        let visibleRange = max(range, minRange)
        let mid = (minW + maxW) / 2
        let yMin = mid - visibleRange * 0.65
        let yMax = mid + visibleRange * 0.55

        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [FuelColors.flame.opacity(0.18), FuelColors.flame.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(FuelColors.flame)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }

            // Start weight marker
            if let first = data.first {
                PointMark(
                    x: .value("Date", first.date),
                    y: .value("Weight", first.weight)
                )
                .foregroundStyle(FuelColors.flame)
                .symbolSize(40)
            }

            // Target weight marker
            if let last = data.last {
                PointMark(
                    x: .value("Date", last.date),
                    y: .value("Weight", last.weight)
                )
                .foregroundStyle(FuelColors.success)
                .symbolSize(50)
            }

            // Target dashed line
            RuleMark(y: .value("Target", displayWeight(targetWeightKg)))
                .foregroundStyle(FuelColors.fog)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .annotation(position: .trailing, alignment: .leading) {
                    Text("Goal")
                        .font(FuelType.micro)
                        .foregroundStyle(FuelColors.stone)
                }
        }
        .chartYScale(domain: yMin...yMax)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(FuelColors.mist)
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text("\(Int(weight))")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated)))
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                }
            }
        }
        .frame(height: 180)
        // Left-to-right reveal mask — draws the chart like a pencil sketch
        .mask(
            GeometryReader { geo in
                Rectangle()
                    .frame(width: geo.size.width * chartProgress)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        )
        .padding(FuelSpacing.lg)
        .background(FuelColors.cloud)
        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
        .padding(.horizontal, FuelSpacing.xl)
        // Card scales up gently as it enters
        .scaleEffect(chartProgress > 0 ? 1 : 0.92)
        .opacity(chartProgress > 0 ? 1 : 0)
        .staggeredAppear(index: 4)
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).delay(0.8)) {
                chartProgress = 1.0
            }
        }
    }

    private var planDetails: some View {
        VStack(spacing: 0) {
            if hasWeightChange {
                let weeklyChange = CalorieCalculator.weeklyChangeKg(calorieDeficit: deficit)
                let weeks = CalorieCalculator.weeksToGoal(currentKg: weightKg, targetKg: targetWeightKg, weeklyChangeKg: weeklyChange)
                let targetDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: Date()) ?? Date()
                let dateStr = targetDate.formatted(.dateTime.month(.wide).year())

                planRow(icon: "calendar", text: "Reach \(formattedWeight(targetWeightKg)) by \(dateStr)", index: 5)
                Divider().foregroundStyle(FuelColors.mist).padding(.leading, 48)
            }

            planRow(icon: "fork.knife", text: "\(targetCalories / max(1, mealsPerDay)) cal across \(mealsPerDay) meal\(mealsPerDay == 1 ? "" : "s")", index: 6)
            Divider().foregroundStyle(FuelColors.mist).padding(.leading, 48)

            planRow(icon: "bolt.fill", text: "\(targetProtein)g protein daily (\(targetProtein / max(1, mealsPerDay))g per meal)", index: 7)
            Divider().foregroundStyle(FuelColors.mist).padding(.leading, 48)

            planRow(icon: "figure.run", text: workoutRecommendation, index: 8)
            Divider().foregroundStyle(FuelColors.mist).padding(.leading, 48)

            planRow(icon: "drop.fill", text: "Drink at least \(waterGoalLiters) of water daily", index: 9)

            if dietStyle != .standard {
                Divider().foregroundStyle(FuelColors.mist).padding(.leading, 48)
                planRow(icon: "leaf.fill", text: "\(dietStyle.displayName) diet — macros tuned to match", index: 10)
            }

            Divider().foregroundStyle(FuelColors.mist).padding(.leading, 48)
            planRow(icon: "chart.line.uptrend.xyaxis", text: "Weigh in weekly to stay on track", index: 11)
        }
        .padding(FuelSpacing.lg)
        .background(FuelColors.cloud)
        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
        .padding(.horizontal, FuelSpacing.xl)
    }

    // MARK: - Components

    private func planRow(icon: String, text: String, index: Int) -> some View {
        HStack(spacing: FuelSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
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

    // MARK: - Dynamic Text

    private var planSubtitle: String {
        switch goalType {
        case .lose:
            let weeklyKg = Double(abs(deficit)) * 7 / 7700
            if isMetric {
                return "A \(abs(deficit)) cal deficit to lose ~\(String(format: "%.1f", weeklyKg)) kg per week"
            } else {
                return "A \(abs(deficit)) cal deficit to lose ~\(String(format: "%.1f", weeklyKg * 2.20462)) lbs per week"
            }
        case .toneUp:
            return "A moderate deficit to lean out while keeping muscle"
        case .maintain:
            return "Matched to your metabolism to maintain your weight"
        case .gain:
            return "A \(abs(deficit)) cal surplus to build lean muscle"
        case .bulk:
            return "A \(abs(deficit)) cal surplus for maximum gains"
        case .athlete:
            return "Fueling your training with enough energy to perform"
        }
    }

    private var contextLabel: String {
        if deficit > 0 {
            return "\(deficit) cal below your maintenance (\(tdee) cal)"
        } else {
            return "\(abs(deficit)) cal above your maintenance (\(tdee) cal)"
        }
    }

    private var workoutRecommendation: String {
        switch activityLevel {
        case .sedentary: return "Start with 2-3 walks per week"
        case .light: return "Aim for 3 workouts per week"
        case .moderate: return "Keep up 3-5 workouts per week"
        case .active: return "Maintain 5-6 training sessions per week"
        case .veryActive: return "Stay consistent with 6+ sessions per week"
        }
    }

    private var waterGoalLiters: String {
        let liters = weightKg * 0.033
        return String(format: "%.1fL", liters)
    }

    // MARK: - Logic

    private func animateCountUp() {
        let target = targetCalories
        let steps = 20
        let interval = 0.8 / Double(steps)
        countUpTask = Task { @MainActor in
            for i in 0...steps {
                if i > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                withAnimation(FuelAnimation.quick) {
                    displayedCalories = Int(Double(target) * Double(i) / Double(steps))
                }
                // Tick every 4th step for subtle counter sound
                if i % 4 == 0 && i > 0 && i < steps {
                    FuelSounds.shared.tick()
                }
            }
        }
    }

    private func updateMacros() {
        let macros = CalorieCalculator.calculateMacros(
            targetCalories: targetCalories,
            goalType: goalType,
            weightKg: weightKg,
            dietStyle: dietStyle
        )
        targetProtein = macros.protein
        targetCarbs = macros.carbs
        targetFat = macros.fat
    }

    private func displayWeight(_ kg: Double) -> Double {
        isMetric ? kg : kg * 2.20462
    }

    private func formattedWeight(_ kg: Double) -> String {
        if isMetric {
            return "\(String(format: "%.1f", kg)) kg"
        } else {
            return "\(Int(kg * 2.20462)) lbs"
        }
    }

    private func projectedWeightData() -> [(date: Date, weight: Double)] {
        let startDisplay = displayWeight(weightKg)
        let targetDisplay = displayWeight(targetWeightKg)
        let diffDisplay = targetDisplay - startDisplay
        let calendar = Calendar.current
        let now = Date()

        let weeklyChange = CalorieCalculator.weeklyChangeKg(calorieDeficit: deficit)
        let rawWeeks = CalorieCalculator.weeksToGoal(currentKg: weightKg, targetKg: targetWeightKg, weeklyChangeKg: weeklyChange)

        let weeks = max(rawWeeks, 16)
        let numPoints = 7
        var points: [(date: Date, weight: Double)] = []

        for i in 0...numPoints {
            let t = Double(i) / Double(numPoints)
            let date = calendar.date(byAdding: .weekOfYear, value: Int(Double(weeks) * t), to: now) ?? now
            let eased = 1 - pow(1 - t, 2.2)
            let weight = startDisplay + diffDisplay * eased
            points.append((date: date, weight: weight))
        }

        return points
    }
}

// MARK: - Macro Preview

private struct MacroPreview: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: FuelSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(value)
                .font(FuelType.stat)
                .foregroundStyle(FuelColors.ink)
            Text(label)
                .font(FuelType.caption)
                .foregroundStyle(FuelColors.stone)
        }
        .frame(maxWidth: .infinity)
    }
}
