import SwiftUI

struct CalorieCardView: View {
    @Environment(AppState.self) private var appState
    @State private var cardScale: Double = 1.0
    @State private var previousCalories: Int = -1

    private var isOver: Bool {
        appState.caloriesConsumed > appState.calorieTarget
    }

    var body: some View {
        VStack(spacing: FuelSpacing.lg) {
            // Hero ring with number inside
            ZStack {
                CalorieRingView(
                    progress: appState.calorieProgress,
                    size: 140,
                    lineWidth: 12
                )

                // Center content inside ring
                VStack(spacing: 2) {
                    Text("\(isOver ? appState.caloriesConsumed - appState.calorieTarget : appState.caloriesRemaining)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(isOver ? FuelColors.over : FuelColors.ink)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appState.caloriesRemaining)

                    Text(isOver ? "over" : "left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isOver ? FuelColors.over.opacity(0.7) : FuelColors.stone)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
            }

            // Eaten / Target context
            HStack(spacing: FuelSpacing.xl) {
                VStack(spacing: 2) {
                    Text("\(appState.caloriesConsumed)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(FuelColors.ink)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appState.caloriesConsumed)
                    Text("eaten")
                        .font(FuelType.micro)
                        .foregroundStyle(FuelColors.stone)
                }

                Rectangle()
                    .fill(FuelColors.mist)
                    .frame(width: 1, height: 24)

                VStack(spacing: 2) {
                    Text("\(appState.calorieTarget)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(FuelColors.ink)
                    Text("target")
                        .font(FuelType.micro)
                        .foregroundStyle(FuelColors.stone)
                }
            }
        }
        .padding(.vertical, FuelSpacing.xl)
        .padding(.horizontal, FuelSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.card)
                .fill(FuelColors.cloud)
                .overlay(
                    RoundedRectangle(cornerRadius: FuelRadius.card)
                        .stroke(FuelColors.mist, lineWidth: 0.5)
                )
        )
        .scaleEffect(cardScale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appState.caloriesRemaining) calories remaining. \(appState.caloriesConsumed) eaten of \(appState.calorieTarget) target.")
        .onAppear {
            previousCalories = appState.caloriesConsumed
        }
        .onChange(of: appState.caloriesConsumed) { oldValue, newValue in
            guard previousCalories >= 0, newValue > oldValue else {
                previousCalories = newValue
                return
            }
            previousCalories = newValue

            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                cardScale = 1.02
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    cardScale = 1.0
                }
            }
        }
    }
}
