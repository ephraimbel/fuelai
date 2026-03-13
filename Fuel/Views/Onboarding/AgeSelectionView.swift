import SwiftUI

struct AgeSelectionView: View {
    @Binding var age: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FuelSpacing.sm) {
                (Text("How ")
                    .foregroundColor(FuelColors.ink) +
                 Text("old ")
                    .foregroundColor(FuelColors.flame) +
                 Text("are you?")
                    .foregroundColor(FuelColors.ink))
                    .font(FuelType.title)
                Text("Age affects your daily calorie needs")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.lg)
            .staggeredAppear(index: 0)

            Spacer()

            VStack(spacing: FuelSpacing.xs) {
                Text("\(age)")
                    .font(.system(size: 72, weight: .bold, design: .serif))
                    .foregroundStyle(FuelColors.ink)
                    .contentTransition(.numericText())
                    .animation(FuelAnimation.snappy, value: age)

                Text("years old")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
            }
            .staggeredAppear(index: 1)

            Spacer().frame(height: FuelSpacing.xl)

            Picker("Age", selection: $age) {
                ForEach(16...80, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            .padding(.horizontal, FuelSpacing.xl)
            .staggeredAppear(index: 2)

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
