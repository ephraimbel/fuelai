import SwiftUI

struct FoodResultsView: View {
    let analysis: FoodAnalysis
    let imageData: Data?
    var isPreview: Bool = false
    let onLog: (FoodAnalysis) -> Void
    let onRetake: () -> Void
    var onRefine: ((String) -> Void)? = nil
    var onSaveFavorite: ((FoodAnalysis) -> Void)? = nil
    var isLogging: Bool = false
    var retakeLabel: String = "Retake"

    @State private var quantities: [UUID: Double] = [:]
    @State private var calorieOverrides: [UUID: Int] = [:]
    @State private var proteinOverrides: [UUID: Double] = [:]
    @State private var carbsOverrides: [UUID: Double] = [:]
    @State private var fatOverrides: [UUID: Double] = [:]
    @State private var isSaved = false
    @State private var removedItems: Set<UUID> = []
    @State private var showingRefineSheet = false
    @State private var refineQuery = ""
    @State private var appeared = false
    @State private var expandedItems: Set<UUID> = []

    private var activeItems: [AnalyzedFoodItem] {
        analysis.items.filter { !removedItems.contains($0.id) }
    }

    private var adjustedAnalysis: FoodAnalysis {
        let adjustedItems = activeItems
            .map { item -> AnalyzedFoodItem in
                let qty = quantities[item.id] ?? 1.0
                let cal = calorieOverrides[item.id] ?? Int(Double(item.calories) * qty)
                let pro = proteinOverrides[item.id] ?? round(item.protein * qty * 10) / 10
                let crb = carbsOverrides[item.id] ?? round(item.carbs * qty * 10) / 10
                let ft = fatOverrides[item.id] ?? round(item.fat * qty * 10) / 10
                return AnalyzedFoodItem(
                    id: item.id,
                    name: item.name,
                    calories: cal,
                    protein: pro,
                    carbs: crb,
                    fat: ft,
                    fiber: round(item.fiber * qty * 10) / 10,
                    sugar: round(item.sugar * qty * 10) / 10,
                    servingSize: item.servingSize,
                    estimatedGrams: round(item.estimatedGrams * qty * 10) / 10,
                    measurementUnit: item.measurementUnit,
                    measurementAmount: round(item.measurementAmount * qty * 10) / 10,
                    confidence: item.confidence,
                    note: item.note,
                    quantity: qty
                )
            }

        let totalCal = adjustedItems.reduce(0) { $0 + $1.calories }
        let totalFiber = round(adjustedItems.reduce(0.0) { $0 + $1.fiber } * 10) / 10
        let totalSugar = round(adjustedItems.reduce(0.0) { $0 + $1.sugar } * 10) / 10
        let microScale = analysis.totalCalories > 0 ? Double(totalCal) / Double(analysis.totalCalories) : 1.0

        return FoodAnalysis(
            items: adjustedItems,
            displayName: analysis.displayName,
            totalCalories: totalCal,
            totalProtein: round(adjustedItems.reduce(0.0) { $0 + $1.protein } * 10) / 10,
            totalCarbs: round(adjustedItems.reduce(0.0) { $0 + $1.carbs } * 10) / 10,
            totalFat: round(adjustedItems.reduce(0.0) { $0 + $1.fat } * 10) / 10,
            fiberG: totalFiber > 0 ? totalFiber : analysis.fiberG.map { round($0 * microScale * 10) / 10 },
            sugarG: totalSugar > 0 ? totalSugar : analysis.sugarG.map { round($0 * microScale * 10) / 10 },
            sodiumMg: analysis.sodiumMg.map { round($0 * microScale * 10) / 10 },
            cholesterolMg: analysis.cholesterolMg.map { round($0 * microScale * 10) / 10 },
            saturatedFatG: analysis.saturatedFatG.map { round($0 * microScale * 10) / 10 },
            healthScore: analysis.healthScore,
            healthScoreReason: analysis.healthScoreReason,
            warnings: analysis.warnings,
            healthInsight: analysis.healthInsight,
            calorieRange: analysis.calorieRange,
            confidenceReason: analysis.confidenceReason,
            servingAssumed: analysis.servingAssumed
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pinned warning banner
            if let warnings = adjustedAnalysis.warnings, !warnings.isEmpty {
                warningBanner(warnings)
            }

            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Hero Image
                    if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 340)
                            .clipped()
                            .padding(.top, -60)
                            .opacity(appeared ? 1 : 0)
                    }

