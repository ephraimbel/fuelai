import Foundation

struct ChatMessage: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date

    // Transient — not persisted to DB, only set from edge function responses
    var cards: [ChatCard]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case role, content
        case createdAt = "created_at"
    }
}

enum MessageRole: String, Codable, Sendable {
    case user, assistant
}
