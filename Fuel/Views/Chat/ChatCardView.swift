import SwiftUI

struct ChatCardView: View {
    let card: ChatCard
    var onLogFood: ((String) -> Void)?
    var onDirectLog: ((String, Int, Double, Double, Double) -> Void)?
    var onApplyEdit: ((MealEditData) -> Void)?
    var onLogWithAnalysis: ((FoodAnalysis) -> Void)?
    @Environment(AppState.self) private var appState

    var body: some View {
        switch card.type {
        case .calorieProgress:
            ChatCalorieCard()
        case .macroBreakdown:
            ChatMacroCard()
        case .mealLog:
            ChatMealLogCard()
        case .tip:
            ChatTipCard(text: card.tipText ?? "")
        case .mealPlan:
            if let plan = card.mealPlanData {
                ChatMealPlanCard(plan: plan)
            }
        case .foodLog:
            if let query = card.foodQuery {
                ChatFoodLogCard(query: query, onTap: { onLogFood?(query) })
            }
        case .dailySummary:
            ChatDailySummaryCard()
        case .restaurantOrder:
            if let data = card.restaurantOrderData {
                ChatRestaurantOrderCard(data: data, onLogOrder: { name, cal, p, c, f in
                    onDirectLog?(name, cal, p, c, f)
                })
            }
        case .mealEdit:
            if let data = card.mealEditData {
                ChatMealEditCard(data: data, onApplyEdit: { onApplyEdit?(data) })
            }
        case .groceryList:
            if let data = card.groceryListData {
                ChatGroceryListCard(data: data)
            }
        case .mealPrep:
            if let data = card.mealPrepData {
                ChatMealPrepCard(data: data, onLogItem: { analysis in
                    onLogWithAnalysis?(analysis)
                })
            }
        case .substitution:
            if let data = card.substitutionData {
                ChatSubstitutionCard(data: data, onLogItem: { analysis in
                    onLogWithAnalysis?(analysis)
                })
            }
        case .fridgeMeal:
            if let data = card.fridgeMealData {
                ChatFridgeMealCard(data: data, onLogMeal: { analysis in
                    onLogWithAnalysis?(analysis)
                })
            }
        case .streakRecovery:
            if let data = card.streakRecoveryData {
                ChatStreakRecoveryCard(data: data, onLogMeal: { analysis in
                    onLogWithAnalysis?(analysis)
                })
            }
        case .unknown:
            EmptyView()
        }
    }
}

// MARK: - Calorie Progress Card

private struct ChatCalorieCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: FuelSpacing.lg) {
            CalorieRingView(progress: appState.calorieProgress, size: 52, lineWidth: 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(appState.caloriesRemaining)")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .contentTransition(.numericText())
                        .foregroundStyle(FuelColors.ink)
                    Text(" cal left")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(FuelColors.stone)
                }

                HStack(spacing: FuelSpacing.lg) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Eaten")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FuelColors.stone)
                        Text("\(appState.caloriesConsumed)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FuelColors.ink)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Target")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FuelColors.stone)
                        Text("\(appState.calorieTarget)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FuelColors.ink)
                    }
                }
            }

            Spacer()
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calorie progress: \(appState.caloriesRemaining) calories remaining. Eaten \(appState.caloriesConsumed) of \(appState.calorieTarget)")
    }
}

// MARK: - Macro Breakdown Card

private struct ChatMacroCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: FuelSpacing.md) {
            miniMacroPill(label: "Protein", consumed: appState.proteinConsumed, target: Double(appState.proteinTarget), color: FuelColors.protein, icon: "bolt.fill")
            miniMacroPill(label: "Carbs", consumed: appState.carbsConsumed, target: Double(appState.carbsTarget), color: FuelColors.carbs, icon: "leaf.fill")
            miniMacroPill(label: "Fat", consumed: appState.fatConsumed, target: Double(appState.fatTarget), color: FuelColors.fat, icon: "oval.fill")
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Macros: Protein \(Int(max(0, Double(appState.proteinTarget) - appState.proteinConsumed)))g left, Carbs \(Int(max(0, Double(appState.carbsTarget) - appState.carbsConsumed)))g left, Fat \(Int(max(0, Double(appState.fatTarget) - appState.fatConsumed)))g left")
    }

    private func miniMacroPill(label: String, consumed: Double, target: Double, color: Color, icon: String) -> some View {
        let progress = target > 0 ? consumed / target : 0
        let remaining = max(0, target - consumed)

        return VStack(spacing: 6) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 3)
                Circle().trim(from: 0, to: min(progress, 1)).stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            }
            .frame(width: 28, height: 28)

            Text("\(Int(remaining))g")
                .font(.system(size: 14, weight: .bold, design: .serif))
                .contentTransition(.numericText())
                .foregroundStyle(FuelColors.ink)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FuelColors.stone)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Meal Log Card

