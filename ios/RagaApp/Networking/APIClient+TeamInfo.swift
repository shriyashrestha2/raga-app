import Foundation

/// Team Roster / Team Info subsystem. `teamInfo` covers the singleton
/// team-level row (backend/src/routes/teamInfo.ts); `updateRoster` reuses
/// the existing per-member roster/contact endpoint (backend/src/routes/users.ts's
/// `PATCH /users/:id`) rather than duplicating it.
extension APIClient {
    func fetchTeamInfo(userId: String) async throws -> TeamInfoModel {
        try await get("team-info", userId: userId)
    }

    @discardableResult
    func updateTeamInfo(teamName: String?, season: String?, description: String?, userId: String) async throws -> TeamInfoModel {
        var body: [String: Any] = [:]
        if let teamName { body["teamName"] = teamName }
        if let season { body["season"] = season }
        if let description { body["description"] = description }
        return try await patch("team-info", body: body, userId: userId)
    }

    @discardableResult
    func updateRoster(
        memberId: String,
        email: String?,
        phone: String?,
        year: String?,
        major: String?,
        bio: String?,
        emergencyContactName: String?,
        emergencyContactPhone: String?,
        userId: String
    ) async throws -> AppUser {
        var body: [String: Any] = [:]
        if let email { body["email"] = email }
        if let phone { body["phone"] = phone }
        if let year { body["year"] = year }
        if let major { body["major"] = major }
        if let bio { body["bio"] = bio }
        if let emergencyContactName { body["emergencyContactName"] = emergencyContactName }
        if let emergencyContactPhone { body["emergencyContactPhone"] = emergencyContactPhone }
        return try await patch("users/\(memberId)", body: body, userId: userId)
    }
}
