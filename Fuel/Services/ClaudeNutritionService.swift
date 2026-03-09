import Foundation
import UIKit

enum NutritionError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case invalidResponse
    case apiError(statusCode: Int, body: String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is not configured. Set ClaudeNutritionService.shared.apiKey."
        case .imageEncodingFailed:
            return "Failed to encode image as JPEG."
        case .invalidResponse:
            return "Received an invalid response from the API."
        case .apiError(let code, let body):
            return "API error (\(code)): \(body)"
        case .parseError(let detail):
            return "Failed to parse nutrition data: \(detail)"
        }
    }

}

final class ClaudeNutritionService: @unchecked Sendable {
    static let shared = ClaudeNutritionService()
    private let rag = NutritionRAG.shared
    private let cache = NutritionCache.shared

    private let _lock = NSLock()
    private var _apiKeyCache: String?
    private var _userContext: UserNutritionContext?
    private static let keychainKey = "anthropic_api_key"

    var apiKey: String {
        get {
            _lock.lock(); defer { _lock.unlock() }
            if let cached = _apiKeyCache { return cached }
            let stored = KeychainHelper.load(key: Self.keychainKey) ?? ""
            _apiKeyCache = stored
            return stored
        }
        set {
            _lock.lock(); defer { _lock.unlock() }
            _apiKeyCache = newValue
            if newValue.isEmpty {
                KeychainHelper.delete(key: Self.keychainKey)
            } else {
                KeychainHelper.save(key: Self.keychainKey, value: newValue)
            }
        }
    }

    var userContext: UserNutritionContext? {
        get { _lock.lock(); defer { _lock.unlock() }; return _userContext }
        set { _lock.lock(); defer { _lock.unlock() }; _userContext = newValue }
    }

    // swiftlint:disable:next force_unwrapping
    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-haiku-4-5-20251001"
    private let maxRetries = 2

    private init() {}

    // MARK: - Public Analysis Methods

    func analyze(description: String, portionHint: String? = nil) async throws -> NutritionAnalysis {
        guard !apiKey.isEmpty else { throw NutritionError.missingAPIKey }

        let cacheKey = [description, portionHint ?? ""].joined(separator: "|")
        if let cached = cache.get(for: cacheKey) {
            return cached
        }

        let context = rag.contextForQuery(description)
        let system = buildSystemPrompt(context: context, isVision: false)
        let userContent = buildTextUserMessage(description: description, portionHint: portionHint)

        let result = try await callClaudeWithRetry(system: system, userContent: userContent)
        cache.set(result, for: cacheKey)
        return result
    }

    func analyze(imageData: Data, additionalDescription: String? = nil, onItemsIdentified: (@Sendable ([String]) -> Void)? = nil) async throws -> NutritionAnalysis {
        guard !apiKey.isEmpty else {
            #if DEBUG
            print("[Fuel] ClaudeNutritionService: API key is EMPTY — throwing missingAPIKey")
            #endif
            throw NutritionError.missingAPIKey
        }

        try Task.checkCancellation()

        let base64 = imageData.base64EncodedString()
        #if DEBUG
        print("[Fuel] analyze(image): \(imageData.count) bytes → \(base64.count) base64 chars")
        #endif

        // Build RAG context: use description if provided, otherwise include
        // common food anchors so Claude has calibration reference data.
        let context: String
        if let desc = additionalDescription, !desc.isEmpty {
            context = rag.contextForQuery(desc)
        } else {
            context = commonFoodAnchors()
        }

        let system = buildVisionSystemPrompt(ragContext: context)
        let userContent = buildVisionUserMessage(base64: base64, mimeType: "image/jpeg", additionalDescription: additionalDescription)

        // PHOTO: Single attempt, 20s timeout. No retry — vision calls are expensive
        // and retrying with the same image rarely helps. Fail fast, let user retry.
        #if DEBUG
        print("[Fuel] analyze(image): single-pass Sonnet call (model: \(model), timeout: 20s)...")
        #endif
        let result = try await callClaude(system: system, userContent: userContent, timeout: 20)
        #if DEBUG
        print("[Fuel] analyze(image): success — \(result.mealName) (\(result.totalCalories) cal)")
        #endif

        // Notify caller of identified items (for UI/RAG)
        let items = result.items.map { $0.item }
        if !items.isEmpty {
            onItemsIdentified?(items)
        }

        return result
    }

