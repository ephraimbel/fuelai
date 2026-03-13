import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var masterEnabled: Bool = NotificationService.shared.isEnabled
    @State private var categoryStates: [NotificationService.Category: Bool] = [:]
    @State private var needsSystemPermission = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: FuelSpacing.lg) {
                    // Master toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Coach Notifications")
                                .font(FuelType.cardTitle)
                                .foregroundStyle(FuelColors.ink)
                            Text("Personalized nudges based on your data")
                                .font(FuelType.caption)
                                .foregroundStyle(FuelColors.stone)
                        }
                        Spacer()
                        Toggle("", isOn: $masterEnabled)
                            .labelsHidden()
                            .tint(FuelColors.flame)
                    }
                    .padding(FuelSpacing.lg)
                    .background(FuelColors.cloud)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))

                    if masterEnabled {
                        // Category toggles
                        VStack(spacing: 1) {
                            ForEach(NotificationService.Category.allCases, id: \.rawValue) { category in
                                HStack(spacing: FuelSpacing.md) {
                                    Image(systemName: category.icon)
                                        .font(FuelType.cardTitle)
                                        .foregroundStyle(FuelColors.flame)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(category.displayName)
                                            .font(FuelType.body)
                                            .foregroundStyle(FuelColors.ink)
                                        Text(category.description)
                                            .font(FuelType.caption)
                                            .foregroundStyle(FuelColors.stone)
                                    }

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { categoryStates[category] ?? true },
                                        set: { newValue in
                                            categoryStates[category] = newValue
                                            NotificationService.shared.setCategoryEnabled(category, enabled: newValue)
                                            NotificationService.shared.forceReschedule()
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(FuelColors.flame)
                                }
                                .padding(.horizontal, FuelSpacing.lg)
                                .padding(.vertical, FuelSpacing.md)
                                .background(FuelColors.white)
                            }
                        }
                        .background(FuelColors.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if needsSystemPermission {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: FuelSpacing.sm) {
                                Image(systemName: "gear")
                                    .font(FuelType.cardTitle)
                                Text("Enable in System Settings")
                                    .font(FuelType.body)
                            }
                            .foregroundStyle(FuelColors.flame)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FuelSpacing.lg)
                            .background(FuelColors.flame.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
                        }
                    }
                }
                .padding(.horizontal, FuelSpacing.xl)
                .padding(.top, FuelSpacing.md)
            }
        }
        .background(FuelColors.pageBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .font(FuelType.label)
                    .foregroundStyle(FuelColors.flame)
            }
        }
        .onAppear {
            for cat in NotificationService.Category.allCases {
                categoryStates[cat] = NotificationService.shared.isCategoryEnabled(cat)
            }
            checkSystemPermission()
        }
        .onChange(of: masterEnabled) { _, newValue in
            NotificationService.shared.isEnabled = newValue
            if newValue {
                Task {
                    let granted = await NotificationService.shared.requestPermission()
                    await MainActor.run {
                        needsSystemPermission = !granted
                        if granted {
                            NotificationService.shared.forceReschedule()
                        }
                    }
                }
            } else {
                NotificationService.shared.cancelAll()
            }
        }
        .animation(FuelAnimation.spring, value: masterEnabled)
    }

    private func checkSystemPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                needsSystemPermission = masterEnabled && settings.authorizationStatus == .denied
            }
        }
    }
}
