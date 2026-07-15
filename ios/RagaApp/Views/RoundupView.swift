import SwiftUI

enum RoundupTab: String, CaseIterable, Identifiable {
    case calendar, reminders, notifications
    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .notifications: return "Notifications"
        }
    }
}

struct RoundupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tab: RoundupTab = .calendar

    private var pinned: [UpdateItem] { appState.updates.filter(\.pinned) }
    private var recent: [UpdateItem] { appState.updates.filter { !$0.pinned }.prefix(3).map { $0 } }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(RoundupTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                LazyVStack(spacing: 12) {
                    switch tab {
                    case .calendar:
                        MiniCalendarView(events: appState.calendarEvents)
                    case .reminders:
                        RemindersSectionView()
                    case .notifications:
                        notificationsContent
                    }
                }
                .padding(16)
            }
            .refreshable { await appState.loadAll() }
        }
    }

    @ViewBuilder
    private var notificationsContent: some View {
        if appState.role == .captain, let userId = appState.currentUserId {
            ChoreoReminderWidgetsView(userId: userId)
        }

        if pinned.isEmpty && recent.isEmpty {
            EmptyStateView(
                icon: "bell",
                title: "No notifications",
                message: "Team announcements and updates will show up here."
            )
        } else {
            ForEach(pinned) { UpdateCardView(update: $0) }
            ForEach(recent) { UpdateCardView(update: $0) }
        }
    }
}