    /// Curated USDA calorie anchors for photo analysis when no description is available.
    /// Gives Claude calibration points to improve portion/calorie accuracy.
    private func commonFoodAnchors() -> String {
        return """
        USDA CALORIE ANCHORS (use as reference for weight-based estimation):
        PROTEINS:
        Chicken breast grilled (4oz/113g): 187cal 35P 0C 4F | Chicken thigh (4oz): 232cal 28P 0C 13F
        Steak sirloin (6oz/170g): 312cal 48P 0C 12F | Ground beef 80/20 (4oz): 290cal 26P 0C 20F
        Salmon fillet (4oz/113g): 234cal 25P 0C 14F | Shrimp (4oz): 120cal 23P 1C 2F
        Egg large: 72cal 6P 0.4C 5F | Tofu firm (½ cup/126g): 181cal 22P 4C 11F
        Turkey breast (4oz): 153cal 34P 0C 1F | Pork chop (4oz): 187cal 30P 0C 7F
        STARCHES:
        White rice cooked (1 cup/186g): 206cal 4P 45C 0.4F | Brown rice (1 cup/195g): 216cal 5P 45C 1.8F
        Pasta cooked (1 cup/140g): 220cal 8P 43C 1.3F | Bread slice white: 79cal 3P 15C 1F
        Baked potato medium (173g): 161cal 4P 37C 0.2F | Sweet potato (130g): 112cal 2P 26C 0.1F
        Tortilla flour 10": 218cal 6P 36C 5F | Hamburger bun: 140cal 5P 25C 2F
        Quinoa cooked (1 cup/185g): 222cal 8P 39C 4F | Naan bread: 262cal 9P 45C 5F
        VEGETABLES:
        Broccoli (1 cup/91g): 31cal 3P 6C 0.3F | Mixed salad greens (2 cups): 15cal 1P 2C 0.2F
        Corn on cob: 90cal 3P 19C 1.5F | Green beans (1 cup): 34cal 2P 8C 0.1F
        FAST FOOD:
        Pizza slice large cheese: 285cal 12P 36C 10F | Pepperoni slice: 313cal 13P 35C 13F
        Big Mac: 563cal 26P 44C 33F | Cheeseburger (single): 303cal 16P 32C 13F
        French fries medium (117g): 365cal 4P 44C 19F | Chicken nuggets (6pc): 270cal 13P 16C 17F
        Burrito chicken (standard): 580cal 32P 62C 20F | Taco beef: 210cal 10P 21C 10F
        COMMON ADDITIONS:
        Butter pat (1 tsp/5g): 36cal 0P 0C 4F | Olive oil (1 tbsp): 119cal 0P 0C 14F
        Avocado half: 161cal 2P 9C 15F | Cheese slice American: 70cal 4P 1C 6F
        Sour cream (2 tbsp): 57cal 1P 1C 6F | Guacamole (2 tbsp): 50cal 1P 3C 4F
        """
    }

