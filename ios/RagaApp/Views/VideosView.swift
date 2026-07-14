import SwiftUI

struct VideosView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.videoSets, id: \.self) { set in
                        Button {
                            appState.activeVideoSet = set
                            Task { await appState.loadVideos() }
                        } label: {
                            HStack(spacing: 4) {
                                if set == "All" {
                                    Image(systemName: "folder.fill")
                                }
                                Text(set)
                            }
                            .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(appState.activeVideoSet == set ? Color("AccentColor") : .gray)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(appState.videos) { video in
                        VideoCardView(video: video)
                    }
                }
                .padding(16)
            }
            .refreshable { await appState.loadVideos() }
        }
    }
}
