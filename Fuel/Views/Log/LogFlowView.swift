import SwiftUI
import StoreKit

struct LogFlowView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var analysisResult: FoodAnalysis?
    @State private var previewResult: FoodAnalysis?
    @State private var capturedImageData: Data?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showingPaywall = false
    @State private var showingSuccess = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var logTask: Task<Void, Never>?
    @State private var isLogging = false
    @State private var errorDismissTask: Task<Void, Never>?
    @State private var photoError: String?
    @State private var showingAIConsent = false

    var body: some View {
        NavigationStack {
            ZStack {
                FuelColors.white.ignoresSafeArea()

                if isAnalyzing {
                    if let preview = previewResult {
                        // Show instant RAG preview while Claude refines (text search only)
                        FoodResultsView(
                            analysis: preview,
                            imageData: capturedImageData,
                            isPreview: true,
                            onLog: { adjustedResult in
                                logMeal(adjustedResult)
                            },
                            onRetake: {
                                analysisTask?.cancel()
                                withAnimation(FuelAnimation.smooth) {
                                    resetAnalysisState()
                                }
                            },
                            onRefine: { newQuery in
                                analyzeText(newQuery)
                            },
                            onSaveFavorite: { analysis in
                                saveFavorite(analysis)
                            },
                            isLogging: isLogging,
                            retakeLabel: capturedImageData != nil ? "Retake" : "Back"
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else if let imageData = capturedImageData {
                        // Photo scan — show captured photo with scanning overlay
                        ZStack {
                            PhotoScanOverlay(imageData: imageData)

                            // Error overlay on photo — retry without jumping back to camera
                            if let photoErr = photoError {
                                VStack(spacing: FuelSpacing.lg) {
                                    Spacer()
                                    VStack(spacing: FuelSpacing.md) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text(photoErr)
                                            .font(FuelType.body)
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.center)
                                        HStack(spacing: FuelSpacing.md) {
                                            Button {
                                                withAnimation(FuelAnimation.smooth) {
                                                    resetAnalysisState()
                                                }
                                            } label: {
                                                Text("Retake")
                                                    .font(FuelType.cardTitle)
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, FuelSpacing.xl)
                                                    .padding(.vertical, FuelSpacing.md)
                                                    .background(.white.opacity(0.2))
                                                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                                            }
                                            Button {
                                                photoError = nil
                                                analyzePhoto(imageData)
                                            } label: {
                                                Text("Try Again")
                                                    .font(FuelType.cardTitle)
                                                    .foregroundStyle(FuelColors.ink)
                                                    .padding(.horizontal, FuelSpacing.xl)
                                                    .padding(.vertical, FuelSpacing.md)
                                                    .background(.white)
                                                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                                            }
                                        }
                                    }
                                    .padding(FuelSpacing.xl)
                                    .background(
                                        RoundedRectangle(cornerRadius: FuelRadius.card)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: FuelRadius.card)
                                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                                            )
                                    )
                                    .padding(.horizontal, FuelSpacing.xl)
                                    .padding(.bottom, 80)
                                }
                                .transition(.opacity)
                            }
                        }
                        .transition(.opacity)
                    } else {
                        // Text/barcode — generic analyzing animation
                        AnalyzingView()
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                } else if let result = analysisResult {
                    FoodResultsView(
                        analysis: result,
                        imageData: capturedImageData,
                        isPreview: false,
                        onLog: { adjustedResult in
                            logMeal(adjustedResult)
                        },
                        onRetake: {
                            withAnimation(FuelAnimation.smooth) {
                                resetAnalysisState()
                            }
                        },
                        onRefine: { newQuery in
                            analyzeText(newQuery)
                        },
                        onSaveFavorite: { analysis in
                            saveFavorite(analysis)
                        },
                        isLogging: isLogging,
                        retakeLabel: capturedImageData != nil ? "Retake" : "Back"
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    VStack(spacing: 0) {
                        switch appState.selectedLogMode {
                        case .camera:
                            CameraLogView(onCapture: analyzePhoto)
                        case .search:
                            SearchLogView(onSearch: { query, exactFood in
                                analyzeText(query, exactFood: exactFood)
                            })
                        case .barcode:
                            BarcodeLogView(onScan: analyzeBarcode)
                        case .quickAdd:
                            QuickAddView(onLog: { analysis in logMeal(analysis) })
                        case .recentMeals:
                            RecentMealsView(onSelect: { analysis in
                                withAnimation(FuelAnimation.smooth) { analysisResult = analysis }
                            })
                        }
                    }
                    .transition(.opacity)
                }

                // Error toast at bottom
                if let error = errorMessage {
                    VStack {
                        Spacer()
                        errorToast(error)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Success celebration overlay
                if showingSuccess {
                    ZStack {
                        FuelColors.shadow.opacity(0.3).ignoresSafeArea()

                        VStack(spacing: FuelSpacing.lg) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(FuelType.hero)
                                .foregroundStyle(FuelColors.success)
                                .symbolEffect(.bounce, value: showingSuccess)

                            Text("Meal Logged!")
                                .font(FuelType.title)
                                .foregroundStyle(FuelColors.ink)
                        }
                        .padding(FuelSpacing.xxl)
                        .background(
                            RoundedRectangle(cornerRadius: FuelRadius.card)
                                .fill(FuelColors.white)
                        )

                        ConfettiView()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isAnalyzing)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: analysisResult != nil)
            .onChange(of: errorMessage) { _, newError in
                errorDismissTask?.cancel()
                if newError != nil {
                    errorDismissTask = Task {
                        try? await Task.sleep(for: .seconds(5))
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            withAnimation { errorMessage = nil }
                        }
                    }
                }
            }
            .onDisappear {
                analysisTask?.cancel()
                logTask?.cancel()
                errorDismissTask?.cancel()
            }
            .interactiveDismissDisabled(isLogging || isAnalyzing)
            .sheet(isPresented: $showingPaywall) {
                UpgradePaywallView(reason: .scanLimit)
            }
            .sheet(isPresented: $showingAIConsent) {
                AIConsentView(
                    onAccept: { showingAIConsent = false },
                    onDecline: {
                        showingAIConsent = false
                        dismiss()
                    }
                )
                .presentationDetents([.large])
                .interactiveDismissDisabled()
            }
            .toolbar(hideNavBar ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(FuelColors.cloud)
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(FuelType.iconXs)
                                .foregroundStyle(isLogging ? FuelColors.stone : FuelColors.ink)
                        }
                    }
                    .disabled(isLogging)
                }

                ToolbarItem(placement: .principal) {
                    Text(toolbarTitle)
                        .font(FuelType.section)
                        .foregroundStyle(FuelColors.ink)
                }
            }
        }
    }

    // MARK: - Toolbar Title

    private var toolbarTitle: String {
        if isAnalyzing && capturedImageData != nil { return "" }
        if isAnalyzing { return "Analyzing" }
        if analysisResult != nil { return "Results" }
        return appState.selectedLogMode.rawValue
    }

    private var hideNavBar: Bool {
        isAnalyzing && capturedImageData != nil && previewResult == nil
    }

    // MARK: - State Reset

    private func resetAnalysisState() {
        analysisResult = nil
        previewResult = nil
        capturedImageData = nil
        errorMessage = nil
        photoError = nil
        isAnalyzing = false
    }

    // MARK: - Error Toast

    private func errorToast(_ message: String) -> some View {
        HStack(spacing: FuelSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(FuelType.iconSm)
                .foregroundStyle(FuelColors.over)

            Text(message)
                .font(FuelType.caption)
                .foregroundStyle(FuelColors.ink)
                .lineLimit(2)

            Spacer()

            Button {
                withAnimation { errorMessage = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(FuelType.badgeMicro)
                    .foregroundStyle(FuelColors.stone)
            }
        }
        .padding(FuelSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.md)
                .fill(FuelColors.white)
                .shadow(color: FuelColors.shadow.opacity(0.1), radius: 12, y: 4)
        )
        .padding(.horizontal, FuelSpacing.xl)
        .padding(.bottom, FuelSpacing.xl)
    }

    // MARK: - Rate Limit & Consent

    private func checkRateLimit() -> Bool {
        // AI consent check (Apple Guideline 5.1.2(i))
        if !AIConsentManager.hasConsented {
            showingAIConsent = true
            return false
        }
        if !RateLimiter.canScan(isPremium: subscriptionService.isPremium) {
            FuelHaptics.shared.error()
            showingPaywall = true
            return false
        }
        return true
    }

    // MARK: - Analysis Timeout Helper

    /// Runs an async analysis call with a 30s safety timeout.
    /// Budget: 20s direct API + 10s Supabase fallback headroom.
    private func withAnalysisTimeout<T: Sendable>(
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw FuelError.aiAnalysisFailed("Analysis timed out. Please try again.")
            }
            guard let first = try await group.next() else {
                throw FuelError.aiAnalysisFailed("AI service not available")
            }
            group.cancelAll()
            return first
        }
    }

    // MARK: - Photo Analysis

    private func analyzePhoto(_ imageData: Data, description: String? = nil) {
        guard checkRateLimit() else { return }

        guard appState.aiService != nil else {
            withAnimation { errorMessage = "AI service is loading. Please try again in a moment." }
            return
        }

        // Validate image before starting analysis — check actual dimensions, not byte count
        guard let validationImage = UIImage(data: imageData),
              validationImage.size.width >= 100, validationImage.size.height >= 100 else {
            withAnimation { errorMessage = "Image quality is very low. Please retake with better lighting." }
            return
        }

        // Surface quality warnings to users so they can retake before waiting 20s
        if let warning = ImageCompressor.qualityWarning(validationImage) {
            #if DEBUG
            print("[Fuel] Image quality warning: \(warning)")
            #endif
            // Don't block — just warn. Dark images are auto-enhanced, low-res may still work.
        }

        capturedImageData = imageData
        isAnalyzing = true
        errorMessage = nil
        previewResult = nil
        photoError = nil

        #if DEBUG
        print("[Fuel] analyzePhoto: starting (imageData=\(imageData.count) bytes)")
        #endif

        analysisTask?.cancel()
        analysisTask = Task {
            do {
                await appState.aiService?.updateUserContext(
                    caloriesRemaining: appState.caloriesRemaining,
                    proteinRemaining: appState.proteinRemaining,
                    carbsRemaining: appState.carbsRemaining,
                    fatRemaining: appState.fatRemaining,
                    goalType: appState.userProfile?.goalType?.rawValue ?? "maintain",
                    dietStyle: appState.userProfile?.dietStyle?.rawValue ?? "standard"
                )

                let result = try await withAnalysisTimeout {
                    guard let r = try await appState.aiService?.analyzePhoto(
                        imageData: imageData,
                        description: description,
                        onItemsIdentified: nil
                    ) else {
                        throw FuelError.aiAnalysisFailed("AI service not available")
                    }
                    return r
                }

                #if DEBUG
                print("[Fuel] analyzePhoto: SUCCESS — \(result.displayName) (\(result.totalCalories) cal)")
                #endif
                await MainActor.run {
                    FuelHaptics.shared.logSuccess()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        analysisResult = result
                        isAnalyzing = false
                        errorMessage = nil
                    }
                }
            } catch is CancellationError {
                #if DEBUG
                print("[Fuel] analyzePhoto: CANCELLED")
                #endif
                await MainActor.run {
                    withAnimation {
                        capturedImageData = nil
                        isAnalyzing = false
                        photoError = nil
                    }
                }
            } catch {
                #if DEBUG
                print("[Fuel] analyzePhoto: ERROR — \(error)")
                #endif

                let errorDetail: String
                if let nutritionError = error as? NutritionError {
                    switch nutritionError {
                    case .missingAPIKey:
                        errorDetail = "Unable to connect to AI. Please close and reopen the app."
                    case .apiError(let code, _):
                        errorDetail = code == 429 ? "Rate limited — please wait a moment." : "Server error (\(code)). Please try again."
                    case .imageEncodingFailed:
                        errorDetail = "Could not process image. Try a different photo."
                    case .parseError:
                        errorDetail = "Could not read AI response. Please try again."
                    default:
                        errorDetail = "Analysis failed. Please try again."
                    }
                } else if let fuelError = error as? FuelError {
                    errorDetail = fuelError.localizedDescription
                } else if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        errorDetail = "Request timed out. Please try again."
                    case .notConnectedToInternet, .networkConnectionLost:
                        errorDetail = "No internet connection. Please check your network."
                    default:
                        errorDetail = "Network error. Please check your connection and try again."
                    }
                } else {
                    errorDetail = "Analysis failed. Please try again."
                }

                await MainActor.run {
                    FuelHaptics.shared.error()
                    withAnimation {
                        photoError = errorDetail
                    }
                }
            }
        }
    }

    // MARK: - Text Analysis

    private func analyzeText(_ query: String, exactFood: FoodItem? = nil) {
        guard checkRateLimit() else { return }

        guard appState.aiService != nil else {
            withAnimation { errorMessage = "AI service is loading. Please try again in a moment." }
            return
        }

        // If user tapped an exact food from autocomplete, use it directly — no AI needed
        if let food = exactFood {
            let result = buildPreviewFromFood(food)
            withAnimation(FuelAnimation.smooth) {
                analysisResult = result
                previewResult = nil
                errorMessage = nil
            }
            return
        }

        isAnalyzing = true
        errorMessage = nil

        // Show instant RAG preview (< 10ms, local database)
        let ragPreview = appState.aiService?.previewFromRAG(query: query)
        if let preview = ragPreview {
            withAnimation(FuelAnimation.smooth) {
                previewResult = preview
            }
        } else {
            previewResult = nil
        }

        // Full AI analysis in background
        // Capture preview for this specific query so fallback uses correct data
        let fallbackPreview = ragPreview
        analysisTask?.cancel()
        analysisTask = Task {
            do {
                await appState.aiService?.updateUserContext(
                    caloriesRemaining: appState.caloriesRemaining,
                    proteinRemaining: appState.proteinRemaining,
                    carbsRemaining: appState.carbsRemaining,
                    fatRemaining: appState.fatRemaining,
                    goalType: appState.userProfile?.goalType?.rawValue ?? "maintain",
                    dietStyle: appState.userProfile?.dietStyle?.rawValue ?? "standard"
                )
                let result = try await withAnalysisTimeout {
                    guard let r = try await appState.aiService?.searchFood(query: query) else {
                        throw FuelError.aiAnalysisFailed("Service not available")
                    }
                    return r
                }
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        analysisResult = result
                        previewResult = nil
                        isAnalyzing = false
                    }
                }
            } catch is CancellationError {
                // Don't clear previewResult here — a new analyzeText call
                // already set the correct preview for the new query.
                // Clearing it would wipe the new preview.
                return
            } catch {
                let errorDetail: String
                if let nutritionError = error as? NutritionError {
                    switch nutritionError {
                    case .missingAPIKey:
                        errorDetail = "Unable to connect to AI. Please close and reopen the app."
                    case .apiError(let code, _):
                        errorDetail = code == 429 ? "Rate limited — please wait a moment and try again." : "Server error (\(code)). Please try again."
                    default:
                        errorDetail = "Text analysis failed. Please try again."
                    }
                } else if let fuelError = error as? FuelError {
                    errorDetail = fuelError.localizedDescription
                } else {
                    errorDetail = "Analysis failed. Check your connection and try again."
                }
                #if DEBUG
                print("[Fuel] Text analysis error: \(error)")
                #endif
                await MainActor.run {
                    withAnimation {
                        // Use the preview captured for THIS query, not current previewResult
                        if let preview = fallbackPreview {
                            analysisResult = preview
                            previewResult = nil
                            isAnalyzing = false
                            errorMessage = "Using local estimate — AI analysis unavailable"
                        } else {
                            errorMessage = errorDetail
                            isAnalyzing = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Barcode Analysis

    private func analyzeBarcode(_ barcode: String) {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            withAnimation { errorMessage = "Invalid barcode. Please try again." }
            return
        }
        guard checkRateLimit() else { return }

        guard appState.aiService != nil else {
            withAnimation { errorMessage = "AI service is loading. Please try again in a moment." }
            return
        }

        isAnalyzing = true
        errorMessage = nil

        analysisTask?.cancel()
        analysisTask = Task {
            do {
                let result = try await withAnalysisTimeout {
                    guard let r = try await appState.aiService?.lookupBarcode(trimmed) else {
                        throw FuelError.aiAnalysisFailed("Service not available")
                    }
                    return r
                }
                await MainActor.run {
                    withAnimation(FuelAnimation.smooth) {
                        analysisResult = result
                        isAnalyzing = false
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    withAnimation { isAnalyzing = false }
                }
            } catch {
                let errorDetail: String
                if let nutritionError = error as? NutritionError {
                    switch nutritionError {
                    case .missingAPIKey:
                        errorDetail = "Unable to connect to AI. Please close and reopen the app."
                    case .apiError(let code, _):
                        errorDetail = code == 429 ? "Rate limited — please wait a moment and try again." : "Server error (\(code)). Please try again."
                    default:
                        errorDetail = "Barcode lookup failed. Please try again."
                    }
                } else if let fuelError = error as? FuelError {
                    errorDetail = fuelError.localizedDescription
                } else {
                    errorDetail = "Barcode lookup failed. Check your connection and try again."
                }
                #if DEBUG
                print("[Fuel] Barcode lookup error: \(error)")
                #endif
                await MainActor.run {
                    withAnimation {
                        errorMessage = errorDetail
                        isAnalyzing = false
                    }
                }
            }
        }
    }

    private func buildPreviewFromFood(_ food: FoodItem) -> FoodAnalysis {
        let item = AnalyzedFoodItem(
            id: UUID(),
            name: food.name,
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            servingSize: food.serving,
            confidence: 0.85,
            note: nil
        )
        return FoodAnalysis(
            items: [item],
            displayName: food.name,
            totalCalories: food.calories,
            totalProtein: food.protein,
            totalCarbs: food.carbs,
            totalFat: food.fat,
            fiberG: food.fiber,
            sugarG: food.sugar,
            sodiumMg: food.sodium,
            warnings: nil,
            healthInsight: nil,
            calorieRange: nil,
            confidenceReason: "Quick estimate from local database",
            servingAssumed: food.serving
        )
    }

    // MARK: - Save Favorite

    private func saveFavorite(_ analysis: FoodAnalysis) {
        guard let profile = appState.userProfile else { return }

        let items = analysis.items.map { item in
            MealItem(
                id: item.id,
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                servingSize: item.servingSize,
                quantity: item.quantity,
                confidence: item.confidence
            )
        }

        let favorite = FavoriteMeal(
            id: UUID(),
            userId: profile.id,
            name: analysis.displayName,
            items: items,
            totalCalories: analysis.totalCalories,
            totalProtein: analysis.totalProtein,
            totalCarbs: analysis.totalCarbs,
            totalFat: analysis.totalFat,
            useCount: 0,
            createdAt: Date()
        )

        Task {
            do {
                try await appState.databaseService?.saveFavorite(favorite)
            } catch {
                await MainActor.run {
                    withAnimation { errorMessage = "Couldn't save favorite. Please try again." }
                }
            }
        }
    }

    // MARK: - Log Meal

    private func logMeal(_ analysis: FoodAnalysis) {
        guard !isLogging else { return }
        guard let profile = appState.userProfile else {
            withAnimation { errorMessage = "Please sign in to log meals." }
            return
        }
        isLogging = true
        // Stop any in-flight analysis — user has committed to logging this result
        analysisTask?.cancel()
        analysisTask = nil
        let now = Date()
        let mealId = UUID()

        let items = analysis.items.map { item in
            MealItem(
                id: item.id,
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                servingSize: item.servingSize,
                quantity: item.quantity,
                confidence: item.confidence
            )
        }

        let meal = Meal(
            id: mealId,
            userId: profile.id,
            items: items,
            totalCalories: analysis.totalCalories,
            totalProtein: analysis.totalProtein,
            totalCarbs: analysis.totalCarbs,
            totalFat: analysis.totalFat,
            imageUrl: nil,
            displayName: analysis.displayName,
            loggedDate: now.dateString,
            loggedAt: now,
            createdAt: now
        )

        // Add meal to list immediately (visible behind sheet)
        appState.todayMeals.append(meal)

        // Prepare updated summary but DON'T apply yet — delay until dismiss
        // so the user SEES the ring animations fill on the home screen
        var summary = appState.todaySummary ?? DailySummary(userId: profile.id, date: now.dateString)
        summary.totalCalories += meal.totalCalories
        summary.totalProtein += meal.totalProtein
        summary.totalCarbs += meal.totalCarbs
        summary.totalFat += meal.totalFat
        summary.isOnTarget = Double(summary.totalCalories) <= Double(appState.calorieTarget) * 1.1

        // Record locally (always works, even offline)
        MealHistoryService.shared.recordMeal(name: meal.displayName, calories: meal.totalCalories)
        RateLimiter.recordScan()

        // Record user corrections for learning
        if let original = analysisResult {
            for loggedItem in analysis.items {
                if let originalItem = original.items.first(where: { $0.id == loggedItem.id }),
                   originalItem.calories != loggedItem.calories {
                    MealHistoryService.shared.recordCorrection(
                        itemName: loggedItem.name,
                        estimatedCal: originalItem.calories,
                        loggedCal: loggedItem.calories
                    )
                }
            }
        }

        // Show success immediately
        FuelHaptics.shared.logSuccess()
        withAnimation(FuelAnimation.spring) {
            showingSuccess = true
        }

        // Dismiss after celebration, then persist to DB in background
        logTask?.cancel()
        logTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }

            // Apply summary update AT dismiss — rings animate as sheet slides away
            await MainActor.run {
                appState.todaySummary = summary
                dismiss()

                // Request App Store review at a moment of delight (after 5+ meals logged)
                // System limits to 3 prompts per 365 days — safe to call often
                let totalScans = UserDefaults.standard.integer(forKey: "lifetime_scan_count") + 1
                UserDefaults.standard.set(totalScans, forKey: "lifetime_scan_count")
                if totalScans == 5 || totalScans == 25 || totalScans == 100 {
                    if let scene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                }
            }

            // Persist to database in background (non-blocking)
            do {
                try await appState.databaseService?.logMeal(meal)

                // Upload image (best-effort)
                if let imageData = capturedImageData {
                    let _ = try? await appState.databaseService?.uploadMealImage(
                        userId: profile.id, mealId: mealId, imageData: imageData
                    )
                    await MainActor.run { capturedImageData = nil }
                }

                // Sync summary to DB
                await appState.recalculateDailySummary()
            } catch {
                #if DEBUG
                print("[Fuel] Failed to save meal to database: \(error)")
                #endif
                // Meal is already in local state — user sees it immediately.
                // It will sync on next refreshTodayData() call.
            }
        }
    }
}
