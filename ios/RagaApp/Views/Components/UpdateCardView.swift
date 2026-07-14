import SwiftUI

struct UpdateCardView: View {
    let update: UpdateItem

    private var tagColor: Color {
        switch update.tag {
        case .announcement: return Color("AccentColor")
        case .costumeLogistics: return .purple
        case .choreoNotes: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(update.pinned ? Color("AccentColor") : tagColor)
                .frame(width: 4)

            HStack(alignment: .top, spacing: 12) {
                Text(update.author.initials)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    if update.pinned {
                        Label("PINNED", systemImage: "bell.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(Color("AccentColor"))
                            .labelStyle(.titleAndIcon)
                    }
                    Text("from \(update.author.name)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(update.tag.label)
                        .font(.subheadline.bold())
                    Text(update.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(update.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Image(systemName: "bell")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(update.pinned ? Color("AccentColor").opacity(0.3) : Color(.separator), lineWidth: update.pinned ? 2 : 0.5)
        )
    }
}
