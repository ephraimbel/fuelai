import SwiftUI

@MainActor @Observable
final class AppState {
    // Auth
    var isAuthenticated = false
    var isLoading = true
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "has_completed_onboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "has_completed_onboarding") }
    }

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

    // Micros (consumed)
    var fiberConsumed: Double { todaySummary?.totalFiber ?? 0 }
    var sugarConsumed: Double { todaySummary?.totalSugar ?? 0 }
    var sodiumConsumed: Double { todaySummary?.totalSodium ?? 0 }

    // Micro targets (general daily recommendations)
    var fiberTarget: Double { 28 }
    var sugarTarget: Double { 50 }
    var sodiumTarget: Double { 2300 }

    // Water
    var waterGoalMl: Int { userProfile?.waterGoalMl ?? Constants.defaultWaterGoalMl }
    var waterProgress: Double { Double(todayWaterMl) / Double(max(1, waterGoalMl)) }
    var waterRemaining: Int { max(0, waterGoalMl - todayWaterMl) }

    func logWater(amountMl: Int) async {
        guard let profile = userProfile else { return }
        // Optimistic update — animate the UI immediately
        await MainActor.run {
            todayWaterMl += amountMl
        }
        // Persist to database (fire-and-forget)
        try? await databaseService?.logWater(userId: profile.id, amountMl: amountMl)
        // Update summary in DB so progress page reflects water changes
        await recalculateDailySummary()
    }

    // Streak
    var currentStreak: Int { userProfile?.streakCount ?? 0 }

    // Selected date for week strip navigation
    var selectedDate: Date = Date()

    // In-memory cache for date data — prevents ring collapse on date switch
    private var dateCache: [String: DateCacheEntry] = [:]
    private struct DateCacheEntry {
        let summary: DailySummary?
        let meals: [Meal]
        let water: Int
        let cachedAt: Date
    }

    // Tracks the in-flight refresh so we can cancel stale fetches
    private var refreshTask: Task<Void, Never>?
    // Tracks which date's data is currently displayed (for cache-on-switch-away)
    private var lastLoadedDate: String?

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

    // Data version — increments when meals/water change, so other tabs can react
    var dataVersion: Int = 0

    // Debug seed data — populated in-memory for screenshot charts
    #if DEBUG
    var seedSummaries: [DailySummary] = []
    var seedWeightHistory: [WeightLog] = []
    #endif

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
            case .settings: "Profile"
            }
        }
    }

    func refreshTodayData() async {
        // Cancel any in-flight refresh to prevent stale data from overwriting
        refreshTask?.cancel()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let dateStr = self.selectedDate.dateString

            // ── Step 1: Snapshot current data into cache BEFORE switching ──
            // This ensures we never lose data when navigating away
            let prevDateStr = self.lastLoadedDate
            if let prevDate = prevDateStr, prevDate != dateStr,
               self.dateCache[prevDate] == nil || self.todaySummary != nil {
                // Only cache if we have real data (summary exists or meals are non-empty)
                if self.todaySummary != nil || !self.todayMeals.isEmpty {
                    self.dateCache[prevDate] = DateCacheEntry(
                        summary: self.todaySummary,
                        meals: self.todayMeals,
                        water: self.todayWaterMl,
                        cachedAt: Date()
                    )
                }
            }
            self.lastLoadedDate = dateStr

            // ── Step 2: Serve from cache instantly ──
            if let cached = self.dateCache[dateStr] {
                self.todaySummary = cached.summary
                self.todayMeals = cached.meals
                self.todayWaterMl = cached.water
            } else {
                // No cache for this date — show empty state immediately (don't keep stale data from another date)
                self.todaySummary = nil
                self.todayMeals = []
                self.todayWaterMl = 0
            }

            // ── Step 3: Fetch from DB in background ──
            guard let profile = self.userProfile else { return }

            do {
                async let mealsTask = self.databaseService?.getMeals(for: dateStr, userId: profile.id)
                async let summaryTask = self.databaseService?.getDailySummary(date: dateStr, userId: profile.id)
                async let waterTask = self.databaseService?.getWaterTotal(date: dateStr, userId: profile.id)

                let meals = (try await mealsTask) ?? []
                let summary = try await summaryTask
                let water = (try await waterTask) ?? 0

                // Only apply if this is still the selected date (not stale)
                guard !Task.isCancelled, self.selectedDate.dateString == dateStr else { return }

                // If DB returned empty but we had cached data with real values, keep the cache
                // (protects against DB read failures or RLS issues for anonymous users)
                let dbHasData = !meals.isEmpty || summary != nil || water > 0
                let cacheHadData = self.dateCache[dateStr] != nil && (self.todaySummary != nil || !self.todayMeals.isEmpty)

                if dbHasData || !cacheHadData {
                    self.todayMeals = meals
                    self.todaySummary = summary
                    self.todayWaterMl = water

                    // Update cache
                    self.dateCache[dateStr] = DateCacheEntry(
                        summary: summary, meals: meals, water: water, cachedAt: Date()
                    )
                }

                // Evict old entries (keep last 14 days)
                if self.dateCache.count > 14 {
                    let sorted = self.dateCache.sorted { $0.value.cachedAt < $1.value.cachedAt }
                    for entry in sorted.prefix(self.dateCache.count - 14) {
                        self.dateCache.removeValue(forKey: entry.key)
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                // On error, keep whatever is showing (cache or empty) — don't flash
            }
        }
        refreshTask = task
        await task.value
    }

    /// Invalidate cache for a specific date (call after logging a meal)
    func invalidateDateCache(for dateStr: String? = nil) {
        let key = dateStr ?? selectedDate.dateString
        dateCache.removeValue(forKey: key)
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
        dateCache = [:]
        lastLoadedDate = nil
        ClaudeNutritionService.shared.apiKey = ""

        // Clear local caches and rate limit counters
        UserDefaults.standard.removeObject(forKey: "daily_scan_count")
        UserDefaults.standard.removeObject(forKey: "daily_chat_count")
        UserDefaults.standard.removeObject(forKey: "rate_limit_last_reset")
        UserDefaults.standard.removeObject(forKey: "lifetime_scan_count")
        AIConsentManager.revokeConsent()
        NotificationService.shared.clearAllData()
    }

    func recalculateDailySummary(forceFromMeals: Bool = true) async {
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
        var totalFiber = 0.0
        var totalSugar = 0.0
        var totalSodium = 0.0
        for meal in snapshot.meals {
            totalCal += meal.totalCalories
            totalP += meal.totalProtein
            totalC += meal.totalCarbs
            totalF += meal.totalFat
            totalFiber += meal.totalFiber
            totalSugar += meal.totalSugar
            totalSodium += meal.totalSodium
        }

        var summary = snapshot.existing ?? DailySummary(userId: snapshot.profile.id, date: snapshot.date)

        // Always trust the current meal list as the source of truth
        summary.totalCalories = totalCal
        summary.totalProtein = totalP
        summary.totalCarbs = totalC
        summary.totalFat = totalF
        summary.totalFiber = totalFiber
        summary.totalSugar = totalSugar
        summary.totalSodium = totalSodium
        summary.waterMl = snapshot.water
        summary.isOnTarget = Double(summary.totalCalories) <= Double(snapshot.target) * 1.1

        // Update local state immediately so progress page can merge it
        await MainActor.run {
            self.todaySummary = summary
            // Update cache too
            self.dateCache[snapshot.date] = DateCacheEntry(
                summary: summary, meals: snapshot.meals, water: snapshot.water, cachedAt: Date()
            )
            // Signal other tabs (progress) to refresh
            self.dataVersion += 1
        }

        // Persist to DB in background
        do {
            try await databaseService?.upsertDailySummary(summary)

            // Recalculate streak after summary is saved (streak checks daily_summaries)
            if let newStreak = try? await databaseService?.updateStreak(userId: snapshot.profile.id) {
                await MainActor.run {
                    if var profile = self.userProfile {
                        profile.streakCount = newStreak
                        profile.longestStreak = max(profile.longestStreak, newStreak)
                        self.userProfile = profile
                    }
                }
            }
        } catch {
            #if DEBUG
            print("[Fuel] Failed to upsert daily summary: \(error)")
            #endif
        }
    }

    // MARK: - Debug Screenshot Seeder

    #if DEBUG
    func seedScreenshotData() async {
        // Use profile ID (which should match auth session), fallback to session ID
        let userId = userProfile?.id ?? Constants.supabase.auth.currentSession?.user.id ?? UUID()
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let sessionUserId = Constants.supabase.auth.currentSession?.user.id
        print("[Seed] Starting with userId: \(userId), session: \(sessionUserId?.uuidString ?? "none"), profile: \(userProfile?.id.uuidString ?? "none")")

        // Seed profile if missing
        if userProfile == nil {
            userProfile = UserProfile(
                id: userId, displayName: "Alex", isPremium: true,
                streakCount: 12, longestStreak: 18, unitSystem: .imperial,
                createdAt: calendar.date(byAdding: .day, value: -90, to: today)!, updatedAt: today
            )
            userProfile?.age = 28
            userProfile?.sex = .male
            userProfile?.heightCm = 178
            userProfile?.weightKg = 79
            userProfile?.goalType = .lose
            userProfile?.targetCalories = 2100
            userProfile?.targetProtein = 160
            userProfile?.targetCarbs = 210
            userProfile?.targetFat = 70
            userProfile?.waterGoalMl = 2500
            userProfile?.dietStyle = .standard
            userProfile?.activityLevel = .moderate
        } else {
            userProfile?.streakCount = 12
            userProfile?.longestStreak = 18
        }

        // -- Today's meals --
        let todayStr = formatter.string(from: today)

        let breakfastItems = [
            MealItem(id: UUID(), name: "Greek Yogurt Parfait", calories: 320, protein: 22, carbs: 38, fat: 10, fiber: 4, sugar: 18, servingSize: "1 bowl", quantity: 1, confidence: 0.95),
            MealItem(id: UUID(), name: "Black Coffee", calories: 5, protein: 0.3, carbs: 0, fat: 0, servingSize: "12 oz", quantity: 1, confidence: 0.98),
        ]
        let breakfast = Meal(
            id: UUID(), userId: userId, items: breakfastItems,
            totalCalories: 325, totalProtein: 22.3, totalCarbs: 38, totalFat: 10,
            totalFiber: 4, totalSugar: 18, totalSodium: 85,
            imageUrl: "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&q=80",
            displayName: "Greek Yogurt Parfait", loggedDate: todayStr,
            loggedAt: calendar.date(bySettingHour: 8, minute: 15, second: 0, of: today)!,
            createdAt: today
        )

        let lunchItems = [
            MealItem(id: UUID(), name: "Grilled Chicken Bowl", calories: 520, protein: 42, carbs: 48, fat: 16, fiber: 6, sugar: 4, servingSize: "1 bowl", quantity: 1, confidence: 0.92),
        ]
        let lunch = Meal(
            id: UUID(), userId: userId, items: lunchItems,
            totalCalories: 520, totalProtein: 42, totalCarbs: 48, totalFat: 16,
            totalFiber: 6, totalSugar: 4, totalSodium: 680,
            imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&q=80",
            displayName: "Grilled Chicken Bowl", loggedDate: todayStr,
            loggedAt: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: today)!,
            createdAt: today
        )

        let snackItems = [
            MealItem(id: UUID(), name: "Apple with Almond Butter", calories: 270, protein: 7, carbs: 30, fat: 16, fiber: 5, sugar: 20, servingSize: "1 apple + 2 tbsp", quantity: 1, confidence: 0.94),
        ]
        let snack = Meal(
            id: UUID(), userId: userId, items: snackItems,
            totalCalories: 270, totalProtein: 7, totalCarbs: 30, totalFat: 16,
            totalFiber: 5, totalSugar: 20, totalSodium: 45,
            imageUrl: "https://images.unsplash.com/photo-1568702846914-96b305d2uj38?w=400&q=80",
            displayName: "Apple & Almond Butter", loggedDate: todayStr,
            loggedAt: calendar.date(bySettingHour: 15, minute: 20, second: 0, of: today)!,
            createdAt: today
        )

        todayMeals = [breakfast, lunch, snack]
        todayWaterMl = 1750

        let todayCal = 1115
        todaySummary = DailySummary(
            userId: userId, date: todayStr,
            totalCalories: todayCal, totalProtein: 71.3, totalCarbs: 116, totalFat: 42,
            totalFiber: 15, totalSugar: 42, totalSodium: 810,
            waterMl: 1750, isOnTarget: true
        )

        // -- Build 90 days of historical data in memory --
        var allSummaries: [DailySummary] = []
        var allWeights: [WeightLog] = []

        let skipDays: Set<Int> = [14, 27, 43, 58, 71]
        for daysAgo in 1...90 {
            guard !skipDays.contains(daysAgo),
                  let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let dateStr = formatter.string(from: date)

            let baseCal = 2100.0
            let variance = Double.random(in: -300...350)
            let weekendBoost = calendar.isDateInWeekend(date) ? Double.random(in: 50...200) : 0
            let cal = Int(baseCal + variance + weekendBoost)

            let p = Double(cal) * Double.random(in: 0.28...0.35) / 4.0
            let f = Double(cal) * Double.random(in: 0.22...0.30) / 9.0
            let c = (Double(cal) - p * 4 - f * 9) / 4.0
            let water = Int.random(in: 1500...2800)

            allSummaries.append(DailySummary(
                userId: userId, date: dateStr,
                totalCalories: cal, totalProtein: p, totalCarbs: c, totalFat: f,
                totalFiber: Double.random(in: 12...28), totalSugar: Double.random(in: 25...55),
                totalSodium: Double.random(in: 600...1600),
                waterMl: water, isOnTarget: cal <= 2310
            ))
        }

        // Add today's summary
        if let s = todaySummary {
            allSummaries.append(s)
        }
        allSummaries.sort { $0.date < $1.date }

        // Weight history — gradual loss over 90 days (83kg → 79kg)
        for daysAgo in stride(from: 90, through: 0, by: -3) {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let progress = Double(90 - daysAgo) / 90.0
            let baseWeight = 83.0 - (progress * 4.0)
            let noise = Double.random(in: -0.3...0.3)
            allWeights.append(WeightLog(id: UUID(), userId: userId, weightKg: baseWeight + noise, loggedAt: date))
        }

        // Store in memory so progress page can use immediately
        seedSummaries = allSummaries
        seedWeightHistory = allWeights

        // Also persist to DB in background (non-blocking)
        let db = databaseService
        Task {
            guard let db else { return }
            for summary in allSummaries {
                try? await db.upsertDailySummary(summary)
            }
            for meal in todayMeals {
                try? await db.logMeal(meal)
            }
            for weight in allWeights {
                try? await db.logWeight(userId: userId, weightKg: weight.weightKg, date: weight.loggedAt)
            }
            if let profile = userProfile {
                try? await db.updateProfile(profile)
            }
        }

        dataVersion += 1
        hasCompletedOnboarding = true
    }
    #endif
}
