import Foundation

extension APIClient {
    /// Fundraising totals are team-wide, not per-user, so every role gets
    /// back the full list — the server doesn't filter this by role.
    func fetchFunds(userId: String) async throws -> [FundItem] {
        try await get("funds", userId: userId)
    }

    @discardableResult
    func createFund(amountCents: Int, source: String, dateAdded: Date, userId: String) async throws -> FundItem {
        let body: [String: Any] = [
            "amountCents": amountCents,
            "source": source,
            "dateAdded": ISO8601DateFormatter().string(from: dateAdded),
        ]
        return try await post("funds", body: body, userId: userId)
    }
}
