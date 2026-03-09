import SwiftUI

struct GoalSelectionView: View {
    @Binding var selected: GoalType
    let onContinue: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: FuelSpacing.md),
        GridItem(.flexible(), spacing: FuelSpacing.md),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                Text("What's your goal?")
                    .font(FuelType.title)
                    .foregroundStyle(FuelColors.ink)
                Text("Choose what fits you best")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.xxl)
            .padding(.bottom, FuelSpacing.xl)

            Spacer()

            LazyVGrid(columns: columns, spacing: FuelSpacing.md) {
                ForEach(Array(GoalType.allCases.enumerated()), id: \.element) { index, goal in
                    Button {
                        withAnimation(FuelAnimation.snappy) { selected = goal }
                        FuelHaptics.shared.tap()
                        FuelSounds.shared.pop()
                    } label: {
                        VStack(spacing: FuelSpacing.sm) {
                            Image(systemName: goal.iconName)
                                .font(.system(size: 28))
                                .foregroundStyle(selected == goal ? FuelColors.flame : FuelColors.stone)
                                .frame(height: 32)

                            Text(goal.displayName)
                                .font(FuelType.cardTitle)
                                .foregroundStyle(FuelColors.ink)

                            Text(goal.goalDescription)
                                .font(FuelType.caption)
                                .foregroundStyle(FuelColors.stone)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.lg)
                        .padding(.horizontal, FuelSpacing.sm)
                        .background(FuelColors.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: FuelRadius.card)
                                .stroke(selected == goal ? FuelColors.flame : .clear, lineWidth: 2)
                        )
                        .scaleEffect(selected == goal ? 1.03 : 1.0)
                        .animation(FuelAnimation.snappy, value: selected)
                    }
                    .staggeredAppear(index: index)
                }
            }
            .padding(.horizontal, FuelSpacing.xl)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
            }
            .buttonStyle(.fuelPrimary)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.md)
            .padding(.bottom, FuelSpacing.lg)
        }
    }
}
