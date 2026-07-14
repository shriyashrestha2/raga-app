import SwiftUI

struct VideoCardView: View {
    let video: VideoItem

    var body: some View {
        Link(destination: URL(string: video.url) ?? URL(string: "https://youtube.com")!) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color("AccentColor").opacity(0.12))
                        Image(systemName: "play.fill")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.caption)
                    }
                    .frame(width: 36, height: 36)

                    Text(video.set)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color("AccentColor"), in: Capsule())

                    if let duration = video.duration {
                        Text(duration)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                    Spacer()
                }
                .padding([.horizontal, .top], 14)
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack {
                        Text(video.date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label(video.uploadedBy.name, systemImage: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}
