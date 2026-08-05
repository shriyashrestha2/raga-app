import SwiftUI

struct PracticeCardView: View {
    let practice: PracticeItem
    let role: Role
    let onYes: () -> Void
    let onNo: () -> Void

    private var total: Int {
        let responded = practice.rsvpYes + practice.rsvpNo
        return responded
    }

    private var yesFraction: Double {
        guard total > 0 else { return 0 }
        return Double(practice.rsvpYes) / Double(total)
    }

    /// The server only includes the per-dancer breakdown when the current
    /// role is allowed to see it for this specific session (Captain always,
    /// Production only on PROPS_DAY) — so its presence alone tells us
    /// whether to show the manager view or the plain RSVP buttons, without
    /// duplicating that role/kind logic client-side.
    private var isManagerView: Bool { practice.detail != nil }

    private var dateBadgeColor: Color {
        practice.kind == .propsDay ? .purple : Color("AccentColor")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(practice.date, format: .dateTime.month(.abbreviated))
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.75))
                        .textCase(.uppercase)
                    Text(practice.date, format: .dateTime.day())
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(practice.date, format: .dateTime.weekday(.abbreviated))
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(width: 64)
                .frame(maxHeight: .infinity)
                .background(dateBadgeColor)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(practice.focus)
                            .font(.subheadline.bold())
                        if practice.kind == .propsDay {
                            Label("PROPS DAY", systemImage: practice.kind.symbol)
                                .font(.caption2.bold())
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.12), in: Capsule())
                        }
                    }
                    Label(practice.date.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(practice.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let reminder = practice.reminder {
                        Label(reminder, systemImage: "tag.fill")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(14)
                Spacer(minLength: 0)
            }

            Divider()

            Group {
                if isManagerView {
                    managerSummary
                } else {
                    returnerActions
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }

    private var managerSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("RSVP Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(practice.rsvpYes) yes").font(.caption.bold()).foregroundStyle(.green)
                    Text("\(practice.rsvpNo) no").font(.caption.bold()).foregroundStyle(Color("AccentColor"))
                }
                ProgressView(value: yesFraction)
                    .tint(.green)
            }

            if let detail = practice.detail, !detail.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(detail) { entry in
                        HStack(spacing: 6) {
                            Image(systemName: entry.response == .yes ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(entry.response == .yes ? .green : Color("AccentColor"))
                            Text(entry.name)
                                .font(.caption.bold())
                            if let reason = entry.reason, !reason.isEmpty {
                                Text("· \(reason)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private var returnerActions: some View {
        HStack {
            Text(total > 0 ? "\(practice.rsvpYes) going · \(practice.rsvpNo) not" : "No responses yet")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 8) {
                Button(action: onYes) {
                    Label("Yes", systemImage: "checkmark")
                }
                .buttonStyle(.bordered)
                .tint(practice.myRsvp?.response == .yes ? .green : .gray)

                Button(action: onNo) {
                    Label("No", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .tint(practice.myRsvp?.response == .no ? Color("AccentColor") : .gray)
            }
            .controlSize(.small)
        }
    }
}