private struct ChatMealLogCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's meals")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FuelColors.stone)
                .textCase(.uppercase)
                .tracking(0.5)

            if appState.todayMeals.isEmpty {
                Text("Nothing logged yet.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(FuelColors.fog)
                    .padding(.vertical, FuelSpacing.sm)
            } else {
                ForEach(appState.todayMeals) { meal in
                    HStack(spacing: 10) {
                        if let imageUrl = meal.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                FuelColors.mist
                            }
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(FuelColors.mist)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(FuelColors.fog)
                                )
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(meal.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(FuelColors.ink)
                                .lineLimit(1)
                            Text("\(meal.totalCalories) cal")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(FuelColors.stone)
                        }

                        Spacer()

                        Text(meal.loggedAt.timeString)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(FuelColors.fog)
                    }

                    if meal.id != appState.todayMeals.last?.id {
                        Divider().foregroundStyle(FuelColors.mist)
                    }
                }
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's meals: \(appState.todayMeals.count) logged")
    }
}

// MARK: - Tip Card

private struct ChatTipCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FuelColors.flame)

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(FuelColors.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FuelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.card)
                .fill(FuelColors.flame.opacity(0.05))
                .stroke(FuelColors.flame.opacity(0.1), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tip: \(text)")
    }
}

// MARK: - Meal Plan Card

private struct ChatMealPlanCard: View {
    let plan: MealPlanData

    private let mealIcons: [String: String] = [
        "breakfast": "sunrise.fill", "lunch": "sun.max.fill",
        "dinner": "moon.fill", "snack": "leaf.fill",
    ]
    private let mealColors: [String: Color] = [
        "breakfast": FuelColors.carbs, "lunch": FuelColors.flame,
        "dinner": FuelColors.protein, "snack": FuelColors.success,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.lg) {
            HStack {
                Text("Your Plan")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(FuelColors.ink)
                Spacer()
                Text("\(plan.totalCalories) cal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FuelColors.flame)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(FuelColors.flame.opacity(0.08))
                    .clipShape(Capsule())
            }

            ForEach(plan.meals) { meal in
                mealRow(meal)
                if meal.id != plan.meals.last?.id {
                    Rectangle().fill(FuelColors.mist).frame(height: 0.5).padding(.leading, 36)
                }
            }

            HStack(spacing: FuelSpacing.md) {
                macroDot(value: Int(plan.totalProtein), label: "P", color: FuelColors.protein)
                macroDot(value: Int(plan.totalCarbs), label: "C", color: FuelColors.carbs)
                macroDot(value: Int(plan.totalFat), label: "F", color: FuelColors.fat)
            }
            .padding(.top, 2)
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Meal plan: \(plan.totalCalories) calories. \(plan.meals.map { "\($0.mealType): \($0.name)" }.joined(separator: ". "))")
    }

    private func mealRow(_ meal: PlannedMeal) -> some View {
        let key = meal.mealType.lowercased()
        let icon = mealIcons[key] ?? "fork.knife"
        let color = mealColors[key] ?? FuelColors.flame

        return HStack(alignment: .top, spacing: FuelSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.mealType)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FuelColors.stone)
                    .textCase(.uppercase).tracking(0.3)
                Text(meal.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FuelColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let desc = meal.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(FuelColors.stone)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(meal.calories)")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(FuelColors.ink)
                Text("cal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(FuelColors.stone)
            }
        }
    }

    private func macroDot(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(value)g \(label)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FuelColors.ink)
        }
    }
}

// MARK: - Food Log Card (Log from Chat)