                    // MARK: - Content
                    VStack(spacing: FuelSpacing.lg) {
                        // Preview banner
                        if isPreview {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(FuelColors.flame)
                                    .scaleEffect(0.8)
                                Text("Quick estimate — refining...")
                                    .font(FuelType.caption)
                                    .foregroundStyle(FuelColors.stone)
                            }
                            .padding(.horizontal, FuelSpacing.lg)
                            .padding(.vertical, FuelSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: FuelRadius.sm)
                                    .fill(FuelColors.flame.opacity(0.08))
                            )
                        }

                        // MARK: - Timestamp + Bookmark
                        HStack(spacing: FuelSpacing.sm) {
                            if onSaveFavorite != nil {
                                Button {
                                    if !isSaved {
                                        onSaveFavorite?(adjustedAnalysis)
                                        withAnimation(FuelAnimation.snappy) { isSaved = true }
                                        FuelHaptics.shared.tap()
                                    }
                                } label: {
                                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                        .font(.system(size: 16))
                                        .foregroundStyle(isSaved ? FuelColors.flame : FuelColors.stone)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }

                            Text(Date().formatted(date: .omitted, time: .shortened))
                                .font(FuelType.caption)
                                .foregroundStyle(FuelColors.stone)

                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // MARK: - Meal Name + Serving Count
                        HStack(alignment: .top) {
                            Text(adjustedAnalysis.displayName)
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundStyle(FuelColors.ink)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            // Serving count pill
                            servingCountPill
                        }
                        .padding(.horizontal, 20)

                        // MARK: - Calorie Card
                        calorieCard
                            .padding(.horizontal, 20)

                        // MARK: - Macro Pills (3-column)
                        HStack(spacing: 10) {
                            ResultMacroPill(label: "Protein", value: adjustedAnalysis.totalProtein, unit: "g", color: FuelColors.protein)
                            ResultMacroPill(label: "Carbs", value: adjustedAnalysis.totalCarbs, unit: "g", color: FuelColors.carbs)
                            ResultMacroPill(label: "Fats", value: adjustedAnalysis.totalFat, unit: "g", color: FuelColors.fat)
                        }
                        .padding(.horizontal, 20)

                        // MARK: - Health Score Card
                        if let score = adjustedAnalysis.healthScore {
                            healthScoreCard(score: score, reason: adjustedAnalysis.healthScoreReason)
                                .padding(.horizontal, 20)
                        }

                        // MARK: - Ingredients Section
                        ingredientsSection
                            .padding(.horizontal, 20)

                        // MARK: - Micronutrients Section
                        micronutrientsSection
                            .padding(.horizontal, 20)

                        // Fix description link
                        if onRefine != nil {
                            Button {
                                FuelHaptics.shared.tap()
                                refineQuery = analysis.displayName
                                showingRefineSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12))
                                    Text("Edit description")
                                        .font(FuelType.caption)
                                }
                                .foregroundStyle(FuelColors.stone)
                            }
                        }

                        Color.clear.frame(height: FuelSpacing.sm)
                    }
                    .padding(.top, imageData != nil ? FuelSpacing.xl : 20)
                    .background(FuelColors.white)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: imageData != nil ? 24 : 0,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: imageData != nil ? 24 : 0
                        )
                    )
                    .offset(y: imageData != nil ? -24 : 0)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }

            bottomBar
        }
        .background(FuelColors.white)
        .sheet(isPresented: $showingRefineSheet) {
            refineSheet
        }
        .onAppear {
            for item in analysis.items { quantities[item.id] = 1.0 }
            withAnimation(.easeOut(duration: 0.45).delay(0.1)) { appeared = true }
        }
        .onChange(of: analysis.items.map(\.id)) { _, newIDs in
            quantities = [:]
            calorieOverrides = [:]
            proteinOverrides = [:]
            carbsOverrides = [:]
            fatOverrides = [:]
            removedItems = []
            expandedItems = []
            for id in newIDs { quantities[id] = 1.0 }
        }
    }

    // MARK: - Serving Count Pill

    private var servingCountPill: some View {
        let totalServings = activeItems.reduce(0.0) { $0 + (quantities[$1.id] ?? 1.0) }
        let displayCount = totalServings == Double(Int(totalServings)) ? "\(Int(totalServings))" : String(format: "%.1f", totalServings)

        return HStack(spacing: 4) {
            Text(displayCount)
                .font(.system(size: 15, weight: .semibold, design: .serif).monospacedDigit())
                .foregroundStyle(FuelColors.ink)
            Image(systemName: "fork.knife")
                .font(.system(size: 11))
                .foregroundStyle(FuelColors.stone)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .stroke(FuelColors.mist, lineWidth: 1)
        )
    }

    // MARK: - Calorie Card

    private var calorieCard: some View {
        HStack(spacing: 8) {
            Image("FlameIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Calories")
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.stone)
                Text("\(adjustedAnalysis.totalCalories)")
                    .font(.system(size: 36, weight: .bold, design: .serif).monospacedDigit())
                    .contentTransition(.numericText())
                    .foregroundStyle(FuelColors.ink)
            }

            Spacer()

            if let range = analysis.calorieRange {
                Text("\(range.low)–\(range.high)")
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.fog)
            }
        }
        .padding(FuelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.md)
                .fill(FuelColors.cloud)
        )
    }

    // MARK: - Health Score Card

    private func healthScoreCard(score: Int, reason: String?) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(healthScoreColor(score))

                Text("Health Score")
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.ink)

                Spacer()

                Text("\(score)/10")
                    .font(.system(size: 18, weight: .bold, design: .serif).monospacedDigit())
                    .foregroundStyle(FuelColors.ink)
            }

            // Gradient progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.red.opacity(0.3),
                                    Color.orange.opacity(0.3),
                                    Color.yellow.opacity(0.3),
                                    Color.green.opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: healthGradientColors(score),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(score) / 10.0, height: 8)
                        .animation(FuelAnimation.snappy, value: score)
                }
            }
            .frame(height: 8)

            if let reason, !reason.isEmpty {
                Text(reason)
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.stone)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(FuelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.md)
                .fill(FuelColors.cardBackground)
                .shadow(color: FuelColors.cardShadow, radius: 8, y: 3)
        )
    }

    private func healthScoreColor(_ score: Int) -> Color {
        switch score {
        case 1...3: return .red
        case 4...5: return .orange
        case 6...7: return .yellow
        case 8...10: return FuelColors.success
        default: return FuelColors.stone
        }
    }

    private func healthGradientColors(_ score: Int) -> [Color] {
        switch score {
        case 1...3: return [.red, .red]
        case 4...5: return [.red, .orange]
        case 6...7: return [.orange, .yellow]
        case 8...10: return [.green.opacity(0.7), FuelColors.success]
        default: return [FuelColors.stone, FuelColors.stone]
        }
    }

    // MARK: - Ingredients Section

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients")
                    .font(FuelType.section)
                    .foregroundStyle(FuelColors.ink)
                Spacer()
                if !removedItems.isEmpty {
                    Button {
                        FuelHaptics.shared.tap()
                        withAnimation(FuelAnimation.snappy) { removedItems.removeAll() }
                    } label: {
                        Text("Restore all")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.flame)
                    }
                }
            }

            if activeItems.isEmpty && !analysis.items.isEmpty {
                VStack(spacing: 8) {
                    Text("All items removed")
                        .font(FuelType.caption)
                        .foregroundStyle(FuelColors.stone)
                    Button {
                        FuelHaptics.shared.tap()
                        withAnimation(FuelAnimation.snappy) { removedItems.removeAll() }
                    } label: {
                        Text("Restore items")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FuelColors.flame)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            VStack(spacing: 8) {
                ForEach(Array(analysis.items.enumerated()), id: \.element.id) { index, item in
                    ingredientRow(item: item, index: index)
                }
            }
        }
    }

    // MARK: - Ingredient Row

    @ViewBuilder
    private func ingredientRow(item: AnalyzedFoodItem, index: Int) -> some View {
        if removedItems.contains(item.id) {
            HStack(spacing: 8) {
                Text(item.name)
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.stone)
                    .strikethrough()
                Spacer()
                Button {
                    FuelHaptics.shared.tap()
                    withAnimation(FuelAnimation.snappy) { _ = removedItems.remove(item.id) }
                } label: {
                    Text("Undo")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FuelColors.flame)
                }
            }
            .padding(.vertical, 6)
        } else {
            FoodItemRow(
                item: item,
                isExpanded: Binding(
                    get: { expandedItems.contains(item.id) },
                    set: { newVal in
                        if newVal { expandedItems.insert(item.id) }
                        else { expandedItems.remove(item.id) }
                    }
                ),
                quantity: Binding(
                    get: { quantities[item.id] ?? 1.0 },
                    set: { newQty in
                        quantities[item.id] = newQty
                        // Clear manual overrides so macros scale with the new quantity
                        calorieOverrides.removeValue(forKey: item.id)
                        proteinOverrides.removeValue(forKey: item.id)
                        carbsOverrides.removeValue(forKey: item.id)
                        fatOverrides.removeValue(forKey: item.id)
                    }
                ),
                calorieOverride: Binding(
                    get: { calorieOverrides[item.id] },
                    set: { calorieOverrides[item.id] = $0 }
                ),
                proteinOverride: Binding(
                    get: { proteinOverrides[item.id] },
                    set: { proteinOverrides[item.id] = $0 }
                ),
                carbsOverride: Binding(
                    get: { carbsOverrides[item.id] },
                    set: { carbsOverrides[item.id] = $0 }
                ),
                fatOverride: Binding(
                    get: { fatOverrides[item.id] },
                    set: { fatOverrides[item.id] = $0 }
                ),
                onRemove: analysis.items.count > 1 ? {
                    withAnimation(FuelAnimation.snappy) { _ = removedItems.insert(item.id) }
                } : nil
            )
        }
    }

    // MARK: - Micronutrients Section

    private var micronutrientsSection: some View {
        let adj = adjustedAnalysis
        let micronutrients: [(String, String, String)] = [
            ("Fiber", formatMicro(adj.fiberG), "g"),
            ("Sugar", formatMicro(adj.sugarG), "g"),
            ("Sodium", formatMicro(adj.sodiumMg), "mg"),
            ("Cholesterol", formatMicro(adj.cholesterolMg), "mg"),
            ("Sat. Fat", formatMicro(adj.saturatedFatG), "g"),
        ].filter { $0.1 != "—" }

        return Group {
            if !micronutrients.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Micronutrients")
                        .font(FuelType.section)
                        .foregroundStyle(FuelColors.ink)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ], spacing: 10) {
                        ForEach(micronutrients, id: \.0) { nutrient in
                            VStack(spacing: 4) {
                                Text("\(nutrient.1)\(nutrient.2)")
                                    .font(.system(size: 16, weight: .semibold, design: .serif).monospacedDigit())
                                    .foregroundStyle(FuelColors.ink)
                                Text(nutrient.0)
                                    .font(FuelType.micro)
                                    .foregroundStyle(FuelColors.stone)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: FuelRadius.sm)
                                    .fill(FuelColors.cloud)
                            )
                        }
                    }
                }
            }
        }
    }

    private func formatMicro(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "—" }
        if v >= 10 { return "\(Int(v.rounded()))" }
        return String(format: "%.1f", v)
    }

    // MARK: - Warning Banner

    private func warningBanner(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(warnings, id: \.self) { warning in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(FuelColors.warning)
                    Text(warning)
                        .font(FuelType.caption)
                        .foregroundStyle(FuelColors.stone)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(FuelColors.warning.opacity(0.08))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // Fix Results button (outline style)
                Button {
                    FuelHaptics.shared.tap()
                    if onRefine != nil {
                        refineQuery = analysis.displayName
                        showingRefineSheet = true
                    } else {
                        onRetake()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Fix Results")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(isLogging ? FuelColors.stone : FuelColors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: FuelRadius.md)
                            .stroke(isLogging ? FuelColors.mist : FuelColors.mist, lineWidth: 1)
                    )
                }
                .disabled(isLogging)

                // Log Meal button (filled)
                Button {
                    onLog(adjustedAnalysis)
                } label: {
                    HStack(spacing: 6) {
                        if isLogging {
                            ProgressView()
                                .tint(FuelColors.onDark)
                                .scaleEffect(0.8)
                        }
                        Text(isLogging ? "Saving..." : "Log Meal")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isLogging || adjustedAnalysis.items.isEmpty ? FuelColors.stone : FuelColors.flame)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                }
                .disabled(isLogging || adjustedAnalysis.items.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(FuelColors.white)
    }

    // MARK: - Refine Sheet

    private var refineSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Describe your meal", text: $refineQuery)
                    .font(FuelType.body)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: FuelRadius.sm)
                            .fill(FuelColors.cloud)
                    )
                Button {
                    showingRefineSheet = false
                    onRefine?(refineQuery)
                } label: {
                    Text("Re-analyze")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FuelColors.buttonFill)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                }
                .disabled(refineQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(20)
            .navigationTitle("Fix Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingRefineSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Result Macro Pill

private struct ResultMacroPill: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(FuelType.micro)
                    .foregroundStyle(FuelColors.stone)
            }
            Text("\(Int(value))\(unit)")
                .font(.system(size: 18, weight: .semibold, design: .serif).monospacedDigit())
                .contentTransition(.numericText())
                .foregroundStyle(FuelColors.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.sm)
                .fill(FuelColors.cloud)
        )
    }
}

