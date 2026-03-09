import SwiftUI

struct FuelTabBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            tabButton(tab: .home, icon: "house", activeIcon: "house.fill", label: "Home")
            tabButton(tab: .progress, icon: "chart.line.uptrend.xyaxis", activeIcon: "chart.line.uptrend.xyaxis", label: "Progress")

            // Center FAB
            logButton
                .padding(.horizontal, 4)

            tabButton(tab: .chat, icon: "bubble.left", activeIcon: "bubble.left.fill", label: "Coach")
            tabButton(tab: .settings, icon: "gearshape", activeIcon: "gearshape.fill", label: "Settings")
        }
        .padding(.horizontal, FuelSpacing.sm)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            FuelColors.white
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Log FAB

    private var logButton: some View {
        Button {
            if appState.showingLogPicker {
                appState.showingLogPicker = false
            } else {
                appState.showingLogPicker = true
            }
            FuelHaptics.shared.tap()
        } label: {
            ZStack {
                Circle()
                    .fill(FuelColors.flame)
                    .frame(width: 50, height: 50)
                    .shadow(color: FuelColors.flame.opacity(0.25), radius: 8, y: 2)

                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(appState.showingLogPicker ? 45 : 0))
            }
        }
        .accessibilityLabel(appState.showingLogPicker ? "Close log menu" : "Log meal")
        .animation(FuelAnimation.snappy, value: appState.showingLogPicker)
    }

    // MARK: - Tab Button

    private func tabButton(tab: AppState.Tab, icon: String, activeIcon: String, label: String) -> some View {
        let isSelected = appState.selectedTab == tab

        return Button {
            guard appState.selectedTab != tab else { return }
            withAnimation(FuelAnimation.snappy) {
                appState.selectedTab = tab
            }
            FuelHaptics.shared.selection()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? activeIcon : icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .frame(width: 24, height: 24)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? FuelColors.ink : FuelColors.stone)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .animation(FuelAnimation.snappy, value: isSelected)
        }
        .accessibilityLabel(tab.accessibilityName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
