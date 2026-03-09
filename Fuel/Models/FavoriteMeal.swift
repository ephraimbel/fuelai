import Foundation

struct FavoriteMeal: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var items: [MealItem]
    var totalCalories: Int
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var useCount: Int
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, items
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
        case useCount = "use_count"
        case createdAt = "created_at"
    }
}
