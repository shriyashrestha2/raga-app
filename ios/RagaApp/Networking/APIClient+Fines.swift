import Foundation

extension APIClient {
    /// `userId` here plays two roles per the server contract: it's both the
    /// `x-user-id` auth header AND (for managers) an optional server-side
    /// filter on whose fines to return. Non-managers are always force-filtered
    /// to their own fines server-side regardless of query params, so this
    /// always fetches "the fines I'm allowed to see."
    func fetchFines(userId: String) async throws -> [FineItem] {
        try await get("fines", userId: userId)
    }

    @discardableResult
    func createFine(targetUserId: String, amountCents: Int, reason: String, userId: String) async throws -> FineItem {
        try await post(
            "fines",
            body: ["userId": targetUserId, "amountCents": amountCents, "reason": reason],
            userId: userId
        )
    }

    @discardableResult
    func updateFineStatus(id: String, status: FineStatus, userId: String) async throws -> FineItem {
        try await patch("fines/\(id)", body: ["status": status.rawValue], userId: userId)
    }

    func deleteFine(id: String, userId: String) async throws {
        try await delete("fines/\(id)", userId: userId)
    }
}
