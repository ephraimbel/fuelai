import Foundation
import Supabase

actor DatabaseService {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Meals

    func logMeal(_ meal: Meal) async throws {
        // Insert meal without items
        struct MealInsert: Codable {
            let id: UUID
            let userId: UUID
            let displayName: String
            let totalCalories: Int
            let totalProtein: Double
            let totalCarbs: Double
            let totalFat: Double
            let totalFiber: Double
            let totalSugar: Double
            let totalSodium: Double
            let imageUrl: String?
            let loggedDate: String
            let loggedAt: Date
            let createdAt: Date

            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case displayName = "display_name"
                case totalCalories = "total_calories"
                case totalProtein = "total_protein"
                case totalCarbs = "total_carbs"
                case totalFat = "total_fat"
                case totalFiber = "total_fiber"
                case totalSugar = "total_sugar"
                case totalSodium = "total_sodium"
                case imageUrl = "image_url"
                case loggedDate = "logged_date"
                case loggedAt = "logged_at"
                case createdAt = "created_at"
            }
        }

        let mealInsert = MealInsert(
            id: meal.id,
            userId: meal.userId,
            displayName: meal.displayName,
            totalCalories: meal.totalCalories,
            totalProtein: meal.totalProtein,
            totalCarbs: meal.totalCarbs,
            totalFat: meal.totalFat,
            totalFiber: meal.totalFiber,
            totalSugar: meal.totalSugar,
            totalSodium: meal.totalSodium,
            imageUrl: meal.imageUrl,
            loggedDate: meal.loggedDate,
            loggedAt: meal.loggedAt,
            createdAt: meal.createdAt
        )

        try await supabase.from("meals").insert(mealInsert).execute()

        // Insert meal items
        struct MealItemInsert: Codable {
            let id: UUID
            let mealId: UUID
            let name: String
            let calories: Int
            let protein: Double
            let carbs: Double
            let fat: Double
            let fiber: Double
            let sugar: Double
            let servingSize: String?
            let estimatedGrams: Double
            let measurementUnit: String
            let measurementAmount: Double
            let quantity: Double
            let confidence: Double

            enum CodingKeys: String, CodingKey {
                case id
                case mealId = "meal_id"
                case name, calories, protein, carbs, fat, fiber, sugar
                case servingSize = "serving_size"
                case estimatedGrams = "estimated_grams"
                case measurementUnit = "measurement_unit"
                case measurementAmount = "measurement_amount"
                case quantity, confidence
            }
        }

        let itemInserts = meal.items.map { item in
            MealItemInsert(
                id: item.id,
                mealId: meal.id,
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                fiber: item.fiber,
                sugar: item.sugar,
                servingSize: item.servingSize,
                estimatedGrams: item.estimatedGrams,
                measurementUnit: item.measurementUnit,
                measurementAmount: item.measurementAmount,
                quantity: item.quantity,
                confidence: item.confidence
            )
        }

        if !itemInserts.isEmpty {
            try await supabase.from("meal_items").insert(itemInserts).execute()
        }
    }

    func getMeals(for date: String, userId: UUID) async throws -> [Meal] {
        try await supabase.from("meals")
            .select("*, items:meal_items(*)")
            .eq("user_id", value: userId.uuidString)
            .eq("logged_date", value: date)
            .order("logged_at", ascending: false)
            .execute()
            .value
    }

    func getRecentMeals(userId: UUID, limit: Int = 20) async throws -> [Meal] {
        guard let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return [] }
        let dateString = sevenDaysAgo.dateString

        return try await supabase.from("meals")
            .select("*, items:meal_items(*)")
            .eq("user_id", value: userId.uuidString)
            .gte("logged_date", value: dateString)
            .order("logged_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func deleteMeal(id: UUID) async throws {
        try await supabase.from("meals")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func updateMealInPlace(_ meal: Meal) async throws {
        struct MealUpdate: Codable {
            let displayName: String
            let totalCalories: Int
            let totalProtein: Double
            let totalCarbs: Double
            let totalFat: Double
            let totalFiber: Double
            let totalSugar: Double
            let totalSodium: Double

            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case totalCalories = "total_calories"
                case totalProtein = "total_protein"
                case totalCarbs = "total_carbs"
                case totalFat = "total_fat"
                case totalFiber = "total_fiber"
                case totalSugar = "total_sugar"
                case totalSodium = "total_sodium"
            }
        }

        let update = MealUpdate(
            displayName: meal.displayName,
            totalCalories: meal.totalCalories,
            totalProtein: meal.totalProtein,
            totalCarbs: meal.totalCarbs,
            totalFat: meal.totalFat,
            totalFiber: meal.totalFiber,
            totalSugar: meal.totalSugar,
            totalSodium: meal.totalSodium
        )

        try await supabase.from("meals")
            .update(update)
            .eq("id", value: meal.id.uuidString)
            .execute()
    }

    // MARK: - Daily Summary

    func getDailySummary(date: String, userId: UUID) async throws -> DailySummary? {
        struct SummaryRow: Codable {
            let id: UUID
            let userId: UUID
            let date: String
            let totalCalories: Int
            let totalProtein: Double
            let totalCarbs: Double
            let totalFat: Double
            let totalFiber: Double?
            let totalSugar: Double?
            let totalSodium: Double?
            let waterMl: Int
            let aiInsight: String?
            let isOnTarget: Bool

            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case date
                case totalCalories = "total_calories"
                case totalProtein = "total_protein"
                case totalCarbs = "total_carbs"
                case totalFat = "total_fat"
                case totalFiber = "total_fiber"
                case totalSugar = "total_sugar"
                case totalSodium = "total_sodium"
                case waterMl = "water_ml"
                case aiInsight = "ai_insight"
                case isOnTarget = "is_on_target"
            }
        }

        guard let row: SummaryRow = try? await supabase.from("daily_summaries")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("date", value: date)
            .single()
            .execute()
            .value else { return nil }

        return DailySummary(
            id: row.id,
            userId: row.userId,
            date: row.date,
            totalCalories: row.totalCalories,
            totalProtein: row.totalProtein,
            totalCarbs: row.totalCarbs,
            totalFat: row.totalFat,
            totalFiber: row.totalFiber ?? 0,
            totalSugar: row.totalSugar ?? 0,
            totalSodium: row.totalSodium ?? 0,
            meals: [],
            waterMl: row.waterMl,
            aiInsight: row.aiInsight,
            isOnTarget: row.isOnTarget
        )
    }

    func upsertDailySummary(_ summary: DailySummary) async throws {
        struct SummaryUpsert: Codable {
            let id: UUID
            let userId: UUID
            let date: String
            let totalCalories: Int
            let totalProtein: Double
            let totalCarbs: Double
            let totalFat: Double
            let totalFiber: Double
            let totalSugar: Double
            let totalSodium: Double
            let waterMl: Int
            let aiInsight: String?
            let isOnTarget: Bool

            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case date
                case totalCalories = "total_calories"
                case totalProtein = "total_protein"
                case totalCarbs = "total_carbs"
                case totalFat = "total_fat"
                case totalFiber = "total_fiber"
                case totalSugar = "total_sugar"
                case totalSodium = "total_sodium"
                case waterMl = "water_ml"
                case aiInsight = "ai_insight"
                case isOnTarget = "is_on_target"
            }
        }

        let upsert = SummaryUpsert(
            id: summary.id,
            userId: summary.userId,
            date: summary.date,
            totalCalories: summary.totalCalories,
            totalProtein: summary.totalProtein,
            totalCarbs: summary.totalCarbs,
            totalFat: summary.totalFat,
            totalFiber: summary.totalFiber,
            totalSugar: summary.totalSugar,
            totalSodium: summary.totalSodium,
            waterMl: summary.waterMl,
            aiInsight: summary.aiInsight,
            isOnTarget: summary.isOnTarget
        )

        try await supabase.from("daily_summaries")
            .upsert(upsert, onConflict: "user_id,date")
            .execute()
    }

    // MARK: - Water

    func logWater(userId: UUID, amountMl: Int) async throws {
        let log = WaterLog(id: UUID(), userId: userId, amountMl: amountMl, loggedAt: Date())
        try await supabase.from("water_logs").insert(log).execute()
    }

    func getWaterTotal(date: String, userId: UUID) async throws -> Int {
        // Calculate next day for proper < boundary
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let nextDay: String
        if let d = formatter.date(from: date), let next = Calendar.current.date(byAdding: .day, value: 1, to: d) {
            nextDay = formatter.string(from: next)
        } else {
            nextDay = date
        }

        let logs: [WaterLog] = try await supabase.from("water_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: "\(date)T00:00:00")
            .lt("logged_at", value: "\(nextDay)T00:00:00")
            .execute()
            .value
        return logs.reduce(0) { $0 + $1.amountMl }
    }

    // MARK: - Weight

    func logWeight(userId: UUID, weightKg: Double, date: Date? = nil) async throws {
        let log = WeightLog(id: UUID(), userId: userId, weightKg: weightKg, loggedAt: date ?? Date())
        try await supabase.from("weight_logs").insert(log).execute()
    }

    func getWeightHistory(userId: UUID, days: Int = 90) async throws -> [WeightLog] {
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: startDate)

        return try await supabase.from("weight_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("logged_at", value: dateString)
            .order("logged_at", ascending: true)
            .execute()
            .value
    }

    // MARK: - Chat

    func saveChatMessage(_ message: ChatMessage) async throws {
        try await supabase.from("chat_messages").insert(message).execute()
    }

    func getChatHistory(userId: UUID, limit: Int = 50) async throws -> [ChatMessage] {
        let messages: [ChatMessage] = try await supabase.from("chat_messages")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return messages.reversed()
    }

    // MARK: - Favorites

    func saveFavorite(_ favorite: FavoriteMeal) async throws {
        try await supabase.from("favorite_meals").insert(favorite).execute()
    }

    func getFavorites(userId: UUID) async throws -> [FavoriteMeal] {
        try await supabase.from("favorite_meals")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("use_count", ascending: false)
            .execute()
            .value
    }

    func incrementFavoriteUse(id: UUID) async throws {
        try await supabase.rpc("increment_favorite_use", params: ["p_id": id.uuidString])
            .execute()
    }

    func deleteFavorite(id: UUID) async throws {
        try await supabase.from("favorite_meals")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Streaks

    func updateStreak(userId: UUID) async throws -> Int {
        let result: StreakResult = try await supabase.rpc("calculate_streak", params: ["p_user_id": userId.uuidString])
            .execute()
            .value
        return result.streak
    }

    // MARK: - Profile

    func updateProfile(_ profile: UserProfile) async throws {
        struct ProfileUpdate: Codable {
            let id: UUID
            let displayName: String?
            let age: Int?
            let sex: Sex?
            let heightCm: Double?
            let weightKg: Double?
            let activityLevel: ActivityLevel?
            let goalType: GoalType?
            let targetCalories: Int?
            let targetProtein: Int?
            let targetCarbs: Int?
            let targetFat: Int?
            let targetWeightKg: Double?
            let dietStyle: DietStyle?
            let mealsPerDay: Int?
            let waterGoalMl: Int?
            let unitSystem: UnitSystem
            let updatedAt: Date

            enum CodingKeys: String, CodingKey {
                case id
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
                case unitSystem = "unit_system"
                case updatedAt = "updated_at"
            }
        }

        let update = ProfileUpdate(
            id: profile.id,
            displayName: profile.displayName,
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            activityLevel: profile.activityLevel,
            goalType: profile.goalType,
            targetCalories: profile.targetCalories,
            targetProtein: profile.targetProtein,
            targetCarbs: profile.targetCarbs,
            targetFat: profile.targetFat,
            targetWeightKg: profile.targetWeightKg,
            dietStyle: profile.dietStyle,
            mealsPerDay: profile.mealsPerDay,
            waterGoalMl: profile.waterGoalMl,
            unitSystem: profile.unitSystem,
            updatedAt: profile.updatedAt
        )

        try await supabase.from("profiles")
            .upsert(update)
            .execute()
    }

    // MARK: - Weekly Data

    func getSummaries(userId: UUID, days: Int) async throws -> [DailySummary] {
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let dateString = startDate.dateString

        struct SummaryRow: Codable {
            let id: UUID
            let userId: UUID
            let date: String
            let totalCalories: Int
            let totalProtein: Double
            let totalCarbs: Double
            let totalFat: Double
            let totalFiber: Double?
            let totalSugar: Double?
            let totalSodium: Double?
            let waterMl: Int
            let aiInsight: String?
            let isOnTarget: Bool

            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case date
                case totalCalories = "total_calories"
                case totalProtein = "total_protein"
                case totalCarbs = "total_carbs"
                case totalFat = "total_fat"
                case totalFiber = "total_fiber"
                case totalSugar = "total_sugar"
                case totalSodium = "total_sodium"
                case waterMl = "water_ml"
                case aiInsight = "ai_insight"
                case isOnTarget = "is_on_target"
            }
        }

        let rows: [SummaryRow] = try await supabase.from("daily_summaries")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("date", value: dateString)
            .order("date", ascending: true)
            .execute()
            .value

        return rows.map { row in
            DailySummary(
                id: row.id,
                userId: row.userId,
                date: row.date,
                totalCalories: row.totalCalories,
                totalProtein: row.totalProtein,
                totalCarbs: row.totalCarbs,
                totalFat: row.totalFat,
                totalFiber: row.totalFiber ?? 0,
                totalSugar: row.totalSugar ?? 0,
                totalSodium: row.totalSodium ?? 0,
                waterMl: row.waterMl,
                aiInsight: row.aiInsight,
                isOnTarget: row.isOnTarget
            )
        }
    }

    func getWeekSummaries(userId: UUID) async throws -> [DailySummary] {
        try await getSummaries(userId: userId, days: 7)
    }

    // MARK: - Account

    func deleteAccount(userId: UUID) async throws {
        try await supabase.rpc("delete_user_account", params: ["user_id": userId.uuidString]).execute()
    }

    // MARK: - Image Upload

    func uploadMealImage(userId: UUID, mealId: UUID, imageData: Data) async throws -> String {
        let path = "\(userId.uuidString)/\(mealId.uuidString).jpg"
        try await supabase.storage.from("meal-images")
            .upload(path: path, file: imageData, options: .init(contentType: "image/jpeg"))

        let publicURL = try supabase.storage.from("meal-images").getPublicURL(path: path)
        return publicURL.absoluteString
    }
}

struct StreakResult: Codable {
    let streak: Int
}
