import SwiftUI

struct SexSelectionView: View {
    @Binding var selected: Sex
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FuelSpacing.sm) {
                (Text("What's your ")
                    .foregroundColor(FuelColors.ink) +
                 Text("sex?")
                    .foregroundColor(FuelColors.flame))
                    .font(FuelType.title)
                Text("This helps us calculate your metabolism")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.lg)
            .staggeredAppear(index: 0)

            Spacer()

            HStack(spacing: FuelSpacing.lg) {
                SexCard(
                    sex: .male,
                    icon: "figure.stand",
                    isSelected: selected == .male
                ) {
                    withAnimation(FuelAnimation.snappy) { selected = .male }
                    FuelHaptics.shared.tap()
                    FuelSounds.shared.pop()
                }
                .staggeredAppear(index: 1)

                SexCard(
                    sex: .female,
                    icon: "figure.stand.dress",
                    isSelected: selected == .female
                ) {
                    withAnimation(FuelAnimation.snappy) { selected = .female }
                    FuelHaptics.shared.tap()
                    FuelSounds.shared.pop()
                }
                .staggeredAppear(index: 2)
            }
            .padding(.horizontal, FuelSpacing.xl)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
            }
            .buttonStyle(.fuelPrimary)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.bottom, FuelSpacing.lg)
            .staggeredAppear(index: 3)
        }
    }
}

private struct SexCard: View {
    let sex: Sex
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: FuelSpacing.md) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundStyle(isSelected ? FuelColors.flame : FuelColors.stone)
                        .frame(height: 50)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(FuelColors.flame)
                            .offset(x: 14, y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(sex == .male ? "Male" : "Female")
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FuelSpacing.xxl)
            .background(FuelColors.cloud)
            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: FuelRadius.card)
                    .stroke(isSelected ? FuelColors.flame : .clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(FuelAnimation.snappy, value: isSelected)
        }
    }
}
