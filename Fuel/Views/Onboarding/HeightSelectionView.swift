import SwiftUI

struct HeightSelectionView: View {
    @Binding var heightCm: Double
    let onContinue: () -> Void

    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 9
    @State private var useMetric = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FuelSpacing.sm) {
                Text("How tall are you?")
                    .font(FuelType.title)
                    .foregroundStyle(FuelColors.ink)
                Text("Used to personalize your targets")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.lg)
            .staggeredAppear(index: 0)

            Spacer()

            VStack(spacing: FuelSpacing.xs) {
                if useMetric {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(heightCm))")
                            .font(.system(size: 72, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.ink)
                            .contentTransition(.numericText())
                            .animation(FuelAnimation.snappy, value: heightCm)

                        Text("cm")
                            .font(FuelType.stat)
                            .foregroundStyle(FuelColors.stone)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(heightFeet)")
                            .font(.system(size: 72, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.ink)
                        Text("'")
                            .font(.system(size: 40, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.stone)
                        Text("\(heightInches)")
                            .font(.system(size: 72, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.ink)
                        Text("\"")
                            .font(.system(size: 40, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.stone)
                    }
                    .contentTransition(.numericText())
                    .animation(FuelAnimation.snappy, value: heightFeet + heightInches)
                }
            }
            .staggeredAppear(index: 1)

            Spacer().frame(height: FuelSpacing.xl)

            if useMetric {
                Picker("Height (cm)", selection: Binding(
                    get: { Int(heightCm) },
                    set: { heightCm = Double($0) }
                )) {
                    ForEach(120...220, id: \.self) { value in
                        Text("\(value) cm").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .padding(.horizontal, FuelSpacing.xl)
            } else {
                HStack(spacing: FuelSpacing.md) {
                    Picker("Feet", selection: $heightFeet) {
                        ForEach(4...7, id: \.self) { value in
                            Text("\(value) ft").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)

                    Picker("Inches", selection: $heightInches) {
                        ForEach(0...11, id: \.self) { value in
                            Text("\(value) in").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }
                .padding(.horizontal, FuelSpacing.xl)
            }

            Button {
                FuelHaptics.shared.selection()
                // Sync before toggling to preserve the current value
                if useMetric {
                    // Switching to imperial: update feet/inches from current cm
                    let totalInches = Int(round(heightCm / 2.54))
                    heightFeet = totalInches / 12
                    heightInches = totalInches % 12
                } else {
                    // Switching to metric: update cm from current feet/inches
                    heightCm = Double(heightFeet) * 30.48 + Double(heightInches) * 2.54
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
                syncHeight()
                onContinue()
            }) {
                Text("Continue")
            }
            .buttonStyle(.fuelPrimary)
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.bottom, FuelSpacing.lg)
        }
        .onAppear {
            let totalInches = Int(round(heightCm / 2.54))
            heightFeet = totalInches / 12
            heightInches = totalInches % 12
        }
    }

    private func syncHeight() {
        if !useMetric {
            heightCm = Double(heightFeet) * 30.48 + Double(heightInches) * 2.54
        }
    }
}
