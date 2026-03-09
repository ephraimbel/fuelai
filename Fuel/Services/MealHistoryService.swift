import Foundation

final class MealHistoryService {
    static let shared = MealHistoryService()

    private let lock = NSLock()
    private let key = "fuel_meal_history"
    private let correctionsKey = "fuel_correction_history"

    private struct MealHistory: Codable {
        var frequencies: [String: MealFrequency]
        var recents: [RecentMeal]
    }

    private struct MealFrequency: Codable {
        var calories: Int
        var count: Int
    }

    private struct RecentMeal: Codable {
        var name: String
        var calories: Int
    }

    /// Tracks how users correct AI estimates over time.
    /// Key: lowercased item name, Value: rolling average correction ratio.
    private struct CorrectionHistory: Codable {
        var corrections: [String: CorrectionEntry]
    }

    private struct CorrectionEntry: Codable {
        var ratioSum: Double  // sum of (logged / estimated) ratios
        var count: Int
        var avgRatio: Double { count > 0 ? ratioSum / Double(count) : 1.0 }
    }

    private init() {}

    // MARK: - Meal History

    private func load() -> MealHistory {
        guard let data = UserDefaults.standard.data(forKey: key),
              let history = try? JSONDecoder().decode(MealHistory.self, from: data) else {
            return MealHistory(frequencies: [:], recents: [])
        }
        return history
    }

    private func save(_ history: MealHistory) {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func recordMeal(name: String, calories: Int) {
        lock.lock()
        defer { lock.unlock() }
        var history = load()

        // Update frequency
        if var existing = history.frequencies[name] {
            existing.count += 1
            existing.calories = calories
            history.frequencies[name] = existing
        } else {
            history.frequencies[name] = MealFrequency(calories: calories, count: 1)
        }

        // Update recents (newest first, max 20)
        history.recents.removeAll { $0.name == name }
        history.recents.insert(RecentMeal(name: name, calories: calories), at: 0)
        if history.recents.count > 20 {
            history.recents = Array(history.recents.prefix(20))
        }

        save(history)
    }

    func topMeals(limit: Int = 5) -> [(name: String, calories: Int, count: Int)] {
        let history = load()
        return history.frequencies
            .sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .map { (name: $0.key, calories: $0.value.calories, count: $0.value.count) }
    }

    /// Get the log count for a specific meal name.
    func frequencyOf(name: String) -> Int {
        let history = load()
        return history.frequencies[name]?.count ?? 0
    }

    func recentMeals(limit: Int = 5) -> [(name: String, calories: Int)] {
        let history = load()
        return history.recents
            .prefix(limit)
            .map { (name: $0.name, calories: $0.calories) }
    }

    // MARK: - Correction Learning

    private func loadCorrections() -> CorrectionHistory {
        guard let data = UserDefaults.standard.data(forKey: correctionsKey),
              let history = try? JSONDecoder().decode(CorrectionHistory.self, from: data) else {
            return CorrectionHistory(corrections: [:])
        }
        return history
    }

    private func saveCorrections(_ history: CorrectionHistory) {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: correctionsKey)
        }
    }

    /// Record a user correction: AI estimated `estimatedCal` but user logged `loggedCal`.
    /// Only records meaningful corrections (>10% difference, non-zero values).
    func recordCorrection(itemName: String, estimatedCal: Int, loggedCal: Int) {
        guard estimatedCal > 0, loggedCal > 0 else { return }
        let ratio = Double(loggedCal) / Double(estimatedCal)
        // Only track if the user actually changed it (>10% difference)
        guard abs(ratio - 1.0) > 0.1 else { return }

        lock.lock()
        defer { lock.unlock() }
        var history = loadCorrections()
        let key = itemName.lowercased().trimmingCharacters(in: .whitespaces)

        if var entry = history.corrections[key] {
            entry.ratioSum += ratio
            entry.count += 1
            // Cap at 20 entries to keep the rolling average responsive
            if entry.count > 20 {
                entry.ratioSum = entry.avgRatio * 20
                entry.count = 20
            }
            history.corrections[key] = entry
        } else {
            history.corrections[key] = CorrectionEntry(ratioSum: ratio, count: 1)
        }

        saveCorrections(history)
    }

    /// Get the user's historical correction factor for an item.
    /// Returns a multiplier (e.g., 1.2 means user typically increases by 20%).
    /// Returns nil if no correction data exists.
    func correctionFactor(for itemName: String) -> Double? {
        let history = loadCorrections()
        let key = itemName.lowercased().trimmingCharacters(in: .whitespaces)
        guard let entry = history.corrections[key], entry.count >= 2 else { return nil }
        let ratio = entry.avgRatio
        // Only return if the pattern is consistent (not a one-off)
        // Clamp to 0.5-2.0 to prevent extreme corrections
        return Swift.min(2.0, Swift.max(0.5, ratio))
    }
}