private struct ChatFoodLogCard: View {
    let query: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: FuelSpacing.md) {
                ZStack {
                    Circle().fill(FuelColors.flame.opacity(0.1)).frame(width: 36, height: 36)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FuelColors.flame)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(query)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FuelColors.ink)
                        .lineLimit(2)
                    Text("Tap to log this")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FuelColors.stone)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FuelColors.fog)
            }
            .padding(FuelSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: FuelRadius.md)
                    .fill(FuelColors.flame.opacity(0.04))
                    .stroke(FuelColors.flame.opacity(0.12), lineWidth: 0.5)
            )
        }
        .pressable()
    }
}

// MARK: - Daily Summary Card

private struct ChatDailySummaryCard: View {
    @Environment(AppState.self) private var appState

    private var proteinProgress: Double { appState.proteinTarget > 0 ? appState.proteinConsumed / Double(appState.proteinTarget) : 0 }
    private var carbsProgress: Double { appState.carbsTarget > 0 ? appState.carbsConsumed / Double(appState.carbsTarget) : 0 }
    private var fatProgress: Double { appState.fatTarget > 0 ? appState.fatConsumed / Double(appState.fatTarget) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.lg) {
            HStack(spacing: FuelSpacing.sm) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FuelColors.flame)
                Text("Daily Recap")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(FuelColors.ink)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(appState.caloriesConsumed)")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                    Text(" / \(appState.calorieTarget) cal")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(FuelColors.stone)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(FuelColors.mist).frame(height: 6)
                        Capsule().fill(appState.calorieProgress > 1 ? FuelColors.over : FuelColors.flame)
                            .frame(width: max(0, geo.size.width * min(appState.calorieProgress, 1.0)), height: 6)
                    }
                }
                .frame(height: 6)
            }

            HStack(spacing: FuelSpacing.md) {
                summaryMacro(label: "Protein", consumed: Int(appState.proteinConsumed), target: appState.proteinTarget, progress: proteinProgress, color: FuelColors.protein)
                summaryMacro(label: "Carbs", consumed: Int(appState.carbsConsumed), target: appState.carbsTarget, progress: carbsProgress, color: FuelColors.carbs)
                summaryMacro(label: "Fat", consumed: Int(appState.fatConsumed), target: appState.fatTarget, progress: fatProgress, color: FuelColors.fat)
            }

            VStack(alignment: .leading, spacing: 4) {
                if proteinProgress >= 0.9 { summaryBadge(icon: "checkmark.circle.fill", text: "Protein target hit", color: FuelColors.success) }
                if appState.calorieProgress >= 0.85 && appState.calorieProgress <= 1.1 { summaryBadge(icon: "checkmark.circle.fill", text: "Calories on target", color: FuelColors.success) }
                if appState.todayMeals.count >= (appState.userProfile?.mealsPerDay ?? 3) { summaryBadge(icon: "checkmark.circle.fill", text: "All meals logged", color: FuelColors.success) }
                if proteinProgress < 0.8 { summaryBadge(icon: "arrow.up.circle.fill", text: "Prioritize protein tomorrow", color: FuelColors.flame) }
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily summary: \(appState.caloriesConsumed) of \(appState.calorieTarget) calories. \(appState.todayMeals.count) meals logged")
    }

    private func summaryMacro(label: String, consumed: Int, target: Int, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(FuelColors.stone).textCase(.uppercase).tracking(0.3)
            Text("\(consumed)g").font(.system(size: 14, weight: .bold, design: .serif)).foregroundStyle(FuelColors.ink)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12)).frame(height: 4)
                    Capsule().fill(color).frame(width: max(0, geo.size.width * min(progress, 1.0)), height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
            Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(FuelColors.ink)
        }
    }
}

// MARK: - Restaurant Order Card

