import Foundation

@MainActor
final class RemindersViewModel: ObservableObject {
    @Published var reminders: [ReminderItem] = []
    @Published var selectedCategory: CalendarCategory?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            reminders = try await APIClient.shared.fetchReminders(category: selectedCategory, userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createReminder(title: String, description: String?, date: Date, type: ReminderKind, category: CalendarCategory, userId: String) async {
        do {
            _ = try await APIClient.shared.createReminder(
                title: title, description: description, date: date, type: type, category: category, userId: userId
            )
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteReminder(id: String, userId: String) async {
        do {
            try await APIClient.shared.deleteReminder(id: id, userId: userId)
            reminders.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rsvp(id: String, response: RsvpResponse, userId: String) async {
        do {
            let updated = try await APIClient.shared.rsvpReminder(id: id, response: response, userId: userId)
            replace(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDone(id: String, done: Bool, userId: String) async {
        do {
            let updated = try await APIClient.shared.setReminderDone(id: id, done: done, userId: userId)
            replace(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replace(_ updated: ReminderItem) {
        if let index = reminders.firstIndex(where: { $0.id == updated.id }) {
            reminders[index] = updated
        }
    }
}
