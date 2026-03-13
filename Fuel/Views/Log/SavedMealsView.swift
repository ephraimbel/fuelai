import SwiftUI

struct SavedMealsView: View {
    @Environment(AppState.self) private var appState
    let onSelect: (FoodAnalysis) -> Void

    @State private var favorites: [FavoriteMeal] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            FuelColors.white.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(FuelColors.flame)
            } else if favorites.isEmpty {
                emptyState
            } else {
                mealList
            }
        }
        .task {
            await loadFavorites()
        }
    }

    // MARK: - Meal List

    private var mealList: some View {
        ScrollView {
            LazyVStack(spacing: FuelSpacing.sm) {
                ForEach(favorites) { favorite in
                    Button {
                        selectFavorite(favorite)
                    } label: {
                        favoriteRow(favorite)
                    }
                    .pressable()
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteFavorite(favorite)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, FuelSpacing.lg)
            .padding(.top, FuelSpacing.md)
        }
    }

    private func favoriteRow(_ favorite: FavoriteMeal) -> some View {
        HStack(spacing: FuelSpacing.md) {
            // Bookmark icon
            Image(systemName: "bookmark.fill")
                .font(.system(size: 14))
                .foregroundStyle(FuelColors.flame)
                .frame(width: 32, height: 32)
                .background(FuelColors.flame.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: FuelSpacing.xs) {
                Text(favorite.name)
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.ink)
                    .lineLimit(1)

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

            if favorite.useCount > 0 {
                Text("\(favorite.useCount)x")
                    .font(FuelType.micro)
                    .foregroundStyle(FuelColors.stone)
            }

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
            Image(systemName: "bookmark")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(FuelColors.fog)

            VStack(spacing: FuelSpacing.xs) {
                Text("No saved meals")
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.ink)

                Text("Tap the bookmark icon on any\nmeal result to save it here.")
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Data

    private func loadFavorites() async {
        guard let profile = appState.userProfile,
              let db = appState.databaseService else {
            isLoading = false
            return
        }

        do {
            let favs = try await db.getFavorites(userId: profile.id)
            await MainActor.run {
                favorites = favs
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
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
            totalFat: favorite.totalFat
        )

        // Increment use count in background
        Task {
            try? await appState.databaseService?.incrementFavoriteUse(id: favorite.id)
        }

        FuelHaptics.shared.tap()
        onSelect(analysis)
    }

    private func deleteFavorite(_ favorite: FavoriteMeal) {
        Task {
            try? await appState.databaseService?.deleteFavorite(id: favorite.id)
            await MainActor.run {
                withAnimation(FuelAnimation.snappy) {
                    favorites.removeAll { $0.id == favorite.id }
                }
            }
            FuelHaptics.shared.tap()
        }
    }
}
