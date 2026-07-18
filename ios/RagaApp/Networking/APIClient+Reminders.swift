import Foundation

/// Shared team reminders — everyone sees the same filterable list; only
/// Captains/board positions can create (server-enforced, mirrored client-side
/// via AppState.capabilities.reminders).
extension APIClient {
    func fetchReminders(category: CalendarCategory?, userId: String) async throws -> [ReminderItem] {
        try await get("reminders", query: category.map { ["category": $0.rawValue] } ?? [:], userId: userId)
    }

    @discardableResult
    func createReminder(
        title: String,
        description: String?,
        date: Date,
        type: ReminderKind,
        category: CalendarCategory,
        userId: String
    ) async throws -> ReminderItem {
        var body: [String: Any] = [
            "title": title,
            "date": ISO8601DateFormatter().string(from: date),
            "type": type.rawValue,
            "category": category.rawValue,
        ]
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["description"] = description
        }
        return try await post("reminders", body: body, userId: userId)
    }

    func deleteReminder(id: String, userId: String) async throws {
        try await delete("reminders/\(id)", userId: userId)
    }

    @discardableResult
    func rsvpReminder(id: String, response: RsvpResponse, userId: String) async throws -> ReminderItem {
        try await post("reminders/\(id)/rsvp", body: ["response": response.rawValue], userId: userId)
    }

    @discardableResult
    func setReminderDone(id: String, done: Bool, userId: String) async throws -> ReminderItem {
        try await post("reminders/\(id)/done", body: ["done": done], userId: userId)
    }
}
