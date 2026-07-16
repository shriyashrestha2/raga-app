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
    @State private var showingNewUpdate = false

    private var pinned: [UpdateItem] { appState.updates.filter(\.pinned) }
    private var recent: [UpdateItem] { appState.updates.filter { !$0.pinned }.prefix(3).map { $0 } }

    private var canPostUpdate: Bool {
        appState.capabilities?.announcements.canPostTeamWide == true || appState.capabilities?.announcements.ownChannelRole != nil
    }

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
        .sheet(isPresented: $showingNewUpdate) {
            NewUpdateSheet { tag, content, pinned, visibleToRoles in
                Task { await appState.createUpdate(tag: tag, content: content, pinned: pinned, visibleToRoles: visibleToRoles) }
            }
        }
    }

    @ViewBuilder
    private var notificationsContent: some View {
        if appState.role == .captain, let userId = appState.currentUserId {
            ChoreoReminderWidgetsView(userId: userId)
        }

        if canPostUpdate {
            Button {
                showingNewUpdate = true
            } label: {
                Label("New Update", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color("AccentColor"))
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
