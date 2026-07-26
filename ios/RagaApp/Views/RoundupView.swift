import SwiftUI

enum RoundupTab: String, CaseIterable, Identifiable {
    case calendar, notifications
    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .notifications: return "Notifications"
        }
    }
}

struct RoundupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tab: RoundupTab = .notifications
    /// Owned here (not by the Calendar/Notifications children) so both tabs
    /// share one live copy of reminders + dismissed state — clearing an
    /// item in either tab updates both immediately.
    @StateObject private var notificationsStore = NotificationsStore()

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
                        TopRemindersWidgetView(store: notificationsStore)
                    case .notifications:
                        NotificationsSectionView(store: notificationsStore)
                    }
                }
                .padding(16)
            }
            .refreshable { await appState.loadAll() }
        }
    }
}
