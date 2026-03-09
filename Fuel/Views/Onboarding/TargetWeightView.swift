import SwiftUI

struct TargetWeightView: View {
    @Binding var targetWeightKg: Double
    let currentWeightKg: Double
    let goalType: GoalType
    let onContinue: () -> Void

    @State private var targetLbs: Int = 155
    @State private var useMetric = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                Text(goalType == .maintain ? "What's your ideal weight?" : "What's your goal weight?")
                    .font(FuelType.title)
                    .foregroundStyle(FuelColors.ink)
                Text(goalType == .maintain ? "We'll help you stay right on track" : "We'll build a plan to get you there")
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
                        Text("\(Int(targetWeightKg))")
                            .font(.system(size: 72, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.ink)
                            .contentTransition(.numericText())
                            .animation(FuelAnimation.snappy, value: targetWeightKg)

                        Text("kg")
                            .font(FuelType.stat)
                            .foregroundStyle(FuelColors.stone)
                    } else {
                        Text("\(targetLbs)")
                            .font(.system(size: 72, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.ink)
                            .contentTransition(.numericText())
                            .animation(FuelAnimation.snappy, value: targetLbs)

                        Text("lbs")
                            .font(FuelType.stat)
                            .foregroundStyle(FuelColors.stone)
                    }
                }
            }
            .staggeredAppear(index: 1)

            Spacer().frame(height: FuelSpacing.xl)

            if useMetric {
                Picker("Target weight (kg)", selection: Binding(
                    get: { Int(targetWeightKg) },
                    set: { targetWeightKg = Double($0) }
                )) {
                    ForEach(30...200, id: \.self) { value in
                        Text("\(value) kg").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .padding(.horizontal, FuelSpacing.xl)
            } else {
                Picker("Target weight (lbs)", selection: $targetLbs) {
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
                    targetLbs = Int(round(targetWeightKg * 2.20462))
                } else {
                    targetWeightKg = Double(targetLbs) * 0.453592
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
            if goalType == .maintain {
                targetWeightKg = currentWeightKg
            }
            targetLbs = Int(round(targetWeightKg * 2.20462))
        }
    }

    private func syncWeight() {
        if !useMetric {
            targetWeightKg = Double(targetLbs) * 0.453592
        }
    }
}
