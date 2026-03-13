import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var deleteError: String?
    @State private var mealToDelete: Meal?
    @State private var editingMeal: Meal?
    @State private var editingMealImageData: Data?
    var body: some View {
        ScrollView {
            VStack(spacing: FuelSpacing.xl) {
                // Header
                HStack {
                    Image("FuelLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 34)
                    Spacer()
                    StreakPillView(streak: appState.currentStreak)
                }
                .padding(.horizontal, FuelSpacing.xl)
                .staggeredAppear(index: 0)

                // Week strip
                WeekStripView()
                    .padding(.horizontal, FuelSpacing.xl)
                    .staggeredAppear(index: 1)

                // Calorie + Macros + Micros unified card
                CalorieCardView()
                    .padding(.horizontal, FuelSpacing.xl)
                    .staggeredAppear(index: 2)

                // Water card
                WaterCardView()
                    .padding(.horizontal, FuelSpacing.xl)
                    .staggeredAppear(index: 3)

                // Today's meals
                VStack(alignment: .leading, spacing: FuelSpacing.md) {
                    HStack {
                        Text(Calendar.current.isDateInToday(appState.selectedDate) ? "Today's meals" : appState.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(FuelType.section)
                            .foregroundStyle(FuelColors.ink)
                        Spacer()
                        if !appState.todayMeals.isEmpty {
                            Text("\(appState.todayMeals.count) logged")
                                .font(FuelType.micro)
                                .foregroundStyle(FuelColors.fog)
                        }
                    }
                    .padding(.horizontal, FuelSpacing.xl)

                    if appState.todayMeals.isEmpty {
                        VStack(spacing: FuelSpacing.sm) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(FuelColors.fog)

                            Text(mealEmptyStateTitle)
                                .font(FuelType.caption)
                                .foregroundStyle(FuelColors.stone)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.xxl)
                        .padding(.horizontal, FuelSpacing.xl)
                    } else {
                        ForEach(Array(appState.todayMeals.enumerated()), id: \.element.id) { index, meal in
                            MealCardView(meal: meal) {
                                mealToDelete = meal
                            }
                            .onTapGesture {
                                FuelHaptics.shared.selection()
                                editingMealImageData = loadMealImageFromCache(meal)
                                editingMeal = meal
                                // Load remote image in background if cache missed
                                if editingMealImageData == nil, let imageUrl = meal.imageUrl, let url = URL(string: imageUrl) {
                                    Task {
                                        if let (data, _) = try? await URLSession.shared.data(from: url) {
                                            await MainActor.run {
                                                editingMealImageData = data
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, FuelSpacing.xl)
                            .staggeredAppear(index: 5 + index)
                        }
                    }
                }
                .staggeredAppear(index: 4)

                Spacer().frame(height: 80)
            }
            .padding(.top, FuelSpacing.sm)
        }
        .background(FuelColors.pageBackground)
        .toolbar(.hidden, for: .navigationBar)
        .animation(FuelAnimation.spring, value: appState.caloriesConsumed)
        .animation(FuelAnimation.spring, value: appState.todayMeals.count)
        .refreshable {
            await appState.refreshTodayData()
        }
        .onChange(of: appState.selectedDate) { _, _ in
            Task { await appState.refreshTodayData() }
        }
        .alert("Delete Meal", isPresented: Binding(
            get: { mealToDelete != nil },
            set: { if !$0 { mealToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let meal = mealToDelete {
                    deleteMeal(meal)
                    mealToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { mealToDelete = nil }
        } message: {
            if let meal = mealToDelete {
                Text("Delete \"\(meal.displayName)\"? This cannot be undone.")
            }
        }
        .alert("Error", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .fullScreenCover(item: $editingMeal) { meal in
            MealEditCover(
                meal: meal,
                initialImageData: editingMealImageData,
                appState: appState,
                onSave: { updatedAnalysis in
                    updateMeal(original: meal, with: updatedAnalysis)
                    editingMeal = nil
                },
                onDismiss: { editingMeal = nil }
            )
        }
    }

    private var mealEmptyStateTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Good morning — what's for breakfast?"
        case 11..<14: return "Lunch time — log what you're eating"
        case 14..<17: return "Afternoon snack? Log it here"
        case 17..<21: return "Dinner time — what's on the plate?"
        default: return "Late night bite? Track it here"
        }
    }

    private func loadMealImageFromCache(_ meal: Meal) -> Data? {
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("meal-images")
            .appendingPathComponent("\(meal.id.uuidString).jpg")
        return try? Data(contentsOf: cachePath)
    }

    private func updateMeal(original: Meal, with analysis: FoodAnalysis) {
        // Build updated meal from the edited analysis
        let updatedItems = analysis.items.map { item in
            MealItem(
                id: item.id, name: item.name, calories: item.calories,
                protein: item.protein, carbs: item.carbs, fat: item.fat,
                fiber: item.fiber, sugar: item.sugar,
                servingSize: item.servingSize, quantity: item.quantity, confidence: item.confidence
            )
        }
        var updatedMeal = Meal(
            id: original.id, userId: original.userId, items: updatedItems,
            totalCalories: analysis.totalCalories,
            totalProtein: analysis.totalProtein,
            totalCarbs: analysis.totalCarbs,
            totalFat: analysis.totalFat,
            totalFiber: analysis.fiberG ?? original.totalFiber,
            totalSugar: analysis.sugarG ?? original.totalSugar,
            totalSodium: analysis.sodiumMg ?? original.totalSodium,
            imageUrl: original.imageUrl,
            displayName: analysis.displayName,
            loggedDate: original.loggedDate,
            loggedAt: original.loggedAt,
            createdAt: original.createdAt
        )

        // Update in-memory
        if let idx = appState.todayMeals.firstIndex(where: { $0.id == original.id }) {
            withAnimation(FuelAnimation.spring) {
                appState.todayMeals[idx] = updatedMeal
            }
        }

        // Recalculate and persist
        Task {
            await appState.recalculateDailySummary(forceFromMeals: true)
            FuelHaptics.shared.tap()
            // Update in DB
            try? await appState.databaseService?.updateMealInPlace(updatedMeal)
            appState.dataVersion += 1
        }
    }

    private func deleteMeal(_ meal: Meal) {
        // Optimistic removal — animate the UI immediately
        withAnimation(FuelAnimation.spring) {
            appState.todayMeals.removeAll { $0.id == meal.id }
        }
        // Invalidate cache so stale data doesn't resurrect the deleted meal
        appState.invalidateDateCache()

        Task {
            // Recalculate summary from the updated meal list (force = skip max() guard)
            await appState.recalculateDailySummary(forceFromMeals: true)
            FuelHaptics.shared.tap()

            do {
                try await appState.databaseService?.deleteMeal(id: meal.id)
                // Refresh from DB to confirm
                await appState.refreshTodayData()
                await appState.recalculateDailySummary(forceFromMeals: true)
            } catch {
                // Restore meal on failure
                await MainActor.run {
                    withAnimation(FuelAnimation.spring) {
                        appState.todayMeals.append(meal)
                    }
                }
                await appState.recalculateDailySummary(forceFromMeals: true)
                await MainActor.run {
                    withAnimation { deleteError = "Couldn't delete meal. Please try again." }
                }
            }
        }
    }
}

// MARK: - Meal Edit Full Screen Cover

private struct MealEditCover: View {
    let meal: Meal
    let initialImageData: Data?
    let appState: AppState
    let onSave: (FoodAnalysis) -> Void
    let onDismiss: () -> Void

    @State private var imageData: Data?

    var body: some View {
        ZStack(alignment: .topLeading) {
            FoodResultsView(
                analysis: meal.toFoodAnalysis(),
                imageData: imageData,
                onLog: onSave,
                onRetake: onDismiss,
                retakeLabel: "Cancel"
            )
            .environment(appState)

            // Floating back button
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FuelColors.ink)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(.top, 54)
            .padding(.leading, FuelSpacing.lg)
        }
        .onAppear { imageData = initialImageData }
        .task {
            // If no cached image, load from remote URL
            if imageData == nil, let imageUrl = meal.imageUrl, let url = URL(string: imageUrl) {
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    withAnimation { imageData = data }
                }
            }
        }
    }
}
