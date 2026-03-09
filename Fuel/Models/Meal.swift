import Foundation

struct Meal: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var items: [MealItem]
    var totalCalories: Int
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var imageUrl: String?
    var displayName: String
    var loggedDate: String
    var loggedAt: Date
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case items
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
        case imageUrl = "image_url"
        case displayName = "display_name"
        case loggedDate = "logged_date"
        case loggedAt = "logged_at"
        case createdAt = "created_at"
    }
}

struct MealItem: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var servingSize: String?
    var quantity: Double
    var confidence: Double

    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat
        case servingSize = "serving_size"
        case quantity, confidence
    }
}
