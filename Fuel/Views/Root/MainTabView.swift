import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService

    var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .bottom) {
            ZStack {
                NavigationStack {
                    HomeView()
                }
                .opacity(appState.selectedTab == .home ? 1 : 0)
                .zIndex(appState.selectedTab == .home ? 1 : 0)

                NavigationStack {
                    ProgressTabView()
                }
                .opacity(appState.selectedTab == .progress ? 1 : 0)
                .zIndex(appState.selectedTab == .progress ? 1 : 0)

                NavigationStack {
                    ChatView()
                }
                .opacity(appState.selectedTab == .chat ? 1 : 0)
                .zIndex(appState.selectedTab == .chat ? 1 : 0)

                NavigationStack {
                    SettingsView()
                }
                .opacity(appState.selectedTab == .settings ? 1 : 0)
                .zIndex(appState.selectedTab == .settings ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(FuelAnimation.smooth, value: appState.selectedTab)

            FuelTabBar()
                .opacity(appState.selectedTab == .chat ? 0 : 1)
                .offset(y: appState.selectedTab == .chat ? 80 : 0)
                .animation(FuelAnimation.smooth, value: appState.selectedTab == .chat)
        }
        .overlay {
            LogPickerOverlay()
        }
        .fullScreenCover(isPresented: $state.showingLogFlow) {
            LogFlowView()
                .environment(appState)
                .environment(subscriptionService)
        }
        .alert("Error", isPresented: $state.showingError) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "Something went wrong")
        }
    }
}

// MARK: - Log Picker Overlay

private struct LogPickerOverlay: View {
    @Environment(AppState.self) private var appState
    @State private var revealed = false

    private var isVisible: Bool { appState.showingLogPicker }

    var body: some View {
        if isVisible || revealed {
            ZStack(alignment: .bottom) {
                // Scrim
                Color.black
                    .opacity(revealed ? 0.2 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                // Card
                VStack(spacing: 0) {
                    // Hero — Scan Food
                    scanHero
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .padding(.bottom, 12)

                    Rectangle()
                        .fill(FuelColors.mist.opacity(0.5))
                        .frame(height: 0.5)

                    // Search & Quick Add
                    HStack(spacing: 0) {
                        optionCell(
                            icon: "magnifyingglass",
                            title: "Search",
                            subtitle: "Describe what you ate",
                            mode: .search
                        )

                        Rectangle()
                            .fill(FuelColors.mist.opacity(0.5))
                            .frame(width: 0.5)
                            .padding(.vertical, 14)

                        optionCell(
                            icon: "bolt.fill",
                            title: "Quick Add",
                            subtitle: "Enter calories",
                            mode: .quickAdd
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    Rectangle()
                        .fill(FuelColors.mist.opacity(0.5))
                        .frame(height: 0.5)

                    // Saved & Recent
                    HStack(spacing: 0) {
                        optionCell(
                            icon: "bookmark.fill",
                            title: "Saved Meals",
                            subtitle: "Reuse a favorite",
                            mode: .savedMeals
                        )

                        Rectangle()
                            .fill(FuelColors.mist.opacity(0.5))
                            .frame(width: 0.5)
                            .padding(.vertical, 14)

                        optionCell(
                            icon: "clock.arrow.circlepath",
                            title: "Recent",
                            subtitle: "Log again quickly",
                            mode: .recentMeals
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(FuelColors.white)
                        .shadow(color: Color.black.opacity(revealed ? 0.1 : 0), radius: 24, y: 8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
                .padding(.bottom, 88)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 60)
                .scaleEffect(revealed ? 1 : 0.01, anchor: UnitPoint(x: 0.5, y: 1.0))
            }
            .onAppear {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    revealed = true
                }
            }
            .onChange(of: isVisible) { _, showing in
                if !showing {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
                        revealed = false
                    }
                }
            }
        }
    }

    // MARK: - Hero Scan

    private var scanHero: some View {
        Button { selectMode(.camera) } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !isVisible)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = t.remainder(dividingBy: 4.0) / 4.0
                let shimmerX = phase * 1.4 - 0.2

                HStack(spacing: 16) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(FuelColors.flame)
                        .frame(width: 46, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(FuelColors.flame.opacity(0.08))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scan Food")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(FuelColors.ink)
                        Text("Photo or barcode")
                            .font(.system(size: 13))
                            .foregroundStyle(FuelColors.stone)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FuelColors.flame)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(FuelColors.flame.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    FuelColors.flame.opacity(0.2),
                                    FuelColors.flame.opacity(0.35),
                                    Color(hex: "#FF8040").opacity(0.25),
                                    FuelColors.flame.opacity(0.2),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: max(0, shimmerX - 0.1)),
                                    .init(color: .white.opacity(0.25), location: shimmerX),
                                    .init(color: .clear, location: min(1, shimmerX + 0.1)),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
            }
        }
    }

    // MARK: - Option Cell

    private func optionCell(icon: String, title: String, subtitle: String, mode: LogMode) -> some View {
        Button { selectMode(mode) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FuelColors.ink)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FuelColors.ink)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(FuelColors.stone)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Actions

    private func selectMode(_ mode: LogMode) {
        FuelHaptics.shared.tap()
        appState.selectedLogMode = mode
        appState.showingLogPicker = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            appState.showingLogFlow = true
        }
    }

    private func dismiss() {
        appState.showingLogPicker = false
    }
}
