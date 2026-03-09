import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var deleteError: String?
    @State private var mealToDelete: Meal?
    var body: some View {
        ScrollView {
            VStack(spacing: FuelSpacing.xl) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(FuelType.iconLg)
                            .foregroundStyle(FuelColors.flameGradient)
                        Text("fuel")
                            .font(FuelType.title)
                            .foregroundStyle(FuelColors.ink)
                            .baselineOffset(-1)
                    }
                    Spacer()
                    StreakPillView(streak: appState.currentStreak)
                }
                .padding(.horizontal, FuelSpacing.xl)
                .staggeredAppear(index: 0)

                // Week strip
                WeekStripView()
                    .padding(.horizontal, FuelSpacing.xl)
                    .staggeredAppear(index: 1)

                // Calorie card
                CalorieCardView()
                    .padding(.horizontal, FuelSpacing.xl)
                    .staggeredAppear(index: 2)

                // Macro pills
                HStack(spacing: FuelSpacing.md) {
                    MacroPillView(
                        label: "Protein",
                        remaining: appState.proteinRemaining,
                        target: Double(appState.proteinTarget),
                        consumed: appState.proteinConsumed,
                        color: FuelColors.protein,
                        icon: "p.circle.fill"
                    )
                    MacroPillView(
                        label: "Carbs",
                        remaining: appState.carbsRemaining,
                        target: Double(appState.carbsTarget),
                        consumed: appState.carbsConsumed,
                        color: FuelColors.carbs,
                        icon: "c.circle.fill"
                    )
                    MacroPillView(
                        label: "Fat",
                        remaining: appState.fatRemaining,
                        target: Double(appState.fatTarget),
                        consumed: appState.fatConsumed,
                        color: FuelColors.fat,
                        icon: "f.circle.fill"
                    )
                }
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
                        VStack(spacing: FuelSpacing.md) {
                            Image(systemName: "fork.knife")
                                .font(FuelType.title)
                                .foregroundStyle(FuelColors.fog)

                            VStack(spacing: FuelSpacing.xs) {
                                Text("No meals yet")
                                    .font(FuelType.cardTitle)
                                    .foregroundStyle(FuelColors.ink)
                                Text("Tap + to log your first meal")
                                    .font(FuelType.caption)
                                    .foregroundStyle(FuelColors.stone)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.xxl)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.card)
                                .fill(FuelColors.cloud)
                                .overlay(
                                    RoundedRectangle(cornerRadius: FuelRadius.card)
                                        .stroke(FuelColors.mist, lineWidth: 0.5)
                                )
                        )
                        .padding(.horizontal, FuelSpacing.xl)
                    } else {
                        ForEach(Array(appState.todayMeals.enumerated()), id: \.element.id) { index, meal in
                            MealCardView(meal: meal) {
                                mealToDelete = meal
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
        .background(FuelColors.white)
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
    }

    private func deleteMeal(_ meal: Meal) {
        Task {
            do {
                try await appState.databaseService?.deleteMeal(id: meal.id)
                await appState.refreshTodayData()
                await appState.recalculateDailySummary()
                FuelHaptics.shared.tap()
            } catch {
                await MainActor.run {
                    withAnimation { deleteError = "Couldn't delete meal. Please try again." }
                }
            }
        }
    }
}
