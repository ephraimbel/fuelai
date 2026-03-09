import SwiftUI
import Charts

struct WeightChartView: View {
    let weights: [WeightLog]
    var period: TimePeriod = .week
    let onAddWeight: () -> Void

    @State private var animatedWeights: [WeightLog] = []
    @State private var selectedWeight: WeightLog?

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
                            Text(String(format: "%.1f kg", latest))
                                .font(FuelType.caption)
                                .foregroundStyle(FuelColors.stone)

                            if let change = weightChange {
                                HStack(spacing: 2) {
                                    Image(systemName: change > 0 ? "arrow.up.right" : change < 0 ? "arrow.down.right" : "arrow.right")
                                        .font(FuelType.badgeMicro)
                                    Text(String(format: "%+.1f kg", change))
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
                        Text(String(format: "%.1f", selected.weightKg))
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
                        .foregroundStyle(FuelColors.ink)
                        .padding(.horizontal, FuelSpacing.md)
                        .padding(.vertical, FuelSpacing.sm)
                        .background(
                            Capsule().fill(FuelColors.onDark)
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
                            yEnd: .value("Weight", log.weightKg)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FuelColors.ink.opacity(0.1), FuelColors.ink.opacity(0.01)],
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
                            y: .value("Weight", log.weightKg)
                        )
                        .foregroundStyle(FuelColors.ink)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }

                    // Points
                    ForEach(animatedWeights) { log in
                        PointMark(
                            x: .value("Date", log.loggedAt),
                            y: .value("Weight", log.weightKg)
                        )
                        .foregroundStyle(FuelColors.ink)
                        .symbolSize(selectedWeight?.id == log.id ? 100 : 30)
                    }

                    // Selection line
                    if let selected = selectedWeight {
                        RuleMark(x: .value("Selected", selected.loggedAt))
                            .foregroundStyle(FuelColors.ink.opacity(0.15))
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
        .background(FuelColors.cloud)
        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weightAccessibilityLabel)
        .accessibilityAction(named: "Log weight") { onAddWeight() }
        .onAppear { animateIn() }
        .onChange(of: weights.map(\.weightKg)) { _, _ in animateIn() }
    }

    private var weightAccessibilityLabel: String {
        if weights.isEmpty {
            return "Weight chart. No entries yet. Double tap to log your first weight."
        }
        var label = "Weight chart."
        if let latest = latestWeight {
            label += " Latest weight \(String(format: "%.1f", latest)) kilograms."
        }
        if let change = weightChange {
            let direction = change > 0 ? "up" : "down"
            label += " \(direction) \(String(format: "%.1f", abs(change))) kilograms over this period."
        }
        if weights.count == 1 {
            label += " Log another weight to see your trend."
        }
        return label
    }

    // MARK: - Y Axis

    private var yAxisMin: Double {
        let min = weights.map(\.weightKg).min() ?? 60
        return (min - 2).rounded(.down)
    }

    private var yAxisMax: Double {
        let max = weights.map(\.weightKg).max() ?? 80
        return (max + 2).rounded(.up)
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
                        Text(String(format: "%.1f kg", entry.weightKg))
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
            Image(systemName: "scalemass")
                .font(FuelType.title)
                .foregroundStyle(FuelColors.fog)

            Text("No weight entries yet")
                .font(FuelType.body)
                .foregroundStyle(FuelColors.stone)

            Button(action: onAddWeight) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(FuelType.iconXs)
                    Text("Log your first weight")
                        .font(FuelType.label)
                }
                .foregroundStyle(FuelColors.ink)
                .padding(.horizontal, FuelSpacing.lg)
                .padding(.vertical, FuelSpacing.sm)
                .background(
                    Capsule().fill(FuelColors.onDark)
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
