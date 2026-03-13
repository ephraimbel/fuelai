import SwiftUI

struct WeekStripView: View {
    @Environment(AppState.self) private var appState
    @Namespace private var selectionNamespace

    private let calendar = Calendar.current
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        let dates = getTrailingDates()

        HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
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
                                    .fill(FuelColors.buttonFill)
                                    .frame(width: 34, height: 34)
                                    .matchedGeometryEffect(id: "weekSelection", in: selectionNamespace)
                            } else if isToday {
                                Circle()
                                    .strokeBorder(FuelColors.mist, lineWidth: 1.5)
                                    .frame(width: 32, height: 32)
                            }

                            Text("\(dayNumber)")
                                .font(FuelType.caption)
                                .foregroundStyle(isSelected ? .white : FuelColors.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(dayNames[weekday - 1]), \(dayNumber)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    /// Returns the last 7 days ending on today (today is always the rightmost day)
    private func getTrailingDates() -> [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }
}
