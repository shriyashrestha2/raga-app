import Foundation

@MainActor
final class PropsCostumesViewModel: ObservableObject {
    @Published var items: [PropCostumeItemModel] = []
    @Published var budget: PropsCostumesBudget?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Loads the data set appropriate to the caller's access mode:
    /// FULL/OWN_ASSIGNMENTS_ONLY hit the list endpoint (the server itself
    /// decides how much of each item to return), BUDGET_ONLY hits the
    /// separate aggregate endpoint. NONE fetches nothing — the view renders
    /// a restricted-access state without calling load at all.
    func load(userId: String, mode: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch mode {
            case "FULL", "OWN_ASSIGNMENTS_ONLY":
                items = try await APIClient.shared.fetchPropsCostumes(userId: userId)
            case "BUDGET_ONLY":
                budget = try await APIClient.shared.fetchPropsCostumesBudget(userId: userId)
            default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createItem(name: String, category: PropCostumeCategoryType, userId: String) async {
        do {
            let created = try await APIClient.shared.createPropCostumeItem(name: name, category: category, userId: userId)
            items.append(created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateStatus(itemId: String, status: PropCostumeStatusType, userId: String) async {
        do {
            let updated = try await APIClient.shared.updatePropCostumeItem(id: itemId, status: status, userId: userId)
            if let index = items.firstIndex(where: { $0.id == itemId }) {
                items[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func assign(itemId: String, targetUserId: String, size: String?, task: String?, userId: String) async {
        do {
            let assignment = try await APIClient.shared.assignPropCostume(
                itemId: itemId,
                targetUserId: targetUserId,
                size: size,
                task: task,
                userId: userId
            )
            if let index = items.firstIndex(where: { $0.id == itemId }) {
                var assignments = items[index].assignments
                if let existingIndex = assignments.firstIndex(where: { $0.userId == targetUserId }) {
                    assignments[existingIndex] = assignment
                } else {
                    assignments.append(assignment)
                }
                let item = items[index]
                items[index] = PropCostumeItemModel(
                    id: item.id,
                    name: item.name,
                    category: item.category,
                    status: item.status,
                    rentalVendor: item.rentalVendor,
                    rentalCostCents: item.rentalCostCents,
                    rentalDueDate: item.rentalDueDate,
                    notes: item.notes,
                    assignments: assignments
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
