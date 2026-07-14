import SwiftUI

struct RoundupView: View {
    @EnvironmentObject private var appState: AppState

    private var pinned: [UpdateItem] { appState.updates.filter(\.pinned) }
    private var recent: [UpdateItem] { appState.updates.filter { !$0.pinned }.prefix(3).map { $0 } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(pinned) { UpdateCardView(update: $0) }
                ForEach(recent) { UpdateCardView(update: $0) }

                HStack {
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                    Text("TEAM CALENDAR")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                }
                .padding(.top, 4)

                MiniCalendarView(events: appState.calendarEvents)
            }
            .padding(16)
        }
        .refreshable { await appState.loadAll() }
    }
}