private struct ChatRestaurantOrderCard: View {
    let data: RestaurantOrderData
    let onLogOrder: (String, Int, Double, Double, Double) -> Void
    @State private var logged = false

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.lg) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FuelColors.flame)
                    Text(data.restaurant)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                }
                Spacer()
                Text("\(data.totalCalories) cal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FuelColors.flame)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(FuelColors.flame.opacity(0.08))
                    .clipShape(Capsule())
            }

            // Items
            ForEach(data.items) { item in
                HStack(alignment: .top, spacing: FuelSpacing.md) {
                    Circle()
                        .fill(FuelColors.flame.opacity(0.1))
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FuelColors.ink)

                        if let mods = item.modifications, !mods.isEmpty {
                            Text(mods.joined(separator: " · "))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(FuelColors.stone)
                        }
                    }

                    Spacer()

                    Text("\(item.calories)")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                }
            }

            // Macro summary
            HStack(spacing: FuelSpacing.md) {
                macroDot(value: Int(data.totalProtein), label: "P", color: FuelColors.protein)
                macroDot(value: Int(data.totalCarbs), label: "C", color: FuelColors.carbs)
                macroDot(value: Int(data.totalFat), label: "F", color: FuelColors.fat)
                Spacer()
            }

            // Log button
            Button {
                guard !logged else { return }
                logged = true
                FuelHaptics.shared.tap()
                onLogOrder(data.foodQuery, data.totalCalories, data.totalProtein, data.totalCarbs, data.totalFat)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: logged ? "checkmark" : "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(logged ? "Logged" : "Log this order")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(logged ? FuelColors.success : FuelColors.inkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(logged)
            .animation(FuelAnimation.quick, value: logged)
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Restaurant order: \(data.foodQuery), \(data.totalCalories) calories")
    }

    private func macroDot(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(value)g \(label)").font(.system(size: 11, weight: .medium)).foregroundStyle(FuelColors.ink)
        }
    }
}

// MARK: - Meal Edit Card

private struct ChatMealEditCard: View {
    let data: MealEditData
    let onApplyEdit: () -> Void
    @State private var applied = false

    private var calDiff: Int { data.newCalories - data.originalCalories }
    private var protDiff: Double { data.newProtein - data.originalProtein }

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.lg) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FuelColors.protein)
                Text("Edit: \(data.mealName)")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(FuelColors.ink)
                    .lineLimit(1)
                Spacer()
            }

            // Changes
            ForEach(data.changes) { change in
                HStack(spacing: FuelSpacing.sm) {
                    Image(systemName: changeIcon(for: change.action))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(changeColor(for: change.action))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 1) {
                        if let original = change.original, !original.isEmpty {
                            Text(original)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(FuelColors.stone)
                                .strikethrough(color: FuelColors.stone.opacity(0.5))
                        }
                        if let replacement = change.replacement, !replacement.isEmpty {
                            Text(replacement)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(FuelColors.ink)
                        }
                    }

                    Spacer()

                    let diff = change.calorieDiff
                    Text(diff > 0 ? "+\(diff)" : "\(diff)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(diff > 0 ? FuelColors.over : FuelColors.success)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background((diff > 0 ? FuelColors.over : FuelColors.success).opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // Before → After
            HStack(spacing: 0) {
                macroColumn(label: "Before", cal: data.originalCalories, protein: Int(data.originalProtein))
                Rectangle().fill(FuelColors.mist).frame(width: 1, height: 36)
                macroColumn(label: "After", cal: data.newCalories, protein: Int(data.newProtein))
            }
            .padding(.vertical, 8).padding(.horizontal, FuelSpacing.md)
            .background(RoundedRectangle(cornerRadius: 10).fill(FuelColors.cloud))

            // Apply button
            Button {
                guard !applied else { return }
                applied = true
                FuelHaptics.shared.tap()
                onApplyEdit()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: applied ? "checkmark" : "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(applied ? "Applied" : "Apply edit")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(applied ? FuelColors.success : FuelColors.protein)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(applied)
            .animation(FuelAnimation.quick, value: applied)
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Meal edit: \(data.mealName). Updated to \(data.newCalories) calories")
    }

    private func macroColumn(label: String, cal: Int, protein: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FuelColors.stone)
                .textCase(.uppercase).tracking(0.3)
            Text("\(cal) cal")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(FuelColors.ink)
            Text("\(protein)g protein")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FuelColors.stone)
        }
        .frame(maxWidth: .infinity)
    }

    private func changeIcon(for action: String) -> String {
        switch action {
        case "swap": return "arrow.triangle.2.circlepath"
        case "remove": return "minus.circle.fill"
        case "add": return "plus.circle.fill"
        case "resize": return "arrow.up.arrow.down"
        default: return "pencil"
        }
    }

    private func changeColor(for action: String) -> Color {
        switch action {
        case "swap": return FuelColors.protein
        case "remove": return FuelColors.over
        case "add": return FuelColors.success
        case "resize": return FuelColors.flame
        default: return FuelColors.stone
        }
    }
}

