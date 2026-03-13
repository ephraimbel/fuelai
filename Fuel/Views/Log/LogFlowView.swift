import SwiftUI
import StoreKit
import Supabase

struct LogFlowView: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.dismiss) private var dismiss

    var initialSearchQuery: String?

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
    @State private var showingSignIn = false
    @State private var lastResultFromDescribe = false

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

                            // Error overlay on photo — retry, retake, or search manually
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

                                        // Fallback: search manually
                                        Button {
                                            withAnimation(FuelAnimation.smooth) {
                                                capturedImageData = nil
                                                photoError = nil
                                                isAnalyzing = false
                                                appState.selectedLogMode = .search
                                            }
                                        } label: {
                                            Text("Search manually instead")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.7))
                                                .underline()
                                        }
                                        .padding(.top, 4)
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
                            if lastResultFromDescribe {
                                analyzeDescription(newQuery)
                            } else {
                                analyzeText(newQuery)
                            }
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
                            CameraLogView(onCapture: analyzePhoto, onSwitchToBarcode: {
                                withAnimation(FuelAnimation.snappy) {
                                    appState.selectedLogMode = .barcode
                                }
                            })
                        case .search:
                            SearchLogView(onSearch: { query, exactFood in
                                analyzeText(query, exactFood: exactFood)
                            }, onDescribe: { description in
                                analyzeDescription(description)
                            }, onQuickLog: { food in
                                quickLogFood(food)
                            }, initialQuery: initialSearchQuery)
                        case .barcode:
                            BarcodeLogView(onScan: analyzeBarcode, onSwitchToCamera: {
                                withAnimation(FuelAnimation.snappy) {
                                    appState.selectedLogMode = .camera
                                }
                            })
                        case .quickAdd:
                            QuickAddView(onLog: { analysis in logMeal(analysis) })
                        case .savedMeals:
                            SavedMealsView(onSelect: { analysis in
                                withAnimation(FuelAnimation.smooth) { analysisResult = analysis }
                            })
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
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(FuelColors.success)
                                .frame(width: 64, height: 64)
                                .background(
                                    Circle()
                                        .fill(FuelColors.success.opacity(0.12))
                                )

                            Text("Logged")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(FuelColors.ink)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(FuelColors.white)
                                .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
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
            .task {
                if let query = initialSearchQuery, !query.isEmpty {
                    appState.selectedLogMode = .search
                    // Small delay to let the view settle
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    analyzeText(query)
                }
            }
            .interactiveDismissDisabled(isLogging || isAnalyzing)
            .sheet(isPresented: $showingPaywall) {
                UpgradePaywallView(reason: .scanLimit)
            }
            .sheet(isPresented: $showingSignIn) {
                PaywallView {
                    showingSignIn = false
                    // Retry the photo scan now that we're signed in
                    if let imageData = capturedImageData {
                        analyzePhoto(imageData)
                    }
                }
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
        // Hide nav bar during photo scan AND on results page with photo (image bleeds to top)
        if isAnalyzing && capturedImageData != nil && previewResult == nil { return true }
        if analysisResult != nil && capturedImageData != nil { return true }
        return false
    }

    // MARK: - State Reset

    private func resetAnalysisState() {
        analysisResult = nil
        previewResult = nil
        capturedImageData = nil
        errorMessage = nil
        photoError = nil
        isAnalyzing = false
        lastResultFromDescribe = false
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

        capturedImageData = imageData
        isAnalyzing = true
        errorMessage = nil
        previewResult = nil
        photoError = nil

        analysisTask?.cancel()
        analysisTask = Task {
            do {
                // Downscale to 512px for faster upload — plenty for food recognition
                let smallImage: Data
                if let uiImage = UIImage(data: imageData),
                   let resized = ImageCompressor.compress(uiImage, maxBytes: 300_000, quality: 0.5) {
                    smallImage = resized
                } else {
                    smallImage = imageData
                }
                let base64 = smallImage.base64EncodedString()

                #if DEBUG
                print("[Fuel] analyzePhoto: original=\(imageData.count)B, compressed=\(smallImage.count)B, base64=\(base64.count) chars")
                #endif

                // All AI calls go through Supabase edge function (API key stays server-side)
                let scanStart = ContinuousClock.now
                let result = try await callEdgeFunction(base64: base64)

                // Ensure scan animation shows for at least 2s (feels premium)
                let elapsed = ContinuousClock.now - scanStart
                if elapsed < .seconds(2) {
                    try? await Task.sleep(for: .seconds(2) - elapsed)
                }

                #if DEBUG
                print("[Fuel] analyzePhoto: SUCCESS — \(result.displayName) (\(result.totalCalories) cal)")
                #endif
                FuelHaptics.shared.logSuccess()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    analysisResult = result
                    isAnalyzing = false
                    errorMessage = nil
                }
            } catch is CancellationError {
                withAnimation {
                    capturedImageData = nil
                    isAnalyzing = false
                    photoError = nil
                }
            } catch {
                #if DEBUG
                print("[Fuel] analyzePhoto: ERROR — \(error)")
                // Extract body from FunctionsError for debugging
                if case let FunctionsError.httpError(code, data) = error {
                    let body = String(data: data, encoding: .utf8) ?? "no body"
                    print("[Fuel] analyzePhoto: HTTP \(code) — \(body.prefix(300))")
                }
                #endif

                let errorDetail: String
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        errorDetail = "Request timed out. Please try again."
                    case .notConnectedToInternet, .networkConnectionLost:
                        errorDetail = "No internet connection."
                    default:
                        errorDetail = "Network error (\(urlError.code.rawValue))."
                    }
                } else if case let FunctionsError.httpError(code, data) = error, code == 401 {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    if body.contains("expired") {
                        errorDetail = "Session expired. Please sign out and sign back in."
                    } else {
                        errorDetail = "Please sign in to scan food."
                    }
                    Task {
                        _ = try? await Constants.supabase.auth.refreshSession()
                    }
                } else if case let FunctionsError.httpError(code, _) = error {
                    errorDetail = "Server error (\(code)). Please try again."
                } else {
                    #if DEBUG
                    errorDetail = "Analysis failed: \(error)"
                    #else
                    errorDetail = "Analysis failed. Please try again."
                    #endif
                }

                FuelHaptics.shared.error()
                withAnimation {
                    photoError = errorDetail
                }
            }
        }
    }

    // MARK: - Edge Function (API key stays server-side)

    private func callEdgeFunction(base64: String) async throws -> FoodAnalysis {
        // Get session — fresh, cached, or create anonymous on the fly
        var accessToken: String?

        if let session = try? await Constants.supabase.auth.session {
            accessToken = session.accessToken
        } else if let cached = Constants.supabase.auth.currentSession {
            accessToken = cached.accessToken
        } else {
            // Last resort: create anonymous session on the fly
            #if DEBUG
            print("[Fuel] callEdgeFunction: no session — creating anonymous")
            #endif
            try? await Constants.supabase.auth.signInAnonymously()
            accessToken = Constants.supabase.auth.currentSession?.accessToken
        }

        guard let token = accessToken else {
            throw FunctionsError.httpError(code: 401, data: Data("Could not create session".utf8))
        }

        let authHeaders = ["Authorization": "Bearer \(token)"]

        let responseData: Data = try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await Constants.supabase.functions.invoke(
                    "analyze-food",
                    options: .init(
                        headers: authHeaders,
                        body: [
                            "image": base64,
                            "request_type": "photo"
                        ] as [String: String]
                    )
                ) { data, _ in data }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw URLError(.timedOut)
            }
            guard let result = try await group.next() else {
                throw URLError(.timedOut)
            }
            group.cancelAll()
            return result
        }

        #if DEBUG
        if let responseStr = String(data: responseData, encoding: .utf8) {
            print("[Fuel] Edge function response: \(responseStr.prefix(200))")
        }
        #endif

        return try JSONDecoder().decode(FoodAnalysis.self, from: responseData)
    }

    // MARK: - Text Analysis (Database Only — no AI, no preview flash)

    private func analyzeText(_ query: String, exactFood: FoodItem? = nil) {
        lastResultFromDescribe = false

        // If user tapped an exact food from autocomplete, use it directly
        if let food = exactFood {
            let result = buildPreviewFromFood(food)
            withAnimation(FuelAnimation.smooth) {
                analysisResult = result
                previewResult = nil
                errorMessage = nil
            }
            return
        }

        guard appState.aiService != nil else {
            withAnimation { errorMessage = "Service is loading. Please try again in a moment." }
            return
        }

        isAnalyzing = true
        errorMessage = nil
        previewResult = nil

        // Database-only search: local RAG + USDA + Open Food Facts (free, instant, no AI)
        let ragPreview = appState.aiService?.previewFromRAG(query: query)
        analysisTask?.cancel()
        analysisTask = Task {
            let localResult = await appState.aiService?.searchFoodLocal(query: query)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    if let result = localResult {
                        analysisResult = result
                    } else if let preview = ragPreview {
                        analysisResult = preview
                    } else {
                        errorMessage = "Couldn't find that food. Try a simpler name like \"chicken breast\" or \"banana\"."
                    }
                    previewResult = nil
                    isAnalyzing = false
                }
            }
        }
    }

    // MARK: - AI Describe (Premium — full ingredient itemization via edge function)

    private func analyzeDescription(_ description: String) {
        guard checkRateLimit() else { return }

        lastResultFromDescribe = true
        isAnalyzing = true
        errorMessage = nil
        previewResult = nil

        analysisTask?.cancel()
        analysisTask = Task {
            do {
                // Call the edge function for AI-powered text analysis
                let result = try await callTextEdgeFunction(query: description)

                await MainActor.run {
                    FuelHaptics.shared.logSuccess()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        analysisResult = result
                        previewResult = nil
                        isAnalyzing = false
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                let errorDetail: String
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        errorDetail = "Request timed out. Please try again."
                    case .notConnectedToInternet, .networkConnectionLost:
                        errorDetail = "No internet connection."
                    default:
                        errorDetail = "Network error (\(urlError.code.rawValue))."
                    }
                } else if case let FunctionsError.httpError(code, data) = error, code == 401 {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    if body.contains("expired") {
                        errorDetail = "Session expired. Please sign out and sign back in."
                    } else {
                        errorDetail = "Please sign in to use AI describe."
                    }
                    Task {
                        _ = try? await Constants.supabase.auth.refreshSession()
                    }
                } else if case let FunctionsError.httpError(code, _) = error {
                    errorDetail = "Server error (\(code)). Please try again."
                } else {
                    #if DEBUG
                    errorDetail = "AI analysis failed: \(error)"
                    #else
                    errorDetail = "AI analysis failed. Please try again."
                    #endif
                }

                #if DEBUG
                print("[Fuel] AI describe error: \(error)")
                #endif

                // Fallback: try local database search
                let localResult = await appState.aiService?.searchFoodLocal(query: description)
                await MainActor.run {
                    FuelHaptics.shared.error()
                    withAnimation {
                        if let result = localResult {
                            analysisResult = result
                            errorMessage = "AI unavailable — showing database result instead."
                        } else {
                            errorMessage = errorDetail
                        }
                        previewResult = nil
                        isAnalyzing = false
                    }
                }
            }
        }
    }

    /// Calls the analyze-food edge function for text descriptions
    private func callTextEdgeFunction(query: String) async throws -> FoodAnalysis {
        var accessToken: String?

        if let session = try? await Constants.supabase.auth.session {
            accessToken = session.accessToken
        } else if let cached = Constants.supabase.auth.currentSession {
            accessToken = cached.accessToken
        } else {
            #if DEBUG
            print("[Fuel] callTextEdgeFunction: no session — creating anonymous")
            #endif
            try? await Constants.supabase.auth.signInAnonymously()
            accessToken = Constants.supabase.auth.currentSession?.accessToken
        }

        guard let token = accessToken else {
            throw FunctionsError.httpError(code: 401, data: Data("Could not create session".utf8))
        }

        let authHeaders = ["Authorization": "Bearer \(token)"]

        let responseData: Data = try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await Constants.supabase.functions.invoke(
                    "analyze-food",
                    options: .init(
                        headers: authHeaders,
                        body: [
                            "query": query,
                            "request_type": "text"
                        ] as [String: String]
                    )
                ) { data, _ in data }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw URLError(.timedOut)
            }
            guard let result = try await group.next() else {
                throw URLError(.timedOut)
            }
            group.cancelAll()
            return result
        }

        #if DEBUG
        if let responseStr = String(data: responseData, encoding: .utf8) {
            print("[Fuel] Text edge function response: \(responseStr.prefix(200))")
        }
        #endif

        return try JSONDecoder().decode(FoodAnalysis.self, from: responseData)
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
        let measurement = AIService.inferMeasurement(from: food)
        let item = AnalyzedFoodItem(
            id: UUID(),
            name: food.name,
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            fiber: food.fiber,
            sugar: food.sugar,
            servingSize: food.serving,
            estimatedGrams: food.servingGrams,
            measurementUnit: measurement.unit,
            measurementAmount: measurement.amount,
            confidence: food.confidence == .high ? 0.9 : 0.75,
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
            confidenceReason: nil,
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
                estimatedGrams: item.estimatedGrams,
                measurementUnit: item.measurementUnit,
                measurementAmount: item.measurementAmount,
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

    // MARK: - Quick Log (instant, no results screen)

    private func quickLogFood(_ food: FoodItem) {
        let analysis = buildPreviewFromFood(food)
        logMeal(analysis)
    }

    // MARK: - Log Meal

    private func logMeal(_ analysis: FoodAnalysis) {
        guard !isLogging else { return }

        // Use existing profile, or create a local-only one for anonymous users
        let profile: UserProfile
        if let existing = appState.userProfile {
            profile = existing
        } else if let session = Constants.supabase.auth.currentSession {
            // Anonymous user — create a temporary local profile
            let anonProfile = UserProfile(
                id: session.user.id,
                isPremium: false,
                streakCount: 0,
                longestStreak: 0,
                unitSystem: .imperial,
                createdAt: Date(),
                updatedAt: Date()
            )
            appState.userProfile = anonProfile
            profile = anonProfile
        } else {
            withAnimation { errorMessage = "Please try again." }
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
                fiber: item.fiber,
                sugar: item.sugar,
                servingSize: item.servingSize,
                estimatedGrams: item.estimatedGrams,
                measurementUnit: item.measurementUnit,
                measurementAmount: item.measurementAmount,
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
            totalFiber: analysis.fiberG ?? 0,
            totalSugar: analysis.sugarG ?? 0,
            totalSodium: analysis.sodiumMg ?? 0,
            imageUrl: nil,
            displayName: analysis.displayName,
            loggedDate: now.dateString,
            loggedAt: now,
            createdAt: now
        )

        // Ensure we're viewing today so the new meal shows in the correct list
        appState.selectedDate = Date()

        // Mark as pending sync BEFORE appending — append triggers didSet which persists to
        // UserDefaults, so the pending queue must already contain this meal at that point
        appState.markMealPending(meal)

        // Add meal to list immediately (visible behind sheet) — also persists to UserDefaults
        appState.todayMeals.append(meal)

        // Update summary IMMEDIATELY so calorie rings reflect the new meal
        appState.rebuildSummaryFromMeals()
        appState.dataVersion += 1

        // Record locally (always works, even offline)
        MealHistoryService.shared.recordMeal(name: meal.displayName, calories: meal.totalCalories)

        // Record scan for all users — rate limiter gates free users' access
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

        // Capture image data NOW before view dismisses (State vars die with the view)
        let savedImageData = capturedImageData

        // Save image to local cache immediately so MealCardView can show it
        if let imgData = savedImageData {
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("meal-images")
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            let localPath = cacheDir.appendingPathComponent("\(mealId.uuidString).jpg")
            try? imgData.write(to: localPath)
        }

        // Dismiss after celebration, then persist to DB in background
        logTask?.cancel()
        logTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                dismiss()
            }

            // Wait for sheet dismiss animation to complete
            try? await Task.sleep(for: .seconds(0.4))

            await MainActor.run {
                let totalScans = UserDefaults.standard.integer(forKey: "lifetime_scan_count") + 1
                UserDefaults.standard.set(totalScans, forKey: "lifetime_scan_count")
                if totalScans == 1 || totalScans == 5 || totalScans == 25 || totalScans == 100 {
                    if let scene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                }
            }

            // Persist to database with retry
            var saved = false
            guard let db = appState.databaseService else {
                #if DEBUG
                print("[Fuel] No database service — meal stays in pending queue")
                #endif
                await MainActor.run {
                    appState.errorMessage = "Meal saved locally. It will sync when you're back online."
                    appState.showingError = true
                }
                return
            }
            for attempt in 1...3 {
                do {
                    try await db.logMeal(meal)
                    saved = true
                    #if DEBUG
                    print("[Fuel] Meal saved to DB (attempt \(attempt))")
                    #endif
                    break
                } catch {
                    #if DEBUG
                    print("[Fuel] DB save attempt \(attempt) failed: \(error)")
                    #endif
                    if attempt < 3 {
                        try? await Task.sleep(for: .seconds(Double(attempt) * 1.0))
                    }
                }
            }

            if saved {
                // Clear from pending queue
                await MainActor.run { appState.markMealSynced(mealId) }

                // Sync summary to DB
                appState.invalidateDateCache()
                await appState.recalculateDailySummary()

                // Upload image in background (non-blocking)
                if let imageData = savedImageData {
                    #if DEBUG
                    print("[Fuel] Uploading meal image (\(imageData.count) bytes)...")
                    #endif
                    if let url = try? await appState.databaseService?.uploadMealImage(
                        userId: profile.id, mealId: mealId, imageData: imageData
                    ) {
                        #if DEBUG
                        print("[Fuel] Image uploaded: \(url.prefix(80))...")
                        #endif
                        await MainActor.run {
                            if let index = appState.todayMeals.firstIndex(where: { $0.id == mealId }) {
                                appState.todayMeals[index].imageUrl = url
                            }
                        }
                    }
                }
            } else {
                // All 3 attempts failed — meal stays in pending queue for next app open
                #if DEBUG
                print("[Fuel] Meal queued for retry: \(meal.displayName)")
                #endif
                await MainActor.run {
                    appState.errorMessage = "Meal saved locally. It will sync when you're back online."
                    appState.showingError = true
                }
            }
        }
    }
}
