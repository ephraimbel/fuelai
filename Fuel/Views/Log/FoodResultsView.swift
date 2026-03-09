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
    @State private var isSaved = false
    @State private var removedItems: Set<UUID> = []
    @State private var showingRefineSheet = false
    @State private var refineQuery = ""

    // Computed adjusted totals based on quantity changes and removals
    private var adjustedAnalysis: FoodAnalysis {
        let adjustedItems = analysis.items
            .filter { !removedItems.contains($0.id) }
            .map { item -> AnalyzedFoodItem in
                let qty = quantities[item.id] ?? 1.0
                return AnalyzedFoodItem(
                    id: item.id,
                    name: item.name,
                    calories: Int(Double(item.calories) * qty),
                    protein: round(item.protein * qty * 10) / 10,
                    carbs: round(item.carbs * qty * 10) / 10,
                    fat: round(item.fat * qty * 10) / 10,
                    servingSize: item.servingSize,
                    confidence: item.confidence,
                    note: item.note,
                    quantity: qty
                )
            }

        // Calorie sanity warnings
        var warnings = analysis.warnings ?? []
        let totalCal = adjustedItems.reduce(0) { $0 + $1.calories }
        if totalCal == 0 && !adjustedItems.isEmpty {
            warnings.append("Total calories are 0 — this may be incorrect")
        }
        for item in adjustedItems where item.calories > 3000 {
            warnings.append("\(item.name) has \(item.calories) cal — verify this is correct")
        }

        // Scale micronutrients proportionally to calorie change
        let microScale = analysis.totalCalories > 0 ? Double(totalCal) / Double(analysis.totalCalories) : 1.0

        return FoodAnalysis(
            items: adjustedItems,
            displayName: analysis.displayName,
            totalCalories: totalCal,
            totalProtein: round(adjustedItems.reduce(0.0) { $0 + $1.protein } * 10) / 10,
            totalCarbs: round(adjustedItems.reduce(0.0) { $0 + $1.carbs } * 10) / 10,
            totalFat: round(adjustedItems.reduce(0.0) { $0 + $1.fat } * 10) / 10,
            fiberG: analysis.fiberG.map { round($0 * microScale * 10) / 10 },
            sugarG: analysis.sugarG.map { round($0 * microScale * 10) / 10 },
            sodiumMg: analysis.sodiumMg.map { round($0 * microScale * 10) / 10 },
            warnings: warnings.isEmpty ? nil : warnings,
            healthInsight: analysis.healthInsight,
            calorieRange: analysis.calorieRange,
            confidenceReason: analysis.confidenceReason,
            servingAssumed: analysis.servingAssumed
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: FuelSpacing.lg) {
                    // Image preview
                    if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.lg))
                            .padding(.horizontal, FuelSpacing.xl)
                            .staggeredAppear(index: 0)
                    }

                    // Preview banner
                    if isPreview {
                        HStack(spacing: FuelSpacing.sm) {
                            ProgressView()
                                .tint(FuelColors.flame)
                                .scaleEffect(0.8)
                            Text("Quick estimate — refining with AI...")
                                .font(FuelType.caption)
                                .foregroundStyle(FuelColors.stone)
                        }
                        .padding(.horizontal, FuelSpacing.lg)
                        .padding(.vertical, FuelSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.sm)
                                .fill(FuelColors.flame.opacity(0.08))
                        )
                        .padding(.horizontal, FuelSpacing.xl)
                    }

                    // Meal name + calorie hero
                    VStack(spacing: FuelSpacing.sm) {
                        HStack(spacing: FuelSpacing.sm) {
                            Text(adjustedAnalysis.displayName)
                                .font(FuelType.title)
                                .foregroundStyle(FuelColors.ink)
                                .multilineTextAlignment(.center)

                            if onSaveFavorite != nil {
                                Button {
                                    if !isSaved {
                                        onSaveFavorite?(adjustedAnalysis)
                                        withAnimation(FuelAnimation.snappy) {
                                            isSaved = true
                                        }
                                        FuelHaptics.shared.tap()
                                    }
                                } label: {
                                    Image(systemName: isSaved ? "heart.fill" : "heart")
                                        .font(FuelType.iconMd)
                                        .foregroundStyle(isSaved ? FuelColors.flame : FuelColors.stone)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }
                        }

                        if onRefine != nil {
                            Button {
                                FuelHaptics.shared.tap()
                                refineQuery = analysis.displayName
                                showingRefineSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(FuelType.micro)
                                    Text("Edit description")
                                        .font(FuelType.caption)
                                }
                                .foregroundStyle(FuelColors.stone)
                            }
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(FuelType.iconMd)
                                .foregroundStyle(FuelColors.flame)
                            Text("\(adjustedAnalysis.totalCalories)")
                                .font(FuelType.hero)
                                .contentTransition(.numericText())
                                .foregroundStyle(FuelColors.ink)
                            Text("cal")
                                .font(FuelType.body)
                                .foregroundStyle(FuelColors.stone)
                                .padding(.top, 12)
                        }

                        if let serving = analysis.servingAssumed, !serving.isEmpty {
                            Text(serving)
                                .font(FuelType.caption)
                                .italic()
                                .foregroundStyle(FuelColors.stone)
                        }

                        // Meal-level confidence indicator
                        mealConfidenceBadge
                    }
                    .staggeredAppear(index: imageData != nil ? 1 : 0)

                    // Macro pills
                    HStack(spacing: FuelSpacing.md) {
                        ResultMacroPill(
                            label: "Protein",
                            value: adjustedAnalysis.totalProtein,
                            color: FuelColors.protein
                        )
                        ResultMacroPill(
                            label: "Carbs",
                            value: adjustedAnalysis.totalCarbs,
                            color: FuelColors.carbs
                        )
                        ResultMacroPill(
                            label: "Fat",
                            value: adjustedAnalysis.totalFat,
                            color: FuelColors.fat
                        )
                    }
                    .padding(.horizontal, FuelSpacing.xl)
                    .staggeredAppear(index: imageData != nil ? 2 : 1)

                    // Macro distribution bar
                    macroBar
                        .padding(.horizontal, FuelSpacing.xl)
                        .staggeredAppear(index: imageData != nil ? 3 : 2)

                    // Warnings
                    if let warnings = adjustedAnalysis.warnings, !warnings.isEmpty {
                        VStack(alignment: .leading, spacing: FuelSpacing.xs) {
                            ForEach(warnings, id: \.self) { warning in
                                HStack(spacing: FuelSpacing.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(FuelType.micro)
                                        .foregroundStyle(FuelColors.warning)
                                    Text(warning)
                                        .font(FuelType.caption)
                                        .foregroundStyle(FuelColors.stone)
                                }
                            }
                        }
                        .padding(.horizontal, FuelSpacing.xl)
                    }

                    // Health insight
                    if let insight = adjustedAnalysis.healthInsight, !insight.isEmpty {
                        HStack(spacing: FuelSpacing.sm) {
                            Image(systemName: "heart.text.square.fill")
                                .font(FuelType.iconMd)
                                .foregroundStyle(FuelColors.success)
                            Text(insight)
                                .font(FuelType.caption)
                                .foregroundStyle(FuelColors.ink)
                        }
                        .padding(FuelSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.md)
                                .fill(FuelColors.success.opacity(0.08))
                        )
                        .padding(.horizontal, FuelSpacing.xl)
                    }

                    // Food items
                    VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                        HStack {
                            Text("Items")
                                .font(FuelType.label)
                                .foregroundStyle(FuelColors.stone)
                            if !removedItems.isEmpty {
                                Spacer()
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
                        .padding(.horizontal, FuelSpacing.xl)

                        ForEach(Array(analysis.items.enumerated()), id: \.element.id) { index, item in
                            itemRow(item: item, index: index)
                        }
                    }

                    Color.clear.frame(height: FuelSpacing.xl)
                }
                .padding(.top, FuelSpacing.lg)
            }
            .scrollIndicators(.hidden)

            // Bottom action bar
            bottomBar
        }
        .background(FuelColors.white)
        .sheet(isPresented: $showingRefineSheet) {
            NavigationStack {
                VStack(spacing: FuelSpacing.lg) {
                    TextField("Describe your meal", text: $refineQuery)
                        .font(FuelType.body)
                        .padding(FuelSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.md)
                                .fill(FuelColors.cloud)
                        )

                    Button {
                        showingRefineSheet = false
                        onRefine?(refineQuery)
                    } label: {
                        Text("Re-analyze")
                            .font(FuelType.cardTitle)
                            .foregroundStyle(FuelColors.onDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FuelSpacing.lg)
                            .background(FuelColors.ink)
                            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                    }
                    .disabled(refineQuery.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding(FuelSpacing.xl)
                .navigationTitle("Refine Description")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingRefineSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            for item in analysis.items {
                quantities[item.id] = 1.0
            }
        }
        .onChange(of: analysis.items.map(\.id)) { _, newIDs in
            // Reset quantities when items change (e.g., preview → final result)
            quantities = [:]
            removedItems = []
            for id in newIDs {
                quantities[id] = 1.0
            }
        }
    }

    // MARK: - Item Row (extracted to reduce type-checker complexity)

    @ViewBuilder
    private func itemRow(item: AnalyzedFoodItem, index: Int) -> some View {
        if removedItems.contains(item.id) {
            HStack(spacing: FuelSpacing.sm) {
                Text(item.name)
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.stone)
                    .strikethrough()
                Spacer()
                Button {
                    FuelHaptics.shared.tap()
                    withAnimation(FuelAnimation.snappy) {
                        _ = removedItems.remove(item.id)
                    }
                } label: {
                    Text("Undo")
                        .font(FuelType.micro)
                        .foregroundStyle(FuelColors.flame)
                }
            }
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.vertical, FuelSpacing.xs)
        } else {
            FoodItemRow(
                item: item,
                quantity: Binding(
                    get: { quantities[item.id] ?? 1.0 },
                    set: { quantities[item.id] = $0 }
                ),
                onRemove: analysis.items.count > 1 ? {
                    withAnimation(FuelAnimation.snappy) {
                        _ = removedItems.insert(item.id)
                    }
                } : nil
            )
            .padding(.horizontal, FuelSpacing.xl)
            .staggeredAppear(index: (imageData != nil ? 4 : 3) + index)
        }
    }

    // MARK: - Macro Bar

    private var mealConfidenceBadge: some View {
        let adj = adjustedAnalysis
        let avgConfidence = adj.items.isEmpty ? 0.5
            : adj.items.reduce(0.0) { $0 + $1.confidence } / Double(adj.items.count)
        let hasRange = adj.calorieRange != nil
        let (icon, label, color): (String, String, Color) = {
            if avgConfidence >= 0.9 {
                return ("checkmark.seal.fill", "High accuracy", FuelColors.success)
            } else if avgConfidence >= 0.75 {
                return ("checkmark.circle.fill", "Good accuracy", FuelColors.success)
            } else if avgConfidence >= 0.6 {
                return ("exclamationmark.circle.fill", "Approximate", FuelColors.warning)
            } else {
                return ("questionmark.circle.fill", "Rough estimate", FuelColors.over)
            }
        }()

        return HStack(spacing: FuelSpacing.xs) {
            Image(systemName: icon)
                .font(FuelType.badgeMicro)
                .foregroundStyle(color)
            Text(label)
                .font(FuelType.caption)
                .foregroundStyle(color)
            if hasRange, let range = adj.calorieRange {
                Text("(\(range.low)-\(range.high) cal)")
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.stone)
            }
        }
    }

    private var macroBar: some View {
        let adj = adjustedAnalysis
        let pCal = adj.totalProtein * 4
        let cCal = adj.totalCarbs * 4
        let fCal = adj.totalFat * 9
        let total = pCal + cCal + fCal

        return GeometryReader { geo in
            let w = geo.size.width
            let pW = total > 0 ? w * pCal / total : 0
            let cW = total > 0 ? w * cCal / total : 0
            let fW = total > 0 ? w * fCal / total : 0

            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(FuelColors.protein)
                    .frame(width: max(pW, 2))
                RoundedRectangle(cornerRadius: 4)
                    .fill(FuelColors.carbs)
                    .frame(width: max(cW, 2))
                RoundedRectangle(cornerRadius: 4)
                    .fill(FuelColors.fat)
                    .frame(width: max(fW, 2))
            }
            .animation(FuelAnimation.snappy, value: adj.totalCalories)
        }
        .frame(height: 8)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(FuelColors.mist.opacity(0.5))
                .frame(height: 0.5)

            HStack(spacing: FuelSpacing.md) {
                // Retake
                Button(action: onRetake) {
                    Text(retakeLabel)
                        .font(FuelType.cardTitle)
                        .foregroundStyle(isLogging ? FuelColors.stone : FuelColors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.lg)
                        .background(isLogging ? FuelColors.mist : FuelColors.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                }
                .pressable()
                .disabled(isLogging)

                // Log
                Button {
                    onLog(adjustedAnalysis)
                } label: {
                    HStack(spacing: FuelSpacing.sm) {
                        if isLogging {
                            ProgressView()
                                .tint(FuelColors.onDark)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(FuelType.iconMd)
                        }
                        Text(isLogging ? "Saving..." : "Log Meal")
                            .font(FuelType.cardTitle)
                    }
                    .foregroundStyle(FuelColors.onDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FuelSpacing.lg)
                    .background(isLogging || adjustedAnalysis.items.isEmpty ? FuelColors.stone : FuelColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                    .animation(FuelAnimation.snappy, value: isLogging)
                }
                .pressable()
                .disabled(isLogging || adjustedAnalysis.items.isEmpty)
                .accessibilityLabel(isLogging ? "Saving meal" : "Log meal")
                .accessibilityHint("Saves this meal to your food diary")
            }
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.vertical, FuelSpacing.md)
        }
        .background(FuelColors.white)
    }
}

