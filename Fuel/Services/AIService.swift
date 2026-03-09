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

    /// Fetch the Anthropic API key from Supabase and activate the RAG pipeline.
    /// Call once at app launch AFTER authentication (get-api-key requires auth).
    func activateRAG() async {
        do {
            #if DEBUG
            print("[Fuel] activateRAG: calling get-api-key edge function...")
            #endif
            struct KeyResponse: Decodable {
                let key: String?
                let error: String?
            }
            let response: KeyResponse = try await supabase.functions.invoke(
                "get-api-key",
                options: .init(body: [:] as [String: String])
            )
            #if DEBUG
            if let error = response.error {
                print("[Fuel] activateRAG: server returned error: \(error)")
            }
            #endif
            if let key = response.key, !key.isEmpty {
                ClaudeNutritionService.shared.apiKey = key
                useRAG = true
                #if DEBUG
                print("[Fuel] RAG activated (key length: \(key.count))")
                #endif
            } else {
                #if DEBUG
                print("[Fuel] activateRAG: key was nil or empty — will use Supabase fallback")
                #endif
            }
        } catch {
            #if DEBUG
            print("[Fuel] activateRAG FAILED: \(error)")
            if let urlError = error as? URLError {
                print("[Fuel] activateRAG URLError code: \(urlError.code.rawValue)")
            }
            #endif
        }

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
        let result: FoodAnalysis

        try Task.checkCancellation()

        let hasApiKey = !ClaudeNutritionService.shared.apiKey.isEmpty
        #if DEBUG
        print("[Fuel] analyzePhoto: start (useRAG=\(useRAG), imageSize=\(imageData.count), apiKey=\(hasApiKey ? "set" : "EMPTY"))")
        #endif

        // If no API key yet, try activating RAG one more time (session might have been restored late)
        if !hasApiKey && !useRAG {
            #if DEBUG
            print("[Fuel] analyzePhoto: no API key — retrying activateRAG()...")
            #endif
            await activateRAG()
            #if DEBUG
            print("[Fuel] analyzePhoto: after retry, apiKey=\(ClaudeNutritionService.shared.apiKey.isEmpty ? "STILL EMPTY" : "set")")
            #endif
        }

        try Task.checkCancellation()

        // Check image hash cache first
        let imageHash = imageData.fuelHash
        if let cached = PhotoScanCache.shared.get(hash: imageHash) {
            #if DEBUG
            print("[Fuel] analyzePhoto: cache HIT")
            #endif
            return cached
        }

        // Single attempt: Direct API → Supabase fallback. No retries for photos.
        // Photos are expensive vision calls — fail fast and let user retry.
        let hasKey = !ClaudeNutritionService.shared.apiKey.isEmpty

        if hasKey {
            // Path 1: Direct Claude API with RAG (fastest, ~5-15s)
            do {
                #if DEBUG
                print("[Fuel] analyzePhoto: direct API path...")
                #endif
                result = try await analyzePhotoWithRAG(imageData: imageData, description: description, onItemsIdentified: onItemsIdentified)
                #if DEBUG
                print("[Fuel] analyzePhoto: direct API succeeded — \(result.displayName) (\(result.totalCalories) cal)")
                #endif
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try Task.checkCancellation()
                // Direct API failed — immediately try Supabase (no further retries)
                #if DEBUG
                print("[Fuel] analyzePhoto: direct API failed (\(error)), trying Supabase fallback...")
                #endif
                do {
                    result = try await analyzePhotoWithSupabase(imageData: imageData)
                    #if DEBUG
                    print("[Fuel] analyzePhoto: Supabase fallback succeeded — \(result.displayName) (\(result.totalCalories) cal)")
                    #endif
                } catch is CancellationError {
                    throw CancellationError()
                } catch let fallbackError {
                    // Both paths failed — try offline if description available
                    if let desc = description, let offline = offlineEstimate(query: desc) {
                        #if DEBUG
                        print("[Fuel] analyzePhoto: ALL paths failed. Offline estimate for: \(desc)")
                        #endif
                        result = offline
                    } else {
                        #if DEBUG
                        print("[Fuel] analyzePhoto: ALL paths FAILED. Direct: \(error), Supabase: \(fallbackError)")
                        #endif
                        throw error // Throw the original (more informative) error
                    }
                }
            }
        } else {
            // No client API key — use Supabase (has server-side key)
            do {
                #if DEBUG
                print("[Fuel] analyzePhoto: Supabase path (no client API key)...")
                #endif
                result = try await analyzePhotoWithSupabase(imageData: imageData)
                #if DEBUG
                print("[Fuel] analyzePhoto: Supabase succeeded — \(result.displayName) (\(result.totalCalories) cal)")
                #endif
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if let desc = description, let offline = offlineEstimate(query: desc) {
                    #if DEBUG
                    print("[Fuel] analyzePhoto: Supabase failed. Offline estimate for: \(desc)")
                    #endif
                    result = offline
                } else {
                    #if DEBUG
                    print("[Fuel] analyzePhoto: Supabase FAILED. Error: \(error)")
                    #endif
                    throw error
                }
            }
        }

        PhotoScanCache.shared.set(result, hash: imageHash)

        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        #if DEBUG
        print("[Fuel] analyzePhoto: completed in \(elapsedMs)ms — \(result.displayName) (\(result.totalCalories) cal)")
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
                    servingSize: item.servingSize,
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
                servingSize: item.servingSize,
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
                servingSize: item.servingSize,
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
                    servingSize: item.servingSize,
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
                    servingSize: item.servingSize,
                    confidence: min(item.confidence, 0.4),
                    note: (item.note.map { $0 + ". " } ?? "") + "Unusually low — please verify"
                )
            }
            // Protein impossible check: protein > total calories / 4 is physically impossible
            if item.protein > 0 && item.protein * 4 > Double(item.calories) * 1.1 {
                needsUpdate = true
                let cappedProtein = round(Double(item.calories) / 4.0 * 10) / 10
                return AnalyzedFoodItem(
                    id: item.id, name: item.name,
                    calories: item.calories,
                    protein: cappedProtein,
                    carbs: item.carbs, fat: item.fat,
                    servingSize: item.servingSize,
                    confidence: item.confidence,
                    note: item.note
                )
            }
            // Fat impossible check: fat > total calories / 9 is physically impossible
            if item.fat > 0 && item.fat * 9 > Double(item.calories) * 1.1 {
                needsUpdate = true
                let cappedFat = round(Double(item.calories) / 9.0 * 10) / 10
                return AnalyzedFoodItem(
                    id: item.id, name: item.name,
                    calories: item.calories,
                    protein: item.protein,
                    carbs: item.carbs, fat: cappedFat,
                    servingSize: item.servingSize,
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
                    servingSize: item.servingSize,
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
                    servingSize: item.servingSize,
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
                servingSize: item.servingSize,
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
                servingSize: item.servingSize,
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

        // Step 1: Macro math check — P×4 + C×4 + F×9 ≈ total
        let computedCal = Int(analysis.totalProtein * 4 + analysis.totalCarbs * 4 + analysis.totalFat * 9)
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
                servingSize: item.servingSize,
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
    private func deduplicateItems(_ analysis: FoodAnalysis) -> FoodAnalysis {
        var seen: [String: Int] = [:] // lowercased name -> index in merged array
        var merged = [AnalyzedFoodItem]()

        for item in analysis.items {
            let key = item.name.lowercased().trimmingCharacters(in: .whitespaces)
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
        let item = AnalyzedFoodItem(
            id: UUID(),
            name: food.name,
            calories: cal,
            protein: p,
            carbs: c,
            fat: f,
            servingSize: scale != 1.0 ? "\(String(format: "%.1f", scale))x \(food.serving)" : food.serving,
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
            confidenceReason: "Quick estimate from local database",
            servingAssumed: item.servingSize
        )
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
            if useRAG {
                // Check cache
                let cacheKey = safeQuery
                if NutritionCache.shared.get(for: cacheKey) != nil {
                    wasCached = true
                }

                do {
                    result = try await searchFoodWithRAG(query: safeQuery)
                } catch {
                    // RAG failed — try Supabase before going offline
                    #if DEBUG
                    print("[Fuel] RAG text analysis failed: \(error.localizedDescription). Trying Supabase fallback...")
                    #endif
                    result = try await searchFoodWithSupabase(query: safeQuery)
                }
            } else {
                do {
                    result = try await searchFoodWithSupabase(query: safeQuery)
                } catch {
                    // Supabase failed — try RAG if API key available
                    if !ClaudeNutritionService.shared.apiKey.isEmpty {
                        #if DEBUG
                        print("[Fuel] Supabase text analysis failed: \(error.localizedDescription). Trying direct API...")
                        #endif
                        result = try await searchFoodWithRAG(query: safeQuery)
                    } else {
                        throw error
                    }
                }
            }
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
        let result: FoodAnalysis = try await supabase.functions.invoke(
            "analyze-food",
            options: .init(body: [
                "query": query,
                "request_type": "text"
            ] as [String: String])
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
        let result: FoodAnalysis
        do {
            let rawResult: FoodAnalysis = try await supabase.functions.invoke(
                "analyze-food",
                options: .init(body: [
                    "barcode": safeBarcode,
                    "request_type": "barcode"
                ] as [String: String])
            )
            result = useRAG ? enrichWithRAG(rawResult) : rawResult
        } catch {
            // Supabase unreachable — try direct Claude API if key available
            if !ClaudeNutritionService.shared.apiKey.isEmpty {
                #if DEBUG
                print("[Fuel] Supabase barcode lookup failed: \(error.localizedDescription). Trying direct API...")
                #endif
                let analysis = try await ClaudeNutritionService.shared.analyze(
                    description: "Nutrition for the packaged product with barcode \(safeBarcode). If you recognize this barcode/UPC, provide accurate nutrition data. Otherwise provide your best estimate for a typical product."
                )
                result = analysis.toFoodAnalysis()
            } else {
                throw error
            }
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
            items.append(AnalyzedFoodItem(
                id: UUID(), name: food.name,
                calories: food.calories, protein: food.protein,
                carbs: food.carbs, fat: food.fat,
                servingSize: food.serving, confidence: confidence,
                note: "Estimated from database (AI fallback)"
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
        var warnings = ["Estimated from database — AI analysis was unavailable"]
        if !unmatchedItems.isEmpty {
            warnings.append("Could not estimate: \(unmatchedItems.joined(separator: ", ")) — not in database")
        }
        return FoodAnalysis(
            items: items, displayName: displayName,
            totalCalories: totalCal,
            totalProtein: round(totalP * 10) / 10,
            totalCarbs: round(totalC * 10) / 10,
            totalFat: round(totalF * 10) / 10,
            fiberG: totalFiber, sugarG: totalSugar, sodiumMg: totalSodium,
            warnings: warnings,
            healthInsight: nil, calorieRange: nil,
            confidenceReason: "RAG fallback from photo identification",
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

            items.append(AnalyzedFoodItem(
                id: UUID(),
                name: food.name,
                calories: cal,
                protein: p,
                carbs: c,
                fat: f,
                servingSize: scale != 1.0 ? "\(String(format: "%.1f", scale))x \(food.serving)" : food.serving,
                confidence: food.confidence == .high ? 0.85 : 0.6,
                note: "Estimated from local database (offline)"
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
            warnings: ["Offline estimate — accuracy may be lower than AI analysis"],
            healthInsight: nil,
            calorieRange: nil,
            confidenceReason: "Matched to local database (no internet)",
            servingAssumed: items.first?.servingSize
        )
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

    func generateDailyInsight(summary: DailySummary, profile: UserProfile) async throws -> String {
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
            target_calories: profile.targetCalories ?? 2000,
            target_protein: profile.targetProtein ?? 150,
            meal_count: summary.meals.count,
            goal_type: profile.goalType?.rawValue ?? "maintain"
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
    let warnings: [String]?
    let healthInsight: String?
    let calorieRange: CalorieRange?
    let confidenceReason: String?
    let servingAssumed: String?

    init(items: [AnalyzedFoodItem], displayName: String, totalCalories: Int, totalProtein: Double, totalCarbs: Double, totalFat: Double, fiberG: Double? = nil, sugarG: Double? = nil, sodiumMg: Double? = nil, warnings: [String]? = nil, healthInsight: String? = nil, calorieRange: CalorieRange? = nil, confidenceReason: String? = nil, servingAssumed: String? = nil) {
        self.items = items
        self.displayName = displayName
        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.sodiumMg = sodiumMg
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
        // Handle totalCalories as Int or Double
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
    let servingSize: String
    let confidence: Double
    let note: String?
    var quantity: Double

    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat
        case servingSize = "serving_size"
        case confidence
        case note
        case quantity
    }

    init(id: UUID = UUID(), name: String, calories: Int, protein: Double, carbs: Double, fat: Double, servingSize: String, confidence: Double, note: String? = nil, quantity: Double = 1.0) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingSize = servingSize
        self.confidence = confidence
        self.note = note
        self.quantity = quantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        // Handle calories as Int or Double (Claude sometimes returns 350.0)
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
        servingSize = (try? container.decode(String.self, forKey: .servingSize)) ?? ""
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
    let todayCalories: Int
    let todayProtein: Double
    let todayCarbs: Double
    let todayFat: Double
    let goalType: String
    let recentMeals: [String]
    let streak: Int

    func toDictionary() -> [String: String] {
        [
            "target_calories": "\(targetCalories)",
            "target_protein": "\(targetProtein)",
            "today_calories": "\(todayCalories)",
            "today_protein": "\(todayProtein)",
            "today_carbs": "\(todayCarbs)",
            "today_fat": "\(todayFat)",
            "goal_type": goalType,
            "recent_meals": recentMeals.joined(separator: ", "),
            "streak": "\(streak)"
        ]
    }
}
