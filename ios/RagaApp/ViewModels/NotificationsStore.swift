import Foundation

/// Single source of truth for the unified Notifications feed, shared by the
/// Notifications tab and the Calendar tab's "Coming Up" widget. Both read
/// from — and clear items through — this one store (owned by RoundupView,
/// one instance per app session) instead of each keeping its own copy, so a
/// swipe-to-clear in either tab is instantly reflected in the other.
///
/// Reminders and Updates (announcements) stay separate backend models —
/// this only unifies them for display via `items(withAnnouncements:)`.
@MainActor
final class NotificationsStore: ObservableObject {
    @Published private(set) var reminders: [ReminderItem] = []
    @Published private(set) var dismissedIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var userId: String?

    private var dismissedIDsKey: String {
        "dismissedNotificationIDs.\(userId ?? "anon")"
    }

    func load(userId: String) async {
        if self.userId != userId {
            self.userId = userId
            dismissedIDs = Set(UserDefaults.standard.stringArray(forKey: dismissedIDsKey) ?? [])
        }
        isLoading = true
        defer { isLoading = false }
        do {
            reminders = try await APIClient.shared.fetchReminders(category: nil, userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func items(withAnnouncements updates: [UpdateItem]) -> [NotificationFeedItem] {
        let reminderItems = reminders.map(NotificationFeedItem.reminder)
        let announcementItems = updates.map(NotificationFeedItem.announcement)
        return (reminderItems + announcementItems)
            .filter { !dismissedIDs.contains($0.id) }
            .sorted { $0.sortDate < $1.sortDate }
    }

    /// Personal, client-side dismiss (not a backend delete) — persisted per
    /// user in UserDefaults so it survives relaunches but doesn't sync
    /// across devices.
    func dismiss(_ item: NotificationFeedItem) {
        dismissedIDs.insert(item.id)
        UserDefaults.standard.set(Array(dismissedIDs), forKey: dismissedIDsKey)
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
