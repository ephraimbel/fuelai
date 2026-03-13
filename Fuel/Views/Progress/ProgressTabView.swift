import SwiftUI
import Charts

enum TimePeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonth = "3 Month"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonth: return 90
        }
    }
}

struct ProgressTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPeriod: TimePeriod = .week
    @State private var summaries: [DailySummary] = []
    @State private var weightHistory: [WeightLog] = []
    @State private var showingWeightEntry = false
    @State private var newWeight = ""
    @State private var isInitialLoad = true
    @State private var isLoadingNow = false
    @State private var cardsAppeared = false
    @State private var loadId = UUID()
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: FuelSpacing.xl) {
                // Period selector
                periodPicker
                    .padding(.horizontal, FuelSpacing.xl)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Time period")

                if isInitialLoad {
                    VStack(spacing: FuelSpacing.lg) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: FuelRadius.card)
                                .fill(FuelColors.mist)
                                .frame(height: i == 0 ? 200 : i == 1 ? 100 : 160)
                                .shimmer()
                        }
                    }
                    .padding(.horizontal, FuelSpacing.xl)
                    .padding(.top, FuelSpacing.md)
                    .accessibilityLabel("Loading progress data")
                } else if let error = loadError, summaries.isEmpty && weightHistory.isEmpty {
                    errorState(message: error)
                } else {
                    // Calorie trend
                    CalorieTrendChart(summaries: summaries, target: appState.calorieTarget, period: selectedPeriod)
                        .padding(.horizontal, FuelSpacing.xl)
                        .offset(y: cardsAppeared ? 0 : 24)
                        .opacity(cardsAppeared ? 1 : 0)
                        .animation(FuelAnimation.spring.delay(0.0), value: cardsAppeared)

                    // Weekly stacked calorie chart
                    WeeklyCalorieChart(summaries: summaries, period: selectedPeriod)
                        .padding(.horizontal, FuelSpacing.xl)
                        .offset(y: cardsAppeared ? 0 : 24)
                        .opacity(cardsAppeared ? 1 : 0)
                        .animation(FuelAnimation.spring.delay(0.04), value: cardsAppeared)

                    // Macro averages
                    MacroAveragesView(summaries: summaries, period: selectedPeriod)
                        .padding(.horizontal, FuelSpacing.xl)
                        .offset(y: cardsAppeared ? 0 : 24)
                        .opacity(cardsAppeared ? 1 : 0)
                        .animation(FuelAnimation.spring.delay(0.08), value: cardsAppeared)

                    // Water trend
                    WaterTrendChart(
                        summaries: summaries,
                        goal: appState.waterGoalMl,
                        period: selectedPeriod,
                        unitSystem: appState.userProfile?.unitSystem ?? .imperial
                    )
                    .padding(.horizontal, FuelSpacing.xl)
                    .offset(y: cardsAppeared ? 0 : 24)
                    .opacity(cardsAppeared ? 1 : 0)
                    .animation(FuelAnimation.spring.delay(0.12), value: cardsAppeared)

                    // Weight chart
                    WeightChartView(weights: weightHistory, period: selectedPeriod, unitSystem: appState.userProfile?.unitSystem ?? .imperial, onAddWeight: {
                        showingWeightEntry = true
                    })
                    .padding(.horizontal, FuelSpacing.xl)
                    .offset(y: cardsAppeared ? 0 : 24)
                    .opacity(cardsAppeared ? 1 : 0)
                    .animation(FuelAnimation.spring.delay(0.20), value: cardsAppeared)

                    // Streak section
                    StreakCalendarView(
                        streak: appState.currentStreak,
                        longestStreak: appState.userProfile?.longestStreak ?? 0,
                        summaries: summaries,
                        period: selectedPeriod
                    )
                    .padding(.horizontal, FuelSpacing.xl)
                    .offset(y: cardsAppeared ? 0 : 24)
                    .opacity(cardsAppeared ? 1 : 0)
                    .animation(FuelAnimation.spring.delay(0.28), value: cardsAppeared)
                }

                Spacer().frame(height: 80)
            }
            .padding(.top, FuelSpacing.md)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            loadError = nil
            await loadData()
        }
        .background(FuelColors.pageBackground)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FuelColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await initialLoad() }
        .task(id: appState.userProfile?.id) {
            // Profile just became available (or changed) — reload
            guard appState.userProfile != nil else { return }
            if summaries.isEmpty {
                isInitialLoad = true
            }
            await initialLoad()
        }
        .task(id: appState.selectedDate) {
            guard !isInitialLoad else { return }
            await loadData()
        }
        .onChange(of: appState.dataVersion) { _, _ in
            guard !isInitialLoad else { return }
            // Instantly merge local today's summary so charts react without waiting for DB
            mergeTodaySummary()
            // Also refresh from DB in background for full historical accuracy
            Task { await loadData() }
        }
        .onChange(of: selectedPeriod) { _, _ in
            cardsAppeared = false
            loadError = nil
            let currentLoadId = UUID()
            loadId = currentLoadId
            Task {
                await loadData()
                guard loadId == currentLoadId else { return }
                withAnimation { cardsAppeared = true }
            }
        }
        .sheet(isPresented: $showingWeightEntry) {
            WeightEntrySheet(weightText: $newWeight, unitSystem: appState.userProfile?.unitSystem ?? .imperial) {
                let isMetric = appState.userProfile?.unitSystem == .metric
                guard let value = Double(newWeight) else {
                    newWeight = ""
                    showingWeightEntry = false
                    return
                }
                let kg = isMetric ? value : value * 0.453592
                guard kg > 20, kg < 500 else {
                    newWeight = ""
                    showingWeightEntry = false
                    return
                }
                newWeight = ""
                showingWeightEntry = false
                if let profile = appState.userProfile {
                    Task {
                        try? await appState.databaseService?.logWeight(userId: profile.id, weightKg: kg)
                        await loadWeights()
                    }
                }
            }
            .presentationDetents([.height(220)])
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button {
                    FuelHaptics.shared.selection()
                    withAnimation(FuelAnimation.snappy) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.rawValue)
                        .font(FuelType.label)
                        .foregroundStyle(selectedPeriod == period ? .white : FuelColors.stone)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.sm + 2)
                        .background {
                            if selectedPeriod == period {
                                Capsule()
                                    .fill(FuelColors.buttonFill)
                                    .matchedGeometryEffect(id: "period_pill", in: periodNamespace)
                            }
                        }
                }
                .accessibilityLabel(period.rawValue)
                .accessibilityAddTraits(selectedPeriod == period ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            Capsule().fill(FuelColors.cloud)
        )
    }

    @Namespace private var periodNamespace

    // MARK: - Error State

    private func errorState(message: String) -> some View {
        VStack(spacing: FuelSpacing.md) {
            Image(systemName: "wifi.slash")
                .font(FuelType.title)
                .foregroundStyle(FuelColors.fog)

            Text("Couldn't load your progress")
                .font(FuelType.section)
                .foregroundStyle(FuelColors.ink)

            Text(message)
                .font(FuelType.caption)
                .foregroundStyle(FuelColors.stone)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    loadError = nil
                    isInitialLoad = true
                    await initialLoad()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(FuelType.iconSm)
                    Text("Try Again")
                        .font(FuelType.label)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, FuelSpacing.lg)
                .padding(.vertical, FuelSpacing.sm)
                .background(FuelColors.buttonFill)
                .clipShape(Capsule())
            }
            .pressable()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.horizontal, FuelSpacing.xl)
    }

    // MARK: - Data Loading

    private func initialLoad() async {
        guard let profile = appState.userProfile else {
            // No profile — stop shimmer and show empty state
            if !appState.isLoading {
                isInitialLoad = false
                withAnimation { cardsAppeared = true }
            }
            return
        }
        guard !isLoadingNow else { return }
        isLoadingNow = true
        defer { isLoadingNow = false }

        #if DEBUG
        // Use in-memory seed data if available (bypasses DB for screenshots)
        if !appState.seedSummaries.isEmpty {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date())!
            let cutoffStr = cutoffDate.dateString
            summaries = appState.seedSummaries.filter { $0.date >= cutoffStr }
            weightHistory = appState.seedWeightHistory.filter { $0.loggedAt >= cutoffDate }
            loadError = nil
            isInitialLoad = false
            withAnimation { cardsAppeared = true }
            return
        }
        #endif

        if let db = appState.databaseService {
            do {
                async let s = db.getSummaries(userId: profile.id, days: selectedPeriod.days)
                async let w = db.getWeightHistory(userId: profile.id, days: selectedPeriod.days)

                summaries = try await s
                weightHistory = try await w

                // Seed initial weight from profile if no weight_logs exist yet
                if weightHistory.isEmpty, let kg = profile.weightKg, kg > 0 {
                    try? await db.logWeight(userId: profile.id, weightKg: kg)
                    weightHistory = (try? await db.getWeightHistory(userId: profile.id, days: selectedPeriod.days)) ?? []
                }

                loadError = nil
            } catch {
                loadError = summaries.isEmpty ? "Unable to load progress data." : nil
            }
        }

        // Merge local todaySummary — it may be ahead of the DB
        if let local = appState.todaySummary {
            let todayDate = local.date
            if let idx = summaries.firstIndex(where: { $0.date == todayDate }) {
                summaries[idx] = local
            } else {
                summaries.append(local)
                summaries.sort { $0.date < $1.date }
            }
        }

        isInitialLoad = false
        withAnimation { cardsAppeared = true }
    }

    private func loadData() async {
        guard let profile = appState.userProfile else { return }

        #if DEBUG
        if !appState.seedSummaries.isEmpty {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date())!
            let cutoffStr = cutoffDate.dateString
            withAnimation(FuelAnimation.spring) {
                summaries = appState.seedSummaries.filter { $0.date >= cutoffStr }
                weightHistory = appState.seedWeightHistory.filter { $0.loggedAt >= cutoffDate }
            }
            loadError = nil
            return
        }
        #endif

        if let db = appState.databaseService {
            do {
                async let s = db.getSummaries(userId: profile.id, days: selectedPeriod.days)
                async let w = db.getWeightHistory(userId: profile.id, days: selectedPeriod.days)

                var newSummaries = try await s
                let newWeights = try await w

                // Merge local todaySummary — it may be ahead of the DB
                if let local = appState.todaySummary {
                    let todayDate = local.date
                    if let idx = newSummaries.firstIndex(where: { $0.date == todayDate }) {
                        newSummaries[idx] = local
                    } else {
                        newSummaries.append(local)
                        newSummaries.sort { $0.date < $1.date }
                    }
                }

                withAnimation(FuelAnimation.spring) {
                    summaries = newSummaries
                    weightHistory = newWeights
                }
                loadError = nil
            } catch {
                // DB failed — still show local data for today if available
                if let local = appState.todaySummary {
                    withAnimation(FuelAnimation.spring) {
                        if summaries.isEmpty {
                            summaries = [local]
                        } else if let idx = summaries.firstIndex(where: { $0.date == local.date }) {
                            summaries[idx] = local
                        }
                    }
                }
                loadError = "Unable to load progress data."
            }
        }
    }

    /// Instantly merge the local todaySummary into the summaries array
    /// so charts react immediately without waiting for a DB round-trip.
    private func mergeTodaySummary() {
        guard let local = appState.todaySummary else { return }
        withAnimation(FuelAnimation.spring) {
            if let idx = summaries.firstIndex(where: { $0.date == local.date }) {
                summaries[idx] = local
            } else {
                summaries.append(local)
                summaries.sort { $0.date < $1.date }
            }
        }
    }

    private func loadWeights() async {
        guard let profile = appState.userProfile else { return }
        let weights = (try? await appState.databaseService?.getWeightHistory(userId: profile.id, days: selectedPeriod.days)) ?? []
        await MainActor.run {
            withAnimation(FuelAnimation.spring) {
                weightHistory = weights
            }
        }
    }
}

