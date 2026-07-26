import SwiftUI

/// "Coming Up" digest shown under the Calendar tab: the 3 most urgent items
/// across announcements, tasks, and RSVP reminders — matching the Figma
/// prototype's compact NotificationCard list. Reads from the same
/// `NotificationsStore` as NotificationsSectionView, so a swipe-to-clear
/// here or there is reflected in both immediately, and clearing an item
/// backfills the 3rd slot from the next-most-urgent item automatically.
struct TopRemindersWidgetView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var store: NotificationsStore

    /// Reminders and announcements sit on different clocks (a reminder's
    /// due date vs. an announcement's post date), so a single raw-date sort
    /// always lets one type crowd out the other — e.g. every reminder due
    /// in October would outrank every announcement posted in July, so
    /// announcements would never appear here once there are 3+ reminders.
    /// Interleaving from two separately-sorted pools guarantees every type
    /// on the Notifications tab stays representable here, regardless of
    /// how its date compares to the other types'.
    private var comingUp: [NotificationFeedItem] {
        var reminderPool: [NotificationFeedItem] = []
        var announcementPool: [NotificationFeedItem] = []
        for item in store.items(withAnnouncements: appState.updates) {
            switch item {
            case .reminder: reminderPool.append(item)
            case .announcement: announcementPool.append(item)
            }
        }
        reminderPool.sort { $0.sortDate < $1.sortDate }
        announcementPool.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.sortDate > rhs.sortDate
        }

        var result: [NotificationFeedItem] = []
        var reminderIndex = 0, announcementIndex = 0
        while result.count < 3 && (reminderIndex < reminderPool.count || announcementIndex < announcementPool.count) {
            if reminderIndex < reminderPool.count {
                result.append(reminderPool[reminderIndex])
                reminderIndex += 1
            }
            if result.count < 3, announcementIndex < announcementPool.count {
                result.append(announcementPool[announcementIndex])
                announcementIndex += 1
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("COMING UP")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Rectangle().fill(Color(.separator)).frame(height: 0.5)
            }

            if comingUp.isEmpty {
                Text("You're all caught up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(comingUp) { item in
                    SwipeToDismissView(onDismiss: { store.dismiss(item) }) {
                        NotificationCardView(
                            item: item,
                            compact: true,
                            onRsvp: { response in
                                guard case .reminder(let reminder) = item, let userId = appState.currentUserId else { return }
                                Task { await store.rsvp(id: reminder.id, response: response, userId: userId) }
                            },
                            onToggleDone: {
                                guard case .reminder(let reminder) = item, let userId = appState.currentUserId else { return }
                                Task { await store.setDone(id: reminder.id, done: !reminder.doneByMe, userId: userId) }
                            }
                        )
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await store.load(userId: userId)
    }
}
