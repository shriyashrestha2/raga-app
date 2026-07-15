import SwiftUI

/// Card for a single prop/costume item. Shows the full assigned-members list
/// when `item.assignments` carries more than the viewer's own record (FULL
/// mode); in OWN_ASSIGNMENTS_ONLY mode the server has already filtered
/// `assignments` down to just the caller's row, so this same view doubles as
/// a "my task" card without any client-side filtering logic.
struct PropCostumeCardView: View {
    let item: PropCostumeItemModel
    var showAssignedMembers: Bool = true

    private var statusColor: Color {
        switch item.status {
        case .notStarted: return .secondary
        case .inProgress: return .orange
        case .ready: return .green
        case .rented: return .blue
        }
    }

    private var rentalCostText: String? {
        guard let cents = item.rentalCostCents else { return nil }
        return (Double(cents) / 100).formatted(.currency(code: "USD"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.category.icon)
                    .font(.subheadline)
                    .foregroundStyle(Color("AccentColor"))
                    .frame(width: 32, height: 32)
                    .background(Color("AccentColor").opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.subheadline.bold())
                    Text(item.category.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(item.status.label)
                    .font(.caption2.bold())
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if item.rentalVendor != nil || rentalCostText != nil || item.rentalDueDate != nil {
                Divider()
                VStack(alignment: .leading, spacing: 3) {
                    if let vendor = item.rentalVendor {
                        Label(vendor, systemImage: "building.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        if let rentalCostText {
                            Label(rentalCostText, systemImage: "dollarsign.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let due = item.rentalDueDate {
                            Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if showAssignedMembers && !item.assignments.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Assigned")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                    ForEach(item.assignments) { assignment in
                        AssignmentRow(assignment: assignment)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}

private struct AssignmentRow: View {
    let assignment: PropCostumeAssignmentModel

    private var detailText: String {
        [assignment.task, assignment.size.map { "Size \($0)" }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(assignment.user?.initials ?? "?")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Color(.tertiarySystemFill), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(assignment.user?.name ?? "Unknown")
                    .font(.caption.bold())
                if !detailText.isEmpty {
                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Text(assignment.status.capitalized)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
