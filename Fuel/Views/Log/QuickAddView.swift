import SwiftUI

struct QuickAddView: View {
    let onLog: (FoodAnalysis) -> Void

    @State private var mealName = ""
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, calories, protein, carbs, fat
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FuelSpacing.xl) {
                // Meal name
                VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                    Text("Meal Name")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)

                    TextField("e.g. Protein shake", text: $mealName)
                        .font(FuelType.body)
                        .foregroundStyle(FuelColors.ink)
                        .padding(FuelSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.sm)
                                .fill(FuelColors.cloud)
                        )
                        .focused($focusedField, equals: .name)
                }

                // Calories
                VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                    Text("Calories")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)

                    TextField("0", text: $caloriesText)
                        .font(FuelType.stat)
                        .foregroundStyle(FuelColors.ink)
                        .keyboardType(.numberPad)
                        .padding(FuelSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.sm)
                                .fill(FuelColors.cloud)
                        )
                        .focused($focusedField, equals: .calories)
                }

                // Macros
                VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                    Text("Macros (optional)")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.stone)

                    HStack(spacing: FuelSpacing.sm) {
                        macroField("Protein", text: $proteinText, color: FuelColors.protein, field: .protein)
                        macroField("Carbs", text: $carbsText, color: FuelColors.carbs, field: .carbs)
                        macroField("Fat", text: $fatText, color: FuelColors.fat, field: .fat)
                    }
                }

                Spacer(minLength: FuelSpacing.xxl)

                // Log button
                Button {
                    logQuickAdd()
                } label: {
                    Text("Log Meal")
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.onDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.md)
                                .fill(isValid ? FuelColors.flame : FuelColors.fog)
                        )
                }
                .disabled(!isValid)
                .pressable()
            }
            .padding(.horizontal, FuelSpacing.lg)
            .padding(.top, FuelSpacing.xl)
        }
        .background(FuelColors.white.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .font(FuelType.label)
                    .foregroundStyle(FuelColors.ink)
            }
        }
        .onAppear { focusedField = .name }
    }

    // MARK: - Macro Field

    private func macroField(_ label: String, text: Binding<String>, color: Color, field: Field) -> some View {
        VStack(spacing: FuelSpacing.xs) {
            Text(label)
                .font(FuelType.micro)
                .foregroundStyle(color)

            TextField("0", text: text)
                .font(FuelType.cardTitle)
                .foregroundStyle(FuelColors.ink)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, FuelSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: FuelRadius.sm)
                        .fill(color.opacity(0.08))
                )
                .focused($focusedField, equals: field)
        }
    }

    // MARK: - Validation & Log

    private var isValid: Bool {
        guard let cal = Int(caloriesText), cal > 0, cal <= 10000 else { return false }
        return true
    }

    private func logQuickAdd() {
        guard let calories = Int(caloriesText), calories > 0 else { return }

        let protein = Double(proteinText) ?? 0
        let carbs = Double(carbsText) ?? 0
        let fat = Double(fatText) ?? 0
        let name = mealName.isEmpty ? "Quick Add" : mealName

        let item = AnalyzedFoodItem(
            id: UUID(),
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: "1 serving",
            confidence: 1.0,
            note: nil
        )

        let analysis = FoodAnalysis(
            items: [item],
            displayName: name,
            totalCalories: calories,
            totalProtein: protein,
            totalCarbs: carbs,
            totalFat: fat,
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
        onLog(analysis)
    }
}
