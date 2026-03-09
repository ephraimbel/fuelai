import Foundation

/// Queries the Open Food Facts API (free, open-source, 3M+ branded/packaged products).
/// Supports both text search and barcode lookup.
/// Endpoint: https://world.openfoodfacts.org/
final class OpenFoodFactsService: @unchecked Sendable {
    static let shared = OpenFoodFactsService()
    private init() {}

    private let baseURL = "https://world.openfoodfacts.org"
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        // Open Food Facts requires a User-Agent
        config.httpAdditionalHeaders = ["User-Agent": "FuelApp/1.0 (iOS; contact@fuelapp.com)"]
        return URLSession(configuration: config)
    }()

    // MARK: - Barcode Lookup

    /// Look up a product by its barcode (EAN-13, UPC, etc.).
    /// Returns nil if not found.
    func lookupBarcode(_ barcode: String) async throws -> FoodItem? {
        guard let url = URL(string: "\(baseURL)/api/v2/product/\(barcode).json?fields=product_name,nutriments,serving_size,serving_quantity,brands,categories_tags") else { return nil }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        let result = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        guard result.status == 1, let product = result.product else { return nil }
        return convertToFoodItem(product)
    }

    // MARK: - Text Search

    /// Search Open Food Facts for products matching a query.
    /// Returns up to `pageSize` results.
    func search(query: String, pageSize: Int = 10) async throws -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard var components = URLComponents(string: "\(baseURL)/cgi/search.pl") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "\(min(pageSize, 25))"),
            URLQueryItem(name: "fields", value: "product_name,nutriments,serving_size,serving_quantity,brands,categories_tags,code"),
            // Filter to products with nutrition data
            URLQueryItem(name: "tagtype_0", value: "states"),
            URLQueryItem(name: "tag_contains_0", value: "contains"),
            URLQueryItem(name: "tag_0", value: "en:nutrition-facts-completed"),
        ]

        guard let url = components.url else { return [] }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        let result = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return result.products.compactMap { convertToFoodItem($0) }
    }

    // MARK: - Convert OFF → FoodItem

    private func convertToFoodItem(_ product: OFFProduct) -> FoodItem? {
        guard let name = product.product_name, !name.isEmpty else { return nil }
        let n = product.nutriments

        // OFF stores values per 100g and per serving
        // Prefer per-serving if available, fall back to per 100g
        let hasServing = (n?.energy_kcal_serving ?? 0) > 0
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double
        let sugar: Double
        let sodium: Double
        let servingSize: String
        let servingGrams: Double

        if hasServing {
            calories = n?.energy_kcal_serving ?? 0
            protein = n?.proteins_serving ?? 0
            carbs = n?.carbohydrates_serving ?? 0
            fat = n?.fat_serving ?? 0
            fiber = n?.fiber_serving ?? 0
            sugar = n?.sugars_serving ?? 0
            sodium = (n?.sodium_serving ?? 0) * 1000 // g → mg
            servingSize = product.serving_size ?? "1 serving"
            servingGrams = product.serving_quantity ?? 100
        } else {
            calories = n?.energy_kcal_100g ?? 0
            protein = n?.proteins_100g ?? 0
            carbs = n?.carbohydrates_100g ?? 0
            fat = n?.fat_100g ?? 0
            fiber = n?.fiber_100g ?? 0
            sugar = n?.sugars_100g ?? 0
            sodium = (n?.sodium_100g ?? 0) * 1000
            servingSize = "100g"
            servingGrams = 100
        }

        // Accept zero-calorie products (water, diet soda, black coffee) if they have a valid name
        guard calories >= 0 else { return nil }

        let brandPrefix = product.brands.map { "\($0) " } ?? ""
        let displayName = "\(brandPrefix)\(name)".trimmingCharacters(in: .whitespaces)

        return FoodItem(
            name: displayName,
            aliases: [],
            serving: servingSize,
            servingGrams: servingGrams,
            calories: Int(calories),
            protein: round(protein * 10) / 10,
            carbs: round(carbs * 10) / 10,
            fat: round(fat * 10) / 10,
            fiber: round(fiber * 10) / 10,
            sugar: round(sugar * 10) / 10,
            sodium: round(sodium * 10) / 10,
            category: inferCategory(from: product),
            subCategory: "",
            tags: ["openfoodfacts"],
            notes: product.code.map { "OFF barcode: \($0)" } ?? "Open Food Facts",
            confidence: .medium
        )
    }

    private func inferCategory(from product: OFFProduct) -> FoodCategory {
        let cats = (product.categories_tags ?? []).joined(separator: " ").lowercased()

        if cats.contains("meat") || cats.contains("chicken") || cats.contains("fish") || cats.contains("seafood") {
            return .protein
        }
        if cats.contains("dairy") || cats.contains("cheese") || cats.contains("milk") || cats.contains("yogurt") {
            return .dairy
        }
        if cats.contains("bread") || cats.contains("cereal") || cats.contains("pasta") || cats.contains("grain") {
            return .grain
        }
        if cats.contains("vegetable") {
            return .vegetable
        }
        if cats.contains("fruit") || cats.contains("juice") {
            return .fruit
        }
        if cats.contains("beverage") || cats.contains("drink") || cats.contains("water") || cats.contains("soda") {
            return .beverage
        }
        if cats.contains("snack") || cats.contains("chip") || cats.contains("crisp") {
            return .snack
        }
        if cats.contains("sweet") || cats.contains("chocolate") || cats.contains("candy") || cats.contains("cookie") {
            return .sweet
        }
        if cats.contains("sauce") || cats.contains("condiment") || cats.contains("dressing") {
            return .condiment
        }
        return .mixed
    }
}

// MARK: - Open Food Facts API Response Models

private struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]
    let count: Int?
}

private struct OFFProduct: Decodable {
    let product_name: String?
    let nutriments: OFFNutriments?
    let serving_size: String?
    let serving_quantity: Double?
    let brands: String?
    let categories_tags: [String]?
    let code: String?
}

private struct OFFNutriments: Decodable {
    // Per 100g
    let energy_kcal_100g: Double?
    let proteins_100g: Double?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let fiber_100g: Double?
    let sugars_100g: Double?
    let sodium_100g: Double?

    // Per serving
    let energy_kcal_serving: Double?
    let proteins_serving: Double?
    let carbohydrates_serving: Double?
    let fat_serving: Double?
    let fiber_serving: Double?
    let sugars_serving: Double?
    let sodium_serving: Double?

    enum CodingKeys: String, CodingKey {
        case energy_kcal_100g = "energy-kcal_100g"
        case proteins_100g
        case carbohydrates_100g
        case fat_100g
        case fiber_100g
        case sugars_100g
        case sodium_100g
        case energy_kcal_serving = "energy-kcal_serving"
        case proteins_serving
        case carbohydrates_serving
        case fat_serving
        case fiber_serving
        case sugars_serving
        case sodium_serving
    }
}