// MARK: - Food Item Row

private struct FoodItemRow: View {
    let item: AnalyzedFoodItem
    @Binding var isExpanded: Bool
    @Binding var quantity: Double
    @Binding var calorieOverride: Int?
    @Binding var proteinOverride: Double?
    @Binding var carbsOverride: Double?
    @Binding var fatOverride: Double?
    var onRemove: (() -> Void)? = nil

    @State private var editingField: EditField?
    @State private var editText = ""
    @FocusState private var fieldFocused: Bool

    private enum EditField: Equatable {
        case servings, calories, protein, carbs, fat, measurement
    }

    // Whether this item has real measurement data from the AI
    private var hasMeasurement: Bool {
        item.estimatedGrams > 0 && item.measurementAmount > 0
    }

    private var displayCalories: Int {
        if let override = calorieOverride { return override }
        return Int(Double(item.calories) * quantity)
    }

    private var displayProtein: Double {
        if let override = proteinOverride { return override }
        return item.protein * quantity
    }

    private var displayCarbs: Double {
        if let override = carbsOverride { return override }
        return item.carbs * quantity
    }

    private var displayFat: Double {
        if let override = fatOverride { return override }
        return item.fat * quantity
    }

    private var displayGrams: Int {
        Int((item.estimatedGrams * quantity).rounded())
    }

