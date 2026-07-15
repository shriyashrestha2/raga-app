import SwiftUI

struct CompApplicationCardView: View {
    let application: CompApplicationItem

    /// Deadline pressure is only meaningful while an application is still
    /// actionable — once submitted/accepted/rejected the deadline is history.
    private var isActionable: Bool {
        application.status == .notStarted || application.status == .inProgress
    }

    private var isPastDue: Bool {
        isActionable && application.deadline < Date()
    }

    private var isUrgent: Bool {
        guard isActionable, !isPastDue else { return false }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: application.deadline).day ?? 999
        return days <= 3
    }

    private var deadlineColor: Color {
        if isPastDue { return .red }
        if isUrgent { return .orange }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.competitionName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Label(
                        application.deadline.formatted(date: .abbreviated, time: .omitted),
                        systemImage: isPastDue ? "exclamationmark.triangle.fill" : "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(deadlineColor)
                }
                Spacer(minLength: 8)
                statusBadge
            }

            if let notes = application.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if let assignedTo = application.assignedTo {
                    Text(assignedTo.initials)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color(.tertiarySystemFill), in: Circle())
                    Text(assignedTo.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Unassigned", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isPastDue ? Color.red.opacity(0.4) : Color(.separator), lineWidth: isPastDue ? 1.5 : 0.5)
        )
    }

    private var statusBadge: some View {
        Text(application.status.label)
            .font(.caption2.bold())
            .foregroundStyle(application.status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(application.status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
