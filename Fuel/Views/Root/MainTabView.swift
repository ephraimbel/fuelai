import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService

    var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .bottom) {
            // All tabs stay alive — only visibility changes
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
            // Log picker on top of everything
            if appState.showingLogPicker {
                LogPickerOverlay()
            }
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

// MARK: - Inline Log Picker Overlay

private struct LogPickerOverlay: View {
    @Environment(AppState.self) private var appState
    @State private var appeared = false

    private let options: [(icon: String, title: String, subtitle: String, accent: Color, mode: LogMode)] = [
        ("camera.fill", "Scan Food", "Take a photo of your meal", FuelColors.flame, .camera),
        ("magnifyingglass", "Search Food", "Type what you ate", FuelColors.ink, .search),
        ("barcode.viewfinder", "Scan Barcode", "Scan a product label", FuelColors.ink, .barcode),
        ("bolt.fill", "Quick Add", "Enter calories & macros", FuelColors.flame, .quickAdd),
        ("clock.arrow.circlepath", "Recent Meals", "Re-log a past meal", FuelColors.ink, .recentMeals),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background
            Color.black
                .opacity(appeared ? 0.25 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .allowsHitTesting(appeared)

            // Option cards
            VStack(spacing: FuelSpacing.sm) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button {
                        selectMode(option.mode)
                    } label: {
                        HStack(spacing: FuelSpacing.lg) {
                            ZStack {
                                RoundedRectangle(cornerRadius: FuelRadius.sm)
                                    .fill(option.accent.opacity(0.1))
                                    .frame(width: 52, height: 52)

                                Image(systemName: option.icon)
                                    .font(FuelType.stat)
                                    .foregroundStyle(option.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(FuelType.cardTitle)
                                    .foregroundStyle(FuelColors.ink)

                                Text(option.subtitle)
                                    .font(FuelType.caption)
                                    .foregroundStyle(FuelColors.stone)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(FuelType.iconSm)
                                .foregroundStyle(FuelColors.fog)
                        }
                        .padding(FuelSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.card)
                                .fill(FuelColors.white)
                        )
                    }
                    .pressable()
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(FuelAnimation.snappy.delay(Double(index) * 0.05), value: appeared)
                }
            }
            .padding(.horizontal, FuelSpacing.lg)
            .padding(.bottom, 100)
            .scaleEffect(appeared ? 1 : 0.92, anchor: .bottom)
        }
        .animation(FuelAnimation.snappy, value: appeared)
        .onAppear { appeared = true }
    }

    private func selectMode(_ mode: LogMode) {
        FuelHaptics.shared.tap()
        appState.selectedLogMode = mode
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            appState.showingLogFlow = true
        }
    }

    private func dismiss() {
        appeared = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            appState.showingLogPicker = false
        }
    }
}