// MARK: - Result Macro Pill

private struct ResultMacroPill: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: FuelSpacing.xs) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text("\(Int(value))g")
                    .font(FuelType.stat)
                    .contentTransition(.numericText())
                    .foregroundStyle(FuelColors.ink)
            }
            Text(label)
                .font(FuelType.micro)
                .foregroundStyle(FuelColors.stone)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FuelSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.md)
                .fill(FuelColors.cloud)
        )
    }
}

// MARK: - Food Item Row

private struct FoodItemRow: View {
    let item: AnalyzedFoodItem
    @Binding var quantity: Double
    var onRemove: (() -> Void)? = nil

    private var adjustedCalories: Int {
        Int(Double(item.calories) * quantity)
    }

    var body: some View {
        VStack(spacing: FuelSpacing.sm) {
            HStack(alignment: .top, spacing: FuelSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: FuelSpacing.sm) {
                        Text(item.name)
                            .font(FuelType.cardTitle)
                            .foregroundStyle(FuelColors.ink)

                        if let onRemove {
                            Button(action: onRemove) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(FuelType.iconSm)
                                    .foregroundStyle(FuelColors.fog)
                            }
                        }
                    }

                    Text(item.servingSize)
                        .font(FuelType.caption)
                        .foregroundStyle(FuelColors.stone)

                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                            .italic()
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(adjustedCalories) cal")
                        .font(FuelType.cardTitle)
                        .contentTransition(.numericText())
                        .foregroundStyle(FuelColors.ink)

                    confidenceBadge
                }
            }

            // Macros + quantity adjuster
            HStack(spacing: 0) {
                HStack(spacing: FuelSpacing.md) {
                    MicroMacroLabel(letter: "P", value: item.protein * quantity, color: FuelColors.protein)
                    MicroMacroLabel(letter: "C", value: item.carbs * quantity, color: FuelColors.carbs)
                    MicroMacroLabel(letter: "F", value: item.fat * quantity, color: FuelColors.fat)
                }

                Spacer()

                // Quantity stepper
                HStack(spacing: 0) {
                    Button {
                        if quantity > 0.5 {
                            quantity -= 0.5
                            FuelHaptics.shared.selection()
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(FuelType.micro)
                            .foregroundStyle(quantity > 0.5 ? FuelColors.ink : FuelColors.fog)
                            .frame(width: 28, height: 28)
                            .background(FuelColors.cloud)
                            .clipShape(Circle())
                    }
                    .disabled(quantity <= 0.5)

                    Text(quantity == 1.0 ? "1x" : String(format: "%.1fx", quantity))
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.ink)
                        .frame(width: 36)
                        .multilineTextAlignment(.center)

                    Button {
                        if quantity < 10.0 {
                            quantity += 0.5
                            FuelHaptics.shared.selection()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(FuelType.micro)
                            .foregroundStyle(quantity < 10.0 ? FuelColors.ink : FuelColors.fog)
                            .frame(width: 28, height: 28)
                            .background(FuelColors.cloud)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(FuelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.card)
                .fill(FuelColors.white)
                .stroke(FuelColors.mist, lineWidth: 0.5)
        )
        .animation(FuelAnimation.snappy, value: quantity)
    }

    private var confidenceBadge: some View {
        let (label, color) = confidenceInfo
        return Text(label)
            .font(FuelType.badgeMicro)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private var confidenceInfo: (String, Color) {
        if item.confidence >= 0.9 {
            return ("Exact", FuelColors.success)
        } else if item.confidence >= 0.75 {
            return ("Good", FuelColors.success)
        } else if item.confidence >= 0.6 {
            return ("Estimate", FuelColors.warning)
        } else {
            return ("Rough", FuelColors.over)
        }
    }
}

// MARK: - Micro Macro Label

private struct MicroMacroLabel: View {
    let letter: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text("\(letter) \(Int(value))g")
                .font(FuelType.micro)
                .foregroundStyle(FuelColors.stone)
        }
    }
}
