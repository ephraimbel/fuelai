import Foundation

struct WaterLog: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var amountMl: Int
    var loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case amountMl = "amount_ml"
        case loggedAt = "logged_at"
    }
}
