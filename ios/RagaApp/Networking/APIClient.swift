import Foundation

/// One file to attach to a multipart request — see APIClient.multipartRequest.
struct MultipartFile {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

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

    /// Like `put`, but for endpoints that reply 204 No Content — decoding an
    /// empty body as JSON would otherwise throw.
    func putNoContent(_ path: String, body: [String: Any], userId: String? = nil) async throws {
        let request = try request(path, method: "PUT", body: body, userId: userId)
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

    @discardableResult
    func createUpdate(tag: UpdateTag, content: String, visibleToRoles: [Role], userId: String) async throws -> UpdateItem {
        let body: [String: Any] = [
            "tag": tag.rawValue,
            "content": content,
            "visibleToRoles": visibleToRoles.map(\.rawValue),
        ]
        return try await post("updates", body: body, userId: userId)
    }

    func deleteUpdate(id: String, userId: String) async throws {
        try await delete("updates/\(id)", userId: userId)
    }

    func fetchPractices(userId: String) async throws -> [PracticeItem] {
        try await get("practices", userId: userId)
    }

    /// The create response is just the raw row (id/date/location/focus/kind),
    /// not the enriched summarized shape `PracticeItem` decodes elsewhere —
    /// callers reload the full list afterward, so this discards the body.
    func createPractice(date: Date, location: String, focus: String, reminder: String?, kind: PracticeKind, userId: String) async throws {
        var body: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: date),
            "location": location,
            "focus": focus,
            "kind": kind.rawValue,
        ]
        if let reminder, !reminder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["reminder"] = reminder
        }
        let _: EmptyDecodable = try await post("practices", body: body, userId: userId)
    }

    func fetchVideos(set: String, userId: String) async throws -> [VideoItem] {
        try await get("videos", query: set == "All" ? [:] : ["set": set], userId: userId)
    }

    /// Builds a multipart/form-data request. `post`/`patch` above only speak
    /// JSON, so uploads (video files, chat attachments) need this instead.
    /// Internal rather than private so other APIClient extensions (e.g.
    /// APIClient+Chat.swift) can build multipart requests of their own.
    func multipartRequest(
        _ path: String,
        fields: [String: String],
        files: [MultipartFile],
        userId: String?
    ) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        if let userId {
            request.setValue(userId, forHTTPHeaderField: "x-user-id")
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        for file in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        return request
    }

    func postMultipart<T: Decodable>(
        _ path: String,
        fields: [String: String] = [:],
        files: [MultipartFile],
        userId: String? = nil
    ) async throws -> T {
        let request = multipartRequest(path, fields: fields, files: files, userId: userId)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    @discardableResult
    func uploadVideo(
        title: String,
        set: String,
        competition: String?,
        duration: String?,
        pinned: Bool,
        pinLabel: String?,
        fileData: Data,
        fileName: String,
        mimeType: String,
        userId: String
    ) async throws -> VideoItem {
        var fields: [String: String] = ["title": title, "set": set, "pinned": pinned ? "true" : "false"]
        if let competition, !competition.isEmpty { fields["competition"] = competition }
        if let duration, !duration.isEmpty { fields["duration"] = duration }
        if pinned, let pinLabel { fields["pinLabel"] = pinLabel }

        return try await postMultipart(
            "videos",
            fields: fields,
            files: [MultipartFile(fieldName: "file", fileName: fileName, mimeType: mimeType, data: fileData)],
            userId: userId
        )
    }

    @discardableResult
    func setVideoPin(id: String, pinned: Bool, pinLabel: String?, userId: String) async throws -> VideoItem {
        var body: [String: Any] = ["pinned": pinned]
        if let pinLabel { body["pinLabel"] = pinLabel }
        return try await patch("videos/\(id)", body: body, userId: userId)
    }

    func fetchCalendarEvents(userId: String) async throws -> [CalendarEventItem] {
        try await get("calendar", userId: userId)
    }

    @discardableResult
    func createCalendarEvent(
        date: Date,
        category: CalendarCategory,
        label: String,
        description: String?,
        visibleToRoles: [Role],
        userId: String
    ) async throws -> CalendarEventItem {
        var body: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: date),
            "category": category.rawValue,
            "label": label,
            "visibleToRoles": visibleToRoles.map(\.rawValue),
        ]
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["description"] = description
        }
        return try await post("calendar", body: body, userId: userId)
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

    // MARK: - Practice attendance (Captain-only to mark)

    func fetchPracticeAttendance(practiceId: String, userId: String) async throws -> PracticeAttendanceForPractice {
        try await get("practices/\(practiceId)/attendance", userId: userId)
    }

    func markPracticeAttendance(practiceId: String, targetUserId: String, status: AttendanceStatus, userId: String) async throws {
        let _: EmptyDecodable = try await put(
            "practices/\(practiceId)/attendance/mark",
            body: ["userId": targetUserId, "status": status.rawValue],
            userId: userId
        )
    }

    func markAllPracticeAttendance(practiceId: String, status: AttendanceStatus, userId: String) async throws {
        try await putNoContent("practices/\(practiceId)/attendance/mark-all", body: ["status": status.rawValue], userId: userId)
    }
}

/// Decodes any JSON body without caring about its shape — used where the
/// server returns a record we don't need back (e.g. mark-attendance results,
/// since the caller just re-fetches the full dashboard after marking).
struct EmptyDecodable: Decodable {}
