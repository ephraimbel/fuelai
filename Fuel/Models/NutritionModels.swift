import Foundation
import UIKit

// MARK: - Food Database Models

enum FoodCategory: String, Codable, Sendable {
    case protein, dairy, grain, vegetable, fruit, fat, legume
    case fastFood, restaurant, beverage, snack, sweet, condiment, mixed, supplement
}

enum DataConfidence: String, Codable, Sendable {
    case high, medium, low
}

struct FoodItem: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let aliases: [String]
    let serving: String
    let servingGrams: Double
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
    let category: FoodCategory
    let subCategory: String
    let tags: [String]
    let notes: String
    let confidence: DataConfidence

    init(
        id: UUID = UUID(),
        name: String,
        aliases: [String] = [],
        serving: String,
        servingGrams: Double,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double = 0,
        sugar: Double = 0,
        sodium: Double = 0,
        category: FoodCategory,
        subCategory: String = "",
        tags: [String] = [],
        notes: String = "",
        confidence: DataConfidence = .high
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.serving = serving
        self.servingGrams = servingGrams
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.category = category
        self.subCategory = subCategory
        self.tags = tags
        self.notes = notes
        self.confidence = confidence
    }
}

// MARK: - Retrieval Result

struct RetrievalResult: Sendable {
    let food: FoodItem
    let score: Double
    let matchedTerms: [String]
}

// MARK: - Nutrition Analysis Response
// All non-essential fields are optional to tolerate partial Claude responses.

struct NutritionAnalysis: Codable, Sendable {
    let mealName: String
    let totalCalories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?
    let servingAssumed: String?
    let confidence: String
    let confidenceReason: String?
    let items: [AnalyzedItem]
    let warnings: [String]?
    let healthInsight: String?
    let calorieRange: CalorieRange?
    let scalingNote: String?

    enum CodingKeys: String, CodingKey {
        case mealName = "meal_name"
        case totalCalories = "total_calories"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case servingAssumed = "serving_assumed"
        case confidence
        case confidenceReason = "confidence_reason"
        case items
        case warnings
        case healthInsight = "health_insight"
        case calorieRange = "calorie_range"
        case scalingNote = "scaling_note"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mealName = try container.decode(String.self, forKey: .mealName)

        // Handle totalCalories as Int or Double
        if let intVal = try? container.decode(Int.self, forKey: .totalCalories) {
            totalCalories = intVal
        } else if let doubleVal = try? container.decode(Double.self, forKey: .totalCalories) {
            totalCalories = Int(doubleVal.rounded())
        } else {
            totalCalories = 0
        }

        proteinG = (try? container.decode(Double.self, forKey: .proteinG)) ?? 0
        carbsG = (try? container.decode(Double.self, forKey: .carbsG)) ?? 0
        fatG = (try? container.decode(Double.self, forKey: .fatG)) ?? 0
        fiberG = try? container.decode(Double.self, forKey: .fiberG)
        sugarG = try? container.decode(Double.self, forKey: .sugarG)
        sodiumMg = try? container.decode(Double.self, forKey: .sodiumMg)
        servingAssumed = try? container.decode(String.self, forKey: .servingAssumed)
        confidence = (try? container.decode(String.self, forKey: .confidence)) ?? "medium"
        confidenceReason = try? container.decode(String.self, forKey: .confidenceReason)
        items = (try? container.decode([AnalyzedItem].self, forKey: .items)) ?? []
        warnings = try? container.decode([String].self, forKey: .warnings)
        healthInsight = try? container.decode(String.self, forKey: .healthInsight)
        calorieRange = try? container.decode(CalorieRange.self, forKey: .calorieRange)
        scalingNote = try? container.decode(String.self, forKey: .scalingNote)
    }
}

struct AnalyzedItem: Codable, Sendable {
    let item: String
    let quantity: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let estimatedGrams: Double
    let note: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        item = (try? container.decode(String.self, forKey: .item)) ?? ""
        quantity = (try? container.decode(String.self, forKey: .quantity)) ?? ""
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
        estimatedGrams = (try? container.decode(Double.self, forKey: .estimatedGrams)) ?? 0
        note = try? container.decode(String.self, forKey: .note)
    }

    private enum CodingKeys: String, CodingKey {
        case item, quantity, calories, protein, carbs, fat
        case estimatedGrams = "estimated_grams"
        case note
    }
}

struct CalorieRange: Codable, Sendable {
    let low: Int
    let high: Int

    init(low: Int, high: Int) {
        self.low = low
        self.high = high
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intVal = try? container.decode(Int.self, forKey: .low) {
            low = intVal
        } else if let doubleVal = try? container.decode(Double.self, forKey: .low) {
            low = Int(doubleVal.rounded())
        } else {
            low = 0
        }
        if let intVal = try? container.decode(Int.self, forKey: .high) {
            high = intVal
        } else if let doubleVal = try? container.decode(Double.self, forKey: .high) {
            high = Int(doubleVal.rounded())
        } else {
            high = 0
        }
    }

    private enum CodingKeys: String, CodingKey {
        case low, high
    }
}

// MARK: - Claude API Types

struct ClaudeAPIRequest: Encodable {
    let model: String
    let maxTokens: Int
    let temperature: Double
    let system: String
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case temperature
        case system
        case messages
    }
}

struct ClaudeMessage: Encodable {
    let role: String
    let content: [ClaudeContent]
}

struct ClaudeContent: Encodable {
    let type: String
    let text: String?
    let source: ClaudeImageSource?

    init(type: String, text: String? = nil, source: ClaudeImageSource? = nil) {
        self.type = type
        self.text = text
        self.source = source
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if let text = text {
            try container.encode(text, forKey: .text)
        }
        if let source = source {
            try container.encode(source, forKey: .source)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, text, source
    }
}

struct ClaudeImageSource: Encodable {
    let type: String
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

struct ClaudeAPIResponse: Decodable {
    let content: [ClaudeResponseContent]
}

struct ClaudeResponseContent: Decodable {
    let type: String
    let text: String?
}
