import SwiftUI

/// One card style for every item in the Notifications feed — announcement,
/// task, or RSVP reminder — matching the Figma prototype's NotificationCard.
/// `compact` drives the condensed variant used in the Calendar tab's
/// "Coming Up" widget (no body text, icon-only RSVP buttons).
struct NotificationCardView: View {
    let item: NotificationFeedItem
    var compact: Bool = false
    var canDelete: Bool = false
    var isEditing: Bool = false
    var onRsvp: ((RsvpResponse) -> Void)? = nil
    var onToggleDone: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var showDeleteConfirm = false

    private var category: CalendarCategory { item.displayCategory }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(category.color).frame(width: 4)

            HStack(alignment: .center, spacing: 12) {
                if isEditing && canDelete {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                avatar

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if item.pinned {
                            Text("PINNED")
                                .font(.caption2.bold())
                                .foregroundStyle(Color("AccentColor"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color("AccentColor").opacity(0.12), in: Capsule())
                        }
                        Text(item.typeLabel.uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(category.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(category.color.opacity(0.12), in: Capsule())
                    }

                    Text(item.title)
                        .font(.subheadline.bold())
                        .lineLimit(2)

                    if !compact, let bodyText = item.bodyText, !bodyText.isEmpty {
                        Text(bodyText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 6) {
                        Text("from \(item.authorName)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("·").foregroundStyle(.tertiary)
                        Text(item.dateLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 8)

                action
            }
            .padding(14)
            .animation(.default, value: isEditing)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
        .confirmationDialog("Delete this reminder?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var avatar: some View {
        Text(item.authorInitials)
            .font(.caption.bold())
            .foregroundStyle(category.color)
            .frame(width: 36, height: 36)
            .background(category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var action: some View {
        switch item {
        case .reminder(let reminder):
            switch reminder.type {
            case .task:
                Button(action: { onToggleDone?() }) {
                    ZStack {
                        Circle()
                            .strokeBorder(reminder.doneByMe ? Color("AccentColor") : Color(.separator), lineWidth: 2)
                            .background(Circle().fill(reminder.doneByMe ? Color("AccentColor") : Color.clear))
                        if reminder.doneByMe {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
            case .rsvp:
                if compact {
                    HStack(spacing: 6) {
                        rsvpIconButton(systemImage: "checkmark", isActive: reminder.myRsvp == .yes, activeColor: .green) { onRsvp?(.yes) }
                        rsvpIconButton(systemImage: "xmark", isActive: reminder.myRsvp == .no, activeColor: Color("AccentColor")) { onRsvp?(.no) }
                    }
                } else {
                    HStack(spacing: 8) {
                        Button { onRsvp?(.yes) } label: { Label("Yes", systemImage: "checkmark") }
                            .tint(reminder.myRsvp == .yes ? .green : .gray)
                        Button { onRsvp?(.no) } label: { Label("No", systemImage: "xmark") }
                            .tint(reminder.myRsvp == .no ? Color("AccentColor") : .gray)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        case .announcement:
            EmptyView()
        }
    }

    private func rsvpIconButton(systemImage: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.bold())
                .foregroundStyle(isActive ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background(isActive ? activeColor : Color(.tertiarySystemFill), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
