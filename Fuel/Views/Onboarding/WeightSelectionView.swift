import SwiftUI

struct WeightSelectionView: View {
    @Binding var weightKg: Double
    let onContinue: () -> Void

    @State private var weightLbs: Int = 165
    @State private var useMetric = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                Text("What's your current weight?")
                    .font(FuelType.title)
                    .foregroundStyle(FuelColors.ink)
                Text("This stays private to you")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.lg)
            .staggeredAppear(index: 0)

            Spacer()

            VStack(spacing: FuelSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if useMetric {
                        Text("\(Int(weightKg))")
                            .font(.system(size: 72, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.ink)
                            .contentTransition(.numericText())
                            .animation(FuelAnimation.snappy, value: weightKg)

                        Text("kg")
                            .font(FuelType.stat)
                            .foregroundStyle(FuelColors.stone)
                    } else {
                        Text("\(weightLbs)")
                            .font(.system(size: 72, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.ink)
                            .contentTransition(.numericText())
                            .animation(FuelAnimation.snappy, value: weightLbs)

                        Text("lbs")
                            .font(FuelType.stat)
                            .foregroundStyle(FuelColors.stone)
                    }
                }
            }
            .staggeredAppear(index: 1)

            Spacer().frame(height: FuelSpacing.xl)

            if useMetric {
                Picker("Weight (kg)", selection: Binding(
                    get: { Int(weightKg) },
                    set: { weightKg = Double($0) }
                )) {
                    ForEach(30...200, id: \.self) { value in
                        Text("\(value) kg").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .padding(.horizontal, FuelSpacing.xl)
            } else {
                Picker("Weight (lbs)", selection: $weightLbs) {
                    ForEach(80...400, id: \.self) { value in
                        Text("\(value) lbs").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .padding(.horizontal, FuelSpacing.xl)
            }

            Button {
                FuelHaptics.shared.selection()
                // Sync before toggling to preserve the current value
                if useMetric {
                    // Switching to imperial: update lbs from current kg
                    weightLbs = Int(round(weightKg * 2.20462))
                } else {
                    // Switching to metric: update kg from current lbs
                    weightKg = Double(weightLbs) * 0.453592
                }
                withAnimation(FuelAnimation.snappy) { useMetric.toggle() }
            } label: {
                Text(useMetric ? "Use imperial" : "Use metric")
                    .font(FuelType.caption)
                    .foregroundStyle(FuelColors.flame)
            }
            .padding(.top, FuelSpacing.sm)
            .staggeredAppear(index: 2)

            Spacer()

            Button(action: {
                syncWeight()
                onContinue()
            }) {
                Text("Continue")
            }
            .buttonStyle(.fuelPrimary)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.bottom, FuelSpacing.lg)
        }
        .onAppear {
            weightLbs = Int(round(weightKg * 2.20462))
        }
    }

    private func syncWeight() {
        if !useMetric {
            weightKg = Double(weightLbs) * 0.453592
        }
    }
}
