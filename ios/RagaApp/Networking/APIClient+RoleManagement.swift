import Foundation

// MARK: - Role Management (Captain-only)
//
// Backend contract: PATCH /users/:id/role, body { role: <Role rawValue> },
// gated server-side by canManageRoles (Captain only — see
// backend/src/routes/users.ts). Returns the updated User record.
extension APIClient {
    @discardableResult
    func updateUserRole(memberId: String, newRole: Role, actingUserId: String) async throws -> AppUser {
        try await patch("users/\(memberId)/role", body: ["role": newRole.rawValue], userId: actingUserId)
    }
}
