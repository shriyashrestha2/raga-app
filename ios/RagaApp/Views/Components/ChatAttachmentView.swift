import SwiftUI

/// Renders one attachment on a sent chat message — an image thumbnail
/// (tap for a full-screen viewer) or a file chip (tap opens it externally).
struct ChatAttachmentView: View {
    let attachment: ChatAttachmentItem

    @State private var showFullScreenImage = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch attachment.kind {
        case .image:
            imageThumbnail
        case .file:
            fileChip
        }
    }

    private var imageThumbnail: some View {
        Button {
            showFullScreenImage = true
        } label: {
            AsyncImage(url: attachment.resolvedURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder(icon: "photo")
                default:
                    placeholder(icon: nil)
                }
            }
            .frame(width: 180, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showFullScreenImage) {
            ChatImageViewerView(url: attachment.resolvedURL)
        }
    }

    private func placeholder(icon: String?) -> some View {
        ZStack {
            Color(.tertiarySystemFill)
            if let icon {
                Image(systemName: icon).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }

    private var fileChip: some View {
        Button {
            if let url = attachment.resolvedURL { openURL(url) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(Color("AccentColor"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.fileName)
                        .font(.caption.bold())
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(attachment.formattedFileSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Full-screen tap-to-dismiss image preview, matching VideoCardView's
/// in-app playback pattern for videos.
private struct ChatImageViewerView: View {
    let url: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let url {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
            .padding()
        }
    }
}
