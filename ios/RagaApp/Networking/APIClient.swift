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

    // There's no real login yet: the app identifies itself to the server via
    // the `x-user-id` header, which the backend trusts as the current user's
    // id and resolves their real role from the database. `userId` is passed
    // explicitly by each caller (not read from a global) so APIClient itself
    // stays free of any dependency on AppState.
    private func request(_ path: String, method: String, query: [String: String] = [:], body: [String: Any]? = nil, userId: String?) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        if let userId {
            request.setValue(userId, forHTTPHeaderField: "x-user-id")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:], userId: String? = nil) async throws -> T {
        let request = try request(path, method: "GET", query: query, userId: userId)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    func post<T: Decodable>(_ path: String, body: [String: Any], userId: String? = nil) async throws -> T {
        let request = try request(path, method: "POST", body: body, userId: userId)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    func put<T: Decodable>(_ path: String, body: [String: Any], userId: String? = nil) async throws -> T {
        let request = try request(path, method: "PUT", body: body, userId: userId)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    func patch<T: Decodable>(_ path: String, body: [String: Any], userId: String? = nil) async throws -> T {
        let request = try request(path, method: "PATCH", body: body, userId: userId)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    func delete(_ path: String, userId: String? = nil) async throws {
        let request = try request(path, method: "DELETE", userId: userId)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
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

    func fetchMe(userId: String) async throws -> MeResponse {
        try await get("me", userId: userId)
    }

    func fetchUpdates(userId: String) async throws -> [UpdateItem] {
        try await get("updates", userId: userId)
    }

    func fetchPractices(userId: String) async throws -> [PracticeItem] {
        try await get("practices", userId: userId)
    }

    func fetchVideos(set: String, userId: String) async throws -> [VideoItem] {
        try await get("videos", query: set == "All" ? [:] : ["set": set], userId: userId)
    }

    func fetchCalendarEvents(userId: String) async throws -> [CalendarEventItem] {
        try await get("calendar", userId: userId)
    }

    @discardableResult
    func submitRsvp(practiceId: String, userId: String, response: RsvpResponse, reason: String?) async throws -> RsvpMine {
        var body: [String: Any] = ["response": response.rawValue]
        if let reason { body["reason"] = reason }
        return try await post("practices/\(practiceId)/rsvp", body: body, userId: userId)
    }

    // MARK: - Choreo/formation reminders (Captain-only)

    func fetchChoreoReminders(userId: String) async throws -> [ChoreoReminderItem] {
        try await get("choreo-reminders", userId: userId)
    }

    @discardableResult
    func setChoreoReminderResolved(id: String, resolved: Bool, userId: String) async throws -> ChoreoReminderItem {
        try await patch("choreo-reminders/\(id)", body: ["resolved": resolved], userId: userId)
    }

    // MARK: - Practice Planner (Captain-only)

    func fetchPracticePlans(userId: String) async throws -> [PracticePlanItem] {
        try await get("practice-plans", userId: userId)
    }

    @discardableResult
    func createPracticePlan(title: String, date: Date, userId: String) async throws -> PracticePlanItem {
        let iso = ISO8601DateFormatter().string(from: date)
        return try await post("practice-plans", body: ["title": title, "date": iso], userId: userId)
    }

    @discardableResult
    func addAgendaItem(planId: String, order: Int, startOffsetMin: Int, durationMin: Int, label: String, userId: String) async throws -> PracticeAgendaItemModel {
        try await post(
            "practice-plans/\(planId)/agenda-items",
            body: ["order": order, "startOffsetMin": startOffsetMin, "durationMin": durationMin, "label": label],
            userId: userId
        )
    }

    // MARK: - Attendance

    func fetchAttendance(eventId: String, userId: String) async throws -> AttendanceForEvent {
        try await get("attendance/event/\(eventId)", userId: userId)
    }

    @discardableResult
    func markAttendance(eventId: String, targetUserId: String, status: AttendanceStatus, notes: String?, userId: String) async throws -> AttendanceRecord {
        var body: [String: Any] = ["userId": targetUserId, "status": status.rawValue]
        if let notes { body["notes"] = notes }
        return try await put("attendance/event/\(eventId)/mark", body: body, userId: userId)
    }
}
