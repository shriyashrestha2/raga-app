import Foundation

/// Personal reminders — every role manages only their own topics/reminders,
/// so unlike quotas/fines there's no separate "target user" concept; `userId`
/// here is always just the acting user (sent as `x-user-id`).
extension APIClient {
    func fetchReminderTopics(userId: String) async throws -> [ReminderTopic] {
        try await get("reminders", userId: userId)
    }

    @discardableResult
    func createReminderTopic(name: String, userId: String) async throws -> ReminderTopic {
        try await post("reminders/topics", body: ["name": name], userId: userId)
    }

    func deleteReminderTopic(id: String, userId: String) async throws {
        try await delete("reminders/topics/\(id)", userId: userId)
    }

    @discardableResult
    func createReminder(topicId: String, title: String, description: String?, date: Date, addToCalendar: Bool, userId: String) async throws -> ReminderItem {
        var body: [String: Any] = [
            "topicId": topicId,
            "title": title,
            "date": ISO8601DateFormatter().string(from: date),
            "addToCalendar": addToCalendar,
        ]
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["description"] = description
        }
        return try await post("reminders", body: body, userId: userId)
    }

    func deleteReminder(id: String, userId: String) async throws {
        try await delete("reminders/\(id)", userId: userId)
    }
}
