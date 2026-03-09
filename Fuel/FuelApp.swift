import SwiftUI

@main
struct FuelApp: App {
    @State private var appState = AppState()
    @State private var subscriptionService = SubscriptionService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(subscriptionService)
                .preferredColorScheme(.light)
                .task {
                    let supabase = Constants.supabase
                    appState.authService = AuthService(supabase: supabase)
                    appState.databaseService = DatabaseService(supabase: supabase)
                    let aiService = AIService(supabase: supabase)
                    appState.aiService = aiService

                    // Restore session FIRST — get-api-key requires authentication
                    do {
                        if let profile = try await appState.authService?.restoreSession() {
                            appState.userProfile = profile
                            appState.isAuthenticated = true
                            appState.hasCompletedOnboarding = profile.targetCalories != nil
                            #if DEBUG
                            print("[FuelApp] Session restored, activating RAG...")
                            #endif
                            if appState.hasCompletedOnboarding {
                                async let refreshTask: Void = appState.refreshTodayData()
                                async let ragTask: Void = aiService.activateRAG()
                                _ = await (refreshTask, ragTask)
                            } else {
                                await aiService.activateRAG()
                            }
                        } else {
                            #if DEBUG
                            print("[FuelApp] No saved session — RAG will activate after sign-in")
                            #endif
                        }
                    } catch {
                        #if DEBUG
                        print("[FuelApp] Session restore failed: \(error) — RAG will activate after sign-in")
                        #endif
                    }
                    appState.isLoading = false
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active, appState.isAuthenticated {
                        Task { await appState.refreshTodayData() }
                    }
                }
        }
    }
}
