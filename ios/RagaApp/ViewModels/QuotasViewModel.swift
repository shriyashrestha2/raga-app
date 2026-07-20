import Foundation

/// Backs the combined per-person Quotas + Fines view: managers (Captain/
/// Finance) see every member's quota alongside their outstanding fines;
/// everyone else only ever gets their own back from both GET /quotas and
/// GET /fines, since the server force-filters non-managers on both routes.
@MainActor
final class QuotasViewModel: ObservableObject {
    @Published var quotas: [QuotaItem] = []
    @Published var fines: [FineItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let quotasTask = APIClient.shared.fetchQuotas(userId: userId)
            async let finesTask = APIClient.shared.fetchFines(userId: userId)
            let (fetchedQuotas, fetchedFines) = try await (quotasTask, finesTask)
            quotas = fetchedQuotas
            fines = fetchedFines
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unpaidFines(for userId: String) -> [FineItem] {
        fines.filter { $0.userId == userId && $0.status == .unpaid }
    }

    /// Outstanding (unpaid) fine total for one member, in cents.
    func unpaidFineCents(for userId: String) -> Int {
        let matching = unpaidFines(for: userId)
        return matching.reduce(0) { $0 + $1.amountCents }
    }

    func unpaidFineCount(for userId: String) -> Int {
        unpaidFines(for: userId).count
    }

    func createQuota(targetUserId: String, label: String, unit: String, targetValue: Double, dueDate: Date?, userId: String) async {
        do {
            let created = try await APIClient.shared.createQuota(
                targetUserId: targetUserId,
                label: label,
                unit: unit,
                targetValue: targetValue,
                dueDate: dueDate,
                userId: userId
            )
            quotas.insert(created, at: 0)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTarget(quotaId: String, targetValue: Double, userId: String) async {
        do {
            let updated = try await APIClient.shared.updateQuotaTarget(id: quotaId, targetValue: targetValue, userId: userId)
            replace(updated)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addContribution(quotaId: String, event: String, amount: Double, userId: String) async {
        do {
            let updated = try await APIClient.shared.createQuotaContribution(quotaId: quotaId, event: event, amount: amount, userId: userId)
            replace(updated)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(quotaId: String, userId: String) async {
        do {
            try await APIClient.shared.deleteQuota(id: quotaId, userId: userId)
            quotas.removeAll { $0.id == quotaId }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replace(_ updated: QuotaItem) {
        if let index = quotas.firstIndex(where: { $0.id == updated.id }) {
            quotas[index] = updated
        }
    }
}
