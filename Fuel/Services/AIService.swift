import Foundation
import UIKit
import Supabase

struct UserNutritionContext: Sendable {
    let caloriesRemaining: Int
    let proteinRemainingG: Double
    let carbsRemainingG: Double
    let fatRemainingG: Double
    let goalType: String
    let dietStyle: String
}

actor AIService {
    private let supabase: SupabaseClient
    private var useRAG = false

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        Task { await NutritionLogger.shared.configure(supabase: supabase) }
    }

    /// Get auth headers for edge function calls. Uses fresh session or falls back to cached.
    private func authHeaders() async throws -> [String: String] {
        if let session = try? await supabase.auth.session {
            return ["Authorization": "Bearer \(session.accessToken)"]
        }
        if let cached = supabase.auth.currentSession {
            return ["Authorization": "Bearer \(cached.accessToken)"]
        }
        throw FuelError.authFailed("No active session")
    }

    /// Activate the RAG pipeline (local database + edge function routing).
    /// No API key is stored on device — all AI calls go through Supabase edge functions.
    func activateRAG() async {
        // Clear any legacy key from Keychain (from old get-api-key flow)
        ClaudeNutritionService.shared.apiKey = ""

        useRAG = true
        #if DEBUG
        print("[Fuel] RAG activated (server-side key — no key on device)")
        #endif

        // Background tasks — don't block the caller
        let client = supabase
        Task.detached(priority: .userInitiated) {
            // Pre-warm RAG index
            _ = NutritionRAG.shared.retrieve(query: "chicken", topK: 1)
        }
        Task.detached(priority: .utility) {
            // Sync remote food database (can be slow — don't block)
            await RemoteFoodSync.shared.sync(supabase: client)
            // Pre-fetch common foods after sync
            await Self.prefetchCommonFoods()
        }
    }

    /// Fetch nutrition data for commonly searched foods that may not be in the local DB.
    /// Runs once at launch, skips items already cached.
    private static func prefetchCommonFoods() async {
        let commonQueries = [
            // Core proteins
            "chicken breast", "ground beef", "salmon", "eggs", "turkey breast",
            "tuna", "shrimp", "pork chop", "steak", "tofu",
            // Staples
            "rice", "pasta", "bread", "oatmeal", "quinoa",
            "tortilla", "bagel", "english muffin", "naan",
            // Dairy
            "yogurt", "cheese", "milk", "butter", "cream cheese",
            // Produce
            "avocado", "banana", "apple", "broccoli", "spinach",
            "sweet potato", "tomato", "lettuce", "onion", "bell pepper",
            // Common meals
            "pizza", "burrito", "sushi", "burger", "sandwich",
            "tacos", "fried rice", "ramen", "pad thai", "curry",
            // Snacks & drinks
            "protein shake", "granola bar", "almonds", "hummus",
            "coffee", "orange juice", "protein bar", "trail mix",
            // Fast food
            "big mac", "chicken nuggets", "french fries", "chipotle bowl",
        ]
        for query in commonQueries {
            // Skip if already well-represented in RAG
            let existing = NutritionRAG.shared.retrieve(query: query, topK: 1)
            if (existing.first?.score ?? 0) >= 10.0 { continue }
            await fetchAndCacheFromAPIs(query: query)
            // Small delay to avoid hammering APIs
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
    }

    /// Update the user's nutrition context on ClaudeNutritionService for personalized responses.
    func updateUserContext(
        caloriesRemaining: Int,
        proteinRemaining: Double,
        carbsRemaining: Double,
        fatRemaining: Double,
        goalType: String,
        dietStyle: String
    ) {
        let ctx = UserNutritionContext(
            caloriesRemaining: caloriesRemaining,
            proteinRemainingG: proteinRemaining,
            carbsRemainingG: carbsRemaining,
            fatRemainingG: fatRemaining,
            goalType: goalType,
            dietStyle: dietStyle
        )
        ClaudeNutritionService.shared.userContext = ctx
    }

    // MARK: - Photo Analysis

    /// Callback for two-pass photo analysis: sends identified item names after pass 1 completes.
    typealias IdentifiedItemsCallback = @Sendable ([String]) -> Void

    func analyzePhoto(imageData: Data, description: String? = nil, onItemsIdentified: IdentifiedItemsCallback? = nil) async throws -> FoodAnalysis {
        let start = CFAbsoluteTimeGetCurrent()

        try Task.checkCancellation()

        #if DEBUG
        print("[Fuel] analyzePhoto: start (imageSize=\(imageData.count) bytes)")
        #endif

        // Check image hash cache first
        let imageHash = imageData.fuelHash
        if let cached = PhotoScanCache.shared.get(hash: imageHash) {
            #if DEBUG
            print("[Fuel] analyzePhoto: cache HIT")
            #endif
            return cached
        }

        try Task.checkCancellation()

        // Single path: Supabase edge function. The API key lives server-side.
        // No client-side key fetch, no branching, no fallback chains.
        #if DEBUG
        print("[Fuel] analyzePhoto: calling Supabase edge function...")
        #endif
        let result = try await analyzePhotoWithSupabase(imageData: imageData)
        #if DEBUG
        print("[Fuel] analyzePhoto: success — \(result.displayName) (\(result.totalCalories) cal)")
        #endif

        PhotoScanCache.shared.set(result, hash: imageHash)

        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        #if DEBUG
        print("[Fuel] analyzePhoto: completed in \(elapsedMs)ms")
        #endif
        await NutritionLogger.shared.log(
            queryType: .photo,
            query: result.displayName,
            ragTopScore: nil,
            ragMatchCount: 0,
            resultCalories: result.totalCalories,
            resultConfidence: result.confidenceReason ?? "unknown",
            responseTimeMs: elapsedMs
        )

        return result
    }

    private func analyzePhotoWithRAG(imageData: Data, description: String? = nil, onItemsIdentified: IdentifiedItemsCallback? = nil) async throws -> FoodAnalysis {
        // Track identified items for fallback if Claude fails on pass 2
        // Use a sendable box to safely capture items across concurrency boundaries
        let capturedBox = SendableBox<[String]>([])
        let wrappedCallback: IdentifiedItemsCallback = { items in
            capturedBox.value = items
            onItemsIdentified?(items)
        }

        try Task.checkCancellation()

        let analysis: NutritionAnalysis
        do {
            analysis = try await ClaudeNutritionService.shared.analyze(imageData: imageData, additionalDescription: description, onItemsIdentified: wrappedCallback)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            // Structured fallback: if pass 1 identified items, build result from RAG
            let capturedItems = capturedBox.value
            if !capturedItems.isEmpty {
                if let fallback = offlineEstimateFromItems(capturedItems) {
                    var result = fallback
                    let warning = "AI analysis failed — using database estimate"
                    let existing = result.warnings ?? []
                    result = FoodAnalysis(
                        items: result.items, displayName: result.displayName,
                        totalCalories: result.totalCalories, totalProtein: result.totalProtein,
                        totalCarbs: result.totalCarbs, totalFat: result.totalFat,
                        fiberG: result.fiberG, sugarG: result.sugarG, sodiumMg: result.sodiumMg,
                        warnings: existing + [warning],
                        healthInsight: result.healthInsight, calorieRange: result.calorieRange,
                        confidenceReason: "Fallback: RAG estimate from identified items",
                        servingAssumed: result.servingAssumed
                    )
                    return result
                }
            }
            // If description was provided, try text-based offline estimate
            if let desc = description, let fallback = offlineEstimate(query: desc) {
                return fallback
            }
            throw error
        }

        try Task.checkCancellation()

        // If Claude read values from a nutrition label, skip RAG cross-validation
        // since label values are ground truth.
        if isNutritionLabelAnalysis(analysis) {
            var foodAnalysis = analysis.toFoodAnalysis()
            let labelNote = "Values read directly from nutrition label"
            let existing = foodAnalysis.confidenceReason.map { $0 + ". " + labelNote } ?? labelNote
            foodAnalysis = FoodAnalysis(
                items: foodAnalysis.items,
                displayName: foodAnalysis.displayName,
                totalCalories: foodAnalysis.totalCalories,
                totalProtein: foodAnalysis.totalProtein,
                totalCarbs: foodAnalysis.totalCarbs,
                totalFat: foodAnalysis.totalFat,
                fiberG: foodAnalysis.fiberG,
                sugarG: foodAnalysis.sugarG,
                sodiumMg: foodAnalysis.sodiumMg,
                warnings: foodAnalysis.warnings,
                healthInsight: foodAnalysis.healthInsight,
                calorieRange: foodAnalysis.calorieRange,
                confidenceReason: existing,
                servingAssumed: foodAnalysis.servingAssumed
            )
            return foodAnalysis
        }

        try Task.checkCancellation()
        var foodAnalysis = analysis.toFoodAnalysis()
        foodAnalysis = deduplicateItems(foodAnalysis)
        foodAnalysis = crossValidateWithRAG(foodAnalysis)
        foodAnalysis = applyUserCorrections(foodAnalysis)
        foodAnalysis = tightenWideRange(foodAnalysis)
        foodAnalysis = flagOutlierItems(foodAnalysis)
        foodAnalysis = crossItemSanityCheck(foodAnalysis)
        foodAnalysis = validateMacroMath(foodAnalysis)
        foodAnalysis = computeScanConfidence(foodAnalysis)

        // Background: cache unrecognized or low-confidence items via API
        let itemNames = foodAnalysis.items.map { $0.name }
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for name in itemNames {
                    group.addTask {
                        let results = NutritionRAG.shared.retrieve(query: name, topK: 1)
                        let score = results.first?.score ?? 0
                        let confidence = results.first?.food.confidence
                        // Fetch if: no match, weak match, or low-confidence match
                        if score < 5.0 || confidence == .low {
                            await Self.fetchAndCacheFromAPIs(query: name)
                        }
                    }
                }
            }
        }

        return foodAnalysis
    }

    /// Detect whether Claude's analysis was based on reading a nutrition label.
    private func isNutritionLabelAnalysis(_ analysis: NutritionAnalysis) -> Bool {
        let reason = (analysis.confidenceReason ?? "").lowercased()
        let labelKeywords = ["nutrition label", "nutrition facts", "printed values", "label"]
        let mentionsLabel = labelKeywords.contains { reason.contains($0) }

        if mentionsLabel {
            return true
        }

        // Fallback: high confidence with very precise values (all macros present and non-zero)
        // is a secondary signal, but only trust it if the reason also hints at a label.
        return false
    }

    /// Enterprise-level cross-validation of Claude's analysis against the RAG database.
    /// - Auto-corrects calories when RAG has high-confidence data and Claude is way off
    /// - Fills missing micronutrients from RAG
    /// - Adjusts confidence scores based on RAG agreement/disagreement
    /// - Caches identified items for future lookups
    private func crossValidateWithRAG(_ analysis: FoodAnalysis) -> FoodAnalysis {
        var validatedItems = [AnalyzedFoodItem]()
        var additionalWarnings = [String]()

        // Accumulators for micronutrients from RAG when Claude returned nil/0
        var ragFiber: Double? = analysis.fiberG
        var ragSugar: Double? = analysis.sugarG
        var ragSodium: Double? = analysis.sodiumMg

        for item in analysis.items {
            let ragResults = NutritionRAG.shared.retrieve(query: item.name, topK: 3)
            guard let best = ragResults.first, best.score >= 3.0 else {
                // No RAG match — lower confidence slightly
                validatedItems.append(AnalyzedFoodItem(
                    id: item.id, name: item.name,
                    calories: item.calories, protein: item.protein,
                    carbs: item.carbs, fat: item.fat,
                    fiber: item.fiber, sugar: item.sugar,
                    servingSize: item.servingSize,
                    estimatedGrams: item.estimatedGrams,
                    measurementUnit: item.measurementUnit,
                    measurementAmount: item.measurementAmount,
                    confidence: min(item.confidence, 0.7),
                    note: item.note
                ))
                continue
            }

            let ragFood = best.food
            let ragCal = ragFood.calories
            let claudeCal = item.calories

            // Portion-aware comparison: estimate how many servings Claude assumed
            let portionScale = claudeCal > 0 && ragCal > 0
                ? Double(claudeCal) / Double(ragCal)
                : 1.0

            // Smart deviation: if portion scale is close to an integer (1x, 2x, 3x),
            // compare per-unit values rather than raw totals. This prevents flagging
            // "2 eggs" (180 cal) vs RAG "1 egg" (90 cal) as 100% deviation.
            let nearestWhole = round(portionScale)
            let isCleanMultiple = nearestWhole >= 1.0 && nearestWhole <= 6.0
                && abs(portionScale - nearestWhole) < 0.25
            let deviation: Double
            if isCleanMultiple && nearestWhole > 0 && ragCal > 0 {
                let perUnit = Double(claudeCal) / nearestWhole
                deviation = abs(perUnit - Double(ragCal)) / Double(ragCal)
            } else if ragCal > 0 {
                deviation = abs(Double(claudeCal - ragCal)) / Double(ragCal)
            } else {
                deviation = 0
            }

            var correctedCal = item.calories
            var correctedP = item.protein
            var correctedC = item.carbs
            var correctedF = item.fat
            var updatedNote = item.note
            var itemConfidence = item.confidence

            if best.score >= 10.0 && ragFood.confidence == .high && deviation > 0.5 {
                // HIGH-CONFIDENCE RAG + >50% off → AUTO-CORRECT to RAG values
                // Scale RAG values by Claude's estimated portion
                let clampedScale = min(max(portionScale, 0.5), 4.0) // Clamp to 0.5x-4x
                correctedCal = Int(Double(ragFood.calories) * clampedScale)
                correctedP = round(ragFood.protein * clampedScale * 10) / 10
                correctedC = round(ragFood.carbs * clampedScale * 10) / 10
                correctedF = round(ragFood.fat * clampedScale * 10) / 10

                let correction = "Auto-corrected from \(claudeCal) to \(correctedCal) cal using USDA data for \(ragFood.name) (\(ragFood.serving))"
                additionalWarnings.append("\(item.name): \(correction)")
                updatedNote = correction
                itemConfidence = 0.9 // High confidence after RAG correction

            } else if deviation > 0.4 {
                // >40% off with non-perfect match — warn but don't auto-correct
                let warning = "Estimate differs from database (\(ragCal) cal for \(ragFood.serving))"
                additionalWarnings.append("\(item.name): \(warning)")
                updatedNote = (updatedNote.map { $0 + ". " } ?? "") + warning
                itemConfidence = min(itemConfidence, 0.6) // Lower confidence

            } else if deviation > 0.2 {
                // 20-40% off — add reference note
                let ref = "Database ref: \(ragCal) cal per \(ragFood.serving)"
                updatedNote = (updatedNote.map { $0 + ". " } ?? "") + ref
                // Nudge Claude's values toward RAG by 30% (soft correction)
                let nudgeFactor = 0.3
                correctedCal = Int(Double(claudeCal) + nudgeFactor * Double(ragCal - claudeCal))
                correctedP = item.protein + nudgeFactor * (ragFood.protein * portionScale - item.protein)
                correctedC = item.carbs + nudgeFactor * (ragFood.carbs * portionScale - item.carbs)
                correctedF = item.fat + nudgeFactor * (ragFood.fat * portionScale - item.fat)
                correctedP = round(correctedP * 10) / 10
                correctedC = round(correctedC * 10) / 10
                correctedF = round(correctedF * 10) / 10

            } else {
                // <=20% off — Claude agrees with RAG. Boost confidence.
                itemConfidence = min(1.0, itemConfidence + 0.1)
            }

            validatedItems.append(AnalyzedFoodItem(
                id: item.id, name: item.name,
                calories: correctedCal, protein: correctedP,
                carbs: correctedC, fat: correctedF,
                fiber: item.fiber, sugar: item.sugar,
                servingSize: item.servingSize,
                estimatedGrams: item.estimatedGrams,
                measurementUnit: item.measurementUnit,
                measurementAmount: item.measurementAmount,
                confidence: itemConfidence,
                note: updatedNote
            ))

            // Fill missing micronutrients from RAG
            let scale = max(portionScale, 1.0)
            if (ragFiber ?? 0) == 0 && ragFood.fiber > 0 {
                ragFiber = (ragFiber ?? 0) + ragFood.fiber * scale
            }
            if (ragSugar ?? 0) == 0 && ragFood.sugar > 0 {
                ragSugar = (ragSugar ?? 0) + ragFood.sugar * scale
            }
            if (ragSodium ?? 0) == 0 && ragFood.sodium > 0 {
                ragSodium = (ragSodium ?? 0) + ragFood.sodium * scale
            }
        }

        let allWarnings: [String]? = {
            let existing = analysis.warnings ?? []
            let combined = existing + additionalWarnings
            return combined.isEmpty ? nil : combined
        }()

        // Recompute totals from validated items (single source of truth)
        let correctedTotalCal = validatedItems.reduce(0) { $0 + $1.calories }
        let correctedTotalP = round(validatedItems.reduce(0.0) { $0 + $1.protein } * 10) / 10
        let correctedTotalC = round(validatedItems.reduce(0.0) { $0 + $1.carbs } * 10) / 10
        let correctedTotalF = round(validatedItems.reduce(0.0) { $0 + $1.fat } * 10) / 10

        // Update confidence reason if corrections were made
        var confidenceReason = analysis.confidenceReason
        let calDiff = correctedTotalCal - analysis.totalCalories
        if calDiff != 0 {
            let adjustNote = "RAG-validated (adjusted \(calDiff > 0 ? "+" : "")\(calDiff) cal)"
            confidenceReason = (confidenceReason.map { $0 + ". " } ?? "") + adjustNote
        }

        return FoodAnalysis(
            items: validatedItems,
            displayName: analysis.displayName,
            totalCalories: correctedTotalCal,
            totalProtein: correctedTotalP,
            totalCarbs: correctedTotalC,
            totalFat: correctedTotalF,
            fiberG: ragFiber,
            sugarG: ragSugar,
            sodiumMg: ragSodium,
            cholesterolMg: analysis.cholesterolMg,
            saturatedFatG: analysis.saturatedFatG,
            warnings: allWarnings,
            healthInsight: analysis.healthInsight,
            calorieRange: analysis.calorieRange,
            confidenceReason: confidenceReason,
            servingAssumed: analysis.servingAssumed
        )
    }

    /// Compute overall scan confidence based on RAG match quality, macro consistency, and range tightness.
    /// Replaces generic Claude confidence with a data-driven score.
    private func computeScanConfidence(_ analysis: FoodAnalysis) -> FoodAnalysis {
        var score: Double = 0.7 // Base confidence

        // Factor 1: Average item confidence from RAG cross-validation
        let avgItemConfidence = analysis.items.isEmpty ? 0.5
            : analysis.items.reduce(0.0) { $0 + $1.confidence } / Double(analysis.items.count)
        score = score * 0.4 + avgItemConfidence * 0.6

        // Factor 2: RAG match quality — how many items have strong database matches
        var ragMatchCount = 0
        for item in analysis.items {
            let results = NutritionRAG.shared.retrieve(query: item.name, topK: 1)
            if let best = results.first, best.score >= 8.0 {
                ragMatchCount += 1
            }
        }
        let ragCoverage = analysis.items.isEmpty ? 0.0 : Double(ragMatchCount) / Double(analysis.items.count)
        score += ragCoverage * 0.15 // Up to +15% for full RAG coverage

        // Factor 3: Macro math consistency (P×4 + C×4 + F×9 ≈ total)
        let computedCal = Int(analysis.totalProtein * 4 + analysis.totalCarbs * 4 + analysis.totalFat * 9)
        if computedCal > 0 {
            let macroDeviation = abs(Double(analysis.totalCalories - computedCal)) / Double(computedCal)
            if macroDeviation < 0.10 {
                score += 0.05 // Tight macro alignment
            } else if macroDeviation > 0.25 {
                score -= 0.10 // Poor alignment
            }
        }

        // Factor 4: Calorie range tightness
        if let range = analysis.calorieRange, range.low > 0, range.high > range.low {
            let spread = Double(range.high - range.low) / Double(range.low)
            if spread < 0.2 { score += 0.05 } // Tight range = high confidence
            else if spread > 0.5 { score -= 0.05 } // Wide range = lower confidence
        }

        // Clamp final score
        let finalConfidence = min(0.98, max(0.3, score))

        // Update each item's confidence proportionally
        let items = analysis.items.map { item -> AnalyzedFoodItem in
            let adjusted = min(0.98, max(0.3, item.confidence * (finalConfidence / max(avgItemConfidence, 0.3))))
            return AnalyzedFoodItem(
                id: item.id, name: item.name,
                calories: item.calories, protein: item.protein,
                carbs: item.carbs, fat: item.fat,
                fiber: item.fiber, sugar: item.sugar,
                servingSize: item.servingSize,
                estimatedGrams: item.estimatedGrams,
                measurementUnit: item.measurementUnit,
                measurementAmount: item.measurementAmount,
                confidence: adjusted,
                note: item.note
            )
        }

        // Build confidence reason
        let confidenceLabel: String
        if finalConfidence >= 0.85 { confidenceLabel = "High" }
        else if finalConfidence >= 0.65 { confidenceLabel = "Medium" }
        else { confidenceLabel = "Low" }
        let ragNote = "\(ragMatchCount)/\(analysis.items.count) items matched in database"
        let newReason = "\(confidenceLabel) confidence (\(String(format: "%.0f", finalConfidence * 100))%). \(ragNote)"
        let fullReason = analysis.confidenceReason.map { $0 + ". " + newReason } ?? newReason

        return FoodAnalysis(
            items: items, displayName: analysis.displayName,
            totalCalories: analysis.totalCalories, totalProtein: analysis.totalProtein,
            totalCarbs: analysis.totalCarbs, totalFat: analysis.totalFat,
            fiberG: analysis.fiberG, sugarG: analysis.sugarG, sodiumMg: analysis.sodiumMg,
            warnings: analysis.warnings, healthInsight: analysis.healthInsight,
            calorieRange: analysis.calorieRange,
            confidenceReason: fullReason,
            servingAssumed: analysis.servingAssumed
        )
    }

    /// Cross-item sanity check: flag implausible relative calorie ordering.
    /// E.g., "side salad" at 600 cal next to "cheeseburger" at 300 cal.
    private func crossItemSanityCheck(_ analysis: FoodAnalysis) -> FoodAnalysis {
        guard analysis.items.count >= 2 else { return analysis }

        // Known "light" keywords that should have lower calories than "heavy" items
        let lightKeywords = ["salad", "side", "vegetable", "veggies", "broccoli", "fruit", "soup", "diet",
                             "steamed", "raw", "plain", "lettuce", "celery", "cucumber", "tomato slice",
                             "dressing", "sauce", "condiment", "pickle", "lemon"]
        let heavyKeywords = ["burger", "steak", "pizza", "fries", "fried", "burrito", "pasta",
                             "mac and cheese", "nachos", "cheesecake", "ribs", "wings", "loaded",
                             "deep dish", "calzone", "pulled pork", "brisket", "lasagna"]

        var warnings = analysis.warnings ?? []
        var flagged = false

        for light in analysis.items {
            let lightName = light.name.lowercased()
            guard lightKeywords.contains(where: { lightName.contains($0) }) else { continue }

            for heavy in analysis.items where heavy.id != light.id {
                let heavyName = heavy.name.lowercased()
                guard heavyKeywords.contains(where: { heavyName.contains($0) }) else { continue }

                // A "light" item shouldn't have more calories than a "heavy" item
                if light.calories > heavy.calories && light.calories > 200 {
                    warnings.append("\(light.name) (\(light.calories) cal) seems high relative to \(heavy.name) (\(heavy.calories) cal) — verify portions")
                    flagged = true
                }
            }
        }

        guard flagged else { return analysis }
        return FoodAnalysis(
            items: analysis.items, displayName: analysis.displayName,
            totalCalories: analysis.totalCalories, totalProtein: analysis.totalProtein,
            totalCarbs: analysis.totalCarbs, totalFat: analysis.totalFat,
            fiberG: analysis.fiberG, sugarG: analysis.sugarG, sodiumMg: analysis.sodiumMg,
            warnings: warnings, healthInsight: analysis.healthInsight,
            calorieRange: analysis.calorieRange,
            confidenceReason: analysis.confidenceReason,
            servingAssumed: analysis.servingAssumed
        )
    }

    /// Flag or cap items with suspiciously extreme calorie values.
    /// Single items >2500 cal or <5 cal (non-zero) are almost certainly errors.
    private func flagOutlierItems(_ analysis: FoodAnalysis) -> FoodAnalysis {
        var warnings = analysis.warnings ?? []
        var needsUpdate = false

        let items = analysis.items.map { item -> AnalyzedFoodItem in
            // Single item over 2500 cal is suspicious (even a large pizza slice is ~400)
            if item.calories > 2500 {
                warnings.append("\(item.name) shows \(item.calories) cal — this seems unusually high. Verify portion size.")
                needsUpdate = true
                return AnalyzedFoodItem(
                    id: item.id, name: item.name,
                    calories: item.calories, protein: item.protein,
                    carbs: item.carbs, fat: item.fat,
                    fiber: item.fiber, sugar: item.sugar,
                    servingSize: item.servingSize,
                    estimatedGrams: item.estimatedGrams,
                    measurementUnit: item.measurementUnit,
                    measurementAmount: item.measurementAmount,
                    confidence: min(item.confidence, 0.5),
                    note: (item.note.map { $0 + ". " } ?? "") + "Unusually high — please verify"
                )
            }
            // Non-zero but suspiciously low (e.g., "steak: 3 cal")
            if item.calories > 0 && item.calories < 5 {
                warnings.append("\(item.name) shows only \(item.calories) cal — this seems too low.")
                needsUpdate = true
                return AnalyzedFoodItem(
                    id: item.id, name: item.name,
                    calories: item.calories, protein: item.protein,
                    carbs: item.carbs, fat: item.fat,
                    fiber: item.fiber, sugar: item.sugar,
                    servingSize: item.servingSize,
                    estimatedGrams: item.estimatedGrams,
                    measurementUnit: item.measurementUnit,
                    measurementAmount: item.measurementAmount,
                    confidence: min(item.confidence, 0.4),
                    note: (item.note.map { $0 + ". " } ?? "") + "Unusually low — please verify"
                )
            }
            // Macro impossible check: if macros exceed calories, scale ALL macros proportionally
            let macroCalories = item.protein * 4 + item.carbs * 4 + item.fat * 9
            if item.calories > 0 && macroCalories > Double(item.calories) * 1.15 {
                needsUpdate = true
                let scaleFactor = Double(item.calories) / macroCalories
                return AnalyzedFoodItem(
                    id: item.id, name: item.name,
                    calories: item.calories,
                    protein: round(item.protein * scaleFactor * 10) / 10,
                    carbs: round(item.carbs * scaleFactor * 10) / 10,
                    fat: round(item.fat * scaleFactor * 10) / 10,
                    servingSize: item.servingSize,
                    estimatedGrams: item.estimatedGrams,
                    measurementUnit: item.measurementUnit,
                    measurementAmount: item.measurementAmount,
                    confidence: item.confidence,
                    note: item.note
                )
            }
            // Negative values guard: clamp to zero
            if item.calories < 0 || item.protein < 0 || item.carbs < 0 || item.fat < 0 {
                needsUpdate = true
                return AnalyzedFoodItem(
                    id: item.id, name: item.name,
                    calories: max(item.calories, 0),
                    protein: max(item.protein, 0),
                    carbs: max(item.carbs, 0), fat: max(item.fat, 0),
                    fiber: max(item.fiber, 0), sugar: max(item.sugar, 0),
                    servingSize: item.servingSize,
                    estimatedGrams: item.estimatedGrams,
                    measurementUnit: item.measurementUnit,
                    measurementAmount: item.measurementAmount,
                    confidence: min(item.confidence, 0.5),
                    note: (item.note.map { $0 + ". " } ?? "") + "Negative values corrected"
                )
            }
            // Zero-calorie with non-zero macros: fix calories from macros
            if item.calories == 0 && (item.protein > 0 || item.carbs > 0 || item.fat > 0) {
                needsUpdate = true
                let computedCal = Int(item.protein * 4 + item.carbs * 4 + item.fat * 9)
                return AnalyzedFoodItem(
                    id: item.id, name: item.name,
                    calories: computedCal,
                    protein: item.protein,
                    carbs: item.carbs, fat: item.fat,
                    fiber: item.fiber, sugar: item.sugar,
                    servingSize: item.servingSize,
                    estimatedGrams: item.estimatedGrams,
                    measurementUnit: item.measurementUnit,
                    measurementAmount: item.measurementAmount,
                    confidence: min(item.confidence, 0.6),
                    note: (item.note.map { $0 + ". " } ?? "") + "Calories computed from macros"
                )
            }
            return item
        }

        guard needsUpdate else { return analysis }

        let totalCal = items.reduce(0) { $0 + $1.calories }
        let totalP = round(items.reduce(0.0) { $0 + $1.protein } * 10) / 10
        let totalC = round(items.reduce(0.0) { $0 + $1.carbs } * 10) / 10
        let totalF = round(items.reduce(0.0) { $0 + $1.fat } * 10) / 10

        return FoodAnalysis(
            items: items, displayName: analysis.displayName,
            totalCalories: totalCal, totalProtein: totalP,
            totalCarbs: totalC, totalFat: totalF,
            fiberG: analysis.fiberG, sugarG: analysis.sugarG, sodiumMg: analysis.sodiumMg,
            warnings: warnings.isEmpty ? nil : warnings,
            healthInsight: analysis.healthInsight, calorieRange: analysis.calorieRange,
            confidenceReason: analysis.confidenceReason,
            servingAssumed: analysis.servingAssumed
        )
    }

    private func tightenWideRange(_ analysis: FoodAnalysis) -> FoodAnalysis {
        guard let range = analysis.calorieRange, range.high > range.low, range.low > 0 else {
            return analysis
        }
        let spread = Double(range.high - range.low) / Double(range.low)
        guard spread > 0.4 else { return analysis } // Only act on wide ranges

        let mid = (range.low + range.high) / 2
        let current = analysis.totalCalories

        // If current is already near the midpoint, leave it
        let midDeviation = abs(Double(current - mid)) / Double(mid)
        guard midDeviation > 0.15 else { return analysis }

        // Nudge 40% toward midpoint
        let nudged = Int(Double(current) + 0.4 * Double(mid - current))
        let scaleFactor = current > 0 ? Double(nudged) / Double(current) : 1.0

        // Scale items proportionally so sum(items.calories) == totalCalories
        let items = analysis.items.map { item -> AnalyzedFoodItem in
            AnalyzedFoodItem(
                id: item.id, name: item.name,
                calories: Int(Double(item.calories) * scaleFactor),
                protein: round(item.protein * scaleFactor * 10) / 10,
                carbs: round(item.carbs * scaleFactor * 10) / 10,
                fat: round(item.fat * scaleFactor * 10) / 10,
                fiber: round(item.fiber * scaleFactor * 10) / 10,
                sugar: round(item.sugar * scaleFactor * 10) / 10,
                servingSize: item.servingSize,
                estimatedGrams: round(item.estimatedGrams * scaleFactor * 10) / 10,
                measurementUnit: item.measurementUnit,
                measurementAmount: round(item.measurementAmount * scaleFactor * 10) / 10,
                confidence: item.confidence,
                note: item.note
            )
        }

        let totalP = round(items.reduce(0.0) { $0 + $1.protein } * 10) / 10
        let totalC = round(items.reduce(0.0) { $0 + $1.carbs } * 10) / 10
        let totalF = round(items.reduce(0.0) { $0 + $1.fat } * 10) / 10

        return FoodAnalysis(
            items: items, displayName: analysis.displayName,
            totalCalories: nudged, totalProtein: totalP,
            totalCarbs: totalC, totalFat: totalF,
            fiberG: analysis.fiberG, sugarG: analysis.sugarG, sodiumMg: analysis.sodiumMg,
            warnings: analysis.warnings, healthInsight: analysis.healthInsight,
            calorieRange: analysis.calorieRange,
            confidenceReason: (analysis.confidenceReason.map { $0 + ". " } ?? "") + "Wide range detected — nudged toward midpoint",
            servingAssumed: analysis.servingAssumed
        )
    }

    /// Apply learned user correction factors to items where the user has a consistent pattern.
    /// E.g., if the user always bumps "chicken breast" from 250 to 300 cal, we auto-apply 1.2x.
    private func applyUserCorrections(_ analysis: FoodAnalysis) -> FoodAnalysis {
        var corrected = false
        let items = analysis.items.map { item -> AnalyzedFoodItem in
            guard let factor = MealHistoryService.shared.correctionFactor(for: item.name),
                  abs(factor - 1.0) > 0.05 else { return item }
            corrected = true
            return AnalyzedFoodItem(
                id: item.id, name: item.name,
                calories: Int(Double(item.calories) * factor),
                protein: round(item.protein * factor * 10) / 10,
                carbs: round(item.carbs * factor * 10) / 10,
                fat: round(item.fat * factor * 10) / 10,
                fiber: round(item.fiber * factor * 10) / 10,
                sugar: round(item.sugar * factor * 10) / 10,
                servingSize: item.servingSize,
                estimatedGrams: round(item.estimatedGrams * factor * 10) / 10,
                measurementUnit: item.measurementUnit,
                measurementAmount: round(item.measurementAmount * factor * 10) / 10,
                confidence: item.confidence,
                note: (item.note.map { $0 + ". " } ?? "") + "Adjusted based on your history"
            )
        }
        guard corrected else { return analysis }

        let totalCal = items.reduce(0) { $0 + $1.calories }
        let totalP = round(items.reduce(0.0) { $0 + $1.protein } * 10) / 10
        let totalC = round(items.reduce(0.0) { $0 + $1.carbs } * 10) / 10
        let totalF = round(items.reduce(0.0) { $0 + $1.fat } * 10) / 10

        return FoodAnalysis(
            items: items, displayName: analysis.displayName,
            totalCalories: totalCal, totalProtein: totalP,
            totalCarbs: totalC, totalFat: totalF,
            fiberG: analysis.fiberG, sugarG: analysis.sugarG, sodiumMg: analysis.sodiumMg,
            warnings: analysis.warnings, healthInsight: analysis.healthInsight,
            calorieRange: analysis.calorieRange,
            confidenceReason: (analysis.confidenceReason.map { $0 + ". " } ?? "") + "Personalized from your corrections",
            servingAssumed: analysis.servingAssumed
        )
    }

    private func validateMacroMath(_ analysis: FoodAnalysis) -> FoodAnalysis {
        var correctedCal = analysis.totalCalories
        var warnings = analysis.warnings ?? []

        // Step 1: Macro math check — P×4 + (C-Fiber)×4 + F×9 ≈ total
        // Fiber is 0-2 cal/g vs 4 cal/g for digestible carbs, so subtract it
        let fiberG = analysis.fiberG ?? 0
        let digestibleCarbs = max(analysis.totalCarbs - fiberG, 0)
        let computedCal = Int(analysis.totalProtein * 4 + digestibleCarbs * 4 + fiberG * 2 + analysis.totalFat * 9)
        if computedCal > 0 {
            let deviation = abs(Double(correctedCal - computedCal)) / Double(computedCal)
            if deviation > 0.15 {
                warnings.append("Calorie total adjusted from \(correctedCal) to \(computedCal) to match macro breakdown")
                correctedCal = computedCal
            }
        }

        // Step 2: Clamp to Claude's own calorie range (sanity bounds)
        if let range = analysis.calorieRange, range.low > 0, range.high > range.low {
            if correctedCal < range.low {
                warnings.append("Calories raised from \(correctedCal) to \(range.low) (below estimated range)")
                correctedCal = range.low
            } else if correctedCal > range.high {
                warnings.append("Calories lowered from \(correctedCal) to \(range.high) (above estimated range)")
                correctedCal = range.high
            }
        }

        guard correctedCal != analysis.totalCalories else { return analysis }

        // Scale items proportionally so sum(items.calories) == correctedCal
        let scaleFactor = analysis.totalCalories > 0 ? Double(correctedCal) / Double(analysis.totalCalories) : 1.0
        let scaledItems = analysis.items.map { item -> AnalyzedFoodItem in
            AnalyzedFoodItem(
                id: item.id, name: item.name,
                calories: Int(Double(item.calories) * scaleFactor),
                protein: round(item.protein * scaleFactor * 10) / 10,
                carbs: round(item.carbs * scaleFactor * 10) / 10,
                fat: round(item.fat * scaleFactor * 10) / 10,
                fiber: round(item.fiber * scaleFactor * 10) / 10,
                sugar: round(item.sugar * scaleFactor * 10) / 10,
                servingSize: item.servingSize,
                estimatedGrams: round(item.estimatedGrams * scaleFactor * 10) / 10,
                measurementUnit: item.measurementUnit,
                measurementAmount: round(item.measurementAmount * scaleFactor * 10) / 10,
                confidence: item.confidence,
                note: item.note
            )
        }
        let totalP = round(scaledItems.reduce(0.0) { $0 + $1.protein } * 10) / 10
        let totalC = round(scaledItems.reduce(0.0) { $0 + $1.carbs } * 10) / 10
        let totalF = round(scaledItems.reduce(0.0) { $0 + $1.fat } * 10) / 10

        return FoodAnalysis(
            items: scaledItems,
            displayName: analysis.displayName,
            totalCalories: correctedCal,
            totalProtein: totalP,
            totalCarbs: totalC,
            totalFat: totalF,
            fiberG: analysis.fiberG,
            sugarG: analysis.sugarG,
            sodiumMg: analysis.sodiumMg,
            warnings: warnings,
            healthInsight: analysis.healthInsight,
            calorieRange: analysis.calorieRange,
            confidenceReason: analysis.confidenceReason,
            servingAssumed: analysis.servingAssumed
        )
    }

    /// Merge duplicate items (same name, case-insensitive) by summing their values.
    /// Normalize item name for deduplication: strip leading quantities, singularize common plurals
    private func deduplicationKey(_ name: String) -> String {
        var key = name.lowercased().trimmingCharacters(in: .whitespaces)
        // Strip leading quantity (e.g. "2 eggs" → "eggs", "3x chicken strips" → "chicken strips")
        let quantityPattern = /^\d+\.?\d*\s*(x\s+)?/
        key = key.replacing(quantityPattern, with: "")
        // Simple plural → singular for common food suffixes
        let pluralMappings = [
            "eggs": "egg", "slices": "slice", "pieces": "piece", "strips": "strip",
            "wings": "wing", "thighs": "thigh", "breasts": "breast", "patties": "patty",
            "tortillas": "tortilla", "buns": "bun", "rolls": "roll", "cookies": "cookie",
            "nuggets": "nugget", "fries": "fry", "tacos": "taco", "tomatoes": "tomato",
            "potatoes": "potato", "onions": "onion", "pickles": "pickle", "berries": "berry",
            "bananas": "banana", "apples": "apple", "oranges": "orange",
        ]
        for (plural, singular) in pluralMappings {
            if key.hasSuffix(plural) {
                key = String(key.dropLast(plural.count)) + singular
                break
            }
        }
        return key.trimmingCharacters(in: .whitespaces)
    }

    private func deduplicateItems(_ analysis: FoodAnalysis) -> FoodAnalysis {
        var seen: [String: Int] = [:] // normalized name -> index in merged array
        var merged = [AnalyzedFoodItem]()

        for item in analysis.items {
            let key = deduplicationKey(item.name)
            if let idx = seen[key] {
                let existing = merged[idx]
                // Merge notes from both items
                let mergedNote: String? = {
                    switch (existing.note, item.note) {
                    case let (a?, b?): return a + ". " + b
                    case let (a?, nil): return a
                    case let (nil, b?): return b
                    case (nil, nil): return nil
                    }
                }()
                merged[idx] = AnalyzedFoodItem(
                    id: existing.id,
                    name: existing.name,
                    calories: existing.calories + item.calories,
                    protein: round((existing.protein + item.protein) * 10) / 10,
                    carbs: round((existing.carbs + item.carbs) * 10) / 10,
                    fat: round((existing.fat + item.fat) * 10) / 10,
                    servingSize: existing.servingSize,
                    confidence: min(existing.confidence, item.confidence),
                    note: mergedNote
                )
            } else {
                seen[key] = merged.count
                merged.append(item)
            }
        }

        guard merged.count < analysis.items.count else { return analysis }

        // Recompute totals from merged items
        let totalCal = merged.reduce(0) { $0 + $1.calories }
        let totalP = round(merged.reduce(0.0) { $0 + $1.protein } * 10) / 10
        let totalC = round(merged.reduce(0.0) { $0 + $1.carbs } * 10) / 10
        let totalF = round(merged.reduce(0.0) { $0 + $1.fat } * 10) / 10

        return FoodAnalysis(
            items: merged,
            displayName: analysis.displayName,
            totalCalories: totalCal,
            totalProtein: totalP,
            totalCarbs: totalC,
            totalFat: totalF,
            fiberG: analysis.fiberG,
            sugarG: analysis.sugarG,
            sodiumMg: analysis.sodiumMg,
            warnings: analysis.warnings,
            healthInsight: analysis.healthInsight,
            calorieRange: analysis.calorieRange,
            confidenceReason: analysis.confidenceReason,
            servingAssumed: analysis.servingAssumed
        )
    }

    private func analyzePhotoWithSupabase(imageData: Data) async throws -> FoodAnalysis {
        let base64 = imageData.base64EncodedString()
        #if DEBUG
        print("[Fuel] analyzePhotoWithSupabase: calling analyze-food edge function (base64=\(base64.count) chars)...")
        #endif
        do {
            let result: FoodAnalysis = try await supabase.functions.invoke(
                "analyze-food",
                options: .init(body: [
                    "image": base64,
                    "request_type": "photo"
                ] as [String: String])
            )
            #if DEBUG
            print("[Fuel] analyzePhotoWithSupabase: success — \(result.displayName) (\(result.totalCalories) cal)")
            #endif
            return result
        } catch {
            #if DEBUG
            print("[Fuel] analyzePhotoWithSupabase FAILED: \(error)")
            #endif
            throw error
        }
    }

    // MARK: - Instant RAG Preview (local-only, < 10ms)

    nonisolated func previewFromRAG(query: String) -> FoodAnalysis? {
        let parsed = PortionParser.shared.parse(query)
        let results = NutritionRAG.shared.retrieve(query: parsed.cleanedFoodName, topK: 1)
        guard let best = results.first, best.score >= 3.0 else { return nil }
        let food = best.food
        let scale = parsed.scaleFactor
        let confidence = best.score >= 10.0 ? 0.9 : (best.score >= 5.0 ? 0.75 : 0.6)
        let cal = Int(Double(food.calories) * scale)
        let p = round(food.protein * scale * 10) / 10
        let c = round(food.carbs * scale * 10) / 10
        let f = round(food.fat * scale * 10) / 10
        let measurement = Self.inferMeasurement(from: food)
        let item = AnalyzedFoodItem(
            id: UUID(),
            name: food.name,
            calories: cal,
            protein: p,
            carbs: c,
            fat: f,
            fiber: food.fiber * scale,
            sugar: food.sugar * scale,
            servingSize: scale != 1.0 ? "\(String(format: "%.1f", scale))x \(food.serving)" : food.serving,
            estimatedGrams: food.servingGrams * scale,
            measurementUnit: measurement.unit,
            measurementAmount: round(measurement.amount * scale * 10) / 10,
            confidence: confidence,
            note: nil
        )
        return FoodAnalysis(
            items: [item],
            displayName: food.name,
            totalCalories: cal,
            totalProtein: p,
            totalCarbs: c,
            totalFat: f,
            fiberG: food.fiber * scale,
            sugarG: food.sugar * scale,
            sodiumMg: food.sodium * scale,
            warnings: nil,
            healthInsight: nil,
            calorieRange: nil,
            confidenceReason: nil,
            servingAssumed: item.servingSize
        )
    }

    // MARK: - Measurement Inference

    /// Infer the most natural measurement unit and amount from a FoodItem's serving and category.
    nonisolated static func inferMeasurement(from food: FoodItem) -> (unit: String, amount: Double) {
        let serving = food.serving.lowercased()
        let grams = food.servingGrams

        // Parse explicit units in serving string
        let patterns: [(regex: String, unit: String)] = [
            (#"([\d.]+)\s*oz"#, "oz"),
            (#"([\d.]+)\s*cup"#, "cup"),
            (#"([\d.]+)\s*tbsp"#, "tbsp"),
            (#"([\d.]+)\s*tsp"#, "tsp"),
            (#"([\d.]+)\s*fl\s*oz"#, "fl oz"),
            (#"([\d.]+)\s*slice"#, "slice"),
            (#"([\d.]+)\s*piece"#, "piece"),
            (#"([\d.]+)\s*large"#, "large"),
            (#"([\d.]+)\s*medium"#, "medium"),
        ]
        for (pattern, unit) in patterns {
            if let match = serving.range(of: pattern, options: .regularExpression) {
                let numStr = serving[match].filter { $0.isNumber || $0 == "." }
                if let amount = Double(numStr), amount > 0 {
                    return (unit, amount)
                }
            }
        }

        // Infer from category + grams
        switch food.category {
        case .protein:
            let oz = round(grams / 28.35 * 10) / 10
            return oz > 0 ? ("oz", oz) : ("g", grams)
        case .grain:
            if grams >= 100 {
                let cups = round(grams / 160.0 * 10) / 10
                return ("cup", max(0.25, cups))
            }
            return serving.contains("slice") ? ("slice", 1) : ("g", grams)
        case .vegetable:
            if grams >= 80 {
                let cups = round(grams / 150.0 * 10) / 10
                return ("cup", max(0.5, cups))
            }
            return ("g", grams)
        case .fruit:
            if grams >= 100 && grams <= 200 { return ("medium", 1) }
            if grams > 200 {
                let cups = round(grams / 150.0 * 10) / 10
                return ("cup", cups)
            }
            return ("g", grams)
        case .condiment, .fat:
            let tbsp = round(grams / 15.0 * 10) / 10
            return ("tbsp", max(0.5, tbsp))
        case .beverage:
            let flOz = round(grams / 29.6 * 10) / 10
            return flOz > 0 ? ("fl oz", flOz) : ("g", grams)
        case .dairy:
            if serving.contains("cup") { return ("cup", 1) }
            let oz = round(grams / 28.35 * 10) / 10
            return oz > 0 ? ("oz", oz) : ("g", grams)
        default:
            if grams == 100 {
                let name = food.name.lowercased()
                if name.contains("chicken") || name.contains("beef") || name.contains("pork") ||
                   name.contains("turkey") || name.contains("salmon") || name.contains("fish") ||
                   name.contains("shrimp") || name.contains("steak") || name.contains("lamb") {
                    return ("oz", 3.5)
                }
                if name.contains("rice") || name.contains("pasta") || name.contains("oat") {
                    return ("cup", 0.5)
                }
            }
            return ("g", grams)
        }
    }

    // MARK: - Text Search

    func searchFood(query: String) async throws -> FoodAnalysis {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FuelError.aiAnalysisFailed("Please describe what you ate")
        }
        let safeQuery = String(trimmed.prefix(500))
        let start = CFAbsoluteTimeGetCurrent()
        let ragResults = useRAG ? NutritionRAG.shared.retrieve(query: safeQuery, topK: 5) : []

        let result: FoodAnalysis
        var wasOffline = false
        var wasCached = false

        do {
            // All AI calls route through the edge function (API key stays server-side)
            let cacheKey = safeQuery
            if NutritionCache.shared.get(for: cacheKey) != nil {
                wasCached = true
            }

            var edgeResult = try await searchFoodWithSupabase(query: safeQuery)
            edgeResult = deduplicateItems(edgeResult)
            edgeResult = crossValidateWithRAG(edgeResult)
            edgeResult = applyUserCorrections(edgeResult)
            edgeResult = flagOutlierItems(edgeResult)
            edgeResult = crossItemSanityCheck(edgeResult)
            edgeResult = validateMacroMath(edgeResult)
            result = edgeResult
        } catch {
            // Both paths failed — try offline estimate as last resort
            if let offline = offlineEstimate(query: safeQuery) {
                wasOffline = true
                #if DEBUG
                print("[Fuel] Both API paths failed for text. Using offline estimate for: \(safeQuery)")
                #endif
                result = offline
            } else {
                throw error
            }
        }

        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        await NutritionLogger.shared.log(
            queryType: .text,
            query: safeQuery,
            ragTopScore: ragResults.first?.score,
            ragMatchCount: ragResults.count,
            resultCalories: result.totalCalories,
            resultConfidence: result.confidenceReason ?? "unknown",
            responseTimeMs: elapsedMs,
            wasOffline: wasOffline,
            wasCached: wasCached
        )

        return result
    }

    private func searchFoodWithRAG(query: String) async throws -> FoodAnalysis {
        // Check if local RAG has a strong match — if not, fetch from APIs in background
        let ragResults = NutritionRAG.shared.retrieve(query: query, topK: 1)
        let ragScore = ragResults.first?.score ?? 0

        if ragScore < 5.0 {
            // Weak local match — fire off API lookups to cache for future queries
            Task.detached(priority: .utility) {
                await Self.fetchAndCacheFromAPIs(query: query)
            }
        }

        let analysis = try await ClaudeNutritionService.shared.analyze(description: query)
        var result = analysis.toFoodAnalysis()
        result = deduplicateItems(result)
        result = crossValidateWithRAG(result)
        result = applyUserCorrections(result)
        result = flagOutlierItems(result)
        result = crossItemSanityCheck(result)
        result = validateMacroMath(result)
        return result
    }

    /// Fetch from USDA + Open Food Facts APIs and cache results locally.
    /// Runs in background — doesn't block the user's current request.
    private static func fetchAndCacheFromAPIs(query: String) async {
        async let usdaResults = { try? await USDAFoodService.shared.search(query: query, pageSize: 5) }()
        async let offResults = { try? await OpenFoodFactsService.shared.search(query: query, pageSize: 5) }()

        let usda = await usdaResults ?? []
        let off = await offResults ?? []

        let combined = usda + off
        if !combined.isEmpty {
            FoodAPICache.shared.addAll(combined)
        }
    }

    private func searchFoodWithSupabase(query: String) async throws -> FoodAnalysis {
        let headers = try await authHeaders()
        let result: FoodAnalysis = try await supabase.functions.invoke(
            "analyze-food",
            options: .init(
                headers: headers,
                body: [
                    "query": query,
                    "request_type": "text"
                ] as [String: String]
            )
        )
        return result
    }

    // MARK: - Barcode

    func lookupBarcode(_ barcode: String) async throws -> FoodAnalysis {
        let safeBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter(\.isNumber)
        guard safeBarcode.count >= 8 && safeBarcode.count <= 15 else {
            throw FuelError.aiAnalysisFailed("Invalid barcode format")
        }
        let start = CFAbsoluteTimeGetCurrent()

        // Tier 1: Check local API cache for this barcode
        if let cached = FoodAPICache.shared.getByBarcode(safeBarcode) {
            let result = foodItemToAnalysis(cached, note: "From cached barcode lookup")
            let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            await NutritionLogger.shared.log(
                queryType: .barcode, query: safeBarcode, ragTopScore: nil, ragMatchCount: 1,
                resultCalories: result.totalCalories, resultConfidence: "barcode_cache",
                responseTimeMs: elapsedMs
            )
            return result
        }

        // Tier 2: Try Open Food Facts barcode lookup (free, 3M+ products)
        if let offFood = try? await OpenFoodFactsService.shared.lookupBarcode(safeBarcode) {
            FoodAPICache.shared.add(offFood, barcode: safeBarcode)
            let result = foodItemToAnalysis(offFood, note: "From Open Food Facts")
            let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            await NutritionLogger.shared.log(
                queryType: .barcode, query: safeBarcode, ragTopScore: nil, ragMatchCount: 1,
                resultCalories: result.totalCalories, resultConfidence: "openfoodfacts",
                responseTimeMs: elapsedMs
            )
            return result
        }

        // Tier 3: Fall back to Supabase edge function (which tries Open Food Facts + Claude AI)
        let headers = try await authHeaders()
        let result: FoodAnalysis
        do {
            let rawResult: FoodAnalysis = try await supabase.functions.invoke(
                "analyze-food",
                options: .init(
                    headers: headers,
                    body: [
                        "barcode": safeBarcode,
                        "request_type": "barcode"
                    ] as [String: String]
                )
            )
            result = useRAG ? enrichWithRAG(rawResult) : rawResult
        } catch {
            // Edge function failed — no direct API fallback (key stays server-side)
            #if DEBUG
            print("[Fuel] Supabase barcode lookup failed: \(error.localizedDescription)")
            #endif
            throw error
        }

        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        await NutritionLogger.shared.log(
            queryType: .barcode, query: safeBarcode, ragTopScore: nil, ragMatchCount: 0,
            resultCalories: result.totalCalories, resultConfidence: result.confidenceReason ?? "unknown",
            responseTimeMs: elapsedMs
        )

        return result
    }

    /// Convert a FoodItem to FoodAnalysis for display.
    private func foodItemToAnalysis(_ food: FoodItem, note: String) -> FoodAnalysis {
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
            confidence: food.confidence == .high ? 0.95 : 0.75,
            note: note
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
            confidenceReason: note,
            servingAssumed: food.serving
        )
    }

    private func enrichWithRAG(_ analysis: FoodAnalysis) -> FoodAnalysis {
        let ragResults = NutritionRAG.shared.retrieve(query: analysis.displayName, topK: 3)
        guard let bestMatch = ragResults.first, bestMatch.score >= 5.0 else {
            return analysis
        }
        // If RAG has a high-confidence match, use its macros (more accurate USDA data)
        let food = bestMatch.food
        if food.confidence == .high {
            let enrichedItems = [AnalyzedFoodItem(
                id: UUID(),
                name: food.name,
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat,
                servingSize: food.serving,
                confidence: 0.95,
                note: "Verified against USDA database"
            )]
            return FoodAnalysis(
                items: enrichedItems,
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
                confidenceReason: "Matched to USDA database entry: \(food.name)",
                servingAssumed: food.serving
            )
        }
        return analysis
    }

    /// Build a FoodAnalysis from a list of identified item names using RAG only.
    /// Used as fallback when Claude's full analysis fails after pass 1 succeeded.
    private func offlineEstimateFromItems(_ itemNames: [String]) -> FoodAnalysis? {
        // Deduplicate item names (Claude Pass 1 can return duplicates like "2 eggs, bacon, 2 eggs")
        var seenItems = Set<String>()
        let uniqueNames = itemNames.filter { name in
            let key = name.lowercased().trimmingCharacters(in: .whitespaces)
            guard !seenItems.contains(key) else { return false }
            seenItems.insert(key)
            return true
        }
        var items = [AnalyzedFoodItem]()
        var totalCal = 0, totalP = 0.0, totalC = 0.0, totalF = 0.0
        var totalFiber = 0.0, totalSugar = 0.0, totalSodium = 0.0
        var unmatchedItems = [String]()

        for name in uniqueNames {
            let results = NutritionRAG.shared.retrieve(query: name, topK: 1)
            guard let best = results.first, best.score >= 3.0 else {
                unmatchedItems.append(name)
                continue
            }
            let food = best.food
            let confidence = best.score >= 10.0 ? 0.85 : (best.score >= 5.0 ? 0.7 : 0.55)
            let measurement = Self.inferMeasurement(from: food)
            items.append(AnalyzedFoodItem(
                id: UUID(), name: food.name,
                calories: food.calories, protein: food.protein,
                carbs: food.carbs, fat: food.fat,
                fiber: food.fiber, sugar: food.sugar,
                servingSize: food.serving,
                estimatedGrams: food.servingGrams,
                measurementUnit: measurement.unit,
                measurementAmount: measurement.amount,
                confidence: confidence,
                note: nil
            ))
            totalCal += food.calories
            totalP += food.protein
            totalC += food.carbs
            totalF += food.fat
            totalFiber += food.fiber
            totalSugar += food.sugar
            totalSodium += food.sodium
        }

        guard !items.isEmpty else { return nil }
        let displayName = items.count == 1 ? items[0].name : items.map(\.name).joined(separator: " & ")
        var warnings: [String] = []
        if !unmatchedItems.isEmpty {
            warnings.append("Could not find: \(unmatchedItems.joined(separator: ", "))")
        }
        return FoodAnalysis(
            items: items, displayName: displayName,
            totalCalories: totalCal,
            totalProtein: round(totalP * 10) / 10,
            totalCarbs: round(totalC * 10) / 10,
            totalFat: round(totalF * 10) / 10,
            fiberG: totalFiber, sugarG: totalSugar, sodiumMg: totalSodium,
            warnings: warnings.isEmpty ? nil : warnings,
            healthInsight: nil, calorieRange: nil,
            confidenceReason: "Offline estimate from food database (AI unavailable)",
            servingAssumed: items.first?.servingSize
        )
    }

    private func offlineEstimate(query: String) -> FoodAnalysis? {
        // Parse portion info for scaling
        let parsed = PortionParser.shared.parse(query)
        let searchQuery = parsed.cleanedFoodName

        // Retrieve multiple results for multi-item queries
        let results = NutritionRAG.shared.retrieve(query: searchQuery, topK: 5)
        guard let best = results.first, best.score >= 3.0 else { return nil }

        // For multi-item queries, include high-scoring matches but deduplicate similar foods
        var seenNames = Set<String>()
        let topMatches = results.filter { result in
            let dominated = result.score >= 5.0 || result.food.name == results.first?.food.name
            guard dominated else { return false }
            let key = result.food.name.lowercased().trimmingCharacters(in: .whitespaces)
            // Skip if name is a substring of an already-included item (e.g., "chicken" after "chicken breast")
            let isDuplicate = seenNames.contains { seen in key.contains(seen) || seen.contains(key) }
            guard !isDuplicate else { return false }
            seenNames.insert(key)
            return true
        }
        let scale = parsed.scaleFactor

        var items: [AnalyzedFoodItem] = []
        var totalCal = 0, totalFiber = 0.0, totalSugar = 0.0, totalSodium = 0.0
        var totalP = 0.0, totalC = 0.0, totalF = 0.0

        for match in topMatches.prefix(3) {
            let food = match.food
            let cal = Int(Double(food.calories) * scale)
            let p = round(food.protein * scale * 10) / 10
            let c = round(food.carbs * scale * 10) / 10
            let f = round(food.fat * scale * 10) / 10
            let measurement = Self.inferMeasurement(from: food)

            items.append(AnalyzedFoodItem(
                id: UUID(),
                name: food.name,
                calories: cal,
                protein: p,
                carbs: c,
                fat: f,
                fiber: food.fiber * scale,
                sugar: food.sugar * scale,
                servingSize: scale != 1.0 ? "\(String(format: "%.1f", scale))x \(food.serving)" : food.serving,
                estimatedGrams: food.servingGrams * scale,
                measurementUnit: measurement.unit,
                measurementAmount: round(measurement.amount * scale * 10) / 10,
                confidence: food.confidence == .high ? 0.85 : 0.6,
                note: nil
            ))

            totalCal += cal
            totalP += p
            totalC += c
            totalF += f
            totalFiber += food.fiber * scale
            totalSugar += food.sugar * scale
            totalSodium += food.sodium * scale

            // Only include multiple items if they're clearly different foods
            if topMatches.count <= 1 { break }
            if match.score < best.score * 0.6 { break }
        }

        guard !items.isEmpty else { return nil }

        // If only one match, use it as the display name
        let displayName = items.count == 1 ? items[0].name : parsed.originalQuery

        return FoodAnalysis(
            items: items,
            displayName: displayName,
            totalCalories: totalCal,
            totalProtein: totalP,
            totalCarbs: totalC,
            totalFat: totalF,
            fiberG: totalFiber,
            sugarG: totalSugar,
            sodiumMg: totalSodium,
            warnings: nil,
            healthInsight: nil,
            calorieRange: nil,
            confidenceReason: "Database estimate using USDA reference data",
            servingAssumed: items.first?.servingSize
        )
    }

    // MARK: - Local Search (no AI cost)

    /// Searches local RAG database first, then USDA + Open Food Facts APIs if needed.
    /// Zero AI cost — only uses free public APIs as fallback.
    func searchFoodLocal(query: String) async -> FoodAnalysis? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let safeQuery = String(trimmed.prefix(500))

        let parsed = PortionParser.shared.parse(safeQuery)
        let searchQuery = parsed.cleanedFoodName.isEmpty ? safeQuery : parsed.cleanedFoodName
        let scale = parsed.scaleFactor

        // Step 1: Try local RAG database (instant, < 10ms)
        let ragResults = NutritionRAG.shared.retrieve(query: searchQuery, topK: 5)
        let bestScore = ragResults.first?.score ?? 0

        // Strong local match — use it directly
        if bestScore >= 5.0, let result = buildLocalResult(from: ragResults, parsed: parsed, scale: scale, source: "nutrition database") {
            // Still cache from APIs in background for future searches
            if bestScore < 10.0 {
                Task.detached(priority: .utility) {
                    await Self.fetchAndCacheFromAPIs(query: searchQuery)
                }
            }
            return result
        }

        // Step 2: Weak or no local match — query free APIs in parallel
        // Use original query for APIs (better for branded products like "Chobani Greek yogurt")
        // and cleaned name for USDA (better for whole foods like "chicken breast")
        let apiQuery = safeQuery
        #if DEBUG
        print("[Fuel] Local search: weak RAG match (\(String(format: "%.1f", bestScore))) for '\(searchQuery)' — querying USDA + OFF APIs...")
        #endif

        async let usdaResults = Self.fetchUSDA(query: searchQuery)
        async let offResults = Self.fetchOFF(query: apiQuery)

        let usda = await usdaResults
        let off = await offResults

        // If task was cancelled while waiting for APIs, bail out
        guard !Task.isCancelled else { return nil }

        // Cache all results for future instant lookups
        let allAPIFoods = usda + off
        if !allAPIFoods.isEmpty {
            FoodAPICache.shared.addAll(allAPIFoods)
        }

        // Step 3: Pick best result from all sources
        // Combine API results with local RAG results and pick the best match
        let bestAPIFood = Self.pickBestMatch(query: searchQuery, from: allAPIFoods)

        if let apiFood = bestAPIFood {
            // Build result from API food
            let cal = Int(Double(apiFood.calories) * scale)
            let p = round(apiFood.protein * scale * 10) / 10
            let c = round(apiFood.carbs * scale * 10) / 10
            let f = round(apiFood.fat * scale * 10) / 10
            let confidence: Double = apiFood.confidence == .high ? 0.85 : 0.7
            let measurement = Self.inferMeasurement(from: apiFood)

            let item = AnalyzedFoodItem(
                id: UUID(),
                name: apiFood.name,
                calories: cal,
                protein: p,
                carbs: c,
                fat: f,
                fiber: apiFood.fiber * scale,
                sugar: apiFood.sugar * scale,
                servingSize: scale != 1.0 ? "\(String(format: "%.1f", scale))x \(apiFood.serving)" : apiFood.serving,
                estimatedGrams: apiFood.servingGrams * scale,
                measurementUnit: measurement.unit,
                measurementAmount: round(measurement.amount * scale * 10) / 10,
                confidence: confidence,
                note: nil
            )

            return FoodAnalysis(
                items: [item],
                displayName: apiFood.name,
                totalCalories: cal,
                totalProtein: p,
                totalCarbs: c,
                totalFat: f,
                fiberG: apiFood.fiber * scale,
                sugarG: apiFood.sugar * scale,
                sodiumMg: apiFood.sodium * scale,
                warnings: nil,
                healthInsight: Self.localFoodInsight(name: apiFood.name, calories: cal, protein: p, carbs: c, fat: f),
                calorieRange: nil,
                confidenceReason: nil,
                servingAssumed: item.servingSize
            )
        }

        // Step 4: Fall back to weak local match if APIs returned nothing
        if let result = buildLocalResult(from: ragResults, parsed: parsed, scale: scale, source: "nutrition database") {
            return result
        }

        return nil
    }

    /// Build a FoodAnalysis from RAG results.
    private func buildLocalResult(from results: [RetrievalResult], parsed: ParsedPortion, scale: Double, source: String) -> FoodAnalysis? {
        guard let best = results.first, best.score >= 2.0 else { return nil }

        var seenNames = Set<String>()
        let topMatches = results.filter { result in
            let dominated = result.score >= 4.0 || result.food.name == results.first?.food.name
            guard dominated else { return false }
            let key = result.food.name.lowercased().trimmingCharacters(in: .whitespaces)
            let isDuplicate = seenNames.contains { seen in key.contains(seen) || seen.contains(key) }
            guard !isDuplicate else { return false }
            seenNames.insert(key)
            return true
        }

        var items: [AnalyzedFoodItem] = []
        var totalCal = 0, totalFiber = 0.0, totalSugar = 0.0, totalSodium = 0.0
        var totalP = 0.0, totalC = 0.0, totalF = 0.0

        for match in topMatches.prefix(3) {
            let food = match.food
            let cal = Int(Double(food.calories) * scale)
            let p = round(food.protein * scale * 10) / 10
            let c = round(food.carbs * scale * 10) / 10
            let f = round(food.fat * scale * 10) / 10
            let measurement = Self.inferMeasurement(from: food)

            items.append(AnalyzedFoodItem(
                id: UUID(),
                name: food.name,
                calories: cal,
                protein: p,
                carbs: c,
                fat: f,
                fiber: food.fiber * scale,
                sugar: food.sugar * scale,
                servingSize: scale != 1.0 ? "\(String(format: "%.1f", scale))x \(food.serving)" : food.serving,
                estimatedGrams: food.servingGrams * scale,
                measurementUnit: measurement.unit,
                measurementAmount: round(measurement.amount * scale * 10) / 10,
                confidence: food.confidence == .high ? 0.85 : 0.65,
                note: nil
            ))

            totalCal += cal
            totalP += p
            totalC += c
            totalF += f
            totalFiber += food.fiber * scale
            totalSugar += food.sugar * scale
            totalSodium += food.sodium * scale

            if topMatches.count <= 1 { break }
            if match.score < best.score * 0.6 { break }
        }

        guard !items.isEmpty else { return nil }
        let displayName = items.count == 1 ? items[0].name : parsed.originalQuery

        return FoodAnalysis(
            items: items,
            displayName: displayName,
            totalCalories: totalCal,
            totalProtein: totalP,
            totalCarbs: totalC,
            totalFat: totalF,
            fiberG: totalFiber,
            sugarG: totalSugar,
            sodiumMg: totalSodium,
            warnings: nil,
            healthInsight: Self.localFoodInsight(name: displayName, calories: totalCal, protein: totalP, carbs: totalC, fat: totalF),
            calorieRange: nil,
            confidenceReason: nil,
            servingAssumed: items.first?.servingSize
        )
    }

    /// Fetch from USDA API (free) with timeout. Returns empty array on failure.
    private static func fetchUSDA(query: String) async -> [FoodItem] {
        await withTimeoutOrEmpty(seconds: 5) {
            (try? await USDAFoodService.shared.search(query: query, pageSize: 5)) ?? []
        }
    }

    /// Fetch from Open Food Facts API (free) with timeout. Returns empty array on failure.
    private static func fetchOFF(query: String) async -> [FoodItem] {
        await withTimeoutOrEmpty(seconds: 5) {
            (try? await OpenFoodFactsService.shared.search(query: query, pageSize: 5)) ?? []
        }
    }

    /// Run an async operation with a timeout — returns empty array if it takes too long.
    private static func withTimeoutOrEmpty(seconds: Double, operation: @Sendable @escaping () async -> [FoodItem]) async -> [FoodItem] {
        await withTaskGroup(of: [FoodItem].self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return []
            }
            // Return whichever finishes first
            let first = await group.next() ?? []
            group.cancelAll()
            return first
        }
    }

    /// Pick the best matching FoodItem from API results using name similarity scoring.
    private static func pickBestMatch(query: String, from foods: [FoodItem]) -> FoodItem? {
        guard !foods.isEmpty else { return nil }
        let queryLower = query.lowercased()
        let queryTokens = Set(queryLower.split(separator: " ").filter { $0.count > 1 }.map(String.init))
        guard !queryTokens.isEmpty else { return foods.first }

        var bestFood: FoodItem?
        var bestScore = 0

        for food in foods {
            let nameLower = food.name.lowercased()
            let nameTokens = Set(nameLower.split(separator: " ").filter { $0.count > 1 }.map(String.init))
            var score = 0

            // Exact containment (strong signal)
            if nameLower.contains(queryLower) { score += 15 }
            else if queryLower.contains(nameLower) { score += 12 }

            // Token overlap — weighted by coverage of query
            let overlap = queryTokens.intersection(nameTokens).count
            score += overlap * 4

            // Bonus for matching most of the query tokens
            if queryTokens.count > 0 {
                let coverage = Double(overlap) / Double(queryTokens.count)
                if coverage >= 0.8 { score += 5 }
                else if coverage >= 0.5 { score += 2 }
            }

            // Prefix matching (e.g., query "chick" matches "chicken")
            for qt in queryTokens {
                if nameTokens.contains(where: { $0.hasPrefix(qt) || qt.hasPrefix($0) }) && !nameTokens.contains(qt) {
                    score += 2
                }
            }

            // Prefer items with calories (skip zero-cal results unless explicitly searching for water/diet)
            if food.calories > 0 { score += 1 }

            // Prefer high confidence (USDA > Open Food Facts)
            if food.confidence == .high { score += 3 }

            if score > bestScore {
                bestScore = score
                bestFood = food
            }
        }

        // Require at least one meaningful token match
        return bestScore >= 4 ? bestFood : foods.first
    }

    /// Generates a quick local health insight for a food item — no API call.
    private static func localFoodInsight(name: String, calories: Int, protein: Double, carbs: Double, fat: Double) -> String? {
        var insights: [String] = []
        let total = protein + carbs + fat
        guard total > 0 else { return nil }

        let proteinPct = protein / total
        let fatPct = fat / total

        if protein >= 20 { insights.append("Great protein source at \(Int(protein))g — helps with muscle recovery and satiety.") }
        if protein >= 30 { insights.append("Packed with \(Int(protein))g protein — excellent for hitting your daily target.") }
        if proteinPct > 0.4 { insights.append("High protein-to-calorie ratio makes this a smart choice for staying full longer.") }
        if calories < 200 && protein >= 10 { insights.append("Low calorie with solid protein — a great snack option.") }
        if calories < 150 { insights.append("Light choice at only \(calories) cal — easy to fit into any meal plan.") }
        if calories > 600 { insights.append("Calorie-dense at \(calories) cal — consider a smaller portion or pairing with lighter sides.") }
        if fatPct > 0.5 && fat > 15 { insights.append("Higher in fat — consider balancing with lean protein at your next meal.") }
        if carbs > 50 && protein < 10 { insights.append("Carb-heavy with less protein — try adding a protein source for better balance.") }
        if carbs < 10 && calories < 300 { insights.append("Low-carb option — fits well into keto or low-carb plans.") }
        if fat < 5 && calories < 300 { insights.append("Very low in fat — a lean option that leaves room for healthy fats elsewhere.") }

        return insights.randomElement()
    }

    // MARK: - Local Daily Insights (no AI cost)

    /// Generates a contextual daily insight using templates — zero API calls.
    /// Picks from 60+ templates based on actual user data for variety.
    nonisolated static func generateLocalInsight(
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        targetCalories: Int,
        targetProtein: Int,
        mealCount: Int,
        goalType: String
    ) -> String {
        let calRemaining = targetCalories - calories
        let proteinRemaining = Double(targetProtein) - protein
        let calPct = targetCalories > 0 ? Double(calories) / Double(targetCalories) : 0
        let proteinPct = targetProtein > 0 ? protein / Double(targetProtein) : 0
        let isOver = calories > targetCalories
        let isClose = calPct >= 0.85 && calPct <= 1.05
        let proteinHit = proteinPct >= 0.9
        let proteinLow = proteinPct < 0.5
        let isLosing = goalType == "lose"
        let isGaining = goalType == "gain"

        var pool: [String] = []

        // -- Calorie-based insights --
        if isOver {
            let overBy = calories - targetCalories
            pool.append("You're \(overBy) cal over target. Not a setback — just adjust tomorrow and stay consistent.")
            pool.append("Went \(overBy) cal over today. One day doesn't define your progress. Reset and keep going.")
            pool.append("Over by \(overBy) cal. Consider a lighter dinner or an extra walk to balance things out.")
            pool.append("A little over target today. Your body won't notice one day — consistency over weeks is what matters.")
            pool.append("Don't stress the extra \(overBy) cal. Focus on making your next meal a solid choice.")
            pool.append("Over target by \(overBy) cal — happens to everyone. What matters is what you do next.")
        } else if isClose {
            pool.append("Right on target! You nailed your calories today — that consistency builds real results.")
            pool.append("Almost perfect calorie day! This kind of consistency is exactly how goals get crushed.")
            pool.append("You're within striking distance of your target. Solid day of tracking.")
            pool.append("Great control today — hitting your calorie target consistently is the #1 factor in progress.")
            pool.append("Dialed in. Your calorie accuracy today is exactly what drives long-term results.")
            pool.append("Textbook day. Keeping calories in this range is how you build sustainable habits.")
        } else if calRemaining > 500 {
            pool.append("You have \(calRemaining) cal left — room for a solid meal. Don't skip it, fuel your body.")
            pool.append("Still \(calRemaining) cal to go. Consider a balanced meal with protein and healthy fats.")
            pool.append("Plenty of room left today (\(calRemaining) cal). A protein-rich dinner would be perfect right now.")
            pool.append("You're running a big deficit with \(calRemaining) cal left. Make sure you eat enough — undereating slows progress too.")
            pool.append("\(calRemaining) cal remaining. A meal with chicken, rice, and veggies would fit perfectly here.")
        } else if calRemaining > 200 {
            pool.append("\(calRemaining) cal left for the day — a smart snack like Greek yogurt or nuts would be perfect.")
            pool.append("Room for \(calRemaining) more calories. A light snack with protein will keep you satisfied tonight.")
            pool.append("You've got \(calRemaining) cal to work with. Consider a protein shake or some cottage cheese.")
            pool.append("Nice pacing — \(calRemaining) cal left. You could fit a small dessert and still hit your goal.")
        } else if calRemaining > 0 {
            pool.append("Just \(calRemaining) cal left — you're basically done for the day. Strong finish.")
            pool.append("Almost at target with only \(calRemaining) cal remaining. Disciplined day.")
            pool.append("Tiny gap of \(calRemaining) cal left. A piece of fruit would round out the day nicely.")
        }

        // -- Protein-based insights --
        if proteinHit {
            pool.append("Protein goal crushed at \(Int(protein))g! Your muscles are thanking you.")
            pool.append("Hit \(Int(protein))g protein today — excellent for recovery and keeping you full.")
            pool.append("Protein on point. Hitting \(Int(protein))g consistently is key for body composition.")
            pool.append("Strong protein day at \(Int(protein))g. This is how you maintain muscle while managing calories.")
        } else if proteinLow && mealCount >= 2 {
            pool.append("Only \(Int(protein))g protein so far — try to include a high-protein food in your next meal.")
            pool.append("Protein is running low at \(Int(protein))g. Consider chicken, fish, eggs, or a protein shake.")
            pool.append("You're at \(Int(protein))g protein with \(Int(proteinRemaining))g to go. Lean meats or Greek yogurt can help close that gap.")
            pool.append("Protein needs attention — \(Int(protein))g of \(targetProtein)g. Add a protein-rich food to your next meal.")
        } else if !proteinHit && proteinPct >= 0.5 {
            pool.append("Protein at \(Int(protein))g — solid progress. One more protein-rich meal and you'll hit your target.")
            pool.append("Halfway there on protein (\(Int(protein))g). A chicken breast or fish fillet would close the gap.")
            pool.append("Good protein progress at \(Int(protein))g. Keep prioritizing it in your remaining meals.")
        }

        // -- Meal count insights --
        if mealCount == 0 {
            pool.append("No meals logged yet today. Start tracking to stay on top of your goals!")
            pool.append("Your food log is empty. Log your first meal to get today's tracking started.")
        } else if mealCount == 1 {
            pool.append("One meal logged. Keep tracking throughout the day for the best accuracy.")
            pool.append("Good start with your first meal logged! Consistency in logging is what makes tracking work.")
        } else if mealCount >= 4 {
            pool.append("\(mealCount) meals logged — excellent tracking discipline! This level of detail gives you the best insights.")
            pool.append("Impressive — \(mealCount) meals tracked today. The more you log, the better your data.")
            pool.append("You've logged \(mealCount) meals. That kind of commitment to tracking is rare and powerful.")
        } else if mealCount >= 2 {
            pool.append("\(mealCount) meals tracked so far. You're building a clear picture of your nutrition today.")
            pool.append("Good tracking with \(mealCount) meals logged. Each entry makes your data more accurate.")
        }

        // -- Goal-specific insights --
        if isLosing {
            if isClose || (!isOver && calRemaining < 200) {
                pool.append("Staying near your target is how weight loss actually happens — through daily consistency, not perfection.")
                pool.append("You're in a great deficit zone. Keep this up and the scale will follow.")
                pool.append("Solid day for fat loss. Remember: it's the weekly average that matters most.")
            }
            if protein >= 25 {
                pool.append("Good protein intake for a cut — this helps preserve muscle while losing fat.")
                pool.append("Keeping protein high during a cut is smart. It reduces muscle loss and keeps hunger in check.")
            }
            pool.append("Tip: eating more protein and fiber helps you feel full on fewer calories.")
            pool.append("Focus on protein and vegetables to stay satisfied while in a calorie deficit.")
        } else if isGaining {
            if isOver || calPct >= 0.95 {
                pool.append("Hitting your calorie target is crucial for gaining. Great job fueling your body today.")
                pool.append("Solid calories for a bulk. Make sure you're training hard to put those nutrients to work.")
            }
            if calRemaining > 300 {
                pool.append("Still \(calRemaining) cal to go for your surplus. A calorie-dense snack like nuts or a shake can help.")
                pool.append("You need \(calRemaining) more cal to hit your gain target. Don't leave gains on the table!")
            }
            pool.append("For gaining, aim to hit your calorie target every day. Consistency in surplus = consistent growth.")
            pool.append("Tip: spreading meals throughout the day makes it easier to hit higher calorie targets.")
        } else {
            // Maintain
            if isClose {
                pool.append("Maintenance on point. Eating at target keeps your weight stable and energy consistent.")
                pool.append("Right at your maintenance calories — this is the sweet spot for holding your current physique.")
            }
            pool.append("Maintaining weight is about hitting your target most days. You're doing great.")
            pool.append("Balance is key for maintenance. Keep hitting your targets and your body stays where you want it.")
        }

        // -- Macro balance insights --
        let totalMacroG = protein + carbs + fat
        if totalMacroG > 0 {
            let carbPct = carbs / totalMacroG
            let fatPctMacro = fat / totalMacroG
            let protPctMacro = protein / totalMacroG

            if carbPct > 0.6 {
                pool.append("Carbs are dominating today (\(Int(carbs))g). Try adding more protein and healthy fats for balance.")
                pool.append("Heavy on carbs today. Pair your next carb-heavy meal with a good protein source.")
            }
            if fatPctMacro > 0.45 {
                pool.append("Fat is higher than usual at \(Int(fat))g. Balance with leaner protein sources in your next meal.")
                pool.append("Running high on fats today. Choose grilled or baked options over fried for the rest of the day.")
            }
            if protPctMacro > 0.35 && protPctMacro < 0.5 {
                pool.append("Great macro balance today — protein is leading the way. Keep it up.")
                pool.append("Your protein ratio is solid. This kind of macro split supports both performance and recovery.")
            }
        }

        // -- General wisdom (always available) --
        let generalTips = [
            "Hydration matters — aim for 8+ glasses of water today. It supports metabolism and reduces false hunger signals.",
            "Eating slowly helps your body register fullness. Try putting your fork down between bites.",
            "Meal prepping even 2-3 meals ahead makes staying on target dramatically easier.",
            "Sleep quality directly impacts hunger hormones. Prioritize 7-9 hours for easier appetite control.",
            "Don't forget fiber — it keeps digestion smooth and helps you feel full. Aim for 25-30g daily.",
            "Variety in your protein sources (chicken, fish, eggs, legumes) ensures you get a full amino acid profile.",
            "Progress isn't linear. Trust the process and focus on the habits, not just the numbers.",
            "Logging consistently — even on \"bad\" days — is what separates people who succeed from those who don't.",
            "Consider your meal timing. Eating most of your calories earlier in the day can improve energy and sleep.",
            "Vegetables are your secret weapon — high volume, low calories, tons of micronutrients.",
            "A post-workout meal with both protein and carbs maximizes recovery and muscle growth.",
            "Healthy fats (avocado, olive oil, nuts) are calorie-dense but crucial for hormone health.",
            "If you're craving something, have a small portion. Restriction often leads to bigger binges later.",
            "Walking after meals can improve digestion and help regulate blood sugar levels.",
            "Track for awareness, not obsession. The goal is understanding your body, not perfection.",
        ]
        pool.append(contentsOf: generalTips.shuffled().prefix(3))

        return pool.randomElement() ?? "Keep tracking your meals to stay on top of your nutrition goals!"
    }

    // MARK: - Chat & Insights (unchanged, always Supabase)

    func sendChatMessage(message: String, history: [ChatMessage], userContext: UserContext) async throws -> ChatAIResponse {
        let historyArray = history.map { ["role": $0.role.rawValue, "content": $0.content] }

        struct ChatRequest: Encodable {
            let message: String
            let history: [[String: String]]
            let context: [String: String]
        }

        let request = ChatRequest(
            message: message,
            history: historyArray,
            context: userContext.toDictionary()
        )

        let result: ChatResponse = try await supabase.functions.invoke(
            "fuel-chat",
            options: .init(body: request)
        )

        return ChatAIResponse(message: result.message, cards: result.cards)
    }

    func generateDailyInsight(summary: DailySummary, profile: UserProfile, isPremium: Bool = false) async throws -> String {
        let targetCal = profile.targetCalories ?? 2000
        let targetProt = profile.targetProtein ?? 150
        let goalType = profile.goalType?.rawValue ?? "maintain"

        // Free users: local templated insight (no API cost)
        guard isPremium else {
            return Self.generateLocalInsight(
                calories: summary.totalCalories,
                protein: summary.totalProtein,
                carbs: summary.totalCarbs,
                fat: summary.totalFat,
                targetCalories: targetCal,
                targetProtein: targetProt,
                mealCount: summary.meals.count,
                goalType: goalType
            )
        }

        // Premium users: AI-generated insight via edge function
        struct InsightRequest: Encodable {
            let calories: Int
            let protein: Double
            let carbs: Double
            let fat: Double
            let target_calories: Int
            let target_protein: Int
            let meal_count: Int
            let goal_type: String
        }

        let request = InsightRequest(
            calories: summary.totalCalories,
            protein: summary.totalProtein,
            carbs: summary.totalCarbs,
            fat: summary.totalFat,
            target_calories: targetCal,
            target_protein: targetProt,
            meal_count: summary.meals.count,
            goal_type: goalType
        )

        let result: InsightResponse = try await supabase.functions.invoke(
            "fuel-insight",
            options: .init(body: request)
        )

        return result.insight
    }
}

// MARK: - NutritionAnalysis -> FoodAnalysis Conversion

extension NutritionAnalysis {
    func toFoodAnalysis() -> FoodAnalysis {
        let foodItems = items.map { item -> AnalyzedFoodItem in
            AnalyzedFoodItem(
                id: UUID(),
                name: item.item,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                servingSize: item.quantity,
                estimatedGrams: item.estimatedGrams,
                confidence: Self.mapConfidence(confidence),
                note: item.note
            )
        }

        // If Claude returned no items, create a single item from totals
        let finalItems: [AnalyzedFoodItem]
        if foodItems.isEmpty {
            finalItems = [
                AnalyzedFoodItem(
                    id: UUID(),
                    name: mealName,
                    calories: totalCalories,
                    protein: proteinG,
                    carbs: carbsG,
                    fat: fatG,
                    servingSize: servingAssumed ?? "1 serving",
                    confidence: Self.mapConfidence(confidence),
                    note: nil
                )
            ]
        } else {
            finalItems = foodItems
        }

        return FoodAnalysis(
            items: finalItems,
            displayName: mealName,
            totalCalories: totalCalories,
            totalProtein: proteinG,
            totalCarbs: carbsG,
            totalFat: fatG,
            fiberG: fiberG,
            sugarG: sugarG,
            sodiumMg: sodiumMg,
            warnings: warnings,
            healthInsight: healthInsight,
            calorieRange: calorieRange,
            confidenceReason: confidenceReason,
            servingAssumed: servingAssumed
        )
    }

    private static func mapConfidence(_ level: String) -> Double {
        switch level.lowercased() {
        case "high": return 0.95
        case "medium": return 0.75
        case "low": return 0.55
        default: return 0.75
        }
    }
}

// MARK: - Response Types

struct FoodAnalysis: Codable, Sendable {
    let items: [AnalyzedFoodItem]
    let displayName: String
    let totalCalories: Int
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?
    let cholesterolMg: Double?
    let saturatedFatG: Double?
    let healthScore: Int?
    let healthScoreReason: String?
    let warnings: [String]?
    let healthInsight: String?
    let calorieRange: CalorieRange?
    let confidenceReason: String?
    let servingAssumed: String?

    init(items: [AnalyzedFoodItem], displayName: String, totalCalories: Int, totalProtein: Double, totalCarbs: Double, totalFat: Double, fiberG: Double? = nil, sugarG: Double? = nil, sodiumMg: Double? = nil, cholesterolMg: Double? = nil, saturatedFatG: Double? = nil, healthScore: Int? = nil, healthScoreReason: String? = nil, warnings: [String]? = nil, healthInsight: String? = nil, calorieRange: CalorieRange? = nil, confidenceReason: String? = nil, servingAssumed: String? = nil) {
        self.items = items
        self.displayName = displayName
        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.sodiumMg = sodiumMg
        self.cholesterolMg = cholesterolMg
        self.saturatedFatG = saturatedFatG
        self.healthScore = healthScore
        self.healthScoreReason = healthScoreReason
        self.warnings = warnings
        self.healthInsight = healthInsight
        self.calorieRange = calorieRange
        self.confidenceReason = confidenceReason
        self.servingAssumed = servingAssumed
    }

    enum CodingKeys: String, CodingKey {
        case items
        case displayName = "display_name"
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case cholesterolMg = "cholesterol_mg"
        case saturatedFatG = "saturated_fat_g"
        case healthScore = "health_score"
        case healthScoreReason = "health_score_reason"
        case warnings
        case healthInsight = "health_insight"
        case calorieRange = "calorie_range"
        case confidenceReason = "confidence_reason"
        case servingAssumed = "serving_assumed"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? container.decode([AnalyzedFoodItem].self, forKey: .items)) ?? []
        displayName = (try? container.decode(String.self, forKey: .displayName)) ?? "Unknown"
        if let intVal = try? container.decode(Int.self, forKey: .totalCalories) {
            totalCalories = intVal
        } else if let doubleVal = try? container.decode(Double.self, forKey: .totalCalories) {
            totalCalories = Int(doubleVal.rounded())
        } else {
            totalCalories = items.reduce(0) { $0 + $1.calories }
        }
        totalProtein = (try? container.decode(Double.self, forKey: .totalProtein)) ?? items.reduce(0.0) { $0 + $1.protein }
        totalCarbs = (try? container.decode(Double.self, forKey: .totalCarbs)) ?? items.reduce(0.0) { $0 + $1.carbs }
        totalFat = (try? container.decode(Double.self, forKey: .totalFat)) ?? items.reduce(0.0) { $0 + $1.fat }
        fiberG = try? container.decode(Double.self, forKey: .fiberG)
        sugarG = try? container.decode(Double.self, forKey: .sugarG)
        sodiumMg = try? container.decode(Double.self, forKey: .sodiumMg)
        cholesterolMg = try? container.decode(Double.self, forKey: .cholesterolMg)
        saturatedFatG = try? container.decode(Double.self, forKey: .saturatedFatG)
        healthScore = try? container.decode(Int.self, forKey: .healthScore)
        healthScoreReason = try? container.decode(String.self, forKey: .healthScoreReason)
        warnings = try? container.decode([String].self, forKey: .warnings)
        healthInsight = try? container.decode(String.self, forKey: .healthInsight)
        calorieRange = try? container.decode(CalorieRange.self, forKey: .calorieRange)
        confidenceReason = try? container.decode(String.self, forKey: .confidenceReason)
        servingAssumed = try? container.decode(String.self, forKey: .servingAssumed)
    }
}

struct AnalyzedFoodItem: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let servingSize: String
    let estimatedGrams: Double
    let measurementUnit: String
    let measurementAmount: Double
    let confidence: Double
    let note: String?
    var quantity: Double

    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat, fiber, sugar
        case servingSize = "serving_size"
        case estimatedGrams = "estimated_grams"
        case measurementUnit = "measurement_unit"
        case measurementAmount = "measurement_amount"
        case confidence
        case note
        case quantity
    }

    init(id: UUID = UUID(), name: String, calories: Int, protein: Double, carbs: Double, fat: Double, fiber: Double = 0, sugar: Double = 0, servingSize: String, estimatedGrams: Double = 0, measurementUnit: String = "g", measurementAmount: Double = 1.0, confidence: Double, note: String? = nil, quantity: Double = 1.0) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.servingSize = servingSize
        self.estimatedGrams = estimatedGrams
        self.measurementUnit = measurementUnit
        self.measurementAmount = measurementAmount
        self.confidence = confidence
        self.note = note
        self.quantity = quantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        if let intVal = try? container.decode(Int.self, forKey: .calories) {
            calories = intVal
        } else if let doubleVal = try? container.decode(Double.self, forKey: .calories) {
            calories = Int(doubleVal.rounded())
        } else {
            calories = 0
        }
        protein = (try? container.decode(Double.self, forKey: .protein)) ?? 0
        carbs = (try? container.decode(Double.self, forKey: .carbs)) ?? 0
        fat = (try? container.decode(Double.self, forKey: .fat)) ?? 0
        fiber = (try? container.decode(Double.self, forKey: .fiber)) ?? 0
        sugar = (try? container.decode(Double.self, forKey: .sugar)) ?? 0
        servingSize = (try? container.decode(String.self, forKey: .servingSize)) ?? ""
        estimatedGrams = (try? container.decode(Double.self, forKey: .estimatedGrams)) ?? 0
        measurementUnit = (try? container.decode(String.self, forKey: .measurementUnit)) ?? "g"
        measurementAmount = (try? container.decode(Double.self, forKey: .measurementAmount)) ?? 1.0
        confidence = (try? container.decode(Double.self, forKey: .confidence)) ?? 0.8
        note = try? container.decode(String.self, forKey: .note)
        quantity = (try? container.decode(Double.self, forKey: .quantity)) ?? 1.0
    }
}

