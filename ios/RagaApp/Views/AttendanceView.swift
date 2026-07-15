import SwiftUI

/// Real attendance/check-in for a calendar event, distinct from the
/// Practice tab's RSVP-intent. Captain edits any event; Production edits
/// only Production-tagged events; everyone else is view-only (per
/// backend/src/permissions.ts's canEditAttendance).
struct AttendanceView: View {
    @EnvironmentObject private var appState: AppState
    let event: CalendarEventItem

    @State private var canEdit = false
    @State private var records: [AttendanceRecord] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if !canEdit {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                        Text("View only for your role")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(appState.users) { user in
                    AttendanceRowView(
                        user: user,
                        status: records.first(where: { $0.userId == user.id })?.status,
                        canEdit: canEdit,
                        onSetStatus: { status in
                            Task { await mark(user: user, status: status) }
                        }
                    )
                }
            }
            .padding(16)
        }
        .navigationTitle(event.label)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let userId = appState.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        if let result = try? await APIClient.shared.fetchAttendance(eventId: event.id, userId: userId) {
            canEdit = result.canEdit
            records = result.records
        }
    }

    private func mark(user: AppUser, status: AttendanceStatus) async {
        guard let userId = appState.currentUserId else { return }
        _ = try? await APIClient.shared.markAttendance(eventId: event.id, targetUserId: user.id, status: status, notes: nil, userId: userId)
        await load()
    }
}

private struct AttendanceRowView: View {
    let user: AppUser
    let status: AttendanceStatus?
    let canEdit: Bool
    let onSetStatus: (AttendanceStatus) -> Void

    private var statusColor: Color {
        switch status {
        case .present: return .green
        case .late: return .orange
        case .excused: return .blue
        case .absent: return Color("AccentColor")
        case nil: return .secondary
        }
    }

    var body: some View {
        HStack {
            Text(user.initials)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(user.name).font(.subheadline.bold())
                Text(user.role.label).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()

            if canEdit {
                Menu {
                    ForEach(AttendanceStatus.allCases, id: \.self) { s in
                        Button(s.label) { onSetStatus(s) }
                    }
                } label: {
                    statusBadge
                }
            } else {
                statusBadge
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }

    private var statusBadge: some View {
        Text(status?.label ?? "Not marked")
            .font(.caption2.bold())
            .foregroundStyle(status == nil ? Color.secondary : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status == nil ? Color(.tertiarySystemFill) : statusColor, in: Capsule())
    }
}
