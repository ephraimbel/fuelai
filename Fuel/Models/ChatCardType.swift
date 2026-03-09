import Foundation

enum ChatCardType: String, Codable, Sendable {
    case calorieProgress = "calorie_progress"
    case macroBreakdown = "macro_breakdown"
    case mealLog = "meal_log"
    case tip
}

struct ChatCard: Codable, Identifiable, Sendable {
    let id: UUID
    let type: ChatCardType
    let tipText: String?

    enum CodingKeys: String, CodingKey {
        case type
        case tipText = "tip_text"
    }

    init(type: ChatCardType, tipText: String? = nil) {
        self.id = UUID()
        self.type = type
        self.tipText = tipText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.type = try container.decode(ChatCardType.self, forKey: .type)
        self.tipText = try container.decodeIfPresent(String.self, forKey: .tipText)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(tipText, forKey: .tipText)
    }
}
