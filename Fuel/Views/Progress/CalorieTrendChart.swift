import SwiftUI
import Charts

struct CalorieTrendChart: View {
    let summaries: [DailySummary]
    let target: Int
    var period: TimePeriod = .week

    @State private var selectedEntry: (date: Date, calories: Int)?
    @State private var animatedData: [(date: Date, calories: Int)] = []

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var parsedData: [(date: Date, calories: Int)] {
        summaries.compactMap { summary in
            guard let date = Self.dateFormatter.date(from: summary.date) else { return nil }
            return (date, summary.totalCalories)
        }.sorted { $0.date < $1.date }
    }

    private var avgCalories: Int {
        guard !summaries.isEmpty else { return 0 }
        return summaries.reduce(0) { $0 + $1.totalCalories } / summaries.count
    }

    private var avgVsTarget: String {
        let diff = avgCalories - target
        if diff > 0 { return "+\(diff) over" }
        if diff < 0 { return "\(abs(diff)) under" }
        return "On target"
    }

    private var yAxisMin: Int {
        let minCal = (parsedData.map(\.calories) + [target]).min() ?? 0
        return max(0, minCal - 200)
    }

    private var yAxisMax: Int {
        let maxCal = (parsedData.map(\.calories) + [target]).max() ?? 2500
        return maxCal + 200
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.md) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: FuelSpacing.xs) {
                    Text("Calorie Trend")
                        .font(FuelType.section)
                        .foregroundStyle(FuelColors.ink)

                    if !summaries.isEmpty {
                        Text("\(avgCalories) avg · \(avgVsTarget)")
                            .font(FuelType.caption)
                            .foregroundStyle(FuelColors.stone)
                    }
                }

                Spacer()

                if let selected = selectedEntry {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(selected.calories)")
                            .font(FuelType.stat)
                            .foregroundStyle(selected.calories > target ? FuelColors.over : FuelColors.flame)
                        Text(selected.date, format: .dateTime.month(.abbreviated).day())
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(FuelAnimation.quick, value: selectedEntry?.date)

            if summaries.isEmpty {
                emptyState
            } else {
                // Chart
                Chart {
                    // Area fill
                    ForEach(animatedData, id: \.date) { entry in
                        AreaMark(
                            x: .value("Date", entry.date),
                            yStart: .value("Base", yAxisMin),
                            yEnd: .value("Calories", entry.calories)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FuelColors.flame.opacity(0.2), FuelColors.flame.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Line
                    ForEach(animatedData, id: \.date) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Calories", entry.calories)
                        )
                        .foregroundStyle(FuelColors.flame)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }

                    // Points for week view
                    if period == .week {
                        ForEach(animatedData, id: \.date) { entry in
                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("Calories", entry.calories)
                            )
                            .foregroundStyle(entry.calories > target ? FuelColors.over : FuelColors.flame)
                            .symbolSize(selectedEntry?.date == entry.date ? 100 : 40)
                        }
                    }

                    // Target line
                    RuleMark(y: .value("Target", target))
                        .foregroundStyle(FuelColors.fog)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Target")
                                .font(FuelType.micro)
                                .foregroundStyle(FuelColors.stone)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(FuelColors.cloud)
                                )
                        }

                    // Selection indicator
                    if let selected = selectedEntry {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(FuelColors.ink.opacity(0.15))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: yAxisMin...yAxisMax)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel()
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride, count: xAxisStrideCount)) { _ in
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
                                            if let closest = animatedData.min(by: {
                                                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                            }) {
                                                if selectedEntry?.date != closest.date {
                                                    FuelHaptics.shared.selection()
                                                    selectedEntry = closest
                                                }
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(FuelAnimation.smooth) {
                                            selectedEntry = nil
                                        }
                                    }
                            )
                    }
                }
                .animation(FuelAnimation.spring, value: animatedData.map(\.calories))
            }
        }
        .padding(FuelSpacing.lg)
        .background(FuelColors.cloud)
        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartAccessibilityLabel)
        .onAppear { animateIn() }
        .onChange(of: summaries.map(\.totalCalories)) { _, _ in animateIn() }
    }

    private var chartAccessibilityLabel: String {
        if summaries.isEmpty {
            return "Calorie trend chart. No data yet. Log meals to see your trend."
        }
        var label = "Calorie trend chart. Average \(avgCalories) calories per day, \(avgVsTarget). Target \(target) calories."
        if let lowest = parsedData.min(by: { $0.calories < $1.calories }) {
            label += " Lowest \(lowest.calories) calories."
        }
        if let highest = parsedData.max(by: { $0.calories < $1.calories }) {
            label += " Highest \(highest.calories) calories."
        }
        return label
    }

    // MARK: - Animation

    private func animateIn() {
        selectedEntry = nil
        animatedData = parsedData.map { (date: $0.date, calories: yAxisMin) }
        withAnimation(FuelAnimation.spring.delay(0.15)) {
            animatedData = parsedData
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FuelSpacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(FuelType.title)
                .foregroundStyle(FuelColors.fog)

            Text("Log meals to see your trend")
                .font(FuelType.body)
                .foregroundStyle(FuelColors.stone)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Axis Config

    private var xAxisStride: Calendar.Component {
        switch period {
        case .week: return .day
        case .month: return .weekOfYear
        case .threeMonth: return .month
        }
    }

    private var xAxisStrideCount: Int { 1 }

    private var xAxisFormat: Date.FormatStyle {
        switch period {
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.month(.abbreviated).day()
        case .threeMonth: return .dateTime.month(.abbreviated)
        }
    }
}
