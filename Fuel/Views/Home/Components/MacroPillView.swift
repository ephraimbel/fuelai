import SwiftUI

// MARK: - Macro & Micro Summary (horizontal bar layout)

struct MacroSummaryView: View {
    @Environment(AppState.self) private var appState
    @State private var appeared = false
    @State private var showMicros = false

    var body: some View {
        VStack(spacing: FuelSpacing.sm) {
            // Macros — 2-column grid
            HStack(spacing: FuelSpacing.md) {
                VStack(spacing: FuelSpacing.md) {
                    MacroBarRow(
                        label: "Protein",
                        consumed: appState.proteinConsumed,
                        target: Double(appState.proteinTarget),
                        unit: "g",
                        color: FuelColors.protein,
                        appeared: appeared
                    )
                    MacroBarRow(
                        label: "Fat",
                        consumed: appState.fatConsumed,
                        target: Double(appState.fatTarget),
                        unit: "g",
                        color: FuelColors.fat,
                        appeared: appeared
                    )
                }

                VStack(spacing: FuelSpacing.md) {
                    MacroBarRow(
                        label: "Carbs",
                        consumed: appState.carbsConsumed,
                        target: Double(appState.carbsTarget),
                        unit: "g",
                        color: FuelColors.carbs,
                        appeared: appeared
                    )
                    MacroBarRow(
                        label: "Fiber",
                        consumed: appState.fiberConsumed,
                        target: appState.fiberTarget,
                        unit: "g",
                        color: FuelColors.success,
                        appeared: appeared
                    )
                }
            }

            // Micros toggle
            if appState.sugarConsumed > 0 || appState.sodiumConsumed > 0 || showMicros {
                Button {
                    withAnimation(FuelAnimation.snappy) { showMicros.toggle() }
                    FuelHaptics.shared.selection()
                } label: {
                    HStack(spacing: FuelSpacing.xs) {
                        Text(showMicros ? "Hide details" : "More nutrients")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                        Image(systemName: showMicros ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(FuelColors.fog)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, FuelSpacing.xs)
            }

            if showMicros {
                HStack(spacing: FuelSpacing.md) {
                    MacroBarRow(
                        label: "Sugar",
                        consumed: appState.sugarConsumed,
                        target: appState.sugarTarget,
                        unit: "g",
                        color: FuelColors.warning,
                        appeared: appeared,
                        invertWarning: true
                    )
                    MacroBarRow(
                        label: "Sodium",
                        consumed: appState.sodiumConsumed,
                        target: appState.sodiumTarget,
                        unit: "mg",
                        color: FuelColors.over,
                        appeared: appeared,
                        invertWarning: true
                    )
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Macronutrients")
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                appeared = true
            }
        }
    }
}

// MARK: - Horizontal Bar Row

private struct MacroBarRow: View {
    let label: String
    let consumed: Double
    let target: Double
    let unit: String
    let color: Color
    let appeared: Bool
    var invertWarning: Bool = false

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard target > 0 else { return 0 }
        return consumed / target
    }

    private var isOver: Bool { consumed > target }

    private var barColor: Color {
        if invertWarning {
            return isOver ? FuelColors.over : color
        }
        return isOver ? FuelColors.warning : color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label + values
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FuelColors.stone)
                Spacer()
                HStack(spacing: 2) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 13, weight: .bold, design: .serif).monospacedDigit())
                        .foregroundStyle(isOver && invertWarning ? FuelColors.over : FuelColors.ink)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: consumed)
                    Text("/ \(Int(target))\(unit)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(FuelColors.fog)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.1))

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * animatedProgress)))
                }
            }
            .frame(height: 6)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                animatedProgress = newValue
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int(consumed))\(unit) of \(Int(target))\(unit)")
    }
}

// MARK: - Legacy alias (keeps existing references compiling)

struct MacroPillView: View {
    let label: String
    let remaining: Double
    let target: Double
    let consumed: Double
    let color: Color
    let icon: String

    var body: some View {
        MacroBarRow(label: label, consumed: consumed, target: target, unit: "g", color: color, appeared: true)
    }
}
