import Foundation
import CoreGraphics
import Supabase

enum Constants {
    static let supabaseURL = URL(string: "https://dafaysnpgdsletsrtmhy.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRhZmF5c25wZ2RzbGV0c3J0bWh5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2NTQ1MjgsImV4cCI6MjA4ODIzMDUyOH0.1JUx0bT4QlnqoAiaVIdJYTaIuD-iC8pMswZJ0ApOpBg"

    static let supabase = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseAnonKey
    )

    // Subscription Product IDs
    static let weeklyProductID = "com.fuel.premium.weekly"
    static let discountedWeeklyProductID = "com.fuel.premium.weekly.discounted"
    static let yearlyProductID = "com.fuel.premium.yearly"

    // Free tier limits
    static let freeScansPerDay = 1
    static let freeChatMessagesPerDay = 1

    // Water
    static let defaultWaterGoalMl = 2500
    static let waterIncrements = [250, 500]

    // Image — optimized for AI analysis speed & reliability
    // Cal AI benchmark: ~500KB-1MB images, 1024px max dimension
    static let maxImageSizeBytes = 1_500_000
    static let imageCompressionQuality: CGFloat = 0.7
    static let thumbnailSize = CGSize(width: 200, height: 200)

    // App
    static let appName = "Fuel"
    static let appTagline = "Fuel your goals, not your guilt."

    // Website — update base URL when custom domain is added
    static let websiteBase = "https://website-theta-pied-51.vercel.app"
    static let termsURL = URL(string: "\(websiteBase)/terms")!
    static let privacyURL = URL(string: "\(websiteBase)/privacy")!
    static let supportURL = URL(string: "\(websiteBase)/support")!
}