struct WeightEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var weightText: String
    var unitSystem: UnitSystem = .imperial
    @FocusState private var isWeightFocused: Bool
    let onSave: () -> Void

    private var isMetric: Bool { unitSystem == .metric }
    private var unitLabel: String { isMetric ? "kg" : "lbs" }

    private var isValid: Bool {
        guard let value = Double(weightText) else { return false }
        let kg = isMetric ? value : value * 0.453592
        return kg > 20 && kg < 500
    }

    var body: some View {
        VStack(spacing: FuelSpacing.lg) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
                Spacer()
                Text("Log Weight")
                    .font(FuelType.section)
                    .foregroundStyle(FuelColors.ink)
                Spacer()
                Button("Cancel") { }.opacity(0)
                    .font(FuelType.body)
            }

            TextField("Weight (\(unitLabel))", text: $weightText)
                .font(FuelType.stat)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isWeightFocused)
                .padding(FuelSpacing.md)
                .background(FuelColors.cloud)
                .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                .padding(.horizontal, FuelSpacing.xl)
                .accessibilityLabel("Weight in \(isMetric ? "kilograms" : "pounds")")
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isWeightFocused = false }
                            .font(FuelType.label)
                            .foregroundStyle(FuelColors.ink)
                    }
                }

            Button(action: onSave) {
                Text("Save")
            }
            .buttonStyle(.fuelPrimary)
            .padding(.horizontal, FuelSpacing.xl)
            .opacity(isValid ? 1 : 0.5)
            .disabled(!isValid)
        }
        .padding(.top, FuelSpacing.xl)
    }
}
