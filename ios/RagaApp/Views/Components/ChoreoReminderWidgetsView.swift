import SwiftUI

/// Captain-dashboard-only widgets — never a standalone page, never fetched or
/// rendered for any other role. Rendered inline at the top of RoundupView
/// (the app's default/landing tab), which is the closest existing analog to
/// a "Captain home" without inventing a new page.
struct ChoreoReminderWidgetsView: View {
    @State private var reminders: [ChoreoReminderItem] = []
    @State private var isLoading = false
    let userId: String

    private var open: [ChoreoReminderItem] { reminders.filter { !$0.resolved } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(Color("AccentColor"))
                Text("Captain Notes")
                    .font(.caption.bold())
                    .foregroundStyle(Color("AccentColor"))
                    .textCase(.uppercase)
                Spacer()
            }

            if open.isEmpty && !isLoading {
                Text("No formation or choreo reminders pending.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(open) { reminder in
                    Button {
                        Task { await toggleResolved(reminder) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: reminder.kind.icon)
                                .foregroundStyle(Color("AccentColor"))
                                .frame(width: 20)
                            Text(reminder.label)
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color("AccentColor").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color("AccentColor").opacity(0.15)))
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        reminders = (try? await APIClient.shared.fetchChoreoReminders(userId: userId)) ?? []
    }

    private func toggleResolved(_ reminder: ChoreoReminderItem) async {
        _ = try? await APIClient.shared.setChoreoReminderResolved(id: reminder.id, resolved: true, userId: userId)
        await load()
    }
}
