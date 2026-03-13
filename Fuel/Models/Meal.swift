import Foundation

struct Meal: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var items: [MealItem]
    var totalCalories: Int
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var totalFiber: Double
    var totalSugar: Double
    var totalSodium: Double
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
        case totalFiber = "total_fiber"
        case totalSugar = "total_sugar"
        case totalSodium = "total_sodium"
        case imageUrl = "image_url"
        case displayName = "display_name"
        case loggedDate = "logged_date"
        case loggedAt = "logged_at"
        case createdAt = "created_at"
    }

    init(id: UUID, userId: UUID, items: [MealItem], totalCalories: Int, totalProtein: Double, totalCarbs: Double, totalFat: Double, totalFiber: Double = 0, totalSugar: Double = 0, totalSodium: Double = 0, imageUrl: String? = nil, displayName: String, loggedDate: String, loggedAt: Date, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.items = items
        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
        self.totalFiber = totalFiber
        self.totalSugar = totalSugar
        self.totalSodium = totalSodium
        self.imageUrl = imageUrl
        self.displayName = displayName
        self.loggedDate = loggedDate
        self.loggedAt = loggedAt
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        items = (try? container.decode([MealItem].self, forKey: .items)) ?? []
        totalCalories = (try? container.decode(Int.self, forKey: .totalCalories)) ?? 0
        totalProtein = (try? container.decode(Double.self, forKey: .totalProtein)) ?? 0
        totalCarbs = (try? container.decode(Double.self, forKey: .totalCarbs)) ?? 0
        totalFat = (try? container.decode(Double.self, forKey: .totalFat)) ?? 0
        totalFiber = (try? container.decode(Double.self, forKey: .totalFiber)) ?? 0
        totalSugar = (try? container.decode(Double.self, forKey: .totalSugar)) ?? 0
        totalSodium = (try? container.decode(Double.self, forKey: .totalSodium)) ?? 0
        imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        displayName = (try? container.decode(String.self, forKey: .displayName)) ?? ""
        loggedDate = (try? container.decode(String.self, forKey: .loggedDate)) ?? ""
        loggedAt = (try? container.decode(Date.self, forKey: .loggedAt)) ?? Date()
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
    }
}

extension Meal {
    func toFoodAnalysis() -> FoodAnalysis {
        let analyzedItems = items.map { item in
            AnalyzedFoodItem(
                id: item.id, name: item.name, calories: item.calories,
                protein: item.protein, carbs: item.carbs, fat: item.fat,
                fiber: item.fiber, sugar: item.sugar,
                servingSize: item.servingSize ?? "1 serving",
                estimatedGrams: item.estimatedGrams,
                measurementUnit: item.measurementUnit,
                measurementAmount: item.measurementAmount,
                confidence: item.confidence, quantity: item.quantity
            )
        }
        return FoodAnalysis(
            items: analyzedItems, displayName: displayName,
            totalCalories: totalCalories, totalProtein: totalProtein,
            totalCarbs: totalCarbs, totalFat: totalFat,
            fiberG: totalFiber, sugarG: totalSugar, sodiumMg: totalSodium
        )
    }
}

struct MealItem: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var servingSize: String?
    var estimatedGrams: Double
    var measurementUnit: String
    var measurementAmount: Double
    var quantity: Double
    var confidence: Double

    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat, fiber, sugar
        case servingSize = "serving_size"
        case estimatedGrams = "estimated_grams"
        case measurementUnit = "measurement_unit"
        case measurementAmount = "measurement_amount"
        case quantity, confidence
    }

    init(id: UUID, name: String, calories: Int, protein: Double, carbs: Double, fat: Double, fiber: Double = 0, sugar: Double = 0, servingSize: String? = nil, estimatedGrams: Double = 0, measurementUnit: String = "g", measurementAmount: Double = 1.0, quantity: Double, confidence: Double) {
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
        self.quantity = quantity
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        calories = (try? container.decode(Int.self, forKey: .calories)) ?? 0
        protein = (try? container.decode(Double.self, forKey: .protein)) ?? 0
        carbs = (try? container.decode(Double.self, forKey: .carbs)) ?? 0
        fat = (try? container.decode(Double.self, forKey: .fat)) ?? 0
        fiber = (try? container.decode(Double.self, forKey: .fiber)) ?? 0
        sugar = (try? container.decode(Double.self, forKey: .sugar)) ?? 0
        servingSize = try? container.decode(String.self, forKey: .servingSize)
        estimatedGrams = (try? container.decode(Double.self, forKey: .estimatedGrams)) ?? 0
        measurementUnit = (try? container.decode(String.self, forKey: .measurementUnit)) ?? "g"
        measurementAmount = (try? container.decode(Double.self, forKey: .measurementAmount)) ?? 1.0
        quantity = (try? container.decode(Double.self, forKey: .quantity)) ?? 1
        confidence = (try? container.decode(Double.self, forKey: .confidence)) ?? 0.75
    }
}
