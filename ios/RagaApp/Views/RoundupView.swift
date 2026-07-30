import SwiftUI

/// The team's home page: calendar up top, unified notifications feed below —
/// merged into one continuous scroll (no more Calendar/Notifications tab
/// switcher) to match the Figma prototype's single-page layout. Styled with
/// `.preferredColorScheme(.light)` so this page alone reads as the
/// prototype's cream/white look via the app's existing semantic tokens
/// (Color(.secondarySystemGroupedBackground), Color("AccentColor"), etc.)
/// while the rest of the app stays in forced dark mode.
struct RoundupView: View {
    @EnvironmentObject private var appState: AppState
    /// Owned here (not by MiniCalendarView/NotificationsSectionView) so a
    /// swipe-to-clear or RSVP anywhere on the page updates every other place
    /// the same item might render.
    @StateObject private var notificationsStore = NotificationsStore()
    /// Shared between the calendar and the feed: tapping a day in
    /// MiniCalendarView sets this, and NotificationsSectionView filters to
    /// that day. Owned here since both are siblings that need it.
    @State private var selectedDate: Date?
    @State private var showingNewReminder = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                MiniCalendarView(
                    events: appState.calendarEvents,
                    practices: appState.practices,
                    selectedDate: $selectedDate,
                    onAddNotification: { showingNewReminder = true }
                )
                NotificationsSectionView(store: notificationsStore, selectedDate: $selectedDate)
            }
            .padding(16)
        }
        .refreshable { await appState.loadAll() }
        .sheet(isPresented: $showingNewReminder) {
            NewReminderSheet(
                lockedCategory: appState.capabilities?.reminders.lockedCategory,
                previewAuthor: appState.currentUser ?? AppUser(
                    id: "preview", name: "You", initials: "ME", role: appState.role,
                    email: nil, phone: nil, year: nil, major: nil, bio: nil,
                    emergencyContactName: nil, emergencyContactPhone: nil
                )
            ) { title, description, date, type, category in
                guard let userId = appState.currentUserId else { return }
                Task { await notificationsStore.createReminder(title: title, description: description, date: date, type: type, category: category, userId: userId) }
            }
        }
        .preferredColorScheme(.light)
    }
}
