import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            FuelColors.white.ignoresSafeArea()

            if appState.isLoading {
                LoadingView()
                    .transition(.opacity)
            } else if !appState.hasCompletedOnboarding {
                OnboardingContainerView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(FuelAnimation.spring, value: appState.isLoading)
        .animation(FuelAnimation.spring, value: appState.hasCompletedOnboarding)
    }
}

struct LoadingView: View {
    @State private var appeared = false
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(FuelType.title)
                .foregroundStyle(FuelColors.flameGradient)
                .scaleEffect(pulse ? 1.08 : 0.96)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

            Text("fuel")
                .font(FuelType.hero)
                .foregroundStyle(FuelColors.ink)
                .baselineOffset(-1)
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.92)
        .animation(.easeOut(duration: 0.6), value: appeared)
        .onAppear {
            appeared = true
            pulse = true
        }
    }
}
