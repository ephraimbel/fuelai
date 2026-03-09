import SwiftUI

struct MacroAveragesView: View {
    @Environment(AppState.self) private var appState
    let summaries: [DailySummary]
    var period: TimePeriod = .week

    @State private var appeared = false
    @State private var selectedMacro: String?

    private var avgProtein: Double {
        guard !summaries.isEmpty else { return 0 }
        return summaries.reduce(0) { $0 + $1.totalProtein } / Double(summaries.count)
    }

    private var avgCarbs: Double {
        guard !summaries.isEmpty else { return 0 }
        return summaries.reduce(0) { $0 + $1.totalCarbs } / Double(summaries.count)
    }

    private var avgFat: Double {
        guard !summaries.isEmpty else { return 0 }
        return summaries.reduce(0) { $0 + $1.totalFat } / Double(summaries.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.md) {
            Text("Macro Averages")
                .font(FuelType.section)
                .foregroundStyle(FuelColors.ink)

            if summaries.isEmpty {
                VStack(spacing: FuelSpacing.sm) {
                    Image(systemName: "chart.pie")
                        .font(FuelType.title)
                        .foregroundStyle(FuelColors.fog)
                    Text("Log meals to see macro averages")
                        .font(FuelType.body)
                        .foregroundStyle(FuelColors.stone)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                HStack(spacing: FuelSpacing.md) {
                    MacroRingColumn(
                        label: "Protein",
                        avg: avgProtein,
                        target: Double(appState.proteinTarget),
                        color: FuelColors.protein,
                        appeared: appeared,
                        isSelected: selectedMacro == "Protein",
                        onTap: { toggleMacro("Protein") }
                    )
                    MacroRingColumn(
                        label: "Carbs",
                        avg: avgCarbs,
                        target: Double(appState.carbsTarget),
                        color: FuelColors.carbs,
                        appeared: appeared,
                        isSelected: selectedMacro == "Carbs",
                        onTap: { toggleMacro("Carbs") }
                    )
                    MacroRingColumn(
                        label: "Fat",
                        avg: avgFat,
                        target: Double(appState.fatTarget),
                        color: FuelColors.fat,
                        appeared: appeared,
                        isSelected: selectedMacro == "Fat",
                        onTap: { toggleMacro("Fat") }
                    )
                }
            }
        }
        .padding(FuelSpacing.lg)
        .background(FuelColors.cloud)
        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(macroAccessibilityLabel)
        .onAppear { triggerAnimation() }
        .onChange(of: period) { _, _ in
            selectedMacro = nil
            appeared = false
            triggerAnimation()
        }
    }

    private var macroAccessibilityLabel: String {
        if summaries.isEmpty {
            return "Macro averages. No data yet."
        }
        let pPct = appState.proteinTarget > 0 ? Int(avgProtein / Double(appState.proteinTarget) * 100) : 0
        let cPct = appState.carbsTarget > 0 ? Int(avgCarbs / Double(appState.carbsTarget) * 100) : 0
        let fPct = appState.fatTarget > 0 ? Int(avgFat / Double(appState.fatTarget) * 100) : 0
        return "Macro averages. Protein \(Int(avgProtein))g, \(pPct)% of target. Carbs \(Int(avgCarbs))g, \(cPct)% of target. Fat \(Int(avgFat))g, \(fPct)% of target."
    }

    private func triggerAnimation() {
        withAnimation(FuelAnimation.spring.delay(0.2)) {
            appeared = true
        }
    }

    private func toggleMacro(_ macro: String) {
        FuelHaptics.shared.selection()
        withAnimation(FuelAnimation.snappy) {
            selectedMacro = selectedMacro == macro ? nil : macro
        }
    }
}

// MARK: - Macro Ring Column

private struct MacroRingColumn: View {
    let label: String
    let avg: Double
    let target: Double
    let color: Color
    let appeared: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var percentage: Double {
        guard target > 0 else { return 0 }
        return min(avg / target, 1.5)
    }

    private var percentageInt: Int {
        Int(percentage * 100)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: FuelSpacing.sm) {
                // Ring
                ZStack {
                    // Track
                    Circle()
                        .stroke(color.opacity(0.12), lineWidth: 6)

                    // Progress
                    Circle()
                        .trim(from: 0, to: appeared ? min(percentage, 1.0) : 0)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    // Over indicator
                    if percentage > 1.0 {
                        Circle()
                            .trim(from: 0, to: appeared ? min(percentage - 1.0, 0.5) : 0)
                            .stroke(
                                color.opacity(0.4),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }

                    // Center value
                    VStack(spacing: 0) {
                        if isSelected {
                            Text("\(Int(avg))g")
                                .font(FuelType.label)
                                .foregroundStyle(FuelColors.ink)
                            Text("of \(Int(target))g")
                                .font(FuelType.badgeMicro)
                                .foregroundStyle(FuelColors.stone)
                        } else {
                            Text("\(percentageInt)")
                                .font(FuelType.cardTitle)
                                .foregroundStyle(FuelColors.ink)
                            Text("%")
                                .font(FuelType.micro)
                                .foregroundStyle(FuelColors.stone)
                        }
                    }
                    .animation(FuelAnimation.quick, value: isSelected)
                }
                .frame(width: 72, height: 72)

                // Label
                Text(label)
                    .font(FuelType.micro)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(FuelAnimation.snappy, value: isSelected)
    }
}
