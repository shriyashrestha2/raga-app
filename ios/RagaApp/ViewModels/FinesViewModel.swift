import Foundation

@MainActor
final class FinesViewModel: ObservableObject {
    @Published var fines: [FineItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            fines = try await APIClient.shared.fetchFines(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createFine(targetUserId: String, amountCents: Int, reason: String, status: FineStatus? = nil, issuedAt: Date? = nil, userId: String) async {
        do {
            try await APIClient.shared.createFine(targetUserId: targetUserId, amountCents: amountCents, reason: reason, status: status, issuedAt: issuedAt, userId: userId)
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setStatus(fineId: String, status: FineStatus, userId: String) async {
        do {
            try await APIClient.shared.updateFineStatus(id: fineId, status: status, userId: userId)
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(fineId: String, userId: String) async {
        do {
            try await APIClient.shared.deleteFine(id: fineId, userId: userId)
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
