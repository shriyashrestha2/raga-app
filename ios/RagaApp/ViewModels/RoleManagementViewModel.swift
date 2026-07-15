import Foundation

/// Drives the Role Management screen's single mutation: changing a member's
/// role. Kept separate from AppState (which owns the canonical `users` list)
/// because this is purely a "submit a mutation, report success/failure"
/// concern — the caller is responsible for calling `AppState.loadAll()`
/// after a successful change so the roster refreshes everywhere in the app.
@MainActor
final class RoleManagementViewModel: ObservableObject {
    @Published var isUpdating = false
    @Published var errorMessage: String?

    @discardableResult
    func changeRole(memberId: String, to newRole: Role, actingUserId: String) async -> Bool {
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }
        do {
            try await APIClient.shared.updateUserRole(memberId: memberId, newRole: newRole, actingUserId: actingUserId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
