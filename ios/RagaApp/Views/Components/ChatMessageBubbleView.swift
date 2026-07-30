import SwiftUI

/// One message row in the Chat tab. Every board role (Captain, Finance,
/// Production, Logistics, PR — see Role.isBoardRole) shows a small role
/// badge next to their name so it's clear who's speaking in what capacity;
/// Returners/Newbies just show their name.
struct ChatMessageBubbleView: View {
    let message: ChatMessageItem
    let isMe: Bool
    let canPin: Bool
    let onReact: (String) -> Void
    let onTogglePin: () -> Void

    @State private var showReactionPicker = false

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 40) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if !isMe {
                    HStack(spacing: 6) {
                        Text(message.author.name)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        if message.author.role.isBoardRole {
                            roleBadge
                        }
                    }
                }

                if message.pinned {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(Color("AccentColor"))
                }

                VStack(alignment: isMe ? .trailing : .leading, spacing: 6) {
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.body)
                            .foregroundStyle(isMe ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                isMe ? Color("AccentColor") : Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                    }
                    ForEach(message.attachments) { attachment in
                        ChatAttachmentView(attachment: attachment)
                    }
                }
                .contextMenu {
                    ForEach(ChatEmoji.quickReactions, id: \.self) { emoji in
                        Button(emoji) { onReact(emoji) }
                    }
                    if canPin {
                        Divider()
                        Button {
                            onTogglePin()
                        } label: {
                            Label(message.pinned ? "Unpin" : "Pin", systemImage: message.pinned ? "pin.slash" : "pin")
                        }
                    }
                }

                reactionsRow

                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !isMe { Spacer(minLength: 40) }
        }
    }

    private var roleBadge: some View {
        Text(message.author.role.label)
            .font(.caption2.bold())
            .foregroundStyle(Color("AccentColor"))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color("AccentColor").opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var reactionsRow: some View {
        if !message.reactions.isEmpty {
            HStack(spacing: 6) {
                ForEach(message.reactions) { reaction in
                    Button {
                        onReact(reaction.emoji)
                    } label: {
                        HStack(spacing: 4) {
                            Text(reaction.emoji).font(.caption)
                            Text("\(reaction.count)").font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            reaction.reactedByMe ? Color("AccentColor").opacity(0.18) : Color(.tertiarySystemFill),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                reaction.reactedByMe ? Color("AccentColor") : Color.clear, lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }

                addReactionButton
            }
        } else {
            HStack {
                addReactionButton
            }
        }
    }

    private var addReactionButton: some View {
        Button {
            showReactionPicker = true
        } label: {
            Image(systemName: "face.smiling")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(6)
                .background(Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showReactionPicker) {
            EmojiPickerGrid(emojis: ChatEmoji.quickReactions) { emoji in
                onReact(emoji)
                showReactionPicker = false
            }
            .presentationCompactAdaptation(.popover)
        }
    }
}
