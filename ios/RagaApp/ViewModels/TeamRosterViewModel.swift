import Foundation

/// Drives TeamRosterView + TeamInfoEditView. Owns the singleton `TeamInfo`
/// row; per-member roster fields still live on `AppState.users` (already
/// loaded app-wide), so `updateMember` returns the freshly-saved `AppUser`
/// for the caller to splice back into `appState.users` rather than owning a
/// duplicate copy of the roster here.
@MainActor
final class TeamRosterViewModel: ObservableObject {
    @Published var teamInfo: TeamInfoModel?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadTeamInfo(userId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            teamInfo = try await APIClient.shared.fetchTeamInfo(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func saveTeamInfo(teamName: String?, season: String?, description: String?, userId: String) async -> Bool {
        errorMessage = nil
        do {
            teamInfo = try await APIClient.shared.updateTeamInfo(teamName: teamName, season: season, description: description, userId: userId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updateMember(
        memberId: String,
        email: String?,
        phone: String?,
        year: String?,
        major: String?,
        bio: String?,
        emergencyContactName: String?,
        emergencyContactPhone: String?,
        userId: String
    ) async -> AppUser? {
        errorMessage = nil
        do {
            return try await APIClient.shared.updateRoster(
                memberId: memberId,
                email: email,
                phone: phone,
                year: year,
                major: major,
                bio: bio,
                emergencyContactName: emergencyContactName,
                emergencyContactPhone: emergencyContactPhone,
                userId: userId
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
