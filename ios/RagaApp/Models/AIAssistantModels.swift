import Foundation

/// Mirrors backend/src/routes/ai.ts's structured output — the assistant
/// either returns a finished draft, or (per the system prompt) a clarifying
/// question when the notes are missing a date/time/dollar amount it needs
/// rather than inventing one.
enum AIAssistantResponse: Codable {
    case draft(String)
    case question(String)

    private enum CodingKeys: String, CodingKey {
        case responseType
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .responseType)
        let message = try container.decode(String.self, forKey: .message)
        switch type {
        case "question": self = .question(message)
        default: self = .draft(message)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .draft(let message):
            try container.encode("draft", forKey: .responseType)
            try container.encode(message, forKey: .message)
        case .question(let message):
            try container.encode("question", forKey: .responseType)
            try container.encode(message, forKey: .message)
        }
    }
}
