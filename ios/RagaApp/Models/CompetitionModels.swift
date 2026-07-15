import Foundation

// MARK: - Competition Dashboard
//
// The backend shapes /competitions responses per-role: section keys the
// viewer's role can't see are omitted from the JSON entirely (not merely
// null). Every section field below is therefore Optional so a missing key
// decodes cleanly to `nil` regardless of which role is signed in.

struct CompFinanceSectionModel: Codable {
    let budgetCents: Int
    let spentCents: Int
    let notes: String?
}

struct CompProductionSectionModel: Codable {
    let musicStatus: String?
    let costumeStatus: String?
    let notes: String?
}

struct CompLogisticsSectionModel: Codable {
    let travelPlan: String?
    let lodging: String?
    let transportationNotes: String?
}

struct CompScheduleItemModel: Codable, Identifiable {
    let id: String
    let time: Date
    let label: String
    let notes: String?
}

struct CompetitionItem: Codable, Identifiable {
    let id: String
    let name: String
    let date: Date
    let location: String?
    let financeSection: CompFinanceSectionModel?
    let productionSection: CompProductionSectionModel?
    let logisticsSection: CompLogisticsSectionModel?
    let scheduleItems: [CompScheduleItemModel]
}
