import SwiftUI

struct VideosView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingNewVideo = false

    private var canUpload: Bool { appState.capabilities?.videos.canUpload == true }

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

                    if canUpload {
                        Button {
                            showingNewVideo = true
                        } label: {
                            Label("Upload", systemImage: "plus.circle.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(Color("AccentColor"))
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
        .sheet(isPresented: $showingNewVideo) {
            NewVideoSheet(videoSets: appState.videoSets.filter { $0 != "All" }) { title, set, competition, duration, pinned, pinLabel, fileData, fileName, mimeType in
                Task {
                    await appState.createVideo(
                        title: title,
                        set: set,
                        competition: competition,
                        duration: duration,
                        pinned: pinned,
                        pinLabel: pinLabel,
                        fileData: fileData,
                        fileName: fileName,
                        mimeType: mimeType
                    )
                }
            }
        }
    }
}
