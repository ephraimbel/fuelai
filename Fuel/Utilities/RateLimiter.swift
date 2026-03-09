import Foundation

struct RateLimiter {
    private static let scanCountKey = "daily_scan_count"
    private static let chatCountKey = "daily_chat_count"
    private static let lastResetKey = "rate_limit_last_reset"
    private static let lock = NSLock()

    static func canScan(isPremium: Bool) -> Bool {
        if isPremium { return true }
        lock.lock()
        defer { lock.unlock() }
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: scanCountKey) < Constants.freeScansPerDay
    }

    static func canChat(isPremium: Bool) -> Bool {
        if isPremium { return true }
        lock.lock()
        defer { lock.unlock() }
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: chatCountKey) < Constants.freeChatMessagesPerDay
    }

    static func recordScan() {
        lock.lock()
        defer { lock.unlock() }
        resetIfNewDay()
        let current = UserDefaults.standard.integer(forKey: scanCountKey)
        UserDefaults.standard.set(current + 1, forKey: scanCountKey)
    }

    static func recordChat() {
        lock.lock()
        defer { lock.unlock() }
        resetIfNewDay()
        let current = UserDefaults.standard.integer(forKey: chatCountKey)
        UserDefaults.standard.set(current + 1, forKey: chatCountKey)
    }

    static var remainingScans: Int {
        lock.lock()
        defer { lock.unlock() }
        resetIfNewDay()
        return max(0, Constants.freeScansPerDay - UserDefaults.standard.integer(forKey: scanCountKey))
    }

    static var remainingChats: Int {
        lock.lock()
        defer { lock.unlock() }
        resetIfNewDay()
        return max(0, Constants.freeChatMessagesPerDay - UserDefaults.standard.integer(forKey: chatCountKey))
    }

    // Must be called while holding lock
    private static func resetIfNewDay() {
        let today = Date().dateString
        let lastReset = UserDefaults.standard.string(forKey: lastResetKey) ?? ""
        if lastReset != today {
            UserDefaults.standard.set(0, forKey: scanCountKey)
            UserDefaults.standard.set(0, forKey: chatCountKey)
            UserDefaults.standard.set(today, forKey: lastResetKey)
        }
    }
}
