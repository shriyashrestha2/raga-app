import Foundation

@MainActor
final class QuotasViewModel: ObservableObject {
    @Published var quotas: [QuotaItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            quotas = try await APIClient.shared.fetchQuotas(userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func updateProgress(quotaId: String, currentValue: Double, userId: String) async {
        do {
            let updated = try await APIClient.shared.updateQuotaProgress(id: quotaId, currentValue: currentValue, userId: userId)
            if let index = quotas.firstIndex(where: { $0.id == quotaId }) {
                quotas[index] = updated
            }
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
}
