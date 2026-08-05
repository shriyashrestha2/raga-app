import SwiftUI

/// Unified team feed shown on the Roundup page, directly below the calendar,
/// merging announcements (Update) and reminders (task/RSVP) into one
/// filterable list — filterable by board category (Finance/Production/
/// Captains/etc. via `CalendarCategory`) and, via `selectedDate` (owned by
/// RoundupView and shared with MiniCalendarView), by the tapped calendar day.
/// The two stay separate backend models/endpoints — this view just blends
/// them for display. Everyone sees the same feed and can mark a task done or
/// RSVP; only Captains/board positions can post (gated by capabilities) or
/// delete (via swipe, gated the same way).
struct NotificationsSectionView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var store: NotificationsStore
    /// Set by tapping a day in MiniCalendarView; tapping the same day again
    /// clears it back to nil. When set, the feed below shows only that
    /// day's items (plus that day's practice, if any) instead of everything.
    @Binding var selectedDate: Date?
    @State private var filter: FeedFilter = .all
    @State private var decliningPracticeId: String?
    @State private var practiceDeclineReason = ""

    private enum FeedFilter: Hashable {
        case all
        case category(CalendarCategory)

        var label: String {
            switch self {
            case .all: return "All"
            case .category(let c): return c.label
            }
        }
    }

    /// Only Captains and board positions (Finance/Production/Logistics/PR) can
    /// create reminders — gated server-side via canCreateReminder in
    /// backend/src/permissions.ts, mirrored here through capabilities.
    private var canCreateReminder: Bool { appState.capabilities?.reminders.canCreate == true }

    /// Any board position (Captain/Finance/Production/Logistics/PR) can
    /// delete any notification — reminder or announcement — mirroring
    /// canDeleteAny in backend/src/permissions.ts. Returners/Newbies can't.
    private var canDeleteAny: Bool { appState.capabilities?.notifications.canDeleteAny == true }

    private var allItems: [NotificationFeedItem] {
        store.items(withAnnouncements: appState.updates)
    }

    private var categoryFilteredItems: [NotificationFeedItem] {
        switch filter {
        case .all: return allItems
        case .category(let c): return allItems.filter { $0.displayCategory == c }
        }
    }

    private var filteredItems: [NotificationFeedItem] {
        guard let selectedDate else { return categoryFilteredItems }
        let calendar = Calendar.current
        return categoryFilteredItems.filter { calendar.isDate($0.sortDate, inSameDayAs: selectedDate) }
    }

    /// The practice (if any) on the selected day — shown as its own card
    /// alongside that day's notifications, reusing Practice's own RSVP
    /// rather than a separate synthesized reminder, so there's only ever one
    /// RSVP count per practice.
    private var selectedDatePractice: PracticeItem? {
        guard let selectedDate else { return nil }
        let calendar = Calendar.current
        return appState.practices.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    /// CalendarEvents (Finance/Production/Captains/Social/Logistics) on the
    /// selected day — these are what actually produce MiniCalendarView's
    /// colored dots, but live in a separate backend model from Reminders, so
    /// without this they'd never appear anywhere once tapped (a dot with
    /// nothing behind it). `.practice`-category events are excluded since
    /// they'd just duplicate the real Practice's own card above. Reminders
    /// stay excluded from calendar dots by design (see backend/prisma/
    /// schema.prisma's Reminder model comment) — this only closes the other
    /// direction, so every dot has something to show when tapped.
    private var selectedDateEvents: [CalendarEventItem] {
        guard let selectedDate else { return [] }
        let calendar = Calendar.current
        return appState.calendarEvents
            .filter { $0.category != .practice && calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    private struct DateGroup: Identifiable {
        let date: Date
        let items: [NotificationFeedItem]
        var id: Date { date }
    }

    /// Grouped by calendar day and sorted soonest-due-first — a date header
    /// only appears for a day that has at least one item in the current
    /// filter, since this groups `filteredItems`, not `allItems`.
    private var dateGroups: [DateGroup] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: filteredItems) { calendar.startOfDay(for: $0.sortDate) }
        return byDay
            .map { DateGroup(date: $0.key, items: $0.value.sorted { $0.sortDate < $1.sortDate }) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 12) {
            if appState.role == .captain, let userId = appState.currentUserId {
                ChoreoReminderWidgetsView(userId: userId)
            }

            filterRow

            if let selectedDate {
                selectedDayBanner(selectedDate)
            }

            if let practice = selectedDatePractice {
                PracticeCardView(
                    practice: practice,
                    role: appState.role,
                    onYes: {
                        Task { await appState.submitRsvp(practiceId: practice.id, response: .yes, reason: nil) }
                    },
                    onNo: {
                        practiceDeclineReason = ""
                        decliningPracticeId = practice.id
                    }
                )
            }

            if !selectedDateEvents.isEmpty {
                VStack(spacing: 8) {
                    ForEach(selectedDateEvents) { event in
                        CalendarEventRowView(event: event)
                    }
                }
            }

            if filteredItems.isEmpty && selectedDatePractice == nil && selectedDateEvents.isEmpty && !store.isLoading {
                EmptyStateView(
                    icon: "bell.fill",
                    title: selectedDate != nil ? "Nothing on this day" : "No notifications",
                    message: selectedDate != nil
                        ? "No notifications or practice scheduled for this day."
                        : (canCreateReminder
                            ? "Tap the + on the calendar to post one for the team."
                            : "Check back later for updates from your captains and board."),
                    actionTitle: nil
                ) {}
            } else if !filteredItems.isEmpty {
                VStack(spacing: 20) {
                    ForEach(dateGroups) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            dateHeader(group.date)
                            VStack(spacing: 12) {
                                ForEach(group.items) { item in
                                    row(for: item)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: Binding(
            get: { decliningPracticeId != nil },
            set: { if !$0 { decliningPracticeId = nil } }
        )) {
            RsvpReasonSheet(reason: $practiceDeclineReason) {
                guard let id = decliningPracticeId else { return }
                Task {
                    await appState.submitRsvp(practiceId: id, response: .no, reason: practiceDeclineReason)
                    decliningPracticeId = nil
                }
            }
        }
    }

    @ViewBuilder
    private func row(for item: NotificationFeedItem) -> some View {
        let card = NotificationCardView(
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

        SwipeToDismissView(
            onDismiss: { store.dismiss(item) },
            canDeleteForAll: canDeleteAny,
            onDeleteAll: {
                switch item {
                case .reminder(let reminder):
                    guard let userId = appState.currentUserId else { return }
                    Task { await store.deleteReminder(id: reminder.id, userId: userId) }
                case .announcement(let update):
                    Task { await appState.deleteUpdate(id: update.id) }
                }
            }
        ) { card }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        await store.load(userId: userId)
    }

    private func dateHeader(_ date: Date) -> some View {
        Text(date.formatted(.dateTime.month(.abbreviated).day()))
            .font(.subheadline.bold())
            .foregroundStyle(.primary)
            .padding(.horizontal, 2)
    }

    /// Shown only while a calendar day is selected — states what's being
    /// filtered and gives a tap target to clear it, mirroring "tap the day
    /// again to deselect" without requiring the user to go find that day.
    private func selectedDayBanner(_ date: Date) -> some View {
        HStack {
            Label(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), systemImage: "calendar")
                .font(.caption.bold())
                .foregroundStyle(Color("AccentColor"))
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { selectedDate = nil }
            } label: {
                Label("Show All", systemImage: "xmark.circle.fill")
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(.all)
                ForEach(CalendarCategory.allCases, id: \.self) { filterChip(.category($0)) }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(_ option: FeedFilter) -> some View {
        Button {
            filter = option
        } label: {
            HStack(spacing: 5) {
                if case .category(let c) = option {
                    Circle().fill(c.color).frame(width: 7, height: 7)
                }
                Text(option.label)
            }
            .font(.caption.bold())
        }
        .buttonStyle(.bordered)
        .tint(filter == option ? Color("AccentColor") : .gray)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
    }
}

/// Read-only info row for a CalendarEvent on the selected day — these have no
/// RSVP/task/dismiss affordance of their own (unlike reminders/announcements),
/// they're just what the calendar dot above was pointing at.
private struct CalendarEventRowView: View {
    let event: CalendarEventItem

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(event.category.color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.label).font(.subheadline.bold())
                Text(event.category.label).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}
