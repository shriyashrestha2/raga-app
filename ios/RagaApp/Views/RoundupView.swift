import SwiftUI

enum RoundupTab: String, CaseIterable, Identifiable {
    case calendar, reminders
    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        }
    }
}

struct RoundupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tab: RoundupTab = .calendar

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
                    }
                }
                .padding(16)
            }
            .refreshable { await appState.loadAll() }
        }
    }
}
