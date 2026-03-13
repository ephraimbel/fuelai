import SwiftUI

struct DietStyleView: View {
    @Binding var selected: DietStyle
    let onContinue: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: FuelSpacing.md),
        GridItem(.flexible(), spacing: FuelSpacing.md),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FuelSpacing.sm) {
                (Text("Do you follow a ")
                    .foregroundColor(FuelColors.ink) +
                 Text("diet?")
                    .foregroundColor(FuelColors.flame))
                    .font(FuelType.title)
                Text("This adjusts your macro balance")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.xxl)
            .padding(.bottom, FuelSpacing.xl)

            Spacer()

            LazyVGrid(columns: columns, spacing: FuelSpacing.md) {
                ForEach(Array(DietStyle.allCases.enumerated()), id: \.element) { index, diet in
                    Button {
                        withAnimation(FuelAnimation.snappy) { selected = diet }
                        FuelHaptics.shared.tap()
                        FuelSounds.shared.pop()
                    } label: {
                        VStack(spacing: FuelSpacing.sm) {
                            Image(systemName: diet.iconName)
                                .font(.system(size: 28))
                                .foregroundStyle(selected == diet ? FuelColors.flame : FuelColors.stone)
                                .frame(height: 32)

                            Text(diet.displayName)
                                .font(FuelType.cardTitle)
                                .foregroundStyle(FuelColors.ink)

                            Text(diet.description)
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
                                .stroke(selected == diet ? FuelColors.flame : .clear, lineWidth: 2)
                        )
                        .scaleEffect(selected == diet ? 1.03 : 1.0)
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
