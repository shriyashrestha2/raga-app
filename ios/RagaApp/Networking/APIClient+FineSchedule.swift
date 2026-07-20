import Foundation

extension APIClient {
    func fetchFineSchedule(userId: String) async throws -> [FineScheduleEntry] {
        try await get("fine-schedule", userId: userId)
    }

    /// `amountCents`/`description` are mutually exclusive per the server's
    /// validation (see backend/src/routes/fineSchedule.ts) — pass exactly one.
    @discardableResult
    func createFineScheduleEntry(offense: String, amountCents: Int?, description: String?, userId: String) async throws -> FineScheduleEntry {
        let body: [String: Any] = [
            "offense": offense,
            "amountCents": amountCents as Any? ?? NSNull(),
            "description": description as Any? ?? NSNull(),
        ]
        return try await post("fine-schedule", body: body, userId: userId)
    }

    @discardableResult
    func updateFineScheduleEntry(id: String, offense: String, amountCents: Int?, description: String?, userId: String) async throws -> FineScheduleEntry {
        let body: [String: Any] = [
            "offense": offense,
            "amountCents": amountCents as Any? ?? NSNull(),
            "description": description as Any? ?? NSNull(),
        ]
        return try await patch("fine-schedule/\(id)", body: body, userId: userId)
    }

    func deleteFineScheduleEntry(id: String, userId: String) async throws {
        try await delete("fine-schedule/\(id)", userId: userId)
    }
}
