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

                    // Macro averages
                    MacroAveragesView(summaries: summaries, period: selectedPeriod)
                        .padding(.horizontal, FuelSpacing.xl)
                        .offset(y: cardsAppeared ? 0 : 24)
                        .opacity(cardsAppeared ? 1 : 0)
                        .animation(FuelAnimation.spring.delay(0.08), value: cardsAppeared)

                    // Weight chart
                    WeightChartView(weights: weightHistory, period: selectedPeriod, onAddWeight: {
                        showingWeightEntry = true
                    })
                    .padding(.horizontal, FuelSpacing.xl)
                    .offset(y: cardsAppeared ? 0 : 24)
                    .opacity(cardsAppeared ? 1 : 0)
                    .animation(FuelAnimation.spring.delay(0.16), value: cardsAppeared)

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
                    .animation(FuelAnimation.spring.delay(0.24), value: cardsAppeared)
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
        .background(FuelColors.white)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .task { await initialLoad() }
        .task(id: appState.selectedDate) {
            guard !isInitialLoad else { return }
            await loadData()
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
            WeightEntrySheet(weightText: $newWeight) {
                guard let kg = Double(newWeight), kg > 20, kg < 500 else {
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
                        .foregroundStyle(selectedPeriod == period ? FuelColors.onDark : FuelColors.stone)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FuelSpacing.sm + 2)
                        .background {
                            if selectedPeriod == period {
                                Capsule()
                                    .fill(FuelColors.ink)
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
                .foregroundStyle(FuelColors.onDark)
                .padding(.horizontal, FuelSpacing.lg)
                .padding(.vertical, FuelSpacing.sm)
                .background(FuelColors.ink)
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
            isInitialLoad = false
            return
        }

        do {
            async let s = appState.databaseService?.getSummaries(userId: profile.id, days: selectedPeriod.days)
            async let w = appState.databaseService?.getWeightHistory(userId: profile.id, days: selectedPeriod.days)

            summaries = (try await s) ?? []
            weightHistory = (try await w) ?? []
            loadError = nil
        } catch {
            loadError = "Unable to load progress data."
        }

        isInitialLoad = false
        withAnimation { cardsAppeared = true }
    }

    private func loadData() async {
        guard let profile = appState.userProfile else { return }

        do {
            async let s = appState.databaseService?.getSummaries(userId: profile.id, days: selectedPeriod.days)
            async let w = appState.databaseService?.getWeightHistory(userId: profile.id, days: selectedPeriod.days)

            summaries = (try await s) ?? []
            weightHistory = (try await w) ?? []
            loadError = nil
        } catch {
            loadError = "Unable to load progress data."
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
    @FocusState private var isWeightFocused: Bool
    let onSave: () -> Void

    private var isValid: Bool {
        guard let kg = Double(weightText) else { return false }
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

            TextField("Weight (kg)", text: $weightText)
                .font(FuelType.stat)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isWeightFocused)
                .padding(FuelSpacing.md)
                .background(FuelColors.cloud)
                .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                .padding(.horizontal, FuelSpacing.xl)
                .accessibilityLabel("Weight in kilograms")
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
