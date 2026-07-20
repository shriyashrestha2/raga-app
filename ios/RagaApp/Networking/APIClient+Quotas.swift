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

    /// Only `targetValue` (the dollar/unit amount needed) is editable here —
    /// `currentValue` is derived server-side from contributions, never set
    /// directly. Server gates with canManageQuotas.
    @discardableResult
    func updateQuotaTarget(id: String, targetValue: Double, userId: String) async throws -> QuotaItem {
        try await patch("quotas/\(id)", body: ["targetValue": targetValue], userId: userId)
    }

    /// Logs one itemized entry toward a quota (event/source + amount) and
    /// bumps `currentValue` by the same amount server-side, in one
    /// transaction. Server gates with canManageQuotas.
    @discardableResult
    func createQuotaContribution(quotaId: String, event: String, amount: Double, userId: String) async throws -> QuotaItem {
        try await post("quotas/\(quotaId)/contributions", body: ["event": event, "amount": amount], userId: userId)
    }

    func deleteQuota(id: String, userId: String) async throws {
        try await delete("quotas/\(id)", userId: userId)
    }
}
