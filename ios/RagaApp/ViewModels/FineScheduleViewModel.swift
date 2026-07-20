import Foundation

@MainActor
final class FineScheduleViewModel: ObservableObject {
    @Published var entries: [FineScheduleEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            entries = try await APIClient.shared.fetchFineSchedule(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(offense: String, amountCents: Int?, description: String?, userId: String) async {
        do {
            try await APIClient.shared.createFineScheduleEntry(offense: offense, amountCents: amountCents, description: description, userId: userId)
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(id: String, offense: String, amountCents: Int?, description: String?, userId: String) async {
        do {
            try await APIClient.shared.updateFineScheduleEntry(id: id, offense: offense, amountCents: amountCents, description: description, userId: userId)
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: String, userId: String) async {
        do {
            try await APIClient.shared.deleteFineScheduleEntry(id: id, userId: userId)
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
