import Foundation

@MainActor
final class RemindersViewModel: ObservableObject {
    @Published var topics: [ReminderTopic] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            topics = try await APIClient.shared.fetchReminderTopics(userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTopic(name: String, userId: String) async {
        do {
            let created = try await APIClient.shared.createReminderTopic(name: name, userId: userId)
            topics.append(created)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTopic(topicId: String, userId: String) async {
        do {
            try await APIClient.shared.deleteReminderTopic(id: topicId, userId: userId)
            topics.removeAll { $0.id == topicId }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns whether the created reminder was also added to the calendar,
    /// so the caller can decide whether to refresh AppState.calendarEvents.
    @discardableResult
    func addReminder(topicId: String, title: String, description: String?, date: Date, addToCalendar: Bool, userId: String) async -> Bool {
        do {
            let created = try await APIClient.shared.createReminder(
                topicId: topicId,
                title: title,
                description: description,
                date: date,
                addToCalendar: addToCalendar,
                userId: userId
            )
            if let index = topics.firstIndex(where: { $0.id == topicId }) {
                var reminders = topics[index].reminders
                reminders.append(created)
                reminders.sort { $0.date < $1.date }
                topics[index] = ReminderTopic(id: topics[index].id, name: topics[index].name, reminders: reminders)
            }
            errorMessage = nil
            return created.addedToCalendar
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteReminder(topicId: String, reminderId: String, userId: String) async {
        do {
            try await APIClient.shared.deleteReminder(id: reminderId, userId: userId)
            if let index = topics.firstIndex(where: { $0.id == topicId }) {
                let reminders = topics[index].reminders.filter { $0.id != reminderId }
                topics[index] = ReminderTopic(id: topics[index].id, name: topics[index].name, reminders: reminders)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
