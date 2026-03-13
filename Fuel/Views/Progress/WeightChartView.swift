import SwiftUI
import Charts

struct WeightChartView: View {
    let weights: [WeightLog]
    var period: TimePeriod = .week
    var unitSystem: UnitSystem = .imperial
    let onAddWeight: () -> Void

    @State private var animatedWeights: [WeightLog] = []
    @State private var selectedWeight: WeightLog?

    private var isMetric: Bool { unitSystem == .metric }
    private var unitLabel: String { isMetric ? "kg" : "lbs" }

    private func displayWeight(_ kg: Double) -> Double {
        isMetric ? kg : kg * 2.20462
    }

    private var weightChange: Double? {
        guard let first = weights.first, let last = weights.last, weights.count >= 2 else { return nil }
        return last.weightKg - first.weightKg
    }

    private var latestWeight: Double? {
        weights.last?.weightKg
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.md) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: FuelSpacing.xs) {
                    Text("Weight")
                        .font(FuelType.section)
                        .foregroundStyle(FuelColors.ink)

                    if let latest = latestWeight {
                        HStack(spacing: FuelSpacing.sm) {
                            Text(String(format: "%.1f %@", displayWeight(latest), unitLabel))
                                .font(FuelType.caption)
                                .foregroundStyle(FuelColors.stone)

                            if let change = weightChange {
                                HStack(spacing: 2) {
                                    Image(systemName: change > 0 ? "arrow.up.right" : change < 0 ? "arrow.down.right" : "arrow.right")
                                        .font(FuelType.badgeMicro)
                                    Text(String(format: "%+.1f %@", displayWeight(change), unitLabel))
                                        .font(FuelType.micro)
                                }
                                .foregroundStyle(change > 0 ? FuelColors.over : change < 0 ? FuelColors.success : FuelColors.stone)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(
                                        (change > 0 ? FuelColors.over : change < 0 ? FuelColors.success : FuelColors.stone).opacity(0.1)
                                    )
                                )
                            }
                        }
                    }
                }

                Spacer()

                // Selected point detail
                if let selected = selectedWeight {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", displayWeight(selected.weightKg)))
                            .font(FuelType.stat)
                            .foregroundStyle(FuelColors.ink)
                        Text(selected.loggedAt, format: .dateTime.month(.abbreviated).day())
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Button(action: onAddWeight) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(FuelType.iconXs)
                            Text("Log")
                                .font(FuelType.micro)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, FuelSpacing.md)
                        .padding(.vertical, FuelSpacing.sm)
                        .background(
                            Capsule().fill(FuelColors.buttonFill)
                        )
                    }
                    .pressable()
                }
            }
            .animation(FuelAnimation.quick, value: selectedWeight?.id)

            if weights.isEmpty {
                emptyState
            } else if weights.count == 1 {
                singleEntryState
            } else {
                Chart {
                    // Area gradient
                    ForEach(animatedWeights) { log in
                        AreaMark(
                            x: .value("Date", log.loggedAt),
                            yStart: .value("Base", yAxisMin),
                            yEnd: .value("Weight", displayWeight(log.weightKg))
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FuelColors.buttonFill.opacity(0.15), FuelColors.buttonFill.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Line
                    ForEach(animatedWeights) { log in
                        LineMark(
                            x: .value("Date", log.loggedAt),
                            y: .value("Weight", displayWeight(log.weightKg))
                        )
                        .foregroundStyle(FuelColors.buttonFill)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }

                    // Points
                    ForEach(animatedWeights) { log in
                        PointMark(
                            x: .value("Date", log.loggedAt),
                            y: .value("Weight", displayWeight(log.weightKg))
                        )
                        .foregroundStyle(FuelColors.buttonFill)
                        .symbolSize(selectedWeight?.id == log.id ? 100 : 30)
                    }

                    // Selection line
                    if let selected = selectedWeight {
                        RuleMark(x: .value("Selected", selected.loggedAt))
                            .foregroundStyle(FuelColors.flame.opacity(0.15))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .frame(height: 160)
                .chartYScale(domain: yAxisMin...yAxisMax)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel()
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride, count: 1)) { _ in
                        AxisValueLabel(format: xAxisFormat)
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            if let closest = animatedWeights.min(by: {
                                                abs($0.loggedAt.timeIntervalSince(date)) < abs($1.loggedAt.timeIntervalSince(date))
                                            }) {
                                                if selectedWeight?.id != closest.id {
                                                    FuelHaptics.shared.selection()
                                                    selectedWeight = closest
                                                }
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(FuelAnimation.smooth) {
                                            selectedWeight = nil
                                        }
                                    }
                            )
                    }
                }
                .animation(FuelAnimation.spring, value: animatedWeights.map(\.weightKg))
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weightAccessibilityLabel)
        .accessibilityAction(named: "Log weight") { onAddWeight() }
        .onAppear { animateIn() }
        .onChange(of: weights.map(\.weightKg)) { _, _ in animateIn() }
        .onChange(of: period) { _, _ in animateIn() }
    }

    private var weightAccessibilityLabel: String {
        if weights.isEmpty {
            return "Weight chart. No entries yet. Double tap to log your first weight."
        }
        let unitName = isMetric ? "kilograms" : "pounds"
        var label = "Weight chart."
        if let latest = latestWeight {
            label += " Latest weight \(String(format: "%.1f", displayWeight(latest))) \(unitName)."
        }
        if let change = weightChange {
            let direction = change > 0 ? "up" : "down"
            label += " \(direction) \(String(format: "%.1f", displayWeight(abs(change)))) \(unitName) over this period."
        }
        if weights.count == 1 {
            label += " Log another weight to see your trend."
        }
        return label
    }

    // MARK: - Y Axis

    private var yAxisMin: Double {
        let min = weights.map { displayWeight($0.weightKg) }.min() ?? displayWeight(60)
        let padding: Double = isMetric ? 2 : 5
        return (min - padding).rounded(.down)
    }

    private var yAxisMax: Double {
        let max = weights.map { displayWeight($0.weightKg) }.max() ?? displayWeight(80)
        let padding: Double = isMetric ? 2 : 5
        return (max + padding).rounded(.up)
    }

    // MARK: - Animation

    private func animateIn() {
        selectedWeight = nil
        guard weights.count >= 2 else {
            animatedWeights = weights
            return
        }
        let mid = weights.map(\.weightKg).reduce(0, +) / Double(weights.count)
        animatedWeights = weights.map { log in
            WeightLog(id: log.id, userId: log.userId, weightKg: mid, loggedAt: log.loggedAt)
        }
        withAnimation(FuelAnimation.spring.delay(0.15)) {
            animatedWeights = weights
        }
    }

    // MARK: - Single Entry

    private var singleEntryState: some View {
        VStack(spacing: FuelSpacing.md) {
            if let entry = weights.first {
                HStack {
                    VStack(alignment: .leading, spacing: FuelSpacing.xs) {
                        Text(String(format: "%.1f %@", displayWeight(entry.weightKg), unitLabel))
                            .font(FuelType.stat)
                            .foregroundStyle(FuelColors.ink)
                        Text(entry.loggedAt, format: .dateTime.month(.abbreviated).day(.defaultDigits).year())
                            .font(FuelType.caption)
                            .foregroundStyle(FuelColors.stone)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(FuelType.title)
                        .foregroundStyle(FuelColors.success)
                }
            }

            Text("Log another weight to see your trend")
                .font(FuelType.caption)
                .foregroundStyle(FuelColors.stone)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, FuelSpacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FuelSpacing.md) {
            // Ghost weight chart
            ZStack {
                // Ghost line — gentle downward trend
                GhostWeightLine()
                    .stroke(FuelColors.mist.opacity(0.4), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(height: 80)

                // Ghost dots
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(FuelColors.mist.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .opacity(0.6)

            Text("Track your weight over time")
                .font(FuelType.caption)
                .foregroundStyle(FuelColors.stone)

            Button(action: onAddWeight) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(FuelType.iconXs)
                    Text("Log your first weight")
                        .font(FuelType.label)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, FuelSpacing.lg)
                .padding(.vertical, FuelSpacing.sm)
                .background(
                    Capsule().fill(FuelColors.buttonFill)
                )
            }
            .pressable()
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }

    // MARK: - Axis Config

    private var xAxisStride: Calendar.Component {
        switch period {
        case .week: return .day
        case .month: return .weekOfYear
        case .threeMonth: return .month
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch period {
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.month(.abbreviated).day()
        case .threeMonth: return .dateTime.month(.abbreviated)
        }
    }
}

// MARK: - Ghost Weight Line

private struct GhostWeightLine: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGFloat] = [0.3, 0.35, 0.25, 0.4, 0.5]
        guard points.count > 1 else { return Path() }
        var path = Path()
        for (i, pct) in points.enumerated() {
            let x = rect.width * CGFloat(i) / CGFloat(points.count - 1)
            let y = rect.height * pct
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}
