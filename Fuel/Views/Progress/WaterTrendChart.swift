import SwiftUI
import Charts

struct WaterTrendChart: View {
    let summaries: [DailySummary]
    let goal: Int
    var period: TimePeriod = .week
    var unitSystem: UnitSystem = .metric

    @State private var selectedEntry: (date: Date, water: Int)?
    @State private var animatedData: [(date: Date, water: Int)] = []

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var parsedData: [(date: Date, water: Int)] {
        summaries.compactMap { summary in
            guard let date = Self.dateFormatter.date(from: summary.date) else { return nil }
            return (date, summary.waterMl)
        }.sorted { $0.date < $1.date }
    }

    private var hasAnyWater: Bool {
        summaries.contains { $0.waterMl > 0 }
    }

    private var avgWater: Int {
        let withWater = summaries.filter { $0.waterMl > 0 }
        guard !withWater.isEmpty else { return 0 }
        return withWater.reduce(0) { $0 + $1.waterMl } / withWater.count
    }

    private var avgVsGoal: String {
        guard avgWater > 0 else { return "No data" }
        let pct = Int(Double(avgWater) / Double(max(1, goal)) * 100)
        return "\(pct)% of goal"
    }

    private var yAxisMin: Int {
        let minWater = (parsedData.map(\.water) + [0]).min() ?? 0
        return max(0, minWater - 200)
    }

    private var yAxisMax: Int {
        let maxWater = (parsedData.map(\.water) + [goal]).max() ?? 2500
        return maxWater + 500
    }

    private var isMetric: Bool { unitSystem == .metric }

    private func displayAmount(_ ml: Int) -> Int {
        isMetric ? ml : Int(Double(ml) / 29.5735)
    }

    private var unitLabel: String {
        isMetric ? "ml" : "oz"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.md) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: FuelSpacing.xs) {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                            .font(FuelType.iconSm)
                            .foregroundStyle(FuelColors.water)
                        Text("Water Trend")
                            .font(FuelType.section)
                            .foregroundStyle(FuelColors.ink)
                    }

                    if hasAnyWater {
                        Text("\(displayAmount(avgWater)) \(unitLabel) avg · \(avgVsGoal)")
                            .font(FuelType.caption)
                            .foregroundStyle(FuelColors.stone)
                    }
                }

                Spacer()

                if let selected = selectedEntry {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(displayAmount(selected.water)) \(unitLabel)")
                            .font(FuelType.stat)
                            .foregroundStyle(FuelColors.water)
                        Text(selected.date, format: .dateTime.month(.abbreviated).day())
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(FuelAnimation.quick, value: selectedEntry?.date)

            if !hasAnyWater {
                emptyState
            } else {
                Chart {
                    // Area fill
                    ForEach(animatedData, id: \.date) { entry in
                        AreaMark(
                            x: .value("Date", entry.date),
                            yStart: .value("Base", yAxisMin),
                            yEnd: .value("Water", entry.water)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FuelColors.water.opacity(0.2), FuelColors.water.opacity(0.02)],
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
                            y: .value("Water", entry.water)
                        )
                        .foregroundStyle(FuelColors.water)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }

                    // Points for week view
                    if period == .week {
                        ForEach(animatedData, id: \.date) { entry in
                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("Water", entry.water)
                            )
                            .foregroundStyle(entry.water >= goal ? FuelColors.water : FuelColors.water.opacity(0.6))
                            .symbolSize(selectedEntry?.date == entry.date ? 100 : 40)
                        }
                    }

                    // Goal line
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(FuelColors.fog)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal")
                                .font(FuelType.micro)
                                .foregroundStyle(FuelColors.stone)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(FuelColors.cardBackground)
                                )
                        }

                    // Selection indicator
                    if let selected = selectedEntry {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(FuelColors.ink.opacity(0.15))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .frame(height: 180)
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
                .animation(FuelAnimation.spring, value: animatedData.map(\.water))
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .onAppear { animateIn() }
        .onChange(of: summaries.map(\.waterMl)) { _, _ in animateIn() }
        .onChange(of: period) { _, _ in animateIn() }
    }

    // MARK: - Animation

    private func animateIn() {
        selectedEntry = nil
        animatedData = parsedData.map { (date: $0.date, water: yAxisMin) }
        withAnimation(FuelAnimation.spring.delay(0.15)) {
            animatedData = parsedData
        }
    }

    // MARK: - Empty State (Ghost Chart)

    private var emptyState: some View {
        VStack(spacing: FuelSpacing.md) {
            ZStack {
                GhostWaterLine()
                    .fill(
                        LinearGradient(
                            colors: [FuelColors.water.opacity(0.15), FuelColors.water.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 120)

                GhostWaterStroke()
                    .stroke(FuelColors.water.opacity(0.2), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(height: 120)

                Rectangle()
                    .fill(FuelColors.mist.opacity(0.3))
                    .frame(height: 1)
                    .offset(y: -20)
            }

            Text("Log water to see your hydration trend")
                .font(FuelType.caption)
                .foregroundStyle(FuelColors.stone)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
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

// MARK: - Ghost Shapes

private struct GhostWaterStroke: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGFloat] = [0.7, 0.5, 0.6, 0.35, 0.45, 0.3, 0.4]
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

private struct GhostWaterLine: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGFloat] = [0.7, 0.5, 0.6, 0.35, 0.45, 0.3, 0.4]
        guard points.count > 1 else { return Path() }
        var path = Path()
        for (i, pct) in points.enumerated() {
            let x = rect.width * CGFloat(i) / CGFloat(points.count - 1)
            let y = rect.height * pct
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