    private var displayMeasurementAmount: Double {
        round(item.measurementAmount * quantity * 10) / 10
    }

    /// Formatted measurement string (e.g. "4 oz", "1.5 cups", "2 tbsp")
    private var measurementLabel: String {
        let amt = displayMeasurementAmount
        let unit = item.measurementUnit
        let amtStr = amt == Double(Int(amt)) ? "\(Int(amt))" : String(format: "%.1f", amt)
        // Pluralize common units
        let pluralUnit: String
        if amt > 1 {
            switch unit {
            case "cup": pluralUnit = "cups"
            case "slice": pluralUnit = "slices"
            case "piece": pluralUnit = "pieces"
            case "large": pluralUnit = "large"
            default: pluralUnit = unit
            }
        } else {
            pluralUnit = unit
        }
        return "\(amtStr) \(pluralUnit)"
    }

    /// Step size for the measurement stepper, based on unit type
    private var measurementStep: Double {
        switch item.measurementUnit {
        case "oz": return 0.5
        case "cup": return 0.25
        case "tbsp": return 0.5
        case "tsp": return 0.5
        case "fl oz": return 2.0
        case "slice", "piece", "large", "medium", "small": return 1.0
        default: return 0.5 // generic step
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed: name, measurement, calories
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FuelColors.ink)
                        .lineLimit(2)

                    // Show measurement info: "4 oz (113g)" or fallback to servingSize
                    if hasMeasurement {
                        HStack(spacing: 4) {
                            Text(measurementLabel)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(FuelColors.stone)
                            if displayGrams > 0 {
                                Text("(\(displayGrams)g)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(FuelColors.fog)
                            }
                        }
                    } else {
                        Text(item.servingSize)
                            .font(FuelType.caption)
                            .foregroundStyle(FuelColors.stone)
                    }
                }

                Spacer()

                // Calories on right
                if editingField == .calories {
                    editFieldView(suffix: "cal") {
                        if let val = Int(editText), val >= 0 {
                            calorieOverride = val
                        }
                    }
                } else {
                    Button {
                        startEditing(.calories, value: "\(displayCalories)")
                    } label: {
                        HStack(spacing: 2) {
                            Text("\(displayCalories)")
                                .font(.system(size: 15, weight: .semibold, design: .serif).monospacedDigit())
                                .contentTransition(.numericText())
                            Text("cal")
                                .font(FuelType.micro)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                        .foregroundStyle(FuelColors.ink)
                    }
                }
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture {
                if editingField == nil {
                    withAnimation(FuelAnimation.snappy) { isExpanded.toggle() }
                    FuelHaptics.shared.selection()
                }
            }

            // Expanded: measurement adjuster, macros, actions
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 14)

                    // Measurement adjuster — primary way to adjust amounts
                    if hasMeasurement {
                        measurementAdjuster
                            .padding(.horizontal, 14)
                    } else {
                        // Fallback: serving multiplier stepper
                        HStack {
                            Text("Servings")
                                .font(FuelType.caption)
                                .foregroundStyle(FuelColors.stone)
                            Spacer()
                            servingStepper
                        }
                        .padding(.horizontal, 14)
                    }

                    // Macros row
                    HStack(spacing: 0) {
                        tappableMacro(field: .protein, letter: "P", value: displayProtein, color: FuelColors.protein)
                        tappableMacro(field: .carbs, letter: "C", value: displayCarbs, color: FuelColors.carbs)
                        tappableMacro(field: .fat, letter: "F", value: displayFat, color: FuelColors.fat)
                        Spacer()
                        if hasMeasurement {
                            // Show grams badge when using measurement adjuster
                            Text("\(displayGrams)g")
                                .font(.system(size: 13, weight: .medium, design: .serif).monospacedDigit())
                                .foregroundStyle(FuelColors.stone)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(FuelColors.cloud)
                                )
                        }
                    }
                    .padding(.horizontal, 14)

