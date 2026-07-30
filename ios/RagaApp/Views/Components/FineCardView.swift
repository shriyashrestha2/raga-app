import SwiftUI

struct FineCardView: View {
    let fine: FineItem
    let canManage: Bool
    var onSetStatus: (FineStatus) -> Void = { _ in }
    var onDelete: () -> Void = {}

    private var amountText: String {
        let dollars = Double(fine.amountCents) / 100.0
        return dollars.formatted(.currency(code: "USD"))
    }

    // dueDate is stored as a UTC-midnight, date-only value (see backend's
    // Fine.dueDate) — format in UTC so it doesn't shift a day earlier here
    // for anyone west of UTC, matching the fix already applied server-side
    // to the same value in fines.ts/scheduler.ts.
    private var dueDateText: String? {
        guard let dueDate = fine.dueDate, fine.status == .unpaid else { return nil }
        let style = Date.FormatStyle(timeZone: TimeZone(identifier: "UTC")!).month(.abbreviated).day().year()
        return "Due \(dueDate.formatted(style))"
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(fine.status.color)
                .frame(width: 4)

            HStack(alignment: .top, spacing: 12) {
                Text(fine.user.initials)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(fine.user.name)
                            .font(.subheadline.bold())
                        Spacer()
                        Text(amountText)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color("AccentColor"))
                    }

                    Text(fine.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        statusBadge
                        Text("· issued by \(fine.issuedBy.name)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(fine.issuedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let dueDateText {
                        Text(dueDateText)
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                }

                if canManage {
                    VStack(spacing: 10) {
                        Menu {
                            ForEach(FineStatus.allCases, id: \.self) { status in
                                Button {
                                    onSetStatus(status)
                                } label: {
                                    Label(status.label, systemImage: status == fine.status ? "checkmark" : "")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.body)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }

    private var statusBadge: some View {
        Text(fine.status.label.uppercased())
            .font(.caption2.bold())
            .foregroundStyle(fine.status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(fine.status.color.opacity(0.14), in: Capsule())
    }
}
