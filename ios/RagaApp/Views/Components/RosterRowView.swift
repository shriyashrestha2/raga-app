import SwiftUI

/// A single roster entry: initials avatar chip, name, role badge, and
/// year/major if present. Matches the card language used elsewhere
/// (UpdateCardView, AttendanceView's row) — secondarySystemGroupedBackground
/// background, 16pt continuous corner radius, hairline separator stroke.
/// `canEdit` only controls the trailing chevron tap affordance; the actual
/// navigation/gating lives in the parent (TeamRosterView), which is the one
/// place that knows about `capabilities.teamInfo.canEdit`.
struct RosterRowView: View {
    let member: AppUser
    let canEdit: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(member.initials)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.subheadline.bold())

                HStack(spacing: 6) {
                    Label(member.role.label, systemImage: member.role.symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(Color("AccentColor"))
                        .labelStyle(.titleAndIcon)

                    if let detail = subtitleDetail {
                        Text("·  \(detail)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            if canEdit {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
        .contentShape(Rectangle())
    }

    private var subtitleDetail: String? {
        let parts = [member.year, member.major].compactMap { $0 }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }
}
