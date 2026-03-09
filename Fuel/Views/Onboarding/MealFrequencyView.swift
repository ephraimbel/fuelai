import SwiftUI

struct MealFrequencyView: View {
    @Binding var mealsPerDay: Int
    let onContinue: () -> Void

    private let options: [(count: Int, label: String)] = [
        (1, "OMAD"),
        (2, "Light"),
        (3, "Classic"),
        (4, "Balanced"),
        (5, "Frequent"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                Text("How many meals a day?")
                    .font(FuelType.title)
                    .foregroundStyle(FuelColors.ink)
                Text("We'll split your calories across meals")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.lg)
            .staggeredAppear(index: 0)

            Spacer()

            // Hero number
            VStack(spacing: FuelSpacing.xs) {
                Text("\(mealsPerDay)")
                    .font(.system(size: 72, weight: .bold, design: .serif))
                    .foregroundStyle(FuelColors.ink)
                    .contentTransition(.numericText())
                    .animation(FuelAnimation.snappy, value: mealsPerDay)

                Text("meals")
                    .font(FuelType.stat)
                    .foregroundStyle(FuelColors.stone)
            }
            .staggeredAppear(index: 1)

            Spacer().frame(height: FuelSpacing.xxl)

            // Pill buttons
            HStack(spacing: FuelSpacing.md) {
                ForEach(Array(options.enumerated()), id: \.element.count) { index, option in
                    Button {
                        withAnimation(FuelAnimation.snappy) { mealsPerDay = option.count }
                        FuelHaptics.shared.tap()
                        FuelSounds.shared.pop()
                    } label: {
                        VStack(spacing: FuelSpacing.xs) {
                            Text("\(option.count)")
                                .font(FuelType.stat)
                            Text(option.label)
                                .font(FuelType.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.lg)
                        .background(mealsPerDay == option.count ? FuelColors.flame : FuelColors.cloud)
                        .foregroundStyle(mealsPerDay == option.count ? FuelColors.onDark : FuelColors.ink)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                    }
                    .staggeredAppear(index: index + 2)
                }
            }
            .padding(.horizontal, FuelSpacing.xl)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
            }
            .buttonStyle(.fuelPrimary)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.bottom, FuelSpacing.lg)
        }
    }
}
