import Foundation

// MARK: - Competition Dashboard

extension APIClient {
    func fetchCompetitions(userId: String) async throws -> [CompetitionItem] {
        try await get("competitions", userId: userId)
    }

    func fetchCompetition(id: String, userId: String) async throws -> CompetitionItem {
        try await get("competitions/\(id)", userId: userId)
    }

    @discardableResult
    func updateFinanceSection(competitionId: String, budgetCents: Int, spentCents: Int, notes: String?, userId: String) async throws -> CompFinanceSectionModel {
        var body: [String: Any] = ["budgetCents": budgetCents, "spentCents": spentCents]
        body["notes"] = notes
        return try await patch("competitions/\(competitionId)/finance", body: body, userId: userId)
    }

    @discardableResult
    func updateProductionSection(competitionId: String, musicStatus: String?, costumeStatus: String?, notes: String?, userId: String) async throws -> CompProductionSectionModel {
        var body: [String: Any] = [:]
        body["musicStatus"] = musicStatus
        body["costumeStatus"] = costumeStatus
        body["notes"] = notes
        return try await patch("competitions/\(competitionId)/production", body: body, userId: userId)
    }

    @discardableResult
    func updateLogisticsSection(competitionId: String, travelPlan: String?, lodging: String?, transportationNotes: String?, userId: String) async throws -> CompLogisticsSectionModel {
        var body: [String: Any] = [:]
        body["travelPlan"] = travelPlan
        body["lodging"] = lodging
        body["transportationNotes"] = transportationNotes
        return try await patch("competitions/\(competitionId)/logistics", body: body, userId: userId)
    }
}
