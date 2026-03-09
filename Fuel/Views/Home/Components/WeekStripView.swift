import SwiftUI

struct WeekStripView: View {
    @Environment(AppState.self) private var appState
    @Namespace private var selectionNamespace

    private let calendar = Calendar.current
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        let weekDates = getWeekDates()

        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: appState.selectedDate)
                let isToday = calendar.isDateInToday(date)
                let dayNumber = calendar.component(.day, from: date)
                let weekday = calendar.component(.weekday, from: date)

                Button {
                    withAnimation(FuelAnimation.snappy) {
                        appState.selectedDate = date
                    }
                    FuelHaptics.shared.tap()
                } label: {
                    VStack(spacing: FuelSpacing.xs) {
                        Text(dayLetters[weekday - 1])
                            .font(FuelType.micro)
                            .foregroundStyle(FuelColors.fog)

                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(FuelColors.ink)
                                    .frame(width: 34, height: 34)
                                    .matchedGeometryEffect(id: "weekSelection", in: selectionNamespace)
                            } else if isToday {
                                Circle()
                                    .strokeBorder(FuelColors.mist, lineWidth: 1.5)
                                    .frame(width: 32, height: 32)
                            }

                            Text("\(dayNumber)")
                                .font(FuelType.caption)
                                .foregroundStyle(isSelected ? FuelColors.onDark : FuelColors.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
            }
        }
    }

    private func getWeekDates() -> [Date] {
        let today = appState.selectedDate
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) else {
            return [today]
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
}