    /// Convenience: accept UIImage by encoding to JPEG first
    func analyze(image: UIImage, additionalDescription: String? = nil, onItemsIdentified: (@Sendable ([String]) -> Void)? = nil) async throws -> NutritionAnalysis {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw NutritionError.imageEncodingFailed
        }
        return try await analyze(imageData: jpegData, additionalDescription: additionalDescription, onItemsIdentified: onItemsIdentified)
    }

    func analyze(imageData: Data, description: String) async throws -> NutritionAnalysis {
        guard !apiKey.isEmpty else { throw NutritionError.missingAPIKey }

        let base64 = imageData.base64EncodedString()
        let context = rag.contextForQuery(description)
        let system = buildSystemPrompt(context: context, isVision: true)
        let userContent = buildVisionUserMessage(base64: base64, mimeType: "image/jpeg", additionalDescription: description)

        return try await callClaudeWithRetry(system: system, userContent: userContent)
    }

    // MARK: - Meal Time Context

    private func mealTimeContext() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "MEAL CONTEXT: It is morning (breakfast time). Default to breakfast portions and items when ambiguous. A 'bowl' likely means oatmeal/cereal. A 'sandwich' likely means a breakfast sandwich."
        case 11..<14: return "MEAL CONTEXT: It is midday (lunch time). Default to lunch portions. A 'bowl' likely means a lunch bowl. A 'sandwich' is a lunch sandwich."
        case 14..<17: return "MEAL CONTEXT: It is afternoon (snack time). Portions are likely smaller — snack-sized. A 'drink' is likely an afternoon coffee or smoothie."
        case 17..<21: return "MEAL CONTEXT: It is evening (dinner time). Default to dinner portions which are typically the largest meal. A 'plate' means a full dinner plate."
        default: return "MEAL CONTEXT: It is late night. Portions may be snack-sized or late-night fast food."
        }
    }

    // MARK: - Vision System Prompt (enterprise-grade food identification)

    private func buildVisionSystemPrompt(ragContext: String) -> String {
        var prompt = """
        You are a USDA-certified clinical nutritionist with 20+ years of dietary assessment expertise. \
        Analyze this food photo with laboratory-grade precision and return nutrition data.

        SYSTEMATIC SCAN PROTOCOL:
        1. Scan the ENTIRE image systematically: center → edges → background → containers → drinks.
        2. Identify EVERY distinct food and drink item. Each visually separate component is its own item.
        3. When multiple foods share a plate, DIFFERENTIATE each — rice next to chicken next to vegetables = 3 items.
        4. Count discrete items precisely: 3 chicken strips, 2 tacos, 4 sushi pieces.
        5. Include ALL sauces, condiments, dressings, toppings, and drinks visible — even small ones.
        6. Compound foods (burger, sandwich, burrito) = ONE item with all components factored in.

        WEIGHT-FIRST ESTIMATION (most accurate method):
        For each item, estimate weight in grams FIRST, then derive calories:
        - Use plate/bowl/container as scale reference (standard dinner plate = 10-11" / 25-28cm)
        - Palm of hand ≈ 3-4oz / 85-113g cooked meat
        - Fist ≈ 1 cup / 240ml / ~200g rice or pasta
        - Thumb tip ≈ 1 tsp, whole thumb ≈ 1 tbsp
        - Cupped hand ≈ ½ cup / 120ml
        - Thickness matters: thin chicken breast 3-4oz, thick 6-8oz
        - Meat shrinks ~25% when cooked (4oz raw ≈ 3oz cooked)
        - Bowl of rice/pasta: 1-1.5 cups cooked (186-280g)
        - Drinks: small=8-12oz, medium=16oz, large=20-24oz

        COOKING METHOD ADJUSTMENTS:
        - Grill marks → grilled (base calories)
        - Golden/crispy coating → fried or breaded (+30-50% cal, add 5-15g fat per item)
        - Glistening/shiny surface → oiled or buttered (+40-120 cal per visible tbsp)
        - Creamy/white sauce → cream-based (150-200 cal per ¼ cup)
        - Charred edges → grilled/roasted (base calories)
        - Steamed/plain → base calories, minimal added fat

        HIDDEN CALORIE CHECKLIST (NEVER skip):
        Oils: 120cal/tbsp | Butter: 100cal/tbsp | Mayo: 100cal/tbsp
        Ranch/creamy dressing: 130cal/2tbsp | Vinaigrette: 70cal/2tbsp
        Cheese slice: 70cal | ¼cup shredded: 110cal | Cream cheese: 50cal/tbsp
        Guacamole: 50cal/2tbsp | Sour cream: 30cal/tbsp | Hummus: 70cal/2tbsp
        Ketchup: 20cal/tbsp | BBQ sauce: 35cal/tbsp | Soy sauce: 10cal/tbsp
        Bun/roll: 120-150cal | Tortilla 10": 220cal | Bread slice: 80cal
        Soda: 140cal/12oz | Juice: 110cal/8oz | Beer: 150cal/12oz | Wine: 125cal/5oz

        ACCURACY RULES:
        1. ALWAYS give definitive numbers — never refuse to estimate.
        2. Slight overestimate (5-10%) is safer than underestimating for calorie tracking.
        3. Restaurant portions = 1.5-2× home portions. Fast food = use exact menu data if brand recognized.
        4. Validate: protein_g×4 + carbs_g×4 + fat_g×9 should ≈ total_calories (±10%).
        5. Read nutrition labels if visible — use printed values EXACTLY.
        6. Non-food image → meal_name: "Not a food item", total_calories: 0, confidence: "low".
        """

        if !ragContext.isEmpty {
            prompt += "\n\nUSDA REFERENCE DATABASE:\n\(ragContext)"
        }

        prompt += "\n\n\(mealTimeContext())"

        prompt += """

        Respond with ONLY valid JSON (no markdown, no backticks, no extra text):
        {"meal_name":"string","total_calories":int,"protein_g":num,"carbs_g":num,"fat_g":num,"fiber_g":num,"sugar_g":num,"sodium_mg":num,"serving_assumed":"string","confidence":"high|medium|low","confidence_reason":"string","items":[{"item":"string","quantity":"string","calories":int,"protein":num,"carbs":num,"fat":num,"estimated_grams":num,"note":"string"}],"warnings":["string"],"health_insight":"string","calorie_range":{"low":int,"high":int}}
        """

        if let ctx = userContext {
            let goal: String = switch ctx.goalType {
            case "lose": "losing weight"
            case "gain": "gaining"
            case "bulk": "bulking"
            default: "maintaining"
            }
            prompt += "\n\nUSER: \(ctx.caloriesRemaining) cal remaining. Goal: \(goal). Tailor health_insight."
        }

        return prompt
    }

    // MARK: - Text System Prompt (detailed for accuracy)

    private func buildSystemPrompt(context: String, isVision: Bool) -> String {
        var prompt = """
        You are a clinical nutrition AI. Provide precise, definitive nutritional analysis.

        RULES:
        1. ALWAYS give definitive numbers. Never refuse to estimate.
        2. Ambiguous portion = standard serving from database below.
        3. Multiply per-unit values by quantity ("2 eggs" = 2 × egg values).
        4. Include ALL hidden calories: oils (120cal/tbsp), butter, sauces, cheese, cream.
        5. Cooking method adjustments: fried +30-50% vs grilled. Breaded+fried ≈ 2× plain.
        6. Conservative: slight overestimate (5-10%) is safer than underestimating.
        7. Restaurant portions = 1.5-2× home portions. Fast food = use exact menu data.
        8. Multiple items → separate entries in "items" array. Sum for totals.
        9. Compound foods ("mac and cheese", "fish and chips") = ONE item, not split.
        10. Validate: P×4 + C×4 + F×9 ≈ total_calories. Alcohol = 7cal/g (add to total, note it).
        11. fiber_g, sugar_g, sodium_mg are REQUIRED. Never 0 unless genuinely zero.
        12. Non-food input → meal_name: "Not a food item", total_calories: 0, confidence: "low".

        QUANTITIES: "a couple"=2, "a few"=3, "handful"=1oz, "large coffee"=16oz, "slice"=standard.
        """

        if isVision {
            prompt += """

            PHOTO RULES:
            - Scan entire image: center, edges, background, containers. Count discrete items precisely.
            - Cooking cues: grill marks=grilled, golden/crispy=fried(+50-200cal), glistening=oiled(+40-120cal), moist=steamed.
            - Restaurant packaging/logos → use exact menu data. Nutrition labels → read printed values.
            - Blurry → state assumptions in serving_assumed, widen calorie_range.

            HIDDEN CALORIES (NEVER skip visible condiments/sides/drinks):
            Sauces: ranch 130/2tbsp, mayo 100/tbsp, BBQ 70/2tbsp, ketchup 20/tbsp. Cheese: slice 70, 1/4cup shredded 110. Fats: butter 100/pat, oil 120/tbsp, guac 50/2tbsp. Bread: bun 120-150, tortilla 180-220. Drinks: soda 140/12oz, juice 110/8oz.

            PORTIONS: dinner plate ~10in, palm ~3-4oz meat, fist ~1cup. Drinks: sm=12oz, md=16oz, lg=20-24oz. Restaurant = 1.5-2x home portions. Compare to database serving sizes and scale for visible portion.
            """
        }

        prompt += """

        \(mealTimeContext())

        DATABASE:
        \(context)

        Respond with ONLY valid JSON. No markdown, no backticks, no text outside the JSON.

        {"meal_name":"string","total_calories":int,"protein_g":num,"carbs_g":num,"fat_g":num,"fiber_g":num,"sugar_g":num,"sodium_mg":num,"serving_assumed":"string","confidence":"high|medium|low","confidence_reason":"string","items":[{"item":"string","quantity":"string","calories":int,"protein":num,"carbs":num,"fat":num,"note":"string"}],"warnings":["string"],"health_insight":"string","calorie_range":{"low":int,"high":int},"scaling_note":"string"}
        """

        if let ctx = userContext {
            let goal: String = switch ctx.goalType {
            case "lose": "losing weight — flag calorie-dense meals"
            case "tone_up": "toning — prioritize high protein"
            case "gain": "gaining — encourage calorie-dense foods"
            case "bulk": "bulking — high cal + high protein"
            case "athlete": "athlete — performance nutrition"
            default: "maintaining — flag surplus/deficit"
            }

            let diet: String = switch ctx.dietStyle {
            case "keto": "keto — warn if >20g net carbs"
            case "vegan": "vegan — warn if animal products"
            case "vegetarian": "vegetarian — warn if meat/fish"
            case "high_protein": "high-protein — highlight protein"
            case "mediterranean": "mediterranean — whole grains, healthy fats"
            default: "standard"
            }

            prompt += """

            USER: \(ctx.caloriesRemaining) cal, \(String(format: "%.0f", ctx.proteinRemainingG))g P, \(String(format: "%.0f", ctx.carbsRemainingG))g C, \(String(format: "%.0f", ctx.fatRemainingG))g F remaining. Goal: \(goal). Diet: \(diet). Tailor health_insight to these.
            """
        }

        return prompt
    }

    // MARK: - Message Builders

    private func buildTextUserMessage(description: String, portionHint: String?) -> [ClaudeContent] {
        var text = "Analyze the nutritional content of: \(description)"
        if let hint = portionHint, !hint.isEmpty {
            text += "\n\n** PORTION OVERRIDE — USE THIS FOR SERVING SIZE **\n\(hint)\nYou MUST scale all nutritional values according to this portion info. Do NOT use a default serving size."
        }
        return [ClaudeContent(type: "text", text: text)]
    }

    private func buildVisionUserMessage(base64: String, mimeType: String, additionalDescription: String?) -> [ClaudeContent] {
        var content: [ClaudeContent] = [
            ClaudeContent(
                type: "image",
                source: ClaudeImageSource(type: "base64", mediaType: mimeType, data: base64)
            )
        ]

        var text = "Analyze the nutritional content of the food shown in this image. Identify every item visible and estimate portions carefully."
        if let desc = additionalDescription, !desc.isEmpty {
            text += " The user describes this as: \(desc)"
        }
        content.append(ClaudeContent(type: "text", text: text))

        return content
    }

    // MARK: - API Call with Retry

    private func callClaudeWithRetry(system: String, userContent: [ClaudeContent]) async throws -> NutritionAnalysis {
        var lastError: Error?
        for attempt in 0...maxRetries {
            try Task.checkCancellation()
            do {
                #if DEBUG
                print("[Fuel] callClaude: attempt \(attempt + 1)/\(maxRetries + 1)...")
                #endif
                let result = try await callClaude(system: system, userContent: userContent, timeout: 30)
                #if DEBUG
                print("[Fuel] callClaude: attempt \(attempt + 1) succeeded — \(result.mealName)")
                #endif
                return result
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as NutritionError {
                lastError = error
                #if DEBUG
                print("[Fuel] callClaude: attempt \(attempt + 1) failed: \(error)")
                #endif
                switch error {
                case .apiError(let code, _) where code == 429 || code == 529 || code >= 500:
                    if attempt < maxRetries {
                        try Task.checkCancellation()
                        let base = Double(attempt + 1)
                        let jitter = Double.random(in: 0...0.5)
                        let delay = base + jitter
                        #if DEBUG
                        print("[Fuel] callClaude: retryable error \(code), waiting \(String(format: "%.1f", delay))s...")
                        #endif
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                default:
                    throw error
                }
            } catch let urlError as URLError where [.timedOut, .networkConnectionLost].contains(urlError.code) {
                lastError = urlError
                #if DEBUG
                print("[Fuel] callClaude: retryable URLError \(urlError.code.rawValue)")
                #endif
                if attempt < maxRetries {
                    try Task.checkCancellation()
                    let delay = Double(attempt + 1) + Double.random(in: 0...0.5)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
            } catch {
                #if DEBUG
                print("[Fuel] callClaude: non-NutritionError: \(error)")
                #endif
                throw error
            }
        }
        throw lastError ?? NutritionError.invalidResponse
    }

    private func callClaude(system: String, userContent: [ClaudeContent], timeout: TimeInterval) async throws -> NutritionAnalysis {
        try Task.checkCancellation()
        let callStart = CFAbsoluteTimeGetCurrent()
        // 2048 tokens accommodates complex multi-item meals (6+ items with notes)
        let request = ClaudeAPIRequest(
            model: model,
            maxTokens: 2048,
            temperature: 0.0,
            system: system,
            messages: [ClaudeMessage(role: "user", content: userContent)]
        )

        var urlRequest = URLRequest(url: Self.apiURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.timeoutInterval = timeout

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        let bodySize = urlRequest.httpBody?.count ?? 0
        #if DEBUG
        print("[Fuel] callClaude: POST to Claude API (model=\(model), bodySize=\(bodySize), timeout=\(Int(timeout))s)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let elapsed = Int((CFAbsoluteTimeGetCurrent() - callStart) * 1000)
        #if DEBUG
        print("[Fuel] callClaude: response received in \(elapsed)ms (\(data.count) bytes)")
        #endif

        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NutritionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            #if DEBUG
            print("[Fuel] Claude API error \(httpResponse.statusCode): \(String(body.prefix(200)))")
            #endif
            throw NutritionError.apiError(statusCode: httpResponse.statusCode, body: body)
        }

        let apiResponse = try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)

        guard let textContent = apiResponse.content.first(where: { $0.type == "text" }),
              let rawText = textContent.text else {
            throw NutritionError.invalidResponse
        }

        // Guard against blank/whitespace-only responses
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NutritionError.parseError("AI returned empty response")
        }

        return try parseNutritionJSON(from: rawText)
    }

    // MARK: - JSON Parsing (Defensive)

    private func parseNutritionJSON(from raw: String) throws -> NutritionAnalysis {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences (```json ... ``` or ```anything ... ```)
        if cleaned.hasPrefix("```") {
            // Remove opening fence and optional language tag (e.g. "```json\n")
            if let newlineIdx = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: newlineIdx)...])
            } else {
                cleaned = String(cleaned.drop(while: { $0 != "{" }))
            }
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find balanced JSON object boundaries (handle nested braces)
        guard let jsonString = extractBalancedJSON(from: cleaned) else {
            throw NutritionError.parseError("No valid JSON object found in response. Raw start: \(String(cleaned.prefix(100)))")
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NutritionError.parseError("Failed to convert JSON string to data")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(NutritionAnalysis.self, from: jsonData)
        } catch {
            throw NutritionError.parseError("JSON decode failed: \(error.localizedDescription). Raw start: \(String(jsonString.prefix(200)))")
        }
    }

    private func extractBalancedJSON(from text: String) -> String? {
        guard let startIdx = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        var endIdx = startIdx

        for idx in text[startIdx...].indices {
            let char = text[idx]

            if escaped {
                escaped = false
                continue
            }

            if char == "\\" && inString {
                escaped = true
                continue
            }

            if char == "\"" {
                inString.toggle()
                continue
            }

            if !inString {
                if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        endIdx = idx
                        return String(text[startIdx...endIdx])
                    }
                }
            }
        }

        // If we didn't find balanced braces, try the simple approach as fallback
        if let lastBrace = text.lastIndex(of: "}") {
            return String(text[startIdx...lastBrace])
        }

        return nil
    }
}
