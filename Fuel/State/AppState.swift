import SwiftUI

@Observable
final class AppState {
    // Auth
    var isAuthenticated = false
    var isLoading = true
    var hasCompletedOnboarding = false

    // User
    var userProfile: UserProfile?

    // Today's Data
    var todaySummary: DailySummary?
    var todayMeals: [Meal] = []
    var todayWaterMl: Int = 0

    // Targets (computed from profile)
    var calorieTarget: Int { userProfile?.targetCalories ?? 2000 }
    var proteinTarget: Int { userProfile?.targetProtein ?? 150 }
    var carbsTarget: Int { userProfile?.targetCarbs ?? 250 }
    var fatTarget: Int { userProfile?.targetFat ?? 65 }

    // Progress (computed)
    var caloriesConsumed: Int { todaySummary?.totalCalories ?? 0 }
    var caloriesRemaining: Int { max(0, calorieTarget - caloriesConsumed) }
    var calorieProgress: Double { Double(caloriesConsumed) / Double(max(1, calorieTarget)) }

    var proteinConsumed: Double { todaySummary?.totalProtein ?? 0 }
    var proteinRemaining: Double { max(0, Double(proteinTarget) - proteinConsumed) }

    var carbsConsumed: Double { todaySummary?.totalCarbs ?? 0 }
    var carbsRemaining: Double { max(0, Double(carbsTarget) - carbsConsumed) }

    var fatConsumed: Double { todaySummary?.totalFat ?? 0 }
    var fatRemaining: Double { max(0, Double(fatTarget) - fatConsumed) }

    // Streak
    var currentStreak: Int { userProfile?.streakCount ?? 0 }

    // Selected date for week strip navigation
    var selectedDate: Date = Date()

    // Services (injected)
    var authService: AuthService?
    var databaseService: DatabaseService?
    var aiService: AIService?

    // UI State
    var selectedTab: Tab = .home
    var showingLogPicker = false
    var showingLogFlow = false
    var selectedLogMode: LogMode = .camera
    var showingOnboarding = false

    // Chat
    var chatMessages: [ChatMessage] = []
    var isSendingMessage = false

    // Error
    var errorMessage: String?
    var showingError = false

    enum Tab: Int, CaseIterable {
        case home = 0
        case progress = 1
        case log = 2
        case chat = 3
        case settings = 4

        var accessibilityName: String {
            switch self {
            case .home: "Home"
            case .progress: "Progress"
            case .log: "Log"
            case .chat: "Chat"
            case .settings: "Settings"
            }
        }
    }

    func refreshTodayData() async {
        guard let profile = userProfile else { return }
        let dateStr = selectedDate.dateString

        do {
            async let mealsTask = databaseService?.getMeals(for: dateStr, userId: profile.id)
            async let summaryTask = databaseService?.getDailySummary(date: dateStr, userId: profile.id)
            async let waterTask = databaseService?.getWaterTotal(date: dateStr, userId: profile.id)

            let meals = (try await mealsTask) ?? []
            let summary = try await summaryTask
            let water = (try await waterTask) ?? 0

            await MainActor.run {
                self.todayMeals = meals
                self.todaySummary = summary
                self.todayWaterMl = water
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Unable to load your data. Please try again."
                self.showingError = true
            }
        }
    }

    func clearAllData() {
        userProfile = nil
        todaySummary = nil
        todayMeals = []
        todayWaterMl = 0
        chatMessages = []
        isSendingMessage = false
        isAuthenticated = false
        selectedTab = .home
        selectedDate = Date()
        errorMessage = nil
        showingError = false
        ClaudeNutritionService.shared.apiKey = ""

        // Clear local caches and rate limit counters
        UserDefaults.standard.removeObject(forKey: "daily_scan_count")
        UserDefaults.standard.removeObject(forKey: "daily_chat_count")
        UserDefaults.standard.removeObject(forKey: "rate_limit_last_reset")
        UserDefaults.standard.removeObject(forKey: "lifetime_scan_count")
        AIConsentManager.revokeConsent()
    }

    func recalculateDailySummary() async {
        // Capture all observable state on MainActor to avoid data races
        let snapshot: (profile: UserProfile, meals: [Meal], water: Int, target: Int, date: String, existing: DailySummary?)? = await MainActor.run {
            guard let profile = userProfile else { return nil }
            return (profile, todayMeals, todayWaterMl, calorieTarget, selectedDate.dateString, todaySummary)
        }
        guard let snapshot else { return }

        var totalCal = 0
        var totalP = 0.0
        var totalC = 0.0
        var totalF = 0.0
        for meal in snapshot.meals {
            totalCal += meal.totalCalories
            totalP += meal.totalProtein
            totalC += meal.totalCarbs
            totalF += meal.totalFat
        }

        var summary = snapshot.existing ?? DailySummary(userId: snapshot.profile.id, date: snapshot.date)
        summary.totalCalories = totalCal
        summary.totalProtein = totalP
        summary.totalCarbs = totalC
        summary.totalFat = totalF
        summary.waterMl = snapshot.water
        summary.isOnTarget = Double(totalCal) <= Double(snapshot.target) * 1.1

        do {
            try await databaseService?.upsertDailySummary(summary)
            await MainActor.run {
                self.todaySummary = summary
            }
        } catch {
            // Silent fail for summary update
        }
    }
}
