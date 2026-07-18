import Foundation

// MARK: - Props & Costumes (backend/src/routes/propsCostumes.ts)
//
// Access is gated per-role via AppState.capabilities.propsCostumes.mode
// (mirrors backend propsCostumesAccess): "FULL" (Captain/Production),
// "BUDGET_ONLY" (Finance), "OWN_ASSIGNMENTS_ONLY" (Returner/Newbie), "NONE"
// (Logistics). See PropsCostumesView.swift for the mode switch.

enum PropCostumeCategoryType: String, Codable {
    case prop = "PROP"
    case costume = "COSTUME"

    var label: String {
        switch self {
        case .prop: return "Prop"
        case .costume: return "Costume"
        }
    }

    var icon: String {
        switch self {
        case .prop: return "theatermasks.fill"
        case .costume: return "tshirt.fill"
        }
    }
}

enum PropCostumeStatusType: String, Codable, CaseIterable {
    case notStarted = "NOT_STARTED"
    case inProgress = "IN_PROGRESS"
    case ready = "READY"
    case rented = "RENTED"

    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .ready: return "Ready"
        case .rented: return "Rented"
        }
    }
}

struct PropCostumeAssignmentModel: Codable, Identifiable {
    let id: String
    let userId: String
    let size: String?
    let task: String?
    let status: String
    let user: AppUser?
}

struct PropCostumeItemModel: Codable, Identifiable {
    let id: String
    let name: String
    let category: PropCostumeCategoryType
    let status: PropCostumeStatusType
    let rentalVendor: String?
    let rentalCostCents: Int?
    let rentalDueDate: Date?
    let notes: String?
    let assignments: [PropCostumeAssignmentModel]
}

struct BudgetLineItem: Codable, Identifiable {
    let id: String
    let name: String
    let rentalCostCents: Int?
}

struct PropsCostumesBudget: Codable {
    let totalBudgetCents: Int
    let totalSpentCents: Int
    let items: [BudgetLineItem]
}
