import Foundation

struct DailySummary: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let date: String
    var totalCalories: Int
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var meals: [Meal]
    var waterMl: Int
    var aiInsight: String?
    var isOnTarget: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
        case waterMl = "water_ml"
        case aiInsight = "ai_insight"
        case isOnTarget = "is_on_target"
    }

    init(id: UUID = UUID(), userId: UUID, date: String, totalCalories: Int = 0, totalProtein: Double = 0, totalCarbs: Double = 0, totalFat: Double = 0, meals: [Meal] = [], waterMl: Int = 0, aiInsight: String? = nil, isOnTarget: Bool = false) {
        self.id = id
        self.userId = userId
        self.date = date
        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
        self.meals = meals
        self.waterMl = waterMl
        self.aiInsight = aiInsight
        self.isOnTarget = isOnTarget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        date = try container.decode(String.self, forKey: .date)
        totalCalories = (try? container.decode(Int.self, forKey: .totalCalories)) ?? 0
        totalProtein = (try? container.decode(Double.self, forKey: .totalProtein)) ?? 0
        totalCarbs = (try? container.decode(Double.self, forKey: .totalCarbs)) ?? 0
        totalFat = (try? container.decode(Double.self, forKey: .totalFat)) ?? 0
        waterMl = (try? container.decode(Int.self, forKey: .waterMl)) ?? 0
        aiInsight = try? container.decodeIfPresent(String.self, forKey: .aiInsight)
        isOnTarget = (try? container.decode(Bool.self, forKey: .isOnTarget)) ?? false
        meals = [] // Not stored in DB, populated separately
    }
}
