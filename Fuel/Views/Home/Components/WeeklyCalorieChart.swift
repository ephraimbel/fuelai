import SwiftUI

struct WeeklyCalorieChart: View {
    @Environment(AppState.self) private var appState
    var summaries: [DailySummary] = []
    var period: TimePeriod = .week
    @State private var appeared = false
    @State private var barData: [DayData] = []

    struct DayData: Identifiable {
        let id = UUID()
        let label: String
        let protein: Double
        let carbs: Double
        let fat: Double
        let total: Int
        let isToday: Bool
    }

    private var title: String {
        switch period {
        case .week: return "This week"
        case .month: return "This month"
        case .threeMonth: return "Last 3 months"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.md) {
            // Header
            HStack {
                Text(title)
                    .font(FuelType.section)
                    .foregroundStyle(FuelColors.ink)
                Spacer()
                if let avg = average {
                    Text("avg \(avg) cal")
                        .font(FuelType.microNum)
                        .foregroundStyle(FuelColors.stone)
                }
            }

            // Chart
            HStack(alignment: .bottom, spacing: period == .week ? FuelSpacing.sm : 2) {
                ForEach(barData) { day in
                    VStack(spacing: FuelSpacing.xs) {
                        // Calorie label (only for week view)
                        if period == .week && day.total > 0 {
                            Text("\(day.total)")
                                .font(.system(size: 10, weight: .medium, design: .serif).monospacedDigit())
                                .foregroundStyle(day.isToday ? FuelColors.ink : FuelColors.stone)
                                .opacity(appeared ? 1 : 0)
                        }

                        // Stacked bar
                        GeometryReader { _ in
                            let maxCal = Double(maxCalories)
                            let totalH: CGFloat = maxCal > 0 ? CGFloat(day.total) / CGFloat(maxCal) : 0
                            let proteinFrac = day.total > 0 ? day.protein / Double(day.total) : 0
                            let carbsFrac = day.total > 0 ? day.carbs / Double(day.total) : 0
                            let fatFrac = day.total > 0 ? day.fat / Double(day.total) : 0

                            VStack(spacing: 0) {
                                Spacer()

                                if day.total > 0 {
                                    VStack(spacing: 0) {
                                        RoundedCornerRect(topLeft: 4, topRight: 4)
                                            .fill(FuelColors.protein)
                                            .frame(height: max(0, 120 * totalH * proteinFrac))

                                        Rectangle()
                                            .fill(FuelColors.carbs)
                                            .frame(height: max(0, 120 * totalH * carbsFrac))

                                        RoundedCornerRect(bottomLeft: 4, bottomRight: 4)
                                            .fill(FuelColors.fat)
                                            .frame(height: max(0, 120 * totalH * fatFrac))
                                    }
                                    .scaleEffect(y: appeared ? 1 : 0, anchor: .bottom)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(FuelColors.mist.opacity(0.4))
                                        .frame(height: 4)
                                }
                            }
                        }
                        .frame(height: 120)

                        // Indicator dot
                        Circle()
                            .fill(day.isToday ? FuelColors.flame : FuelColors.fog.opacity(0.5))
                            .frame(width: 4, height: 4)

                        // Day label
                        Text(day.label)
                            .font(.system(size: period == .threeMonth ? 8 : 10, weight: day.isToday ? .bold : .regular))
                            .foregroundStyle(day.isToday ? FuelColors.ink : FuelColors.stone)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Legend
            HStack(spacing: FuelSpacing.lg) {
                legendDot(color: FuelColors.protein, label: "Protein")
                legendDot(color: FuelColors.carbs, label: "Carbs")
                legendDot(color: FuelColors.fat, label: "Fat")
                Spacer()
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(FuelColors.fog)
                        .frame(width: 12, height: 1)
                    Text("\(appState.calorieTarget) goal")
                        .font(.system(size: 10))
                        .foregroundStyle(FuelColors.fog)
                }
            }
        }
        .padding(FuelSpacing.lg)
        .fuelCard()
        .onAppear {
            buildBarData()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.65).delay(0.2)) {
                appeared = true
            }
        }
        .onChange(of: summaries.map(\.totalCalories)) { _, _ in
            buildBarData()
        }
        .onChange(of: period) { _, _ in
            appeared = false
            buildBarData()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.65).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Helpers

    private var maxCalories: Int {
        let dataMax = barData.map(\.total).max() ?? 0
        return max(dataMax, appState.calorieTarget) + 100
    }

    private var average: Int? {
        let logged = barData.filter { $0.total > 0 }
        guard !logged.isEmpty else { return nil }
        return logged.reduce(0) { $0 + $1.total } / logged.count
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(FuelColors.stone)
        }
    }

    private func buildBarData() {
        let calendar = Calendar.current
        let today = appState.selectedDate
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Build a lookup from summaries
        var summaryMap: [String: DailySummary] = [:]
        for s in summaries {
            summaryMap[s.date] = s
        }

        switch period {
        case .week:
            buildWeekBars(calendar: calendar, today: today, formatter: formatter, summaryMap: summaryMap)
        case .month:
            buildMonthBars(calendar: calendar, today: today, formatter: formatter, summaryMap: summaryMap)
        case .threeMonth:
            buildThreeMonthBars(calendar: calendar, today: today, formatter: formatter, summaryMap: summaryMap)
        }
    }

