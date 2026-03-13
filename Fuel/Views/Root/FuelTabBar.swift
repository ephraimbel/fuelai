import SwiftUI

struct FuelTabBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            tabButton(tab: .home, icon: "house", activeIcon: "house.fill", label: "Home")
            tabButton(tab: .progress, icon: "chart.line.uptrend.xyaxis", activeIcon: "chart.line.uptrend.xyaxis", label: "Progress")

            // Center FAB
            logButton
                .frame(maxWidth: .infinity)

            tabButton(tab: .chat, icon: "bubble.left", activeIcon: "bubble.left.fill", label: "Coach")
            tabButton(tab: .settings, icon: "person.crop.circle", activeIcon: "person.crop.circle.fill", label: "Profile")
        }
        .padding(.horizontal, FuelSpacing.sm)
        .padding(.top, 4)
        .background(
            FuelColors.pageBackground
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Log FAB

    private var logButton: some View {
        Button {
            FuelHaptics.shared.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                appState.showingLogPicker.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(FuelColors.buttonFill)
                    .frame(width: 52, height: 52)
                    .shadow(color: FuelColors.buttonFill.opacity(0.25), radius: 8, y: 3)

                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(appState.showingLogPicker ? 45 : 0))
            }
            .offset(y: -10)
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
            VStack(spacing: 1) {
                Image(systemName: isSelected ? activeIcon : icon)
                    .font(.system(size: 16, weight: isSelected ? .medium : .regular))
                    .frame(width: 22, height: 20)

                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .medium : .regular))
            }
            .foregroundStyle(isSelected ? FuelColors.ink : FuelColors.fog)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 1)
            .contentShape(Rectangle())
            .animation(FuelAnimation.snappy, value: isSelected)
        }
        .accessibilityLabel(tab.accessibilityName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
