import Foundation

enum APIError: Error, LocalizedError {
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .invalidResponse: return "Unexpected response from server."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    /// Backend runs locally for this build (see backend/README.md). The iOS
    /// Simulator shares the Mac's network stack, so `localhost` resolves.
    /// A physical device needs the Mac's LAN IP here instead.
    var baseURL = URL(string: "http://localhost:4000")!

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: string) { return date }
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }()

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        try Self.validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw APIError.server(message)
        }
    }

    func fetchUsers() async throws -> [AppUser] {
        try await get("users")
    }

    func fetchUpdates() async throws -> [UpdateItem] {
        try await get("updates")
    }

    func fetchPractices(userId: String?, role: Role) async throws -> [PracticeItem] {
        var query = ["role": role.rawValue]
        if let userId { query["userId"] = userId }
        return try await get("practices", query: query)
    }

    func fetchVideos(set: String) async throws -> [VideoItem] {
        try await get("videos", query: set == "All" ? [:] : ["set": set])
    }

    func fetchCalendarEvents() async throws -> [CalendarEventItem] {
        try await get("calendar")
    }

    @discardableResult
    func submitRsvp(practiceId: String, userId: String, response: RsvpResponse, reason: String?) async throws -> RsvpMine {
        var body: [String: Any] = ["userId": userId, "response": response.rawValue]
        if let reason { body["reason"] = reason }
        return try await post("practices/\(practiceId)/rsvp", body: body)
    }
}