// MARK: - Grocery List Card

private struct ChatGroceryListCard: View {
    let data: GroceryListData
    @State private var copied = false

    private let categoryColors: [String: Color] = [
        "produce": FuelColors.success,
        "protein": FuelColors.flame,
        "dairy": FuelColors.fat,
        "dairy & eggs": FuelColors.fat,
        "grains": FuelColors.carbs,
        "grains & bread": FuelColors.carbs,
        "pantry": FuelColors.protein,
        "pantry staples": FuelColors.protein,
        "frozen": FuelColors.water,
        "snacks": FuelColors.sugar,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.lg) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FuelColors.flame)
                    Text("Grocery List")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                }
                Spacer()
                Text("\(data.totalItems) items")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FuelColors.stone)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(FuelColors.cloud)
                    .clipShape(Capsule())
            }

            // Categories
            ForEach(data.categories) { category in
                VStack(alignment: .leading, spacing: 6) {
                    // Category header
                    HStack(spacing: 6) {
                        Image(systemName: category.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(colorForCategory(category.name))
                        Text(category.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FuelColors.ink)
                            .textCase(.uppercase)
                            .tracking(0.3)
                    }

                    // Items
                    ForEach(category.items) { item in
                        HStack(spacing: 0) {
                            Text(item.name)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(FuelColors.ink)

                            if let note = item.note, !note.isEmpty {
                                Text(" \(note)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(FuelColors.flame)
                            }

                            Spacer()

                            Text(item.quantity)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(FuelColors.stone)
                        }
                        .padding(.leading, 16)
                    }
                }

                if category.id != data.categories.last?.id {
                    Rectangle().fill(FuelColors.mist).frame(height: 0.5)
                }
            }

            // Footer
            HStack {
                Text("\(data.estimatedDays)-day estimate")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FuelColors.stone)

                Spacer()

                // Copy button
                Button {
                    UIPasteboard.general.string = data.asPlainText
                    copied = true
                    FuelHaptics.shared.tap()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        copied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(copied ? "Copied" : "Copy list")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(copied ? FuelColors.success : FuelColors.flame)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background((copied ? FuelColors.success : FuelColors.flame).opacity(0.08))
                    .clipShape(Capsule())
                }
                .animation(FuelAnimation.quick, value: copied)

                // Share button
                ShareLink(item: data.asPlainText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FuelColors.stone)
                        .padding(6)
                        .background(FuelColors.cloud)
                        .clipShape(Circle())
                }
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Grocery list: \(data.categories.flatMap(\.items).count) items across \(data.categories.count) categories")
    }

    private func colorForCategory(_ name: String) -> Color {
        categoryColors[name.lowercased()] ?? FuelColors.flame
    }
}

// MARK: - Meal Prep Card

