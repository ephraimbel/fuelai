import Foundation

/// Queries the USDA FoodData Central API (free, no key required for foundation foods).
/// Endpoint: https://api.nal.usda.gov/fdc/v1/
final class USDAFoodService: @unchecked Sendable {
    static let shared = USDAFoodService()
    private init() {}

    // Demo key works for moderate usage. Replace with a real key for production.
    private let apiKey = "DEMO_KEY"
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    // MARK: - Search

    /// Search USDA FoodData Central for foods matching a query.
    /// Returns up to `pageSize` results (max 25 for speed).
    func search(query: String, pageSize: Int = 10) async throws -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard var components = URLComponents(string: "\(baseURL)/foods/search") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "pageSize", value: "\(min(pageSize, 25))"),
            // Prefer foundation & SR Legacy (USDA curated) over branded
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy"),
        ]

        guard let url = components.url else { return [] }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        let result = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        return result.foods.compactMap { convertToFoodItem($0) }
    }

    // MARK: - Convert USDA → FoodItem

    private func convertToFoodItem(_ usda: USDAFood) -> FoodItem? {
        // Extract key nutrients from the nutrients array
        let nutrients = usda.foodNutrients
        let energy = nutrientValue(nutrients, id: 1008) // Energy (kcal)
        let protein = nutrientValue(nutrients, id: 1003) // Protein
        let fat = nutrientValue(nutrients, id: 1004) // Total fat
        let carbs = nutrientValue(nutrients, id: 1005) // Carbohydrate
        let fiber = nutrientValue(nutrients, id: 1079) // Fiber
        let sugar = nutrientValue(nutrients, id: 2000) ?? nutrientValue(nutrients, id: 1063) // Sugars
        let sodium = nutrientValue(nutrients, id: 1093) // Sodium

        guard energy > 0 else { return nil }

        // USDA values are per 100g
        let servingGrams: Double = 100
        let name = cleanUSDAName(usda.description)

        return FoodItem(
            name: name,
            aliases: [],
            serving: "100g",
            servingGrams: servingGrams,
            calories: Int(energy),
            protein: round(protein * 10) / 10,
            carbs: round(carbs * 10) / 10,
            fat: round(fat * 10) / 10,
            fiber: round(fiber * 10) / 10,
            sugar: round(sugar * 10) / 10,
            sodium: round(sodium * 10) / 10,
            category: inferCategory(from: usda),
            subCategory: usda.foodCategory ?? "",
            tags: ["usda"],
            notes: "USDA FDC #\(usda.fdcId)",
            confidence: .high
        )
    }

    private func nutrientValue(_ nutrients: [USDANutrient], id: Int) -> Double {
        nutrients.first(where: { $0.nutrientId == id })?.value ?? 0
    }

    /// Clean up USDA's verbose naming (e.g. "Chicken, breast, meat only, cooked, roasted")
    private func cleanUSDAName(_ raw: String) -> String {
        // Capitalize first letter, lowercase rest, trim
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return raw }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst().lowercased()
    }

    private func inferCategory(from food: USDAFood) -> FoodCategory {
        let cat = (food.foodCategory ?? "").lowercased()
        let desc = food.description.lowercased()

        if cat.contains("beef") || cat.contains("pork") || cat.contains("poultry") ||
            cat.contains("chicken") || cat.contains("fish") || cat.contains("lamb") ||
            cat.contains("sausage") || cat.contains("finfish") || cat.contains("shellfish") ||
            desc.contains("meat") || desc.contains("turkey") {
            return .protein
        }
        if cat.contains("dairy") || cat.contains("cheese") || cat.contains("milk") || cat.contains("yogurt") {
            return .dairy
        }
        if cat.contains("cereal") || cat.contains("grain") || cat.contains("bread") || cat.contains("baked") || cat.contains("pasta") {
            return .grain
        }
        if cat.contains("vegetable") || cat.contains("legume") {
            return .vegetable
        }
        if cat.contains("fruit") {
            return .fruit
        }
        if cat.contains("fat") || cat.contains("oil") {
            return .fat
        }
        if cat.contains("nut") || cat.contains("seed") {
            return .legume
        }
        if cat.contains("beverage") {
            return .beverage
        }
        if cat.contains("snack") || cat.contains("candy") || cat.contains("sweet") {
            return .snack
        }
        if cat.contains("condiment") || cat.contains("spice") || cat.contains("sauce") {
            return .condiment
        }
        if cat.contains("fast food") || cat.contains("restaurant") {
            return .fastFood
        }
        return .mixed
    }
}

// MARK: - USDA API Response Models

private struct USDASearchResponse: Decodable {
    let foods: [USDAFood]
    let totalHits: Int?
}

private struct USDAFood: Decodable {
    let fdcId: Int
    let description: String
    let foodCategory: String?
    let foodNutrients: [USDANutrient]
}

private struct USDANutrient: Decodable {
    let nutrientId: Int
    let value: Double

    enum CodingKeys: String, CodingKey {
        case nutrientId, value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nutrientId = (try? container.decode(Int.self, forKey: .nutrientId)) ?? 0
        value = (try? container.decode(Double.self, forKey: .value)) ?? 0
    }
}
