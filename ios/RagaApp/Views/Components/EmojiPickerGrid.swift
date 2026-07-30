import SwiftUI

/// Curated emoji set shared by the Chat composer (inserting into the
/// message draft) and the reaction picker (reacting to a message) — a
/// full Unicode emoji browser is overkill here since iOS's own emoji
/// keyboard is always one tap away via the globe key for anything not in
/// this list.
enum ChatEmoji {
    static let quickReactions = ["👍", "❤️", "😂", "😮", "😢", "🙏", "🔥", "🎉"]
    static let picker = [
        "😀", "😂", "😍", "🥲", "😅", "😎", "🤔", "😭",
        "😡", "👍", "👎", "🙏", "🎉", "🔥", "💯", "❤️",
        "💀", "👀", "✨", "🙌", "😴", "🤝", "👏", "😬",
    ]
}

/// A simple tappable grid of emoji, used both for the composer's "insert an
/// emoji" popover and the per-message reaction picker.
struct EmojiPickerGrid: View {
    let emojis: [String]
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(emojis, id: \.self) { emoji in
                Button {
                    onSelect(emoji)
                } label: {
                    Text(emoji).font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }
}
