import SwiftUI

struct ChatCardView: View {
    let card: ChatCard
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
                        .font(.system(size: 22, weight: .bold, design: .rounded))
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
        .padding(14)
        .background(cardBackground)
    }
}

// MARK: - Macro Breakdown Card

private struct ChatMacroCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: FuelSpacing.md) {
            miniMacroPill(
                label: "Protein",
                consumed: appState.proteinConsumed,
                target: Double(appState.proteinTarget),
                color: FuelColors.protein,
                icon: "bolt.fill"
            )
            miniMacroPill(
                label: "Carbs",
                consumed: appState.carbsConsumed,
                target: Double(appState.carbsTarget),
                color: FuelColors.carbs,
                icon: "leaf.fill"
            )
            miniMacroPill(
                label: "Fat",
                consumed: appState.fatConsumed,
                target: Double(appState.fatTarget),
                color: FuelColors.fat,
                icon: "drop.fill"
            )
        }
        .padding(14)
        .background(cardBackground)
    }

    private func miniMacroPill(label: String, consumed: Double, target: Double, color: Color, icon: String) -> some View {
        let progress = target > 0 ? consumed / target : 0
        let remaining = max(0, target - consumed)

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 28, height: 28)

            Text("\(Int(remaining))g")
                .font(.system(size: 14, weight: .bold, design: .rounded))
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
                        Divider()
                            .foregroundStyle(FuelColors.mist)
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground)
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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FuelColors.flame.opacity(0.05))
                .stroke(FuelColors.flame.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Shared Card Background

private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 14)
        .fill(FuelColors.white)
        .stroke(FuelColors.mist.opacity(0.6), lineWidth: 0.5)
}
