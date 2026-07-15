import Foundation

/// Backs `CompetitionDashboardView`. Mirrors `AppState`'s load/mutate/error
/// pattern but stays self-contained since this feature is scoped to a
/// single screen. `userId` is passed per-call (not stored) so this survives
/// `AppState.switchUser(to:)` swapping the acting demo user mid-session.
@MainActor
final class CompetitionDashboardViewModel: ObservableObject {
    @Published var competitions: [CompetitionItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            competitions = try await APIClient.shared.fetchCompetitions(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replace(_ updated: CompetitionItem) {
        if let index = competitions.firstIndex(where: { $0.id == updated.id }) {
            competitions[index] = updated
        }
    }

    /// After a section PATCH we only get the section payload back, not the
    /// whole shaped competition, so we re-fetch that one competition (still
    /// correctly shaped per the caller's role) rather than trying to
    /// reconstruct it client-side.
    private func refreshOne(_ competitionId: String, userId: String) async {
        do {
            let updated = try await APIClient.shared.fetchCompetition(id: competitionId, userId: userId)
            replace(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateFinance(competitionId: String, budgetCents: Int, spentCents: Int, notes: String?, userId: String) async {
        do {
            _ = try await APIClient.shared.updateFinanceSection(
                competitionId: competitionId,
                budgetCents: budgetCents,
                spentCents: spentCents,
                notes: notes,
                userId: userId
            )
            await refreshOne(competitionId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProduction(competitionId: String, musicStatus: String?, costumeStatus: String?, notes: String?, userId: String) async {
        do {
            _ = try await APIClient.shared.updateProductionSection(
                competitionId: competitionId,
                musicStatus: musicStatus,
                costumeStatus: costumeStatus,
                notes: notes,
                userId: userId
            )
            await refreshOne(competitionId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateLogistics(competitionId: String, travelPlan: String?, lodging: String?, transportationNotes: String?, userId: String) async {
        do {
            _ = try await APIClient.shared.updateLogisticsSection(
                competitionId: competitionId,
                travelPlan: travelPlan,
                lodging: lodging,
                transportationNotes: transportationNotes,
                userId: userId
            )
            await refreshOne(competitionId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
