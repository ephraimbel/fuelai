import SwiftUI

struct WaterCardView: View {
    @Environment(AppState.self) private var appState
    @State private var animatedProgress: Double = 0
    @State private var barScale: CGFloat = 1.0
    @State private var showingWaterSheet = false

    private var unitSystem: UnitSystem {
        appState.userProfile?.unitSystem ?? .imperial
    }

    private var progress: Double { appState.waterProgress }
    private var unitLabel: String { unitSystem == .metric ? "ml" : "oz" }

    private func formatAmount(_ ml: Int) -> String {
        if unitSystem == .metric { return "\(ml)" }
        return "\(Int(round(Double(ml) / 29.5735)))"
    }

    var body: some View {
        HStack(spacing: FuelSpacing.md) {
            // Water icon
            Image(systemName: "drop.fill")
                .font(.system(size: 14))
                .foregroundStyle(FuelColors.water)

            // Amount + bar
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(formatAmount(appState.todayWaterMl))
                        .font(.system(size: 15, weight: .semibold, design: .serif).monospacedDigit())
                        .foregroundStyle(FuelColors.ink)
                        .contentTransition(.numericText())

                    Text("/ \(formatAmount(appState.waterGoalMl)) \(unitLabel)")
                        .font(.system(size: 13, weight: .regular).monospacedDigit())
                        .foregroundStyle(FuelColors.stone)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(FuelColors.water.opacity(0.10))
                            .frame(height: 4)

                        Capsule()
                            .fill(FuelColors.water)
                            .frame(width: max(0, geo.size.width * min(animatedProgress, 1.0)), height: 4)
                            .scaleEffect(y: barScale, anchor: .center)
                    }
                }
                .frame(height: 4)
            }

            // Add button
            Button {
                FuelHaptics.shared.selection()
                showingWaterSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(FuelColors.water)
            }
            .pressable()
        }
        .padding(.vertical, FuelSpacing.lg)
        .padding(.horizontal, FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water: \(formatAmount(appState.todayWaterMl)) of \(formatAmount(appState.waterGoalMl)) \(unitLabel)")
        .accessibilityAction(named: "Add water") { showingWaterSheet = true }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                animatedProgress = progress
            }
        }
        .onChange(of: appState.todayWaterMl) { oldValue, newValue in
            let newProgress = Double(newValue) / Double(max(1, appState.waterGoalMl))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = newProgress
            }

            guard newValue > oldValue else { return }

            // Bar bounce on increase
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                barScale = 1.4
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    barScale = 1.0
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appState.todayWaterMl)
        .sheet(isPresented: $showingWaterSheet) {
            WaterQuickAddSheet(unitSystem: unitSystem) { ml in
                Task { await appState.logWater(amountMl: ml) }
            }
            .presentationDetents([.height(360)])
        }
    }
}

// MARK: - Water Quick-Add Sheet

private struct WaterQuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    let unitSystem: UnitSystem
    let onAdd: (Int) -> Void

    @State private var customAmount = ""
    @FocusState private var customFocused: Bool

    private let quickOptions: [WaterMeasurement] = WaterMeasurement.allCases

    var body: some View {
        VStack(spacing: FuelSpacing.xl) {
            // Drag handle
            Capsule()
                .fill(FuelColors.mist)
                .frame(width: 36, height: 4)
                .padding(.top, FuelSpacing.sm)

            Text("Add Water")
                .font(FuelType.section)
                .foregroundStyle(FuelColors.ink)

            // Quick-add grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: FuelSpacing.md) {
                ForEach(quickOptions) { measurement in
                    Button {
                        FuelHaptics.shared.tap()
                        onAdd(measurement.mlAmount)
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: measurement.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(FuelColors.water)
                                .frame(height: 28)
                            Text(measurement.displayAmount(unitSystem: unitSystem))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FuelColors.ink)
                            Text(measurement.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(FuelColors.stone)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.md)
                                .fill(FuelColors.water.opacity(0.06))
                        )
                    }
                    .pressable()
                }
            }
            .padding(.horizontal, FuelSpacing.xl)

            // Custom input
            HStack(spacing: FuelSpacing.sm) {
                TextField(unitSystem == .metric ? "Custom ml" : "Custom oz", text: $customAmount)
                    .font(.system(size: 15, weight: .medium))
                    .keyboardType(.numberPad)
                    .focused($customFocused)
                    .padding(FuelSpacing.md)
                    .background(FuelColors.cloud)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))

                Button {
                    if let value = Int(customAmount), value > 0 {
                        let ml = unitSystem == .metric ? value : Int(Double(value) * 29.5735)
                        FuelHaptics.shared.tap()
                        onAdd(ml)
                        dismiss()
                    }
                } label: {
                    Text("Add")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, FuelSpacing.lg)
                        .padding(.vertical, FuelSpacing.md)
                        .background(FuelColors.buttonFill)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                }
                .disabled(Int(customAmount) == nil || (Int(customAmount) ?? 0) <= 0)
                .opacity((Int(customAmount) ?? 0) > 0 ? 1 : 0.5)
            }
            .padding(.horizontal, FuelSpacing.xl)
        }
        .padding(.bottom, FuelSpacing.xl)
    }
}
