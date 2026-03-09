import SwiftUI

struct StreakCalendarView: View {
    @Environment(AppState.self) private var appState
    let streak: Int
    let longestStreak: Int
    let summaries: [DailySummary]
    var period: TimePeriod = .week

    @State private var appeared = false
    @State private var tappedDate: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var calendarDays: Int {
        switch period {
        case .week: return 28
        case .month: return 35
        case .threeMonth: return 91
        }
    }

    private var loggedDateData: [String: DailySummary] {
        Dictionary(summaries.filter { $0.totalCalories > 0 }.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.md) {
            // Streak stats
            HStack(spacing: FuelSpacing.lg) {
                // Current streak
                HStack(spacing: FuelSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(FuelColors.flame.opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: "flame.fill")
                            .font(FuelType.iconMd)
                            .foregroundStyle(FuelColors.flame)
                            .scaleEffect(appeared ? 1.0 : 0.5)
                            .animation(FuelAnimation.spring.delay(0.3), value: appeared)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(streak)")
                                .font(FuelType.stat)
                                .foregroundStyle(FuelColors.ink)
                                .contentTransition(.numericText())
                            Text("days")
                                .font(FuelType.micro)
                                .foregroundStyle(FuelColors.stone)
                        }
                        Text("Current")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                }

                // Divider
                Rectangle()
                    .fill(FuelColors.mist)
                    .frame(width: 1, height: 32)

                // Longest streak
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(longestStreak)")
                            .font(FuelType.stat)
                            .foregroundStyle(FuelColors.ink)
                            .contentTransition(.numericText())
                        Text("days")
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                    Text("Longest")
                        .font(FuelType.micro)
                        .foregroundStyle(FuelColors.stone)
                }

                Spacer()

                // Tapped date detail
                if let date = tappedDate, let summary = loggedDateData[date] {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(summary.totalCalories) cal")
                            .font(FuelType.label)
                            .foregroundStyle(FuelColors.flame)
                        Text(formatDateString(date))
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.stone)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(FuelAnimation.quick, value: tappedDate)

            // Day labels
            let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
            HStack(spacing: 0) {
                ForEach(dayLabels.indices, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(FuelType.badgeMicro)
                        .foregroundStyle(FuelColors.stone)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 2)

            // Calendar heat map
            let dates = getLastNDays(calendarDays)
            let loggedDates = Set(loggedDateData.keys)
            // Pad start so first date aligns under its correct weekday column
            let leadingPadding = dates.first.map { Calendar.current.component(.weekday, from: $0) - 1 } ?? 0

            LazyVGrid(columns: columns, spacing: 4) {
                // Empty cells for weekday alignment
                ForEach(0..<leadingPadding, id: \.self) { _ in
                    Color.clear
                        .frame(height: period == .threeMonth ? 16 : 22)
                }

                ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                    let dateStr = date.dateString
                    let isLogged = loggedDates.contains(dateStr)
                    let isToday = Calendar.current.isDateInToday(date)
                    let isTapped = tappedDate == dateStr

                    CalendarCell(
                        isLogged: isLogged,
                        isToday: isToday,
                        isTapped: isTapped,
                        intensity: cellIntensity(for: dateStr),
                        size: period == .threeMonth ? 16 : 22,
                        appeared: appeared,
                        delay: Double(index) * 0.008
                    )
                    .onTapGesture {
                        if isLogged {
                            FuelHaptics.shared.selection()
                            withAnimation(FuelAnimation.snappy) {
                                tappedDate = tappedDate == dateStr ? nil : dateStr
                            }
                        }
                    }
                }
            }
        }
        .padding(FuelSpacing.lg)
        .background(FuelColors.cloud)
        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(streakAccessibilityLabel)
        .onAppear { triggerAnimation() }
        .onChange(of: period) { _, _ in
            tappedDate = nil
            appeared = false
            triggerAnimation()
        }
    }

    // MARK: - Helpers

    private var streakAccessibilityLabel: String {
        let daysLogged = loggedDateData.count
        return "Logging streak. Current streak \(streak) days. Longest streak \(longestStreak) days. \(daysLogged) days logged in the last \(calendarDays) days."
    }

    private func triggerAnimation() {
        withAnimation(FuelAnimation.spring.delay(0.1)) {
            appeared = true
        }
    }

    private func cellIntensity(for dateStr: String) -> Double {
        guard let summary = loggedDateData[dateStr] else { return 0 }
        let target = max(Double(appState.calorieTarget), 1)
        let ratio = Double(summary.totalCalories) / target
        return min(max(ratio, 0.3), 1.0)
    }

    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private func formatDateString(_ dateStr: String) -> String {
        guard let date = Self.inputFormatter.date(from: dateStr) else { return dateStr }
        return Self.displayFormatter.string(from: date)
    }

    private func getLastNDays(_ n: Int) -> [Date] {
        (0..<n).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }.reversed()
    }
}

// MARK: - Calendar Cell

private struct CalendarCell: View {
    let isLogged: Bool
    let isToday: Bool
    let isTapped: Bool
    let intensity: Double
    let size: CGFloat
    let appeared: Bool
    let delay: Double

    var body: some View {
        RoundedRectangle(cornerRadius: size > 16 ? 5 : 3)
            .fill(cellColor)
            .frame(height: size)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: size > 16 ? 5 : 3)
                        .stroke(FuelColors.flame, lineWidth: 1.5)
                }
            }
            .scaleEffect(appeared ? (isTapped ? 1.15 : 1.0) : 0.3)
            .opacity(appeared ? 1 : 0)
            .animation(
                FuelAnimation.spring.delay(delay),
                value: appeared
            )
            .animation(FuelAnimation.snappy, value: isTapped)
    }

    private var cellColor: Color {
        if isTapped {
            return FuelColors.flame
        }
        if isLogged {
            return FuelColors.flame.opacity(0.2 + (intensity * 0.4))
        }
        return FuelColors.mist
    }
}
