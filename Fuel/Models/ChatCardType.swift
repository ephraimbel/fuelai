import Foundation

enum ChatCardType: String, Codable, Sendable {
    case calorieProgress = "calorie_progress"
    case macroBreakdown = "macro_breakdown"
    case mealLog = "meal_log"
    case tip
    case mealPlan = "meal_plan"
    case foodLog = "food_log"
    case dailySummary = "daily_summary"
    case restaurantOrder = "restaurant_order"
    case mealEdit = "meal_edit"
    case groceryList = "grocery_list"
    case mealPrep = "meal_prep"
    case substitution
    case fridgeMeal = "fridge_meal"
    case streakRecovery = "streak_recovery"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ChatCardType(rawValue: rawValue) ?? .unknown
    }
}

struct ChatCard: Codable, Identifiable, Sendable {
    let id: UUID
    let type: ChatCardType
    let tipText: String?
    let foodQuery: String?
    let mealPlanData: MealPlanData?
    let restaurantOrderData: RestaurantOrderData?
    let mealEditData: MealEditData?
    let groceryListData: GroceryListData?
    let mealPrepData: MealPrepData?
    let substitutionData: SubstitutionData?
    let fridgeMealData: FridgeMealData?
    let streakRecoveryData: StreakRecoveryData?

    enum CodingKeys: String, CodingKey {
        case type
        case tipText = "tip_text"
        case foodQuery = "food_query"
        case mealPlanData = "meal_plan"
        case restaurantOrderData = "restaurant_order"
        case mealEditData = "meal_edit"
        case groceryListData = "grocery_list"
        case mealPrepData = "meal_prep"
        case substitutionData = "substitution"
        case fridgeMealData = "fridge_meal"
        case streakRecoveryData = "streak_recovery"
    }

    init(type: ChatCardType, tipText: String? = nil, foodQuery: String? = nil, mealPlanData: MealPlanData? = nil, restaurantOrderData: RestaurantOrderData? = nil, mealEditData: MealEditData? = nil, groceryListData: GroceryListData? = nil, mealPrepData: MealPrepData? = nil, substitutionData: SubstitutionData? = nil, fridgeMealData: FridgeMealData? = nil, streakRecoveryData: StreakRecoveryData? = nil) {
        self.id = UUID()
        self.type = type
        self.tipText = tipText
        self.foodQuery = foodQuery
        self.mealPlanData = mealPlanData
        self.restaurantOrderData = restaurantOrderData
        self.mealEditData = mealEditData
        self.groceryListData = groceryListData
        self.mealPrepData = mealPrepData
        self.substitutionData = substitutionData
        self.fridgeMealData = fridgeMealData
        self.streakRecoveryData = streakRecoveryData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.type = try container.decode(ChatCardType.self, forKey: .type)
        self.tipText = try container.decodeIfPresent(String.self, forKey: .tipText)
        self.foodQuery = try container.decodeIfPresent(String.self, forKey: .foodQuery)
        self.mealPlanData = try container.decodeIfPresent(MealPlanData.self, forKey: .mealPlanData)
        self.restaurantOrderData = try container.decodeIfPresent(RestaurantOrderData.self, forKey: .restaurantOrderData)
        self.mealEditData = try container.decodeIfPresent(MealEditData.self, forKey: .mealEditData)
        self.groceryListData = try container.decodeIfPresent(GroceryListData.self, forKey: .groceryListData)
        self.mealPrepData = try container.decodeIfPresent(MealPrepData.self, forKey: .mealPrepData)
        self.substitutionData = try container.decodeIfPresent(SubstitutionData.self, forKey: .substitutionData)
        self.fridgeMealData = try container.decodeIfPresent(FridgeMealData.self, forKey: .fridgeMealData)
        self.streakRecoveryData = try container.decodeIfPresent(StreakRecoveryData.self, forKey: .streakRecoveryData)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(tipText, forKey: .tipText)
        try container.encodeIfPresent(foodQuery, forKey: .foodQuery)
        try container.encodeIfPresent(mealPlanData, forKey: .mealPlanData)
        try container.encodeIfPresent(restaurantOrderData, forKey: .restaurantOrderData)
        try container.encodeIfPresent(mealEditData, forKey: .mealEditData)
        try container.encodeIfPresent(groceryListData, forKey: .groceryListData)
        try container.encodeIfPresent(mealPrepData, forKey: .mealPrepData)
        try container.encodeIfPresent(substitutionData, forKey: .substitutionData)
        try container.encodeIfPresent(fridgeMealData, forKey: .fridgeMealData)
        try container.encodeIfPresent(streakRecoveryData, forKey: .streakRecoveryData)
    }
}

