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
            let servingSize: String?
            let quantity: Double
            let confidence: Double

            enum CodingKeys: String, CodingKey {
                case id
                case mealId = "meal_id"
                case name, calories, protein, carbs, fat
                case servingSize = "serving_size"
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
                servingSize: item.servingSize,
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
            waterMl: summary.waterMl,
            aiInsight: summary.aiInsight,
            isOnTarget: summary.isOnTarget
        )

        try await supabase.from("daily_summaries")
            .upsert(upsert)
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

    func logWeight(userId: UUID, weightKg: Double) async throws {
        let log = WeightLog(id: UUID(), userId: userId, weightKg: weightKg, loggedAt: Date())
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

    // MARK: - Streaks

    func updateStreak(userId: UUID) async throws -> Int {
        let result: StreakResult = try await supabase.rpc("calculate_streak", params: ["p_user_id": userId.uuidString])
            .execute()
            .value
        return result.streak
    }

    // MARK: - Profile

    func updateProfile(_ profile: UserProfile) async throws {
        try await supabase.from("profiles")
            .update(profile)
            .eq("id", value: profile.id.uuidString)
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
                waterMl: row.waterMl,
                aiInsight: row.aiInsight,
                isOnTarget: row.isOnTarget
            )
        }
    }

    func getWeekSummaries(userId: UUID) async throws -> [DailySummary] {
        guard let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return [] }
        let dateString = sevenDaysAgo.dateString

        struct SummaryRow: Codable {
            let id: UUID
            let userId: UUID
            let date: String
            let totalCalories: Int
            let totalProtein: Double
            let totalCarbs: Double
            let totalFat: Double
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
                waterMl: row.waterMl,
                aiInsight: row.aiInsight,
                isOnTarget: row.isOnTarget
            )
        }
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
