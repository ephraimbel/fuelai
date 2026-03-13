import SwiftUI

struct RecentMealsView: View {
    @Environment(AppState.self) private var appState
    let onSelect: (FoodAnalysis) -> Void

    @State private var meals: [GroupedMeal] = []
    @State private var favorites: [FavoriteMeal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            FuelColors.white.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(FuelColors.flame)
            } else if let error = errorMessage {
                VStack(spacing: FuelSpacing.md) {
                    Image(systemName: "wifi.slash")
                        .font(FuelType.title)
                        .foregroundStyle(FuelColors.fog)
                    Text(error)
                        .font(FuelType.caption)
                        .foregroundStyle(FuelColors.stone)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        isLoading = true
                        errorMessage = nil
                        Task {
                            await loadFavorites()
                            await loadRecentMeals()
                        }
                    }
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.flame)
                }
            } else if meals.isEmpty && favorites.isEmpty {
                emptyState
            } else {
                mealList
            }
        }
        .task {
            await loadFavorites()
            await loadRecentMeals()
        }
    }

    // MARK: - Meal List

    private var mealList: some View {
        ScrollView {
            LazyVStack(spacing: FuelSpacing.sm) {
                if !favorites.isEmpty {
                    HStack {
                        Text("Favorites")
                            .font(FuelType.label)
                            .foregroundStyle(FuelColors.stone)
                        Spacer()
                    }
                    .padding(.horizontal, FuelSpacing.lg)

                    ForEach(favorites) { favorite in
                        Button {
                            selectFavorite(favorite)
                        } label: {
                            favoriteRow(favorite)
                        }
                        .pressable()
                    }
                }

                if !meals.isEmpty {
                    HStack {
                        Text("Recent")
                            .font(FuelType.label)
                            .foregroundStyle(FuelColors.stone)
                        Spacer()
                    }
                    .padding(.horizontal, FuelSpacing.lg)
                    .padding(.top, favorites.isEmpty ? 0 : FuelSpacing.sm)

                    ForEach(meals) { meal in
                        Button {
                            selectMeal(meal)
                        } label: {
                            mealRow(meal)
                        }
                        .pressable()
                    }
                }
            }
            .padding(.horizontal, FuelSpacing.lg)
            .padding(.top, FuelSpacing.md)
        }
    }

    private func mealRow(_ meal: GroupedMeal) -> some View {
        HStack(spacing: FuelSpacing.md) {
            VStack(alignment: .leading, spacing: FuelSpacing.xs) {
                HStack(spacing: FuelSpacing.sm) {
                    Text(meal.displayName)
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.ink)
                        .lineLimit(1)

                    if meal.count > 1 {
                        Text("\(meal.count)x")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.onDark)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(FuelColors.stone)
                            )
                    }
                }

                HStack(spacing: FuelSpacing.sm) {
                    Text("\(meal.totalCalories) cal")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.flame)

                    macroPill("P", value: meal.totalProtein, color: FuelColors.protein)
                    macroPill("C", value: meal.totalCarbs, color: FuelColors.carbs)
                    macroPill("F", value: meal.totalFat, color: FuelColors.fat)
                }

                Text(meal.relativeTime)
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.stone)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(FuelType.iconSm)
                .foregroundStyle(FuelColors.fog)
        }
        .padding(FuelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.card)
                .fill(FuelColors.cloud)
        )
    }

    private func favoriteRow(_ favorite: FavoriteMeal) -> some View {
        HStack(spacing: FuelSpacing.md) {
            VStack(alignment: .leading, spacing: FuelSpacing.xs) {
                HStack(spacing: FuelSpacing.sm) {
                    Image(systemName: "star.fill")
                        .font(FuelType.badgeMicro)
                        .foregroundStyle(FuelColors.flame)

                    Text(favorite.name)
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.ink)
                        .lineLimit(1)
                }

                HStack(spacing: FuelSpacing.sm) {
                    Text("\(favorite.totalCalories) cal")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.flame)

                    macroPill("P", value: favorite.totalProtein, color: FuelColors.protein)
                    macroPill("C", value: favorite.totalCarbs, color: FuelColors.carbs)
                    macroPill("F", value: favorite.totalFat, color: FuelColors.fat)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(FuelType.iconSm)
                .foregroundStyle(FuelColors.fog)
        }
        .padding(FuelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.card)
                .fill(FuelColors.cloud)
        )
    }

    private func macroPill(_ label: String, value: Double, color: Color) -> some View {
        Text("\(label) \(Int(value))g")
            .font(FuelType.micro)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(color.opacity(0.1))
            )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FuelSpacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(FuelType.hero)
                .foregroundStyle(FuelColors.fog)

            Text("No recent meals")
                .font(FuelType.cardTitle)
                .foregroundStyle(FuelColors.ink)

            Text("Meals you log will appear here\nfor quick re-logging.")
                .font(FuelType.caption)
                .foregroundStyle(FuelColors.stone)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Data

    private func loadFavorites() async {
        guard let profile = appState.userProfile,
              let db = appState.databaseService else { return }

        do {
            let favs = try await db.getFavorites(userId: profile.id)
            await MainActor.run {
                favorites = favs
            }
        } catch {
            // Silently fail — favorites are non-critical
        }
    }

    private func selectFavorite(_ favorite: FavoriteMeal) {
        var items = favorite.items.map { item in
            AnalyzedFoodItem(
                id: UUID(),
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                servingSize: item.servingSize ?? "1 serving",
                estimatedGrams: item.estimatedGrams,
                measurementUnit: item.measurementUnit,
                measurementAmount: item.measurementAmount,
                confidence: item.confidence,
                note: nil
            )
        }

        // Fallback: if items are empty, create one from totals
        if items.isEmpty && favorite.totalCalories > 0 {
            items = [AnalyzedFoodItem(
                name: favorite.name,
                calories: favorite.totalCalories,
                protein: favorite.totalProtein,
                carbs: favorite.totalCarbs,
                fat: favorite.totalFat,
                servingSize: "1 serving",
                confidence: 1.0
            )]
        }

        let analysis = FoodAnalysis(
            items: items,
            displayName: favorite.name,
            totalCalories: favorite.totalCalories,
            totalProtein: favorite.totalProtein,
            totalCarbs: favorite.totalCarbs,
            totalFat: favorite.totalFat,
            fiberG: nil,
            sugarG: nil,
            sodiumMg: nil,
            warnings: nil,
            healthInsight: nil,
            calorieRange: nil,
            confidenceReason: nil,
            servingAssumed: nil
        )

        // Increment use count in background
        Task {
            try? await appState.databaseService?.incrementFavoriteUse(id: favorite.id)
        }

        FuelHaptics.shared.tap()
        onSelect(analysis)
    }

    private func loadRecentMeals() async {
        // Always include locally-logged meals (available immediately, no DB needed)
        let localMeals = await MainActor.run { appState.todayMeals }

        guard let profile = appState.userProfile,
              let db = appState.databaseService else {
            // No DB — show local meals only
            await MainActor.run {
                meals = groupMeals(localMeals)
                isLoading = false
            }
            return
        }

        do {
            let dbMeals = try await db.getRecentMeals(userId: profile.id)

            // Merge: DB meals + local meals not yet in DB (dedup by ID)
            let dbIDs = Set(dbMeals.map(\.id))
            let unsyncedLocal = localMeals.filter { !dbIDs.contains($0.id) }
            let allMeals = dbMeals + unsyncedLocal

            await MainActor.run {
                meals = groupMeals(allMeals)
                isLoading = false
            }
        } catch {
            // DB failed — fall back to local meals
            await MainActor.run {
                if localMeals.isEmpty {
                    errorMessage = "Unable to load recent meals."
                } else {
                    meals = groupMeals(localMeals)
                }
                isLoading = false
            }
        }
    }

    private func groupMeals(_ rawMeals: [Meal]) -> [GroupedMeal] {
        var seen: [String: (meal: Meal, count: Int)] = [:]
        var order: [String] = []

        for meal in rawMeals {
            let key = meal.displayName
            if var existing = seen[key] {
                existing.count += 1
                seen[key] = existing
            } else {
                seen[key] = (meal, 1)
                order.append(key)
            }
        }

        return order.compactMap { key in
            guard let entry = seen[key] else { return nil }
            let meal = entry.meal
            return GroupedMeal(
                id: meal.id,
                displayName: meal.displayName,
                totalCalories: meal.totalCalories,
                totalProtein: meal.totalProtein,
                totalCarbs: meal.totalCarbs,
                totalFat: meal.totalFat,
                items: meal.items,
                loggedAt: meal.loggedAt,
                count: entry.count
            )
        }
    }

    private func selectMeal(_ meal: GroupedMeal) {
        var items = meal.items.map { item in
            AnalyzedFoodItem(
                id: UUID(),
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                servingSize: item.servingSize ?? "1 serving",
                estimatedGrams: item.estimatedGrams,
                measurementUnit: item.measurementUnit,
                measurementAmount: item.measurementAmount,
                confidence: 1.0,
                note: nil
            )
        }

        // Fallback: if items are empty (e.g. meal_items not synced), create one from totals
        if items.isEmpty && meal.totalCalories > 0 {
            items = [AnalyzedFoodItem(
                name: meal.displayName,
                calories: meal.totalCalories,
                protein: meal.totalProtein,
                carbs: meal.totalCarbs,
                fat: meal.totalFat,
                servingSize: "1 serving",
                confidence: 1.0
            )]
        }

        let analysis = FoodAnalysis(
            items: items,
            displayName: meal.displayName,
            totalCalories: meal.totalCalories,
            totalProtein: meal.totalProtein,
            totalCarbs: meal.totalCarbs,
            totalFat: meal.totalFat,
            fiberG: nil,
            sugarG: nil,
            sodiumMg: nil,
            warnings: nil,
            healthInsight: nil,
            calorieRange: nil,
            confidenceReason: nil,
            servingAssumed: nil
        )

        FuelHaptics.shared.tap()
        onSelect(analysis)
    }
}

// MARK: - Grouped Meal

struct GroupedMeal: Identifiable {
    let id: UUID
    let displayName: String
    let totalCalories: Int
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let items: [MealItem]
    let loggedAt: Date
    let count: Int

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var relativeTime: String {
        Self.relativeDateFormatter.localizedString(for: loggedAt, relativeTo: Date())
    }
}
