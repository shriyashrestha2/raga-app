import Foundation

@MainActor
final class FundsViewModel: ObservableObject {
    @Published var funds: [FundItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            funds = try await APIClient.shared.fetchFunds(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createFund(amountCents: Int, source: String, dateAdded: Date, userId: String) async {
        do {
            try await APIClient.shared.createFund(amountCents: amountCents, source: source, dateAdded: dateAdded, userId: userId)
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
