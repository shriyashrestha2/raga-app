import Foundation

extension APIClient {
    /// `userId` is the acting/requesting user (sent as `x-user-id`). The
    /// server force-filters to that user's own quota(s) unless their role
    /// can manage quotas (Captain/Finance), in which case it returns every
    /// member's quota. There is deliberately no separate "target user"
    /// query param exposed here for reads — filtering by a specific member
    /// is a manager-only convenience the UI doesn't currently need.
    func fetchQuotas(userId: String) async throws -> [QuotaItem] {
        try await get("quotas", userId: userId)
    }

    /// `targetUserId` is whose quota this is; `userId` is the manager
    /// creating it (sent as `x-user-id`). Server gates with canManageQuotas.
    @discardableResult
    func createQuota(targetUserId: String, label: String, unit: String, targetValue: Double, dueDate: Date?, userId: String) async throws -> QuotaItem {
        var body: [String: Any] = [
            "userId": targetUserId,
            "label": label,
            "unit": unit,
            "targetValue": targetValue,
        ]
        if let dueDate {
            body["dueDate"] = ISO8601DateFormatter().string(from: dueDate)
        }
        return try await post("quotas", body: body, userId: userId)
    }

    @discardableResult
    func updateQuotaProgress(id: String, currentValue: Double, userId: String) async throws -> QuotaItem {
        try await patch("quotas/\(id)", body: ["currentValue": currentValue], userId: userId)
    }

    func deleteQuota(id: String, userId: String) async throws {
        try await delete("quotas/\(id)", userId: userId)
    }
}
