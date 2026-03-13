import Foundation

struct UserProfile: Codable, Identifiable, Sendable {
    let id: UUID
    var email: String?
    var displayName: String?
    var age: Int?
    var sex: Sex?
    var heightCm: Double?
    var weightKg: Double?
    var activityLevel: ActivityLevel?
    var goalType: GoalType?
    var targetCalories: Int?
    var targetProtein: Int?
    var targetCarbs: Int?
    var targetFat: Int?
    var isPremium: Bool
    var streakCount: Int
    var longestStreak: Int
    var targetWeightKg: Double?
    var dietStyle: DietStyle?
    var mealsPerDay: Int?
    var waterGoalMl: Int?
    var unitSystem: UnitSystem
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case age, sex
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case activityLevel = "activity_level"
        case goalType = "goal_type"
        case targetCalories = "target_calories"
        case targetProtein = "target_protein"
        case targetCarbs = "target_carbs"
        case targetFat = "target_fat"
        case targetWeightKg = "target_weight_kg"
        case dietStyle = "diet_style"
        case mealsPerDay = "meals_per_day"
        case waterGoalMl = "water_goal_ml"
        case isPremium = "is_premium"
        case streakCount = "streak_count"
        case longestStreak = "longest_streak"
        case unitSystem = "unit_system"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum Sex: String, Codable, CaseIterable, Sendable {
    case male, female
}

enum UnitSystem: String, Codable, CaseIterable, Sendable {
    case imperial, metric
}

enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive = "very_active"

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly Active"
        case .moderate: return "Moderately Active"
        case .active: return "Very Active"
        case .veryActive: return "Extra Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: return "Little to no exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .active: return "Hard exercise 6-7 days/week"
        case .veryActive: return "Very hard exercise, physical job"
        }
    }
}

enum DietStyle: String, Codable, CaseIterable, Sendable {
    case standard
    case highProtein = "high_protein"
    case keto
    case vegetarian
    case vegan
    case mediterranean

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .highProtein: return "High Protein"
        case .keto: return "Keto"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .mediterranean: return "Mediterranean"
        }
    }

    var description: String {
        switch self {
        case .standard: return "No restrictions, balanced nutrition"
        case .highProtein: return "Extra protein for muscle"
        case .keto: return "High fat, very low carb"
        case .vegetarian: return "Plant-based with dairy & eggs"
        case .vegan: return "100% plant-based"
        case .mediterranean: return "Heart-healthy, whole foods"
        }
    }

    var iconName: String {
        switch self {
        case .standard: return "fork.knife"
        case .highProtein: return "figure.strengthtraining.traditional"
        case .keto: return "drop.fill"
        case .vegetarian: return "leaf.fill"
        case .vegan: return "leaf.circle"
        case .mediterranean: return "fish.fill"
        }
    }
}

enum GoalType: String, Codable, CaseIterable, Sendable {
    case lose
    case toneUp = "tone_up"
    case maintain
    case gain
    case bulk
    case athlete

    var calorieAdjustment: Int {
        switch self {
        case .lose: return -500
        case .toneUp: return -250
        case .maintain: return 0
        case .gain: return 300
        case .bulk: return 500
        case .athlete: return 200
        }
    }

    var displayName: String {
        switch self {
        case .lose: return "Lose Weight"
        case .toneUp: return "Tone Up"
        case .maintain: return "Stay Healthy"
        case .gain: return "Build Muscle"
        case .bulk: return "Gain Weight"
        case .athlete: return "Performance"
        }
    }

    var goalDescription: String {
        switch self {
        case .lose: return "Burn fat and slim down"
        case .toneUp: return "Lean out and build definition"
        case .maintain: return "Keep your current weight"
        case .gain: return "Add muscle with a surplus"
        case .bulk: return "Maximize weight gain"
        case .athlete: return "Fuel your training"
        }
    }

    var iconName: String {
        switch self {
        case .lose: return "arrow.down.circle"
        case .toneUp: return "figure.strengthtraining.traditional"
        case .maintain: return "heart.circle"
        case .gain: return "dumbbell.fill"
        case .bulk: return "arrow.up.circle"
        case .athlete: return "figure.run"
        }
    }
}
