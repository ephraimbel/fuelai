import SwiftUI

@main
struct FuelApp: App {
    @State private var appState = AppState()
    @State private var subscriptionService = SubscriptionService()
    @State private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(subscriptionService)
                .environment(themeManager)
                .preferredColorScheme(appState.hasCompletedOnboarding ? themeManager.theme.colorScheme : .light)
                .task {
                    let supabase = Constants.supabase
                    appState.authService = AuthService(supabase: supabase)
                    appState.databaseService = DatabaseService(supabase: supabase)
                    let aiService = AIService(supabase: supabase)
                    appState.aiService = aiService

                    // Restore session or create anonymous one
                    do {
                        if let profile = try await appState.authService?.restoreSession() {
                            appState.userProfile = profile
                            appState.isAuthenticated = true
                            // Trust UserDefaults for onboarding state — also mark complete
                            // if the profile has targets (returning user from a fresh install)
                            if profile.targetCalories != nil {
                                appState.hasCompletedOnboarding = true
                            }
                            // Update local profile cache with fresh DB data
                            if let data = try? JSONEncoder().encode(profile) {
                                UserDefaults.standard.set(data, forKey: "fuel_local_profile")
                            }
                            #if DEBUG
                            print("[FuelApp] Session restored (user: \(profile.id))")
                            #endif
                        } else {
                            // No saved session — create anonymous session so edge functions work
                            await appState.authService?.ensureSession()
                            // If anonymous user completed onboarding, try to load their profile
                            if appState.hasCompletedOnboarding,
                               let session = Constants.supabase.auth.currentSession,
                               let profile = try? await appState.authService?.fetchProfile(userId: session.user.id) {
                                appState.userProfile = profile
                            }
                            #if DEBUG
                            print("[FuelApp] Anonymous session ready — app works without sign-in")
                            #endif
                        }
                    } catch {
                        // Even if restore fails, ensure we have at least an anonymous session
                        await appState.authService?.ensureSession()
                        #if DEBUG
                        print("[FuelApp] Session restore failed: \(error) — using anonymous session")
                        #endif
                    }

                    // Fallback: if onboarding completed but profile is nil (DB write was killed),
                    // restore from local cache so the user doesn't see empty targets
                    if appState.hasCompletedOnboarding, appState.userProfile == nil,
                       let data = UserDefaults.standard.data(forKey: "fuel_local_profile"),
                       let localProfile = try? JSONDecoder().decode(UserProfile.self, from: data) {
                        appState.userProfile = localProfile
                        #if DEBUG
                        print("[FuelApp] Restored profile from local cache")
                        #endif
                        // Retry DB persistence
                        Task { try? await appState.databaseService?.updateProfile(localProfile) }
                    }

                    // Activate RAG and refresh data if onboarding is done
                    if appState.hasCompletedOnboarding {
                        // Load locally-cached meals FIRST so UI is instant
                        appState.loadLocalMeals()

                        async let refreshTask: Void = appState.refreshTodayData()
                        async let ragTask: Void = aiService.activateRAG()
                        _ = await (refreshTask, ragTask)

                        // Retry any meals that failed to sync last session
                        await appState.syncPendingMeals()
                    } else {
                        await aiService.activateRAG()
                    }
                    appState.isLoading = false
                    // Schedule notifications with current data
                    updateNotificationSnapshot()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active, appState.hasCompletedOnboarding {
                        Task {
                            await appState.syncPendingMeals()
                            await appState.refreshTodayData()
                        }
                        updateNotificationSnapshot()
                    }
                }
        }
    }

    private func updateNotificationSnapshot() {
        guard let profile = appState.userProfile else { return }
        NotificationService.shared.updateSnapshot(
            name: profile.displayName,
            calorieTarget: appState.calorieTarget,
            proteinTarget: appState.proteinTarget,
            carbsTarget: appState.carbsTarget,
            fatTarget: appState.fatTarget,
            caloriesConsumed: appState.caloriesConsumed,
            proteinConsumed: appState.proteinConsumed,
            carbsConsumed: appState.carbsConsumed,
            fatConsumed: appState.fatConsumed,
            streak: appState.currentStreak,
            longestStreak: profile.longestStreak,
            goalType: profile.goalType?.rawValue,
            mealsLogged: appState.todayMeals.count,
            waterMl: appState.todayWaterMl,
            waterGoalMl: appState.waterGoalMl
        )
        NotificationService.shared.scheduleAll()
    }
}
