import SwiftUI

struct ActivityLevelView: View {
    @Binding var selected: ActivityLevel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FuelSpacing.sm) {
                (Text("How ")
                    .foregroundColor(FuelColors.ink) +
                 Text("active ")
                    .foregroundColor(FuelColors.flame) +
                 Text("are you?")
                    .foregroundColor(FuelColors.ink))
                    .font(FuelType.title)
                Text("This helps us calculate your daily calories")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.lg)
            .padding(.bottom, FuelSpacing.lg)

            Spacer()

            VStack(spacing: FuelSpacing.md) {
                ForEach(Array(ActivityLevel.allCases.enumerated()), id: \.element) { index, level in
                    Button {
                        withAnimation(FuelAnimation.snappy) { selected = level }
                        FuelHaptics.shared.tap()
                        FuelSounds.shared.pop()
                    } label: {
                        HStack(spacing: FuelSpacing.lg) {
                            Group {
                                if iconName(for: level) == "FlameIcon" {
                                    Image("FlameIcon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                } else {
                                    Image(systemName: iconName(for: level))
                                        .font(.system(size: 22))
                                        .foregroundStyle(selected == level ? FuelColors.flame : FuelColors.stone)
                                }
                            }
                            .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(selected == level ? FuelColors.flame.opacity(0.12) : FuelColors.cloud)
                                )

                            VStack(alignment: .leading, spacing: FuelSpacing.xs) {
                                Text(level.displayName)
                                    .font(FuelType.cardTitle)
                                    .foregroundStyle(FuelColors.ink)
                                Text(level.description)
                                    .font(FuelType.caption)
                                    .foregroundStyle(FuelColors.stone)
                            }

                            Spacer()
                        }
                        .padding(FuelSpacing.lg)
                        .background(FuelColors.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: FuelRadius.card)
                                .stroke(selected == level ? FuelColors.flame : .clear, lineWidth: 2)
                        )
                        .scaleEffect(selected == level ? 1.02 : 1.0)
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

    private func iconName(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "figure.seated.side"
        case .light: return "figure.walk"
        case .moderate: return "figure.run"
        case .active: return "figure.strengthtraining.traditional"
        case .veryActive: return "FlameIcon"
        }
    }
}
