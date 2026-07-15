import Foundation

// MARK: - Comp Applications (Captain/Logistics-only)

extension APIClient {
    func fetchCompApplications(userId: String) async throws -> [CompApplicationItem] {
        try await get("comp-applications", userId: userId)
    }

    func fetchCompApplication(id: String, userId: String) async throws -> CompApplicationItem {
        try await get("comp-applications/\(id)", userId: userId)
    }

    @discardableResult
    func createCompApplication(competitionName: String, deadline: Date, assignedToId: String?, userId: String) async throws -> CompApplicationItem {
        var body: [String: Any] = [
            "competitionName": competitionName,
            "deadline": ISO8601DateFormatter().string(from: deadline),
        ]
        if let assignedToId { body["assignedToId"] = assignedToId }
        return try await post("comp-applications", body: body, userId: userId)
    }

    @discardableResult
    func updateCompApplicationStatus(id: String, status: CompApplicationStatusType, userId: String) async throws -> CompApplicationItem {
        try await patch("comp-applications/\(id)", body: ["status": status.rawValue], userId: userId)
    }

    /// Full-edit variant backing the detail sheet (status, packet URL, notes,
    /// assignee) — `updateCompApplicationStatus` above stays as the narrow
    /// status-only convenience the spec called out explicitly.
    @discardableResult
    func updateCompApplication(
        id: String,
        competitionName: String? = nil,
        deadline: Date? = nil,
        status: CompApplicationStatusType? = nil,
        packetUrl: String? = nil,
        notes: String? = nil,
        assignedToId: String?? = nil,
        userId: String
    ) async throws -> CompApplicationItem {
        var body: [String: Any] = [:]
        if let competitionName { body["competitionName"] = competitionName }
        if let deadline { body["deadline"] = ISO8601DateFormatter().string(from: deadline) }
        if let status { body["status"] = status.rawValue }
        if let packetUrl { body["packetUrl"] = packetUrl }
        if let notes { body["notes"] = notes }
        if let assignedToId {
            body["assignedToId"] = assignedToId ?? NSNull()
        }
        return try await patch("comp-applications/\(id)", body: body, userId: userId)
    }

    func deleteCompApplication(id: String, userId: String) async throws {
        try await delete("comp-applications/\(id)", userId: userId)
    }
}