// MARK: - Meal Plan Data

struct MealPlanData: Codable, Sendable {
    let meals: [PlannedMeal]
    let totalCalories: Int
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double

    enum CodingKeys: String, CodingKey {
        case meals
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
    }
}

struct PlannedMeal: Codable, Identifiable, Sendable {
    let id = UUID()
    let mealType: String
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let description: String?

    enum CodingKeys: String, CodingKey {
        case mealType = "meal_type"
        case name, calories, protein, carbs, fat, description
    }
}

// MARK: - Restaurant Order Data

struct RestaurantOrderData: Codable, Sendable {
    let restaurant: String
    let items: [RestaurantItem]
    let totalCalories: Int
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let foodQuery: String

    enum CodingKeys: String, CodingKey {
        case restaurant, items
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
        case foodQuery = "food_query"
    }
}

struct RestaurantItem: Codable, Identifiable, Sendable {
    let id = UUID()
    let name: String
    let modifications: [String]?
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double

    enum CodingKeys: String, CodingKey {
        case name, modifications, calories, protein, carbs, fat
    }
}

// MARK: - Meal Edit Data

struct MealEditData: Codable, Sendable {
    let mealId: String
    let mealName: String
    let changes: [MealChange]
    let originalCalories: Int
    let originalProtein: Double
    let originalCarbs: Double
    let originalFat: Double
    let newCalories: Int
    let newProtein: Double
    let newCarbs: Double
    let newFat: Double

    enum CodingKeys: String, CodingKey {
        case mealId = "meal_id"
        case mealName = "meal_name"
        case changes
        case originalCalories = "original_calories"
        case originalProtein = "original_protein"
        case originalCarbs = "original_carbs"
        case originalFat = "original_fat"
        case newCalories = "new_calories"
        case newProtein = "new_protein"
        case newCarbs = "new_carbs"
        case newFat = "new_fat"
    }
}

struct MealChange: Codable, Identifiable, Sendable {
    let id = UUID()
    let action: String
    let original: String?
    let replacement: String?
    let calorieDiff: Int
    let proteinDiff: Double

    enum CodingKeys: String, CodingKey {
        case action, original, replacement
        case calorieDiff = "calorie_diff"
        case proteinDiff = "protein_diff"
    }
}

// MARK: - Grocery List Data

struct GroceryListData: Codable, Sendable {
    let categories: [GroceryCategory]
    let totalItems: Int
    let estimatedDays: Int

    enum CodingKeys: String, CodingKey {
        case categories
        case totalItems = "total_items"
        case estimatedDays = "estimated_days"
    }

