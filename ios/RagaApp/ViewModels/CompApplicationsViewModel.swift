import Foundation

/// Backs `CompApplicationsView` (Captain/Logistics-only competition
/// application tracker). Mirrors `AppState`'s load/mutate/error pattern but
/// stays self-contained since this feature is scoped to a single screen.
@MainActor
final class CompApplicationsViewModel: ObservableObject {
    @Published var applications: [CompApplicationItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            applications = try await APIClient.shared.fetchCompApplications(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func create(competitionName: String, deadline: Date, assignedToId: String?, userId: String) async -> Bool {
        do {
            _ = try await APIClient.shared.createCompApplication(
                competitionName: competitionName,
                deadline: deadline,
                assignedToId: assignedToId,
                userId: userId
            )
            await load(userId: userId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateStatus(id: String, status: CompApplicationStatusType, userId: String) async {
        do {
            let updated = try await APIClient.shared.updateCompApplicationStatus(id: id, status: status, userId: userId)
            apply(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Full-edit save backing the detail sheet (competition name, deadline,
    /// status, packet URL, notes, assignee all in one round trip).
    func update(
        id: String,
        competitionName: String,
        deadline: Date,
        status: CompApplicationStatusType,
        packetUrl: String,
        notes: String,
        assignedToId: String??,
        userId: String
    ) async {
        do {
            let updated = try await APIClient.shared.updateCompApplication(
                id: id,
                competitionName: competitionName,
                deadline: deadline,
                status: status,
                packetUrl: packetUrl,
                notes: notes,
                assignedToId: assignedToId,
                userId: userId
            )
            apply(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: String, userId: String) async {
        do {
            try await APIClient.shared.deleteCompApplication(id: id, userId: userId)
            applications.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ updated: CompApplicationItem) {
        if let idx = applications.firstIndex(where: { $0.id == updated.id }) {
            applications[idx] = updated
        } else {
            applications.append(updated)
        }
        applications.sort { $0.deadline < $1.deadline }
    }
}