                    // Actions row
                    HStack(spacing: 16) {
                        if let onRemove {
                            Button {
                                FuelHaptics.shared.tap()
                                onRemove()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                    Text("Remove")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(FuelColors.over)
                            }
                        }
                        Spacer()
                        if calorieOverride != nil || proteinOverride != nil || carbsOverride != nil || fatOverride != nil || quantity != 1.0 {
                            Button {
                                FuelHaptics.shared.tap()
                                withAnimation(FuelAnimation.snappy) {
                                    quantity = 1.0
                                    calorieOverride = nil
                                    proteinOverride = nil
                                    carbsOverride = nil
                                    fatOverride = nil
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 12))
                                    Text("Reset")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(FuelColors.stone)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.sm)
                .fill(FuelColors.white)
                .stroke(isExpanded ? FuelColors.flame.opacity(0.3) : FuelColors.mist, lineWidth: isExpanded ? 1 : 0.5)
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    if let field = editingField {
                        switch field {
                        case .calories:
                            if let val = Int(editText), val >= 0 { calorieOverride = val }
                        case .protein:
                            proteinOverride = max(Double(editText) ?? 0, 0)
                        case .carbs:
                            carbsOverride = max(Double(editText) ?? 0, 0)
                        case .fat:
                            fatOverride = max(Double(editText) ?? 0, 0)
                        case .servings:
                            if let val = Double(editText), val > 0, val <= 20 {
                                quantity = (val * 2).rounded() / 2
                                clearOverrides()
                            }
                        case .measurement:
                            if let val = Double(editText), val > 0, item.measurementAmount > 0 {
                                quantity = val / item.measurementAmount
                                clearOverrides()
                            }
                        }
                    }
                    editingField = nil
                    fieldFocused = false
                    FuelHaptics.shared.tap()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FuelColors.flame)
            }
        }
        .onChange(of: editText) { _, newText in
            guard let field = editingField else { return }
            switch field {
            case .calories:
                if let val = Int(newText), val >= 0 { calorieOverride = val }
            case .protein:
                if let val = Double(newText), val >= 0 { proteinOverride = val }
            case .carbs:
                if let val = Double(newText), val >= 0 { carbsOverride = val }
            case .fat:
                if let val = Double(newText), val >= 0 { fatOverride = val }
            case .servings:
                if let val = Double(newText), val > 0, val <= 20 {
                    quantity = (val * 2).rounded() / 2
                    clearOverrides()
                }
            case .measurement:
                if let val = Double(newText), val > 0, item.measurementAmount > 0 {
                    quantity = val / item.measurementAmount
                    clearOverrides()
                }
            }
        }
        .animation(FuelAnimation.snappy, value: quantity)
        .animation(FuelAnimation.snappy, value: isExpanded)
    }

    // MARK: - Measurement Adjuster

    private var measurementAdjuster: some View {
        HStack(spacing: 0) {
            // Decrease button
            Button {
                let currentAmount = displayMeasurementAmount
                let step = measurementStep
                if currentAmount > step {
                    let newAmount = currentAmount - step
                    quantity = newAmount / item.measurementAmount
                    clearOverrides()
                    FuelHaptics.shared.selection()
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(displayMeasurementAmount > measurementStep ? FuelColors.ink : FuelColors.fog)
                    .frame(width: 32, height: 32)
                    .background(FuelColors.cloud)
                    .clipShape(Circle())
            }
            .disabled(displayMeasurementAmount <= measurementStep)

            // Tappable measurement display
            if editingField == .measurement {
                HStack(spacing: 3) {
                    TextField("", text: $editText)
                        .font(.system(size: 15, weight: .semibold, design: .serif).monospacedDigit())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                        .focused($fieldFocused)
                        .onSubmit {
                            commitEdit {
                                if let val = Double(editText), val > 0, item.measurementAmount > 0 {
                                    quantity = val / item.measurementAmount
                                    clearOverrides()
                                }
                            }
                        }
                    Text(item.measurementUnit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FuelColors.stone)
                }
                .padding(.horizontal, 8)
            } else {
                Button {
                    let amt = displayMeasurementAmount
                    startEditing(.measurement, value: amt == Double(Int(amt)) ? "\(Int(amt))" : String(format: "%.1f", amt))
                } label: {
                    HStack(spacing: 3) {
                        let amt = displayMeasurementAmount
                        Text(amt == Double(Int(amt)) ? "\(Int(amt))" : String(format: "%.1f", amt))
                            .font(.system(size: 15, weight: .semibold, design: .serif).monospacedDigit())
                            .contentTransition(.numericText())
                            .foregroundStyle(FuelColors.ink)
                        Text(item.measurementUnit)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FuelColors.stone)
                    }
                    .padding(.horizontal, 8)
                }
            }

            // Increase button
            Button {
                let currentAmount = displayMeasurementAmount
                let step = measurementStep
                let newAmount = currentAmount + step
                quantity = newAmount / item.measurementAmount
                clearOverrides()
                FuelHaptics.shared.selection()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FuelColors.ink)
                    .frame(width: 32, height: 32)
                    .background(FuelColors.cloud)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.sm)
                .fill(FuelColors.cloud.opacity(0.5))
        )
    }

    // MARK: - Tappable Macro

    @ViewBuilder
    private func tappableMacro(field: EditField, letter: String, value: Double, color: Color) -> some View {
        if editingField == field {
            editFieldView(suffix: "g") {
                let parsed = Double(editText) ?? 0
                switch field {
                case .protein: proteinOverride = max(parsed, 0)
                case .carbs: carbsOverride = max(parsed, 0)
                case .fat: fatOverride = max(parsed, 0)
                default: break
                }
            }
            .frame(width: 70)
        } else {
            Button {
                startEditing(field, value: "\(Int(value))")
            } label: {
                HStack(spacing: 3) {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                    Text("\(letter) \(Int(value))g")
                        .font(FuelType.caption)
                        .foregroundStyle(FuelColors.stone)
                }
                .padding(.trailing, 12)
            }
        }
    }

    // MARK: - Inline Edit Field

    private func editFieldView(suffix: String, onCommit: @escaping () -> Void) -> some View {
        HStack(spacing: 2) {
            TextField("", text: $editText)
                .font(.system(size: 14, weight: .semibold, design: .serif).monospacedDigit())
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 48)
                .focused($fieldFocused)
                .onSubmit { commitEdit(onCommit) }

            Text(suffix)
                .font(FuelType.micro)
                .foregroundStyle(FuelColors.stone)

            Button {
                commitEdit(onCommit)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(FuelColors.flame)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(FuelColors.flame.opacity(0.06))
        )
    }

    // MARK: - Serving Stepper (fallback when no measurement data)

    private var servingStepper: some View {
        HStack(spacing: 0) {
            Button {
                if quantity > 0.5 {
                    quantity -= 0.5
                    clearOverrides()
                    FuelHaptics.shared.selection()
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(quantity > 0.5 ? FuelColors.ink : FuelColors.fog)
                    .frame(width: 28, height: 28)
                    .background(FuelColors.cloud)
                    .clipShape(Circle())
            }
            .disabled(quantity <= 0.5)

            if editingField == .servings {
                TextField("", text: $editText)
                    .font(.system(size: 14, weight: .medium, design: .serif).monospacedDigit())
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 42)
                    .focused($fieldFocused)
                    .onSubmit {
                        commitEdit {
                            if let val = Double(editText), val > 0, val <= 20 {
                                quantity = (val * 2).rounded() / 2
                                clearOverrides()
                            }
                        }
                    }
            } else {
                Button {
                    startEditing(.servings, value: quantity == Double(Int(quantity)) ? "\(Int(quantity))" : String(format: "%.1f", quantity))
                } label: {
                    Text(quantity == 1.0 ? "1x" : String(format: "%.1fx", quantity))
                        .font(.system(size: 14, weight: .medium, design: .serif).monospacedDigit())
                        .foregroundStyle(FuelColors.ink)
                        .frame(width: 42)
                }
            }

            Button {
                if quantity < 10.0 {
                    quantity += 0.5
                    clearOverrides()
                    FuelHaptics.shared.selection()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(quantity < 10.0 ? FuelColors.ink : FuelColors.fog)
                    .frame(width: 28, height: 28)
                    .background(FuelColors.cloud)
                    .clipShape(Circle())
            }
            .disabled(quantity >= 10.0)
        }
    }

    // MARK: - Helpers

    private func startEditing(_ field: EditField, value: String) {
        editText = value
        editingField = field
        FuelHaptics.shared.selection()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            fieldFocused = true
        }
    }

    private func commitEdit(_ apply: () -> Void) {
        apply()
        editingField = nil
        fieldFocused = false
        FuelHaptics.shared.tap()
    }

    private func clearOverrides() {
        calorieOverride = nil
        proteinOverride = nil
        carbsOverride = nil
        fatOverride = nil
    }
}
