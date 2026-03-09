import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showingEditGoals = false
    @State private var showingEditProfile = false
    @State private var showingSubscription = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingDeleteConfirm = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingHealthDisclaimer = false

    var body: some View {
        ScrollView {
            VStack(spacing: FuelSpacing.lg) {
                // Profile card
                if let profile = appState.userProfile {
                    VStack(spacing: FuelSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(FuelColors.mist)
                                .frame(width: 56, height: 56)

                            Text(initials(for: profile))
                                .font(FuelType.iconLg)
                                .foregroundStyle(FuelColors.ink)
                        }

                        Text(profile.displayName ?? "Fuel User")
                            .font(FuelType.section)
                            .foregroundStyle(FuelColors.ink)

                        Text(profile.email ?? "")
                            .font(FuelType.caption)
                            .foregroundStyle(FuelColors.stone)

                        HStack(spacing: 4) {
                            if subscriptionService.isPremium {
                                Image(systemName: "flame.fill")
                                    .font(FuelType.badgeMicro)
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
                    .frame(maxWidth: .infinity)
                    .padding(FuelSpacing.xl)
                    .background(FuelColors.cloud)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
                }

                // Goals
                SettingsSection(title: "Goals") {
                    SettingsRow(icon: "target", title: "Calorie & Macro Targets", detail: goalDetail) {
                        showingEditGoals = true
                    }
                }

                // Profile
                SettingsSection(title: "Profile") {
                    SettingsRow(icon: "person", title: "Body Stats", detail: bodyDetail) {
                        showingEditProfile = true
                    }
                    SettingsRow(
                        icon: "ruler",
                        title: "Units",
                        detail: appState.userProfile?.unitSystem == .metric ? "Metric" : "Imperial"
                    ) {
                        toggleUnits()
                    }
                }

                // Subscription
                SettingsSection(title: "Subscription") {
                    SettingsRow(
                        icon: "star",
                        title: subscriptionService.isPremium ? "Manage Subscription" : "Upgrade to fuel+",
                        detail: nil
                    ) {
                        showingSubscription = true
                    }
                }

                // About
                SettingsSection(title: "About") {
                    SettingsRow(icon: "heart.text.square", title: "Health & AI Disclaimers", detail: nil) {
                        showingHealthDisclaimer = true
                    }
                    SettingsRow(icon: "doc.text", title: "Terms of Service", detail: nil) {
                        if let url = URL(string: "https://fuel.app/terms") {
                            UIApplication.shared.open(url)
                        }
                    }
                    SettingsRow(icon: "lock.shield", title: "Privacy Policy", detail: nil) {
                        if let url = URL(string: "https://fuel.app/privacy") {
                            UIApplication.shared.open(url)
                        }
                    }
                    SettingsRow(icon: "info.circle", title: "Version", detail: appVersion, showChevron: false) {}
                }

                // Account
                SettingsSection(title: "Account") {
                    SettingsRow(icon: "trash", title: "Delete Account", detail: nil) {
                        showingDeleteAlert = true
                    }
                }

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
        .background(FuelColors.white)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Helpers

    private var goalDetail: String? {
        guard let profile = appState.userProfile,
              let cal = profile.targetCalories else { return nil }
        return "\(cal) cal"
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

    private func initials(for profile: UserProfile) -> String {
        if let name = profile.displayName, !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }
        return "FU"
    }

    private func toggleUnits() {
        if var profile = appState.userProfile {
            profile.unitSystem = profile.unitSystem == .imperial ? .metric : .imperial
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
}

// MARK: - Settings Section

private struct SettingsSection<Content: View>: View {
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

// MARK: - Settings Row

private struct SettingsRow: View {
    let icon: String
    let title: String
    var detail: String?
    var showChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FuelSpacing.md) {
                Image(systemName: icon)
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.ink)
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
