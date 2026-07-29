import SwiftUI
import AVKit

struct VideoCardView: View {
    let video: VideoItem

    @State private var isPlaying = false

    var body: some View {
        Button {
            isPlaying = true
        } label: {
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
                    if video.pinned, let pinLabel = video.pinLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                            Text(pinLabel.uppercased())
                        }
                        .font(.caption2.bold())
                        .foregroundStyle(Color("AccentColor"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color("AccentColor").opacity(0.12), in: Capsule())
                    }

                    Text(video.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack {
                        Text(video.date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label(video.uploadedBy.name, systemImage: "play.circle")
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
        .fullScreenCover(isPresented: $isPlaying) {
            if let url = video.resolvedURL {
                VideoPlayerView(url: url)
            }
        }
    }
}

/// Plays a video fully in-app (AVKit), no external browser/YouTube handoff.
private struct VideoPlayerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: player)
                .ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
            .padding()
        }
        .onAppear {
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
