import SwiftUI

struct SearchLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService

    /// Called for database search results: (query, exactFoodItem?)
    let onSearch: (String, FoodItem?) -> Void
    /// Called for AI describe mode: (description)
    let onDescribe: (String) -> Void
    /// Quick-log a food at default serving without showing results screen
    var onQuickLog: ((FoodItem) -> Void)? = nil
    /// Pre-fill the search field (e.g. from HomeView quick action)
    var initialQuery: String? = nil

    @State private var query = ""
    @FocusState private var isFocused: Bool

    /// Two distinct modes: database search vs AI describe
    @State private var isDescribeMode = false
    @State private var selectedCategory: QuickCategory = .popular
    @State private var didSetInitialCategory = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var cachedAutocomplete: [RetrievalResult] = []
    @State private var usdaResults: [FoodItem] = []
    @State private var isSearchingUSDA = false
    @State private var showingPaywall = false

    private var recentMeals: [(name: String, calories: Int)] {
        MealHistoryService.shared.recentMeals(limit: 8)
    }

    /// Pick the best default category based on time of day and what's already been logged.
    private var smartDefaultCategory: QuickCategory {
        let hour = Calendar.current.component(.hour, from: Date())
        let cals = appState.caloriesConsumed
        if cals == 0 {
            switch hour {
            case 5..<11: return .breakfast
            case 11..<15: return .lunch
            case 15..<17: return .snacks
            case 17..<22: return .dinner
            default: return .snacks
            }
        }
        switch hour {
        case 5..<11: return cals < 300 ? .breakfast : .snacks
        case 11..<15: return cals < 800 ? .lunch : .snacks
        case 15..<17: return .snacks
        case 17..<22: return .dinner
        default: return .snacks
        }
    }

    // MARK: - Quick Categories

    private enum QuickCategory: String, CaseIterable {
        case popular = "Popular"
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snacks = "Snacks"
        case fastFood = "Fast Food"
        case drinks = "Drinks"
        case protein = "Protein"

        var icon: String {
            switch self {
            case .popular: return "FlameIcon"
            case .breakfast: return "sunrise.fill"
            case .lunch: return "sun.max.fill"
            case .dinner: return "moon.stars.fill"
            case .snacks: return "cup.and.saucer.fill"
            case .fastFood: return "takeoutbag.and.cup.and.straw.fill"
            case .drinks: return "mug.fill"
            case .protein: return "bolt.fill"
            }
        }

        var foods: [(name: String, cal: Int, emoji: String)] {
            switch self {
            case .popular:
                return [
                    ("Chicken breast (6oz)", 281, "🍗"),
                    ("White rice (1 cup)", 206, "🍚"),
                    ("2 eggs scrambled", 182, "🥚"),
                    ("Banana", 105, "🍌"),
                    ("Greek yogurt", 130, "🥛"),
                    ("Salmon fillet (4oz)", 234, "🐟"),
                    ("Avocado (half)", 161, "🥑"),
                    ("Chicken salad bowl", 420, "🥗"),
                    ("Protein shake", 160, "🥤"),
                    ("Oatmeal with banana", 280, "🥣"),
                    ("Turkey sandwich", 380, "🥪"),
                    ("Sweet potato (medium)", 103, "🍠"),
                ]
            case .breakfast:
                return [
                    ("2 eggs scrambled", 182, "🥚"),
                    ("Oatmeal with banana", 280, "🥣"),
                    ("Greek yogurt with berries", 180, "🫐"),
                    ("Avocado toast", 290, "🥑"),
                    ("Breakfast burrito", 450, "🌯"),
                    ("Protein pancakes (3)", 340, "🥞"),
                    ("Overnight oats", 310, "🥣"),
                    ("Bagel with cream cheese", 370, "🥯"),
                    ("Smoothie bowl", 350, "🍓"),
                    ("2 eggs with toast", 280, "🍳"),
                    ("Fruit bowl", 180, "🍇"),
                    ("Granola with milk", 320, "🥄"),
                ]
            case .lunch:
                return [
                    ("Chicken breast with rice", 487, "🍗"),
                    ("Caesar salad with chicken", 440, "🥗"),
                    ("Turkey sandwich", 380, "🥪"),
                    ("Chipotle burrito bowl", 650, "🌯"),
                    ("Salmon with vegetables", 380, "🐟"),
                    ("Soup and salad", 350, "🥣"),
                    ("Tuna salad wrap", 420, "🫔"),
                    ("Grilled chicken wrap", 460, "🌯"),
                    ("Poke bowl", 520, "🍣"),
                    ("Mediterranean bowl", 480, "🥙"),
                    ("BLT sandwich", 390, "🥓"),
                    ("Cobb salad", 510, "🥗"),
                ]
            case .dinner:
                return [
                    ("Grilled chicken with vegetables", 380, "🍗"),
                    ("Salmon with asparagus", 380, "🐟"),
                    ("Steak with sweet potato", 580, "🥩"),
                    ("Pasta with marinara", 440, "🍝"),
                    ("Stir fry with rice", 520, "🥘"),
                    ("Burrito bowl", 650, "🌯"),
                    ("Grilled shrimp tacos (3)", 480, "🌮"),
                    ("Chicken curry with rice", 580, "🍛"),
                    ("Meatballs with pasta", 620, "🍝"),
                    ("Teriyaki salmon bowl", 540, "🐟"),
                    ("Stuffed bell peppers", 350, "🫑"),
                    ("Lemon herb chicken thighs", 420, "🍗"),
                ]
            case .snacks:
                return [
                    ("Apple with peanut butter", 270, "🍎"),
                    ("Protein bar", 220, "🍫"),
                    ("Trail mix (1/4 cup)", 175, "🥜"),
                    ("Hummus with veggies", 180, "🥕"),
                    ("Rice cakes with almond butter", 200, "🍘"),
                    ("Cottage cheese with fruit", 180, "🍑"),
                    ("Hard boiled egg", 78, "🥚"),
                    ("Banana with almond butter", 265, "🍌"),
                    ("Cheese and crackers", 210, "🧀"),
                    ("Edamame (1 cup)", 188, "🫛"),
                    ("Dark chocolate (1oz)", 170, "🍫"),
                    ("Mixed nuts (1oz)", 172, "🥜"),
                ]
            case .fastFood:
                return [
                    ("Big Mac", 563, "🍔"),
                    ("Chick-fil-A sandwich", 440, "🐔"),
                    ("Chipotle burrito", 1050, "🌯"),
                    ("In-N-Out burger", 480, "🍔"),
                    ("Subway 6\" turkey", 280, "🥪"),
                    ("Chicken nuggets (10pc)", 410, "🐔"),
                    ("French fries (medium)", 365, "🍟"),
                    ("Pizza slice (pepperoni)", 313, "🍕"),
                    ("Taco Bell crunchy taco", 170, "🌮"),
                    ("Wendy's Dave's Single", 570, "🍔"),
                    ("Panda Express orange chicken", 490, "🍊"),
                    ("Five Guys cheeseburger", 840, "🍔"),
                ]
            case .drinks:
                return [
                    ("Black coffee", 5, "☕"),
                    ("Starbucks latte (grande)", 190, "☕"),
                    ("Protein shake", 160, "🥤"),
                    ("Orange juice (8oz)", 112, "🍊"),
                    ("Green smoothie", 180, "🥬"),
                    ("Iced matcha latte", 200, "🍵"),
                    ("Coca-Cola (12oz)", 140, "🥤"),
                    ("Almond milk (8oz)", 30, "🥛"),
                    ("Whole milk (8oz)", 149, "🥛"),
                    ("Kombucha (12oz)", 60, "🍵"),
                    ("Coconut water (11oz)", 45, "🥥"),
                    ("Sports drink (20oz)", 140, "🥤"),
                ]
            case .protein:
                return [
                    ("Chicken breast (6oz)", 281, "🍗"),
                    ("Salmon (4oz)", 234, "🐟"),
                    ("Ground beef 90% lean (4oz)", 200, "🥩"),
                    ("2 large eggs", 156, "🥚"),
                    ("Turkey breast (4oz)", 153, "🦃"),
                    ("Tuna (1 can)", 191, "🐟"),
                    ("Shrimp (6oz)", 170, "🦐"),
                    ("Tofu firm (1/2 block)", 183, "🧈"),
                    ("Greek yogurt (1 cup)", 130, "🥛"),
                    ("Cottage cheese (1 cup)", 206, "🧀"),
                    ("Pork tenderloin (4oz)", 150, "🥩"),
                    ("Protein powder (1 scoop)", 120, "🥤"),
                ]
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: FuelSpacing.lg) {
                // Remaining macros card
                if appState.calorieTarget > 0 {
                    remainingMacrosCard
                }

                // Mode toggle + search bar
                if isDescribeMode {
                    describeBar
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .offset(y: -8)),
                            removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                        ))
                } else {
                    searchBar
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .offset(y: -8)),
                            removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                        ))
                }

                // Content based on mode
                if isDescribeMode {
                    describeContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 12)),
                            removal: .opacity
                        ))
                } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchActiveContent
                        .transition(.opacity)
                } else {
                    browseContent
                        .transition(.opacity)
                }

                Spacer(minLength: FuelSpacing.section)
            }
            .padding(.top, FuelSpacing.lg)
            .animation(FuelAnimation.snappy, value: isDescribeMode)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            isFocused = true
            if !didSetInitialCategory {
                didSetInitialCategory = true
                selectedCategory = smartDefaultCategory
            }
            if let initial = initialQuery, !initial.isEmpty, query.isEmpty {
                query = initial
            }
        }
        .onChange(of: query) { _, newValue in
            guard !isDescribeMode else { return } // Don't autocomplete in describe mode
            if newValue.count > 200 { query = String(newValue.prefix(200)); return }
            debounceTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 2 {
                cachedAutocomplete = []
                usdaResults = []
                return
            }
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                let results = NutritionRAG.shared.retrieve(query: trimmed, topK: 8)
                await MainActor.run { cachedAutocomplete = results }

                let bestScore = results.first?.score ?? 0
                if bestScore < 5.0 && trimmed.count >= 3 {
                    await MainActor.run { isSearchingUSDA = true }
                    let usda = (try? await USDAFoodService.shared.search(query: trimmed, pageSize: 8)) ?? []
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        usdaResults = usda
                        isSearchingUSDA = false
                    }
                } else {
                    await MainActor.run { usdaResults = [] }
                }
            }
        }
    }

    // MARK: - Search Bar (plain, database mode)

    private var searchBar: some View {
        VStack(spacing: FuelSpacing.sm) {
            HStack(spacing: FuelSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.stone)

                TextField("Search food...", text: $query)
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.ink)
                    .submitLabel(.search)
                    .focused($isFocused)
                    .onSubmit { submitDatabaseSearch() }

                if !query.isEmpty {
                    Button {
                        query = ""
                        usdaResults = []
                        cachedAutocomplete = []
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

            // "Describe with AI" toggle button
            describeToggleButton
        }
    }

    // MARK: - Describe Bar (AI mode, gradient)

    private var describeBar: some View {
        VStack(spacing: FuelSpacing.sm) {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = t.remainder(dividingBy: 4.0) / 4.0
                let shimmerX = phase * 1.4 - 0.2

                HStack(spacing: FuelSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.flame)

                    TextField("Describe what you ate...", text: $query)
                        .font(FuelType.body)
                        .foregroundStyle(FuelColors.ink)
                        .submitLabel(.search)
                        .focused($isFocused)
                        .onSubmit { submitDescribe() }

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
                .overlay(
                    RoundedRectangle(cornerRadius: FuelRadius.md)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    FuelColors.flame.opacity(0.25),
                                    FuelColors.flame.opacity(0.5),
                                    Color(hex: "#FF8040").opacity(0.4),
                                    FuelColors.flame.opacity(0.25),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FuelRadius.md)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: max(0, shimmerX - 0.1)),
                                    .init(color: .white.opacity(0.35), location: shimmerX),
                                    .init(color: .clear, location: min(1, shimmerX + 0.1)),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
            }
            .padding(.horizontal, FuelSpacing.xl)

            // Back to search toggle
            Button {
                withAnimation(FuelAnimation.snappy) {
                    isDescribeMode = false
                    query = ""
                }
                isFocused = true
                FuelHaptics.shared.tap()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                    Text("Back to search")
                        .font(FuelType.label)
                }
                .foregroundStyle(FuelColors.stone)
            }
        }
    }

    // MARK: - Describe Toggle Button

    private var describeToggleButton: some View {
        Button {
            if subscriptionService.isPremium {
                withAnimation(FuelAnimation.snappy) {
                    isDescribeMode = true
                    query = ""
                }
                isFocused = true
            } else {
                showingPaywall = true
            }
            FuelHaptics.shared.tap()
        } label: {
            HStack(spacing: FuelSpacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FuelColors.flame)
                Text(subscriptionService.isPremium ? "Describe with AI" : "Describe with AI")
                    .font(FuelType.label)
                    .foregroundStyle(FuelColors.flame)
                if !subscriptionService.isPremium {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(FuelColors.onDark)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(FuelColors.flame)
                        )
                }
            }
            .padding(.horizontal, FuelSpacing.md)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(FuelColors.flame.opacity(0.08))
            )
        }
        .sheet(isPresented: $showingPaywall) {
            UpgradePaywallView(reason: .aiDescribe)
        }
    }

    // MARK: - Describe Content

    private var describeContent: some View {
        VStack(spacing: FuelSpacing.lg) {
            // Examples
            VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                Text("Try describing your meal")
                    .font(FuelType.label)
                    .foregroundStyle(FuelColors.stone)
                    .padding(.horizontal, FuelSpacing.xl)

                let examples = [
                    ("🍔", "In-N-Out double-double with animal fries"),
                    ("🥗", "Grilled chicken salad with ranch dressing"),
                    ("🌯", "Chipotle burrito bowl with chicken, rice, beans, cheese"),
                    ("🍳", "3 scrambled eggs with 2 slices of toast and butter"),
                    ("🍝", "Spaghetti bolognese with garlic bread"),
                    ("🥪", "Turkey club sandwich, no mayo"),
                ]

                ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                    Button {
                        query = example.1
                        isFocused = false
                        FuelHaptics.shared.tap()
                        submitDescribe()
                    } label: {
                        HStack(spacing: FuelSpacing.md) {
                            Text(example.0)
                                .font(.system(size: 20))
                                .frame(width: 28)

                            Text(example.1)
                                .font(FuelType.body)
                                .foregroundStyle(FuelColors.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: "arrow.up.left")
                                .font(FuelType.micro)
                                .foregroundStyle(FuelColors.fog)
                        }
                        .padding(.horizontal, FuelSpacing.lg)
                        .padding(.vertical, FuelSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.sm)
                                .fill(FuelColors.cloud)
                        )
                    }
                    .pressable()
                    .staggeredAppear(index: index)
                }
            }
            .padding(.horizontal, FuelSpacing.xl)

            // Analyze button (only when text is entered)
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                describeAnalyzeButton
            }
        }
    }

    // MARK: - Describe Analyze Button

    private var describeAnalyzeButton: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = t.remainder(dividingBy: 4.0) / 4.0
            let shimmerX = phase * 1.4 - 0.2
            let glowPulse = 0.3 + 0.15 * sin(t * 2.0)

            Button { submitDescribe() } label: {
                HStack(spacing: FuelSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(FuelType.iconSm)
                        .foregroundStyle(FuelColors.flame)
                    Text("Analyze with AI")
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FuelSpacing.lg)
                .background(FuelColors.white)
                .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: FuelRadius.md)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    FuelColors.flame.opacity(0.35),
                                    FuelColors.flame.opacity(0.6),
                                    Color(hex: "#FF8040").opacity(0.5),
                                    FuelColors.flame.opacity(0.35),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FuelRadius.md)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: max(0, shimmerX - 0.12)),
                                    .init(color: .white.opacity(0.6), location: shimmerX),
                                    .init(color: .clear, location: min(1, shimmerX + 0.12)),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: FuelColors.flame.opacity(glowPulse), radius: 12, y: 2)
                .shadow(color: Color(hex: "#FF8040").opacity(glowPulse * 0.5), radius: 20, y: 4)
            }
            .pressable()
            .accessibilityLabel("Analyze with AI")
        }
        .padding(.horizontal, FuelSpacing.xl)
    }

    // MARK: - Remaining Macros Card

    private var remainingMacrosCard: some View {
        let rawCalRemaining = appState.calorieTarget - appState.caloriesConsumed
        let rawProteinRemaining = Double(appState.proteinTarget) - appState.proteinConsumed
        let rawCarbsRemaining = Double(appState.carbsTarget) - appState.carbsConsumed
        let rawFatRemaining = Double(appState.fatTarget) - appState.fatConsumed
        let isOver = rawCalRemaining < 0
        return HStack(spacing: FuelSpacing.lg) {
            VStack(spacing: 2) {
                Text("\(abs(rawCalRemaining))")
                    .font(FuelType.stat)
                    .foregroundStyle(isOver ? FuelColors.over : FuelColors.flame)
                Text(isOver ? "cal over" : "cal left")
                    .font(FuelType.micro)
                    .foregroundStyle(FuelColors.stone)
            }
            Divider().frame(height: 28)
            VStack(spacing: 2) {
                Text("\(abs(Int(rawProteinRemaining)))g")
                    .font(FuelType.label)
                    .foregroundStyle(rawProteinRemaining < 0 ? FuelColors.over : FuelColors.protein)
                Text("protein")
                    .font(FuelType.micro)
                    .foregroundStyle(FuelColors.stone)
            }
            VStack(spacing: 2) {
                Text("\(abs(Int(rawCarbsRemaining)))g")
                    .font(FuelType.label)
                    .foregroundStyle(rawCarbsRemaining < 0 ? FuelColors.over : FuelColors.carbs)
                Text("carbs")
                    .font(FuelType.micro)
                    .foregroundStyle(FuelColors.stone)
            }
            VStack(spacing: 2) {
                Text("\(abs(Int(rawFatRemaining)))g")
                    .font(FuelType.label)
                    .foregroundStyle(rawFatRemaining < 0 ? FuelColors.over : FuelColors.fat)
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

    // MARK: - Search Active Content (database results)

    private var searchActiveContent: some View {
        VStack(spacing: FuelSpacing.lg) {
            let localMatches = cachedAutocomplete.filter { $0.score >= 2.0 }
            let allResults = mergedSearchResults(local: localMatches, usda: usdaResults)

            if !allResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(allResults.prefix(8).enumerated()), id: \.offset) { index, item in
                        Button {
                            isFocused = false
                            FuelHaptics.shared.tap()
                            onSearch(item.name, item.food)
                        } label: {
                            searchResultRow(item: item)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.name), \(item.calories) calories")
                        if index < min(allResults.count, 8) - 1 {
                            Divider().padding(.leading, FuelSpacing.lg + 20 + FuelSpacing.md)
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

            if isSearchingUSDA {
                HStack(spacing: FuelSpacing.sm) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching database...")
                        .font(FuelType.micro)
                        .foregroundStyle(FuelColors.stone)
                }
            }

            // Database lookup button (when query doesn't match autocomplete well)
            Button { submitDatabaseSearch() } label: {
                HStack(spacing: FuelSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(FuelType.iconSm)
                    Text("Look up \"\(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))\"")
                        .font(FuelType.cardTitle)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FuelSpacing.lg)
                .background(FuelColors.buttonFill)
                .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            }
            .pressable()
            .padding(.horizontal, FuelSpacing.xl)
            .accessibilityLabel("Look up nutrition")
        }
    }

    // MARK: - Browse Content

    private var browseContent: some View {
        VStack(spacing: FuelSpacing.xl) {
            // Recent meals
            if !recentMeals.isEmpty {
                recentMealsSection
            }

            // Category chips
            categoryChips

            // Category foods grid
            categoryFoodsGrid
        }
    }

    // MARK: - Recent Meals Section

    private var recentMealsSection: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.sm) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(FuelType.iconXs)
                    .foregroundStyle(FuelColors.stone)
                Text("Recent")
                    .font(FuelType.label)
                    .foregroundStyle(FuelColors.stone)
            }
            .padding(.horizontal, FuelSpacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FuelSpacing.sm) {
                    ForEach(Array(recentMeals.enumerated()), id: \.offset) { index, meal in
                        Button {
                            isFocused = false
                            FuelHaptics.shared.tap()
                            let ragFood = NutritionRAG.shared.retrieve(query: meal.name, topK: 1).first(where: { $0.score >= 3.0 })?.food
                            onSearch(meal.name, ragFood)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal.name)
                                    .font(FuelType.caption)
                                    .foregroundStyle(FuelColors.ink)
                                    .lineLimit(1)
                                Text("\(meal.calories) cal")
                                    .font(FuelType.micro)
                                    .foregroundStyle(FuelColors.stone)
                            }
                            .padding(.horizontal, FuelSpacing.md)
                            .padding(.vertical, FuelSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: FuelRadius.sm)
                                    .fill(FuelColors.cloud)
                            )
                        }
                        .pressable()
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.horizontal, FuelSpacing.xl)
            }
        }
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FuelSpacing.sm) {
                ForEach(QuickCategory.allCases, id: \.rawValue) { category in
                    Button {
                        withAnimation(FuelAnimation.snappy) {
                            selectedCategory = category
                        }
                        FuelHaptics.shared.tap()
                    } label: {
                        HStack(spacing: 4) {
                            Group {
                                if category.icon == "FlameIcon" {
                                    Image("FlameIcon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 13, height: 13)
                                } else {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 11, weight: .medium))
                                }
                            }
                            Text(category.rawValue)
                                .font(FuelType.label)
                        }
                        .foregroundStyle(selectedCategory == category ? FuelColors.onDark : FuelColors.ink)
                        .padding(.horizontal, FuelSpacing.md)
                        .padding(.vertical, FuelSpacing.sm)
                        .background(
                            Capsule()
                                .fill(selectedCategory == category ? FuelColors.buttonFill : FuelColors.cloud)
                        )
                    }
                    .pressable()
                }
            }
            .padding(.horizontal, FuelSpacing.xl)
        }
    }

    // MARK: - Category Foods Grid

    private var categoryFoodsGrid: some View {
        VStack(spacing: FuelSpacing.sm) {
            ForEach(Array(selectedCategory.foods.enumerated()), id: \.offset) { index, food in
                Button {
                    isFocused = false
                    FuelHaptics.shared.tap()
                    let ragFood = NutritionRAG.shared.retrieve(query: food.name, topK: 1).first(where: { $0.score >= 3.0 })?.food
                    onSearch(food.name, ragFood)
                } label: {
                    HStack(spacing: FuelSpacing.md) {
                        Text(food.emoji)
                            .font(.system(size: 20))
                            .frame(width: 28)

                        Text(food.name)
                            .font(FuelType.body)
                            .foregroundStyle(FuelColors.ink)
                            .lineLimit(1)

                        Spacer()

                        Text("\(food.cal) cal")
                            .font(FuelType.label)
                            .foregroundStyle(FuelColors.stone)
                            .monospacedDigit()

                        Image(systemName: "plus.circle.fill")
                            .font(FuelType.iconSm)
                            .foregroundStyle(FuelColors.flame.opacity(0.6))
                    }
                    .padding(.horizontal, FuelSpacing.lg)
                    .padding(.vertical, FuelSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: FuelRadius.sm)
                            .fill(FuelColors.cloud)
                    )
                }
                .pressable()
                .staggeredAppear(index: index)
            }
        }
        .padding(.horizontal, FuelSpacing.xl)
        .id(selectedCategory)
    }

    // MARK: - Search Result Row

    private func searchResultRow(item: SearchResult) -> some View {
        HStack(spacing: FuelSpacing.md) {
            Image(systemName: item.isUSDA ? "leaf.fill" : "magnifyingglass")
                .font(FuelType.micro)
                .foregroundStyle(item.isUSDA ? FuelColors.success : FuelColors.fog)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.ink)
                    .lineLimit(1)

                HStack(spacing: FuelSpacing.sm) {
                    Text("\(item.calories) cal")
                        .font(FuelType.micro)
                        .foregroundStyle(FuelColors.stone)

                    if let p = item.protein {
                        Text("P:\(Int(p))g")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.protein)
                    }
                    if let c = item.carbs {
                        Text("C:\(Int(c))g")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.carbs)
                    }
                    if let f = item.fat {
                        Text("F:\(Int(f))g")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.fat)
                    }
                }
            }

            Spacer()

            if let serving = item.serving {
                Text(serving)
                    .font(FuelType.micro)
                    .foregroundStyle(FuelColors.fog)
            }

            // Quick-log button
            if let food = item.food, onQuickLog != nil {
                Button {
                    FuelHaptics.shared.tap()
                    onQuickLog?(food)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(FuelColors.flame)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quick log \(item.name)")
            } else {
                Image(systemName: "arrow.up.left")
                    .font(FuelType.micro)
                    .foregroundStyle(FuelColors.fog)
            }
        }
        .padding(.horizontal, FuelSpacing.lg)
        .padding(.vertical, FuelSpacing.sm)
    }

    // MARK: - Helpers

    private struct SearchResult {
        let name: String
        let calories: Int
        let protein: Double?
        let carbs: Double?
        let fat: Double?
        let serving: String?
        let food: FoodItem?
        let isUSDA: Bool
    }

    /// Normalize name for dedup: lowercase, strip parentheticals and extra whitespace
    private func deduplicationKey(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private func mergedSearchResults(local: [RetrievalResult], usda: [FoodItem]) -> [SearchResult] {
        var results: [SearchResult] = []
        var seenKeys: Set<String> = []

        for result in local {
            let key = deduplicationKey(result.food.name)
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            results.append(SearchResult(
                name: result.food.name,
                calories: result.food.calories,
                protein: result.food.protein,
                carbs: result.food.carbs,
                fat: result.food.fat,
                serving: result.food.serving,
                food: result.food,
                isUSDA: false
            ))
        }

        for food in usda {
            let key = deduplicationKey(food.name)
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            results.append(SearchResult(
                name: food.name,
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat,
                serving: food.serving,
                food: food,
                isUSDA: true
            ))
        }

        return results
    }

    /// Database search — uses local RAG + USDA, no AI
    private func submitDatabaseSearch() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isFocused = false
        FuelHaptics.shared.tap()
        onSearch(text, nil)
    }

    /// AI describe — sends to AI edge function for full ingredient itemization
    private func submitDescribe() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isFocused = false
        FuelHaptics.shared.tap()
        onDescribe(text)
    }
}