    var asPlainText: String {
        var lines: [String] = ["Grocery List (\(estimatedDays)-day estimate)", ""]
        for cat in categories {
            lines.append(cat.name.uppercased())
            for item in cat.items {
                let note = item.note.map { " — \($0)" } ?? ""
                lines.append("  \(item.name)  \(item.quantity)\(note)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

struct GroceryCategory: Codable, Identifiable, Sendable {
    let id = UUID()
    let name: String
    let icon: String
    let items: [GroceryItem]

    enum CodingKeys: String, CodingKey {
        case name, icon, items
    }
}

struct GroceryItem: Codable, Identifiable, Sendable {
    let id = UUID()
    let name: String
    let quantity: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case name, quantity, note
    }
}

// MARK: - Meal Prep Data

struct MealPrepData: Codable, Sendable {
    let prepSessions: [PrepSession]
    let grocerySummary: [PrepGroceryItem]?
    let totalServings: Int
    let coversDays: Int
    let dailyAverage: PrepDailyAverage

    enum CodingKeys: String, CodingKey {
        case prepSessions = "prep_sessions"
        case grocerySummary = "grocery_summary"
        case totalServings = "total_servings"
        case coversDays = "covers_days"
        case dailyAverage = "daily_average"
    }
}

struct PrepSession: Codable, Identifiable, Sendable {
    let id = UUID()
    let sessionName: String
    let estimatedTime: String
    let items: [PrepItem]

    enum CodingKeys: String, CodingKey {
        case sessionName = "session_name"
        case estimatedTime = "estimated_time"
        case items
    }
}

struct PrepItem: Codable, Identifiable, Sendable {
    let id = UUID()
    let name: String
    let servings: Int
    let perServing: PrepMacros
    let prepNote: String?

    enum CodingKeys: String, CodingKey {
        case name, servings
        case perServing = "per_serving"
        case prepNote = "prep_note"
    }
}

struct PrepMacros: Codable, Sendable {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct PrepGroceryItem: Codable, Identifiable, Sendable {
    let id = UUID()
    let name: String
    let quantity: String

    enum CodingKeys: String, CodingKey {
        case name, quantity
    }
}

struct PrepDailyAverage: Codable, Sendable {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

// MARK: - Substitution Data

struct SubstitutionData: Codable, Sendable {
    let original: SubstitutionItem
    let substitutes: [SubstitutionItem]
}

struct SubstitutionItem: Codable, Identifiable, Sendable {
    let id = UUID()
    let name: String
    let serving: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let why: String?
    let bestFor: String?

    enum CodingKeys: String, CodingKey {
        case name, serving, calories, protein, carbs, fat, why
        case bestFor = "best_for"
    }
}

// MARK: - Fridge Meal Data

struct FridgeMealData: Codable, Sendable {
    let mealName: String
    let description: String?
    let cookTime: String?
    let ingredients: [FridgeIngredient]
    let totalCalories: Int
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let instructions: [String]?

    enum CodingKeys: String, CodingKey {
        case mealName = "meal_name"
        case description
        case cookTime = "cook_time"
        case ingredients
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
        case instructions
    }
}

struct FridgeIngredient: Codable, Identifiable, Sendable {
    let id = UUID()
    let name: String
    let amount: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double

    enum CodingKeys: String, CodingKey {
        case name, amount, calories, protein, carbs, fat
    }
}

// MARK: - Streak Recovery Data

struct StreakRecoveryData: Codable, Sendable {
    let situation: String
    let yesterdayCalories: Int?
    let yesterdayTarget: Int?
    let excessOrDeficit: Int?
    let recoveryPlan: RecoveryPlan
    let motivation: String?

    enum CodingKeys: String, CodingKey {
        case situation
        case yesterdayCalories = "yesterday_calories"
        case yesterdayTarget = "yesterday_target"
        case excessOrDeficit = "excess_or_deficit"
        case recoveryPlan = "recovery_plan"
        case motivation
    }
}

struct RecoveryPlan: Codable, Sendable {
    let strategy: String
    let targetAdjustment: RecoveryTargets
    let meals: [RecoveryMeal]

    enum CodingKeys: String, CodingKey {
        case strategy
        case targetAdjustment = "target_adjustment"
        case meals
    }
}

struct RecoveryTargets: Codable, Sendable {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct RecoveryMeal: Codable, Identifiable, Sendable {
    let id = UUID()
    let mealType: String
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let description: String?

    enum CodingKeys: String, CodingKey {
        case mealType = "meal_type"
        case name, calories, protein, carbs, fat, description
    }
}