    private func buildWeekBars(calendar: Calendar, today: Date, formatter: DateFormatter, summaryMap: [String: DailySummary]) {
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else { return }

        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

        barData = (0..<7).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: monday) else {
                return DayData(label: dayLabels[offset], protein: 0, carbs: 0, fat: 0, total: 0, isToday: false)
            }
            let dateStr = formatter.string(from: date)
            let isToday = calendar.isDate(date, inSameDayAs: today)

            if isToday {
                return DayData(
                    label: dayLabels[offset],
                    protein: appState.proteinConsumed * 4,
                    carbs: appState.carbsConsumed * 4,
                    fat: appState.fatConsumed * 9,
                    total: appState.caloriesConsumed,
                    isToday: true
                )
            }

            if let s = summaryMap[dateStr] {
                return DayData(
                    label: dayLabels[offset],
                    protein: s.totalProtein * 4, carbs: s.totalCarbs * 4, fat: s.totalFat * 9,
                    total: s.totalCalories, isToday: false
                )
            }

            return DayData(label: dayLabels[offset], protein: 0, carbs: 0, fat: 0, total: 0, isToday: false)
        }
    }

    private func buildMonthBars(calendar: Calendar, today: Date, formatter: DateFormatter, summaryMap: [String: DailySummary]) {
        // Show 30 days
        guard let startDate = calendar.date(byAdding: .day, value: -29, to: today) else { return }

        barData = (0..<30).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else {
                return DayData(label: "", protein: 0, carbs: 0, fat: 0, total: 0, isToday: false)
            }
            let dateStr = formatter.string(from: date)
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let day = calendar.component(.day, from: date)
            // Show label every 5 days
            let label = (day % 5 == 0 || offset == 29) ? "\(day)" : ""

            if isToday {
                return DayData(
                    label: label,
                    protein: appState.proteinConsumed * 4,
                    carbs: appState.carbsConsumed * 4,
                    fat: appState.fatConsumed * 9,
                    total: appState.caloriesConsumed,
                    isToday: true
                )
            }

            if let s = summaryMap[dateStr] {
                return DayData(
                    label: label,
                    protein: s.totalProtein * 4, carbs: s.totalCarbs * 4, fat: s.totalFat * 9,
                    total: s.totalCalories, isToday: false
                )
            }

            return DayData(label: label, protein: 0, carbs: 0, fat: 0, total: 0, isToday: false)
        }
    }

    private func buildThreeMonthBars(calendar: Calendar, today: Date, formatter: DateFormatter, summaryMap: [String: DailySummary]) {
        // Group by week (13 weeks)
        guard let startDate = calendar.date(byAdding: .day, value: -90, to: today) else { return }

        let weekFormatter = DateFormatter()
        weekFormatter.dateFormat = "MMM d"

        barData = (0..<13).map { weekIndex in
            guard let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: startDate) else {
                return DayData(label: "", protein: 0, carbs: 0, fat: 0, total: 0, isToday: false)
            }

            var totalP = 0.0, totalC = 0.0, totalF = 0.0, totalCal = 0, count = 0
            let isCurrentWeek = calendar.isDate(weekStart, equalTo: today, toGranularity: .weekOfYear)

            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                let dateStr = formatter.string(from: date)

                if calendar.isDate(date, inSameDayAs: today) {
                    totalP += appState.proteinConsumed * 4
                    totalC += appState.carbsConsumed * 4
                    totalF += appState.fatConsumed * 9
                    totalCal += appState.caloriesConsumed
                    count += 1
                } else if let s = summaryMap[dateStr], s.totalCalories > 0 {
                    totalP += s.totalProtein * 4
                    totalC += s.totalCarbs * 4
                    totalF += s.totalFat * 9
                    totalCal += s.totalCalories
                    count += 1
                }
            }

            let avg = count > 0 ? totalCal / count : 0
            let avgP = count > 0 ? totalP / Double(count) : 0
            let avgC = count > 0 ? totalC / Double(count) : 0
            let avgF = count > 0 ? totalF / Double(count) : 0

            // Show label every 3 weeks
            let label = weekIndex % 3 == 0 ? weekFormatter.string(from: weekStart) : ""

            return DayData(
                label: label,
                protein: avgP, carbs: avgC, fat: avgF,
                total: avg, isToday: isCurrentWeek
            )
        }
    }
}

// MARK: - Rounded Corner Shape

private struct RoundedCornerRect: Shape {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = min(topLeft, min(rect.width, rect.height) / 2)
        let tr = min(topRight, min(rect.width, rect.height) / 2)
        let bl = min(bottomLeft, min(rect.width, rect.height) / 2)
        let br = min(bottomRight, min(rect.width, rect.height) / 2)

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