private struct ChatMealPrepCard: View {
    let data: MealPrepData
    let onLogItem: (FoodAnalysis) -> Void
    @State private var showGrocery = false

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.lg) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FuelColors.flame)
                    Text("Meal Prep Plan")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                }
                Spacer()
                Text("\(data.coversDays)-day plan")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FuelColors.flame)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(FuelColors.flame.opacity(0.08))
                    .clipShape(Capsule())
            }

            // Sessions
            ForEach(data.prepSessions) { session in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(session.sessionName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FuelColors.ink)
                            .textCase(.uppercase)
                            .tracking(0.3)
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "timer")
                                .font(.system(size: 10, weight: .semibold))
                            Text(session.estimatedTime)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(FuelColors.stone)
                    }

                    ForEach(session.items) { item in
                        HStack(spacing: FuelSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(FuelColors.ink)
                                if let note = item.prepNote, !note.isEmpty {
                                    Text(note)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(FuelColors.stone)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Text("x\(item.servings)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FuelColors.stone)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(FuelColors.cloud)
                                .clipShape(Capsule())

                            Text("\(item.perServing.calories)")
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(FuelColors.ink)

                            // Log one serving
                            Button {
                                FuelHaptics.shared.tap()
                                onLogItem(buildAnalysis(from: item))
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(FuelColors.flame)
                            }
                        }
                    }
                }

                if session.id != data.prepSessions.last?.id {
                    Rectangle().fill(FuelColors.mist).frame(height: 0.5)
                }
            }

            // Daily average
            HStack(spacing: FuelSpacing.md) {
                Text("~\(data.dailyAverage.calories) cal/day")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FuelColors.ink)
                Spacer()
                macroDot(value: Int(data.dailyAverage.protein), label: "P", color: FuelColors.protein)
                macroDot(value: Int(data.dailyAverage.carbs), label: "C", color: FuelColors.carbs)
                macroDot(value: Int(data.dailyAverage.fat), label: "F", color: FuelColors.fat)
            }
            .padding(.vertical, 6).padding(.horizontal, FuelSpacing.md)
            .background(RoundedRectangle(cornerRadius: 10).fill(FuelColors.cloud))

            // Grocery summary toggle
            if let grocery = data.grocerySummary, !grocery.isEmpty {
                Button {
                    withAnimation(FuelAnimation.snappy) { showGrocery.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(showGrocery ? "Hide shopping list" : "Shopping list (\(grocery.count) items)")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(.degrees(showGrocery ? 90 : 0))
                    }
                    .foregroundStyle(FuelColors.flame)
                }

                if showGrocery {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(grocery) { item in
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(FuelColors.ink)
                                Spacer()
                                Text(item.quantity)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(FuelColors.stone)
                            }
                        }
                    }
                    .padding(.leading, FuelSpacing.lg)
                }
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
    }

    private func buildAnalysis(from item: PrepItem) -> FoodAnalysis {
        let foodItem = AnalyzedFoodItem(
            name: item.name,
            calories: item.perServing.calories,
            protein: item.perServing.protein,
            carbs: item.perServing.carbs,
            fat: item.perServing.fat,
            servingSize: "1 serving",
            confidence: 0.85
        )
        return FoodAnalysis(
            items: [foodItem],
            displayName: item.name,
            totalCalories: item.perServing.calories,
            totalProtein: item.perServing.protein,
            totalCarbs: item.perServing.carbs,
            totalFat: item.perServing.fat
        )
    }

    private func macroDot(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(value)g \(label)").font(.system(size: 11, weight: .medium)).foregroundStyle(FuelColors.ink)
        }
    }
}

// MARK: - Substitution Card

private struct ChatSubstitutionCard: View {
    let data: SubstitutionData
    let onLogItem: (FoodAnalysis) -> Void

    private let bestForColors: [String: Color] = [
        "low carb": FuelColors.fat,
        "high protein": FuelColors.protein,
        "low calorie": FuelColors.success,
        "similar taste": FuelColors.carbs,
        "low fat": FuelColors.water,
        "keto": FuelColors.sugar,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.lg) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FuelColors.flame)
                Text("Swap Options")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(FuelColors.ink)
                Spacer()
            }

            // Original
            VStack(alignment: .leading, spacing: 4) {
                Text("ORIGINAL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FuelColors.fog)
                    .tracking(0.5)

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(data.original.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FuelColors.stone)
                        Text(data.original.serving)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(FuelColors.fog)
                    }
                    Spacer()
                    Text("\(data.original.calories) cal")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(FuelColors.stone)
                }
            }
            .padding(FuelSpacing.md)
            .background(RoundedRectangle(cornerRadius: 10).fill(FuelColors.cloud))

            // Arrow
            HStack {
                Spacer()
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FuelColors.fog)
                Spacer()
            }

            // Substitutes
            ForEach(data.substitutes) { sub in
                HStack(alignment: .top, spacing: FuelSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(sub.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FuelColors.ink)

                            if let bestFor = sub.bestFor {
                                Text(bestFor)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(bestForColors[bestFor.lowercased()] ?? FuelColors.flame)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(sub.serving)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(FuelColors.stone)

                        if let why = sub.why, !why.isEmpty {
                            Text(why)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(FuelColors.stone)
                                .lineSpacing(2)
                        }

                        // Macro comparison
                        HStack(spacing: FuelSpacing.md) {
                            let calDiff = sub.calories - data.original.calories
                            Text(calDiff >= 0 ? "+\(calDiff)" : "\(calDiff)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(calDiff > 0 ? FuelColors.over : FuelColors.success)

                            macroDot(value: Int(sub.protein), label: "P", color: FuelColors.protein)
                            macroDot(value: Int(sub.carbs), label: "C", color: FuelColors.carbs)
                            macroDot(value: Int(sub.fat), label: "F", color: FuelColors.fat)
                        }
                    }

                    Spacer()

                    Button {
                        FuelHaptics.shared.tap()
                        onLogItem(buildAnalysis(from: sub))
                    } label: {
                        Text("Log")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(FuelColors.inkSurface)
                            .clipShape(Capsule())
                    }
                }

                if sub.id != data.substitutes.last?.id {
                    Rectangle().fill(FuelColors.mist).frame(height: 0.5)
                }
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
    }

    private func buildAnalysis(from item: SubstitutionItem) -> FoodAnalysis {
        let foodItem = AnalyzedFoodItem(
            name: item.name,
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            servingSize: item.serving,
            confidence: 0.85
        )
        return FoodAnalysis(
            items: [foodItem],
            displayName: item.name,
            totalCalories: item.calories,
            totalProtein: item.protein,
            totalCarbs: item.carbs,
            totalFat: item.fat
        )
    }

    private func macroDot(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(value)g \(label)").font(.system(size: 11, weight: .medium)).foregroundStyle(FuelColors.ink)
        }
    }
}

