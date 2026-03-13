import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(ThemeManager.self) private var themeManager
    @State private var showingEditGoals = false
    @State private var showingEditProfile = false
    @State private var showingSubscription = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingDeleteConfirm = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingHealthDisclaimer = false
    @State private var showingNotifications = false
    @State private var seedingData = false

    var body: some View {
        ScrollView {
            VStack(spacing: FuelSpacing.lg) {
                // Profile header
                if let profile = appState.userProfile {
                    HStack(spacing: FuelSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(FuelColors.cloud)
                                .frame(width: 44, height: 44)

                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(FuelColors.stone)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName ?? "Fuel User")
                                .font(FuelType.cardTitle)
                                .foregroundStyle(FuelColors.ink)

                            if let email = profile.email, !email.isEmpty {
                                Text(email)
                                    .font(FuelType.caption)
                                    .foregroundStyle(FuelColors.stone)
                            }
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            if subscriptionService.isPremium {
                                Image("FlameIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                            }
                            Text(subscriptionService.isPremium ? "Premium" : "Free")
                                .font(FuelType.micro)
                        }
                        .foregroundStyle(subscriptionService.isPremium ? FuelColors.onDark : FuelColors.ink)
                        .padding(.horizontal, FuelSpacing.md)
                        .padding(.vertical, FuelSpacing.xs)
                        .background(subscriptionService.isPremium ? FuelColors.flame : FuelColors.cloud)
                        .clipShape(Capsule())
                    }
                    .padding(.vertical, FuelSpacing.sm)
                }

                // My Plan
                ProfileSection(title: "My Plan") {
                    ProfileRow(icon: "FlameIcon", title: "Daily Target", detail: goalDetail) {
                        showingEditGoals = true
                    }
                    ProfileRow(icon: "figure.stand", title: "Body & Activity", detail: bodyDetail) {
                        showingEditProfile = true
                    }
                    ProfileRow(
                        icon: "ruler",
                        title: "Units",
                        detail: appState.userProfile?.unitSystem == .metric ? "Metric" : "Imperial"
                    ) {
                        setUnit(appState.userProfile?.unitSystem == .imperial ? .metric : .imperial)
                    }
                }

                // Notifications
                ProfileSection(title: "Notifications") {
                    ProfileRow(
                        icon: "bell.fill",
                        title: "Coach Notifications",
                        detail: NotificationService.shared.isEnabled ? "On" : "Off"
                    ) {
                        showingNotifications = true
                    }
                }

                // Subscription
                ProfileSection(title: "Subscription") {
                    ProfileRow(
                        icon: "star",
                        title: subscriptionService.isPremium ? "Manage Subscription" : "Upgrade to fuel+",
                        detail: nil
                    ) {
                        showingSubscription = true
                    }
                }

                // About
                ProfileSection(title: "About") {
                    ProfileRow(icon: "heart.text.square", title: "Health & AI Info", detail: nil) {
                        showingHealthDisclaimer = true
                    }
                    ProfileRow(icon: "doc.text", title: "Terms of Service", detail: nil) {
                        UIApplication.shared.open(Constants.termsURL)
                    }
                    ProfileRow(icon: "lock.shield", title: "Privacy Policy", detail: nil) {
                        UIApplication.shared.open(Constants.privacyURL)
                    }
                    ProfileRow(icon: "info.circle", title: "Version", detail: appVersion, showChevron: false) {}
                }

                // Account
                ProfileSection(title: "Account") {
                    ProfileRow(icon: "trash", title: "Delete Account", detail: nil) {
                        showingDeleteAlert = true
                    }
                }

                #if DEBUG
                // Debug section
                ProfileSection(title: "Debug") {
                    ProfileRow(icon: "photo.on.rectangle", title: seedingData ? "Seeding..." : "Seed Screenshot Data", detail: nil) {
                        guard !seedingData else { return }
                        seedingData = true
                        Task {
                            await appState.seedScreenshotData()
                            seedingData = false
                        }
                    }
                }
                #endif

                // Sign out
                Button {
                    showingSignOutAlert = true
                } label: {
                    Text("Sign Out")
                        .font(FuelType.label)
                        .foregroundStyle(FuelColors.over)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.lg)
                        .background(FuelColors.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.md)
        }
        .background(FuelColors.pageBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FuelColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                themeToggle
            }
        }
        .sheet(isPresented: $showingEditGoals) {
            NavigationStack {
                EditGoalsView()
                    .environment(appState)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingEditProfile) {
            NavigationStack {
                EditProfileView()
                    .environment(appState)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSubscription) {
            if subscriptionService.isPremium {
                NavigationStack {
                    SubscriptionView()
                        .environment(subscriptionService)
                }
                .presentationDragIndicator(.visible)
            } else {
                UpgradePaywallView(reason: .scanLimit)
                    .environment(subscriptionService)
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    do {
                        try await appState.authService?.signOut()
                        appState.clearAllData()
                        appState.hasCompletedOnboarding = false
                    } catch {
                        errorMessage = "Could not sign out. Please try again."
                        showingError = true
                    }
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                showingDeleteConfirm = true
            }
        } message: {
            Text("This will permanently delete your account and all data. This cannot be undone.")
        }
        .alert("Are you absolutely sure?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete My Account", role: .destructive) {
                Task {
                    guard let userId = appState.userProfile?.id else { return }
                    do {
                        try await appState.databaseService?.deleteAccount(userId: userId)
                        try await appState.authService?.signOut()
                        appState.clearAllData()
                        appState.hasCompletedOnboarding = false
                    } catch {
                        errorMessage = "Could not delete account. Please try again."
                        showingError = true
                    }
                }
            }
        } message: {
            Text("All your meals, progress, and settings will be permanently deleted.")
        }
        .sheet(isPresented: $showingNotifications) {
            NavigationStack {
                NotificationSettingsView()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingHealthDisclaimer) {
            NavigationStack {
                HealthDisclaimerView()
            }
            .presentationDragIndicator(.visible)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Theme Toggle

    private var themeToggle: some View {
        HStack(spacing: 0) {
            ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                let selected = themeManager.theme == theme
                Button {
                    FuelHaptics.shared.selection()
                    themeManager.setTheme(theme)
                } label: {
                    Image(systemName: theme.icon)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .white : FuelColors.stone)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(selected ? FuelColors.ink : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(FuelColors.cloud))
    }

    // MARK: - Helpers

    private var goalDetail: String? {
        guard let profile = appState.userProfile,
              let cal = profile.targetCalories else { return nil }
        let p = profile.targetProtein ?? 0
        let c = profile.targetCarbs ?? 0
        let f = profile.targetFat ?? 0
        return "\(cal) cal · \(p)p · \(c)c · \(f)f"
    }

    private var bodyDetail: String? {
        guard let profile = appState.userProfile else { return nil }
        if profile.unitSystem == .metric {
            let w = profile.weightKg.map { "\(Int($0)) kg" } ?? ""
            let h = profile.heightCm.map { "\(Int($0)) cm" } ?? ""
            return [w, h].filter { !$0.isEmpty }.joined(separator: " · ")
        } else {
            let w = profile.weightKg.map { "\(Int($0 * 2.205)) lbs" } ?? ""
            let h = profile.heightCm.map {
                let totalInches = Int($0 / 2.54)
                return "\(totalInches / 12)'\(totalInches % 12)\""
            } ?? ""
            return [w, h].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func setUnit(_ unit: UnitSystem) {
        guard var profile = appState.userProfile, profile.unitSystem != unit else { return }
        profile.unitSystem = unit
        appState.userProfile = profile
        FuelHaptics.shared.tap()
        Task {
            do {
                try await appState.databaseService?.updateProfile(profile)
            } catch {
                errorMessage = "Could not save unit preference."
                showingError = true
            }
        }
    }
}

// MARK: - Profile Section

private struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: FuelSpacing.sm) {
            Text(title)
                .font(FuelType.label)
                .foregroundStyle(FuelColors.stone)
                .padding(.leading, FuelSpacing.xs)

            VStack(spacing: 1) {
                content
            }
            .background(FuelColors.cloud)
            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
        }
    }
}

// MARK: - Profile Row

private struct ProfileRow: View {
    let icon: String
    let title: String
    var detail: String?
    var showChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FuelSpacing.md) {
                Group {
                    if icon == "FlameIcon" {
                        Image("FlameIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: icon)
                            .font(FuelType.cardTitle)
                            .foregroundStyle(FuelColors.ink)
                    }
                }
                .frame(width: 24)

                Text(title)
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.ink)

                Spacer()

                if let detail {
                    Text(detail)
                        .font(FuelType.caption)
                        .foregroundStyle(FuelColors.stone)
                }

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(FuelType.iconXs)
                        .foregroundStyle(FuelColors.fog)
                }
            }
            .padding(.horizontal, FuelSpacing.lg)
            .padding(.vertical, FuelSpacing.md)
            .background(FuelColors.white)
        }
    }
}