struct ChatResponse: Codable {
    let message: String
    let cards: [ChatCard]?
}

struct ChatAIResponse: Sendable {
    let message: String
    let cards: [ChatCard]?
}

struct InsightResponse: Codable {
    let insight: String
}

/// Thread-safe box for capturing values across `@Sendable` closure boundaries.
final class SendableBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { _value = value }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); defer { lock.unlock() }; _value = newValue }
    }
}

struct UserContext: Sendable {
    let targetCalories: Int
    let targetProtein: Int
    let targetCarbs: Int
    let targetFat: Int
    let todayCalories: Int
    let todayProtein: Double
    let todayCarbs: Double
    let todayFat: Double
    let goalType: String
    let recentMeals: [String]
    let streak: Int
    let displayName: String?
    let dietStyle: String?
    let weekHistory: [WeekDaySummary]
    let topFoods: [String]
    let weightTrend: String?
    let todayMealsDetail: String?
    let yesterdayCalories: Int?
    let yesterdayTarget: Int?

    func toDictionary() -> [String: String] {
        var dict = [
            "target_calories": "\(targetCalories)",
            "target_protein": "\(targetProtein)",
            "target_carbs": "\(targetCarbs)",
            "target_fat": "\(targetFat)",
            "today_calories": "\(todayCalories)",
            "today_protein": "\(todayProtein)",
            "today_carbs": "\(todayCarbs)",
            "today_fat": "\(todayFat)",
            "goal_type": goalType,
            "recent_meals": recentMeals.joined(separator: ", "),
            "streak": "\(streak)"
        ]
        if let name = displayName, !name.isEmpty { dict["display_name"] = name }
        if let diet = dietStyle, !diet.isEmpty { dict["diet_style"] = diet }

        // 7-day history
        if !weekHistory.isEmpty {
            let weekJson = weekHistory.map { d in
                "{\"date\":\"\(d.date)\",\"cal\":\(d.calories),\"p\":\(Int(d.protein)),\"c\":\(Int(d.carbs)),\"f\":\(Int(d.fat)),\"on_target\":\(d.isOnTarget)}"
            }.joined(separator: ",")
            dict["week_history"] = "[\(weekJson)]"
        }
        if !topFoods.isEmpty { dict["top_foods"] = topFoods.joined(separator: ", ") }
        if let wt = weightTrend, !wt.isEmpty { dict["weight_trend"] = wt }
        if let detail = todayMealsDetail, !detail.isEmpty { dict["today_meals_detail"] = detail }
        if let yc = yesterdayCalories, yc > 0 { dict["yesterday_calories"] = "\(yc)" }
        if let yt = yesterdayTarget, yt > 0 { dict["yesterday_target"] = "\(yt)" }
        return dict
    }
}

struct WeekDaySummary: Sendable {
    let date: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let isOnTarget: Bool
}
