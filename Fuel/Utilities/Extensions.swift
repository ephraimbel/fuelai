import Foundation

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension Date {
    private static let dateStringLock = NSLock()
    private static let timeStringLock = NSLock()

    private static let dateStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var dateString: String {
        Self.dateStringLock.lock()
        defer { Self.dateStringLock.unlock() }
        return Self.dateStringFormatter.string(from: self)
    }

    var timeString: String {
        Self.timeStringLock.lock()
        defer { Self.timeStringLock.unlock() }
        return Self.timeStringFormatter.string(from: self)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}
