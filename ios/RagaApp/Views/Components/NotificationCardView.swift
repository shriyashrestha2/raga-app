import SwiftUI

/// One card style for every item in the Notifications feed — announcement,
/// task, or RSVP reminder — matching the Figma prototype's NotificationCard.
/// `compact` drives the condensed variant (no body text, icon-only RSVP
/// buttons) used in the sheet preview and elsewhere. Deletion now happens via
/// a swipe gesture (see SwipeToDismissView), not an inline edit-mode button.
struct NotificationCardView: View {
    let item: NotificationFeedItem
    var compact: Bool = false
    var onRsvp: ((RsvpResponse) -> Void)? = nil
    var onToggleDone: (() -> Void)? = nil

    private var category: CalendarCategory { item.displayCategory }

    /// A task-type reminder the current user has checked off — grayed out
    /// (rather than removed from the feed) so it's still visible as
    /// completed, distinct from swipe-to-dismiss which actually hides it.
    private var isCompletedTask: Bool {
        if case .reminder(let r) = item, r.type == .task { return r.doneByMe }
        return false
    }

    /// Accent color for the stripe/avatar/type pill — muted to gray once a
    /// task is completed instead of the category color, so a done item reads
    /// as "checked off" at a glance rather than competing with still-open ones.
    private var accent: Color { isCompletedTask ? .secondary : category.color }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(accent).frame(width: 4)

            HStack(alignment: .center, spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if item.isAnnouncement {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                                .foregroundStyle(accent)
                        }
                        Text(isCompletedTask ? "DONE" : item.typeLabel.uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.12), in: Capsule())
                    }

                    Text(item.title)
                        .font(.subheadline.bold())
                        .strikethrough(isCompletedTask)
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
        }
        // Opacity dims only this content layer, applied before .background()
        // so the card's own background stays fully opaque — otherwise it
        // would let whatever sits behind it in the feed (SwipeToDismissView's
        // green "Clear" reveal) show through a translucent card.
        .opacity(isCompletedTask ? 0.55 : 1)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    private var avatar: some View {
        Text(item.authorInitials)
            .font(.caption.bold())
            .foregroundStyle(accent)
            .frame(width: 36, height: 36)
            .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