// MARK: - Fridge Meal Card

private struct ChatFridgeMealCard: View {
    let data: FridgeMealData
    let onLogMeal: (FoodAnalysis) -> Void
    @State private var logged = false
    @State private var showSteps = false

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.lg) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "refrigerator.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FuelColors.success)
                    Text(data.mealName)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                        .lineLimit(2)
                }
                Spacer()
                if let time = data.cookTime, !time.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(time)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(FuelColors.stone)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(FuelColors.cloud)
                    .clipShape(Capsule())
                }
            }

            if let desc = data.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(FuelColors.stone)
            }

            // Ingredients
            VStack(alignment: .leading, spacing: 6) {
                Text("INGREDIENTS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FuelColors.fog)
                    .tracking(0.5)

                ForEach(data.ingredients) { ingredient in
                    HStack {
                        Text(ingredient.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FuelColors.ink)
                        Spacer()
                        Text(ingredient.amount)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(FuelColors.stone)
                        Text("\(ingredient.calories)")
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                            .foregroundStyle(FuelColors.ink)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            // Macro summary
            HStack(spacing: FuelSpacing.md) {
                Text("\(data.totalCalories) cal")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(FuelColors.ink)
                Spacer()
                macroDot(value: Int(data.totalProtein), label: "P", color: FuelColors.protein)
                macroDot(value: Int(data.totalCarbs), label: "C", color: FuelColors.carbs)
                macroDot(value: Int(data.totalFat), label: "F", color: FuelColors.fat)
            }
            .padding(.vertical, 8).padding(.horizontal, FuelSpacing.md)
            .background(RoundedRectangle(cornerRadius: 10).fill(FuelColors.cloud))

            // Instructions toggle
            if let steps = data.instructions, !steps.isEmpty {
                Button {
                    withAnimation(FuelAnimation.snappy) { showSteps.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.number")
                            .font(.system(size: 11, weight: .semibold))
                        Text(showSteps ? "Hide steps" : "Show steps")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(.degrees(showSteps ? 90 : 0))
                    }
                    .foregroundStyle(FuelColors.success)
                }

                if showSteps {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(FuelColors.success)
                                    .frame(width: 16)
                                Text(step)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(FuelColors.ink)
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(.leading, FuelSpacing.sm)
                }
            }

            // Log button
            Button {
                guard !logged else { return }
                logged = true
                FuelHaptics.shared.tap()
                onLogMeal(buildAnalysis())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: logged ? "checkmark" : "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(logged ? "Logged" : "Log This Meal")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(logged ? FuelColors.success : FuelColors.success)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(logged)
            .animation(FuelAnimation.quick, value: logged)
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
    }

    private func buildAnalysis() -> FoodAnalysis {
        let items = data.ingredients.map { ing in
            AnalyzedFoodItem(
                name: ing.name,
                calories: ing.calories,
                protein: ing.protein,
                carbs: ing.carbs,
                fat: ing.fat,
                servingSize: ing.amount,
                confidence: 0.85
            )
        }
        return FoodAnalysis(
            items: items,
            displayName: data.mealName,
            totalCalories: data.totalCalories,
            totalProtein: data.totalProtein,
            totalCarbs: data.totalCarbs,
            totalFat: data.totalFat
        )
    }

    private func macroDot(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(value)g \(label)").font(.system(size: 11, weight: .medium)).foregroundStyle(FuelColors.ink)
        }
    }
}

// MARK: - Streak Recovery Card

private struct ChatStreakRecoveryCard: View {
    let data: StreakRecoveryData
    let onLogMeal: (FoodAnalysis) -> Void

    private var situationColor: Color {
        switch data.situation {
        case "over_target": return FuelColors.over
        case "under_target": return FuelColors.warning
        default: return FuelColors.flame
        }
    }

    private var situationLabel: String {
        switch data.situation {
        case "over_target":
            if let excess = data.excessOrDeficit, excess > 0 { return "Over by \(excess) cal" }
            return "Over target"
        case "under_target":
            if let deficit = data.excessOrDeficit { return "Under by \(abs(deficit)) cal" }
            return "Under target"
        default: return "Streak reset"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.lg) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FuelColors.protein)
                    Text("Recovery Plan")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                }
                Spacer()
                Text(situationLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(situationColor)
                    .clipShape(Capsule())
            }

            // Strategy
            Text(data.recoveryPlan.strategy)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(FuelColors.ink)
                .lineSpacing(3)

            // Adjusted targets
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("ADJUSTED TARGET")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FuelColors.stone)
                        .tracking(0.3)
                    Text("\(data.recoveryPlan.targetAdjustment.calories) cal")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(FuelColors.mist).frame(width: 1, height: 36)

                HStack(spacing: FuelSpacing.md) {
                    macroDot(value: Int(data.recoveryPlan.targetAdjustment.protein), label: "P", color: FuelColors.protein)
                    macroDot(value: Int(data.recoveryPlan.targetAdjustment.carbs), label: "C", color: FuelColors.carbs)
                    macroDot(value: Int(data.recoveryPlan.targetAdjustment.fat), label: "F", color: FuelColors.fat)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 10).padding(.horizontal, FuelSpacing.md)
            .background(RoundedRectangle(cornerRadius: 10).fill(FuelColors.cloud))

            // Recovery meals
            let mealIcons: [String: String] = [
                "breakfast": "sunrise.fill", "lunch": "sun.max.fill",
                "dinner": "moon.fill", "snack": "leaf.fill",
            ]
            let mealColors: [String: Color] = [
                "breakfast": FuelColors.carbs, "lunch": FuelColors.flame,
                "dinner": FuelColors.protein, "snack": FuelColors.success,
            ]

            ForEach(data.recoveryPlan.meals) { meal in
                let key = meal.mealType.lowercased()
                HStack(alignment: .top, spacing: FuelSpacing.md) {
                    Image(systemName: mealIcons[key] ?? "fork.knife")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(mealColors[key] ?? FuelColors.flame)
                        .frame(width: 24, height: 24)
                        .background((mealColors[key] ?? FuelColors.flame).opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.mealType)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(FuelColors.stone)
                            .textCase(.uppercase).tracking(0.3)
                        Text(meal.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FuelColors.ink)
                        if let desc = meal.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(FuelColors.stone)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(meal.calories)")
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.ink)

                        Button {
                            FuelHaptics.shared.tap()
                            onLogMeal(buildAnalysis(from: meal))
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(FuelColors.protein)
                        }
                    }
                }
            }

            // Motivation
            if let motivation = data.motivation, !motivation.isEmpty {
                Rectangle().fill(FuelColors.mist).frame(height: 0.5)
                Text(motivation)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(FuelColors.stone)
                    .italic()
                    .lineSpacing(3)
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
    }

    private func buildAnalysis(from meal: RecoveryMeal) -> FoodAnalysis {
        let foodItem = AnalyzedFoodItem(
            name: meal.name,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat,
            servingSize: "1 serving",
            confidence: 0.85
        )
        return FoodAnalysis(
            items: [foodItem],
            displayName: meal.name,
            totalCalories: meal.calories,
            totalProtein: meal.protein,
            totalCarbs: meal.carbs,
            totalFat: meal.fat
        )
    }

    private func macroDot(value: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(value)g \(label)").font(.system(size: 11, weight: .medium)).foregroundStyle(FuelColors.ink)
        }
    }
}
