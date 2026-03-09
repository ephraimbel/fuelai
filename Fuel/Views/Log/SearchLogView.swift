import SwiftUI

struct SearchLogView: View {
    @Environment(AppState.self) private var appState
    let onSearch: (String, FoodItem?) -> Void
    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var frequentMeals: [(name: String, calories: Int, count: Int)] {
        MealHistoryService.shared.topMeals(limit: 5)
    }

    private var suggestions: [(String, String)] {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: // Breakfast
            return [
                ("sunrise.fill", "2 eggs with toast"),
                ("cup.and.saucer.fill", "Oatmeal with banana"),
                ("takeoutbag.and.cup.and.straw.fill", "Starbucks latte"),
                ("frying.pan.fill", "Breakfast burrito"),
                ("leaf.fill", "Greek yogurt with berries"),
                ("bolt.fill", "Protein shake"),
            ]
        case 11..<14: // Lunch
            return [
                ("bird.fill", "Chicken breast 6oz"),
                ("takeoutbag.and.cup.and.straw.fill", "Chipotle burrito bowl"),
                ("fish.fill", "Salmon with rice"),
                ("leaf.fill", "Caesar salad with chicken"),
                ("flame.fill", "Turkey sandwich"),
                ("cup.and.saucer.fill", "Soup and salad"),
            ]
        case 14..<17: // Afternoon snack
            return [
                ("leaf.fill", "Apple with peanut butter"),
                ("bolt.fill", "Protein bar"),
                ("cup.and.saucer.fill", "Trail mix handful"),
                ("takeoutbag.and.cup.and.straw.fill", "Smoothie"),
                ("flame.fill", "Rice cakes with hummus"),
                ("star.fill", "Cottage cheese with fruit"),
            ]
        case 17..<21: // Dinner
            return [
                ("bird.fill", "Grilled chicken with vegetables"),
                ("fish.fill", "Salmon with asparagus"),
                ("frying.pan.fill", "Steak with sweet potato"),
                ("takeoutbag.and.cup.and.straw.fill", "Pasta with marinara"),
                ("flame.fill", "Stir fry with rice"),
                ("leaf.fill", "Burrito bowl"),
            ]
        default: // Late night
            return [
                ("takeoutbag.and.cup.and.straw.fill", "Late night pizza slice"),
                ("flame.fill", "Chips and guac"),
                ("cup.and.saucer.fill", "Cereal and milk"),
                ("star.fill", "Ice cream"),
                ("leaf.fill", "PB&J sandwich"),
                ("bolt.fill", "Protein shake"),
            ]
        }
    }

    private var suggestionsTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Breakfast ideas"
        case 11..<14: return "Lunch ideas"
        case 14..<17: return "Snack ideas"
        case 17..<21: return "Dinner ideas"
        default: return "Late night ideas"
        }
    }

    @State private var debouncedQuery = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var cachedAutocomplete: [RetrievalResult] = []

    var body: some View {
        ScrollView {
        VStack(spacing: FuelSpacing.lg) {
            // Remaining macros card
            if appState.calorieTarget > 0 {
                let isOver = appState.caloriesRemaining <= 0
                HStack(spacing: FuelSpacing.lg) {
                    VStack(spacing: 2) {
                        Text("\(abs(appState.caloriesRemaining))")
                            .font(FuelType.stat)
                            .foregroundStyle(isOver ? FuelColors.over : FuelColors.flame)
                        Text(isOver ? "cal over" : "cal left")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                    Divider().frame(height: 28)
                    VStack(spacing: 2) {
                        Text("\(abs(Int(appState.proteinRemaining)))g")
                            .font(FuelType.label)
                            .foregroundStyle(appState.proteinRemaining < 0 ? FuelColors.over : FuelColors.protein)
                        Text("protein")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                    VStack(spacing: 2) {
                        Text("\(abs(Int(appState.carbsRemaining)))g")
                            .font(FuelType.label)
                            .foregroundStyle(appState.carbsRemaining < 0 ? FuelColors.over : FuelColors.carbs)
                        Text("carbs")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                    VStack(spacing: 2) {
                        Text("\(abs(Int(appState.fatRemaining)))g")
                            .font(FuelType.label)
                            .foregroundStyle(appState.fatRemaining < 0 ? FuelColors.over : FuelColors.fat)
                        Text("fat")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                }
                .padding(.horizontal, FuelSpacing.lg)
                .padding(.vertical, FuelSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: FuelRadius.md)
                        .fill(isOver ? FuelColors.over.opacity(0.08) : FuelColors.cloud)
                )
                .padding(.horizontal, FuelSpacing.xl)
            }

            // Search field
            HStack(spacing: FuelSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.stone)

                TextField("What did you eat?", text: $query)
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.ink)
                    .submitLabel(.search)
                    .focused($isFocused)
                    .onSubmit { submitSearch() }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(FuelType.iconMd)
                            .foregroundStyle(FuelColors.fog)
                    }
                }
            }
            .padding(.horizontal, FuelSpacing.lg)
            .padding(.vertical, FuelSpacing.md)
            .background(FuelColors.cloud)
            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            .padding(.horizontal, FuelSpacing.xl)

            // Search button + autocomplete when query is entered
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Live autocomplete from local database
                let matches = autocompleteResults
                if !matches.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(matches.prefix(5).enumerated()), id: \.element.food.name) { index, result in
                            Button {
                                isFocused = false
                                FuelHaptics.shared.tap()
                                onSearch(result.food.name, result.food)
                            } label: {
                                HStack(spacing: FuelSpacing.md) {
                                    Image(systemName: "magnifyingglass")
                                        .font(FuelType.micro)
                                        .foregroundStyle(FuelColors.fog)
                                        .frame(width: 16)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.food.name)
                                            .font(FuelType.body)
                                            .foregroundStyle(FuelColors.ink)
                                            .lineLimit(1)
                                        Text("\(result.food.calories) cal · \(result.food.serving)")
                                            .font(FuelType.micro)
                                            .foregroundStyle(FuelColors.stone)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.up.left")
                                        .font(FuelType.micro)
                                        .foregroundStyle(FuelColors.fog)
                                }
                                .padding(.horizontal, FuelSpacing.lg)
                                .padding(.vertical, FuelSpacing.sm)
                            }
                            if index < min(matches.count, 5) - 1 {
                                Divider().padding(.leading, FuelSpacing.lg + 16 + FuelSpacing.md)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: FuelRadius.md)
                            .fill(FuelColors.white)
                            .shadow(color: FuelColors.shadow.opacity(0.08), radius: 8, y: 4)
                    )
                    .padding(.horizontal, FuelSpacing.xl)
                }

                Button { submitSearch() } label: {
                    HStack(spacing: FuelSpacing.sm) {
                        Image(systemName: "sparkles")
                            .font(FuelType.iconSm)
                        Text("Analyze with AI")
                            .font(FuelType.cardTitle)
                    }
                    .foregroundStyle(FuelColors.onDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FuelSpacing.lg)
                    .background(FuelColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                }
                .pressable()
                .padding(.horizontal, FuelSpacing.xl)
                .accessibilityLabel("Analyze with AI")
                .accessibilityHint("Sends your food description for AI-powered nutrition analysis")
            }

            if query.isEmpty {
                // Frequent meals from history
                if !frequentMeals.isEmpty {
                    VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                        Text("Your frequent meals")
                            .font(FuelType.label)
                            .foregroundStyle(FuelColors.stone)

                        ForEach(Array(frequentMeals.enumerated()), id: \.offset) { index, meal in
                            Button {
                                isFocused = false
                                FuelHaptics.shared.tap()
                                let ragFood = NutritionRAG.shared.retrieve(query: meal.name, topK: 1).first(where: { $0.score >= 3.0 })?.food
                                onSearch(meal.name, ragFood)
                            } label: {
                                HStack(spacing: FuelSpacing.md) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(FuelType.label)
                                        .foregroundStyle(FuelColors.stone)
                                        .frame(width: 20)

                                    Text(meal.name)
                                        .font(FuelType.body)
                                        .foregroundStyle(FuelColors.ink)

                                    Spacer()

                                    Text("\(meal.calories) cal")
                                        .font(FuelType.caption)
                                        .foregroundStyle(FuelColors.stone)

                                    Text("logged \(meal.count)x")
                                        .font(FuelType.micro)
                                        .foregroundStyle(FuelColors.fog)
                                }
                                .padding(.horizontal, FuelSpacing.lg)
                                .padding(.vertical, FuelSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: FuelRadius.md)
                                        .fill(FuelColors.cloud)
                                )
                            }
                            .pressable()
                            .staggeredAppear(index: index)
                        }
                    }
                    .padding(.horizontal, FuelSpacing.xl)
                }

                // Suggestions
                VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                    Text(suggestionsTitle)
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)

                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                        Button {
                            isFocused = false
                            FuelHaptics.shared.tap()
                            let ragFood = NutritionRAG.shared.retrieve(query: suggestion.1, topK: 1).first(where: { $0.score >= 3.0 })?.food
                            onSearch(suggestion.1, ragFood)
                        } label: {
                            HStack(spacing: FuelSpacing.md) {
                                Image(systemName: suggestion.0)
                                    .font(FuelType.label)
                                    .foregroundStyle(FuelColors.stone)
                                    .frame(width: 20)

                                Text(suggestion.1)
                                    .font(FuelType.body)
                                    .foregroundStyle(FuelColors.ink)

                                Spacer()

                                Image(systemName: "arrow.up.left")
                                    .font(FuelType.micro)
                                    .foregroundStyle(FuelColors.fog)
                            }
                            .padding(.horizontal, FuelSpacing.lg)
                            .padding(.vertical, FuelSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: FuelRadius.md)
                                    .fill(FuelColors.cloud)
                            )
                        }
                        .pressable()
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, FuelSpacing.xl)
            }

            Spacer()
        }
        .padding(.top, FuelSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { isFocused = true }
        .onChange(of: query) { _, newValue in
            if newValue.count > 200 { query = String(newValue.prefix(200)); return }
            debounceTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 2 {
                cachedAutocomplete = []
                return
            }
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                let results = NutritionRAG.shared.retrieve(query: trimmed, topK: 5)
                await MainActor.run { cachedAutocomplete = results }
            }
        }
    }

    private var autocompleteResults: [RetrievalResult] {
        cachedAutocomplete
    }

    private func submitSearch() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isFocused = false
        FuelHaptics.shared.tap()
        onSearch(text, nil)
    }
}
