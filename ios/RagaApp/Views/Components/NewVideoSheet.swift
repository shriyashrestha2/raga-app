import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Sheet for uploading a video, styled after NewUpdateSheet/NewReminderSheet.
/// The video itself is picked from the photo library (PhotosPicker) and
/// uploaded as a real file — there's no "paste a link" path, since videos are
/// meant to play back entirely in-app rather than linking out to YouTube.
struct NewVideoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let videoSets: [String]
    let onCreate: (
        _ title: String,
        _ set: String,
        _ competition: String?,
        _ duration: String?,
        _ pinned: Bool,
        _ pinLabel: String?,
        _ fileData: Data,
        _ fileName: String,
        _ mimeType: String
    ) -> Void

    @State private var title: String = ""
    @State private var set: String = ""
    @State private var competition: String = ""
    @State private var duration: String = ""
    @State private var pinned = false
    @State private var pinLabel: String = ""

    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedVideoURL: URL?
    @State private var isLoadingVideo = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !set.isEmpty
            && pickedVideoURL != nil
            && (!pinned || !pinLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Video") {
                    PhotosPicker(selection: $pickerItem, matching: .videos) {
                        HStack {
                            Image(systemName: pickedVideoURL == nil ? "video.badge.plus" : "checkmark.circle.fill")
                                .foregroundStyle(pickedVideoURL == nil ? Color("AccentColor") : .green)
                            Text(pickedVideoURL == nil ? "Choose Video" : (pickedVideoURL?.lastPathComponent ?? "Video selected"))
                                .foregroundStyle(pickedVideoURL == nil ? Color("AccentColor") : .primary)
                            Spacer()
                            if isLoadingVideo {
                                ProgressView()
                            }
                        }
                    }
                    .onChange(of: pickerItem) { _, newItem in
                        guard let newItem else { return }
                        isLoadingVideo = true
                        pickedVideoURL = nil
                        Task {
                            let payload = try? await newItem.loadTransferable(type: VideoFilePayload.self)
                            pickedVideoURL = payload?.url
                            isLoadingVideo = false
                        }
                    }

                    TextField("Title", text: $title)
                    Picker("Set", selection: $set) {
                        Text("Select a set").tag("")
                        ForEach(videoSets, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    TextField("Competition (optional)", text: $competition)
                    TextField("Duration, e.g. 4:22 (optional)", text: $duration)
                }

                Section("Pin") {
                    Toggle("Pin this video", isOn: $pinned)
                    if pinned {
                        TextField("Pin label, e.g. \"Competition Take\"", text: $pinLabel)
                    }
                }
            }
            .navigationTitle("New Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload") {
                        guard let pickedVideoURL, let fileData = try? Data(contentsOf: pickedVideoURL) else { return }
                        onCreate(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            set,
                            competition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : competition,
                            duration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : duration,
                            pinned,
                            pinned ? pinLabel.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                            fileData,
                            pickedVideoURL.lastPathComponent,
                            mimeType(for: pickedVideoURL)
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mov": return "video/quicktime"
        case "mp4": return "video/mp4"
        case "m4v": return "video/x-m4v"
        default: return "video/mp4"
        }
    }
}

/// Copies a picked PhotosPickerItem's video into a temp file so it can be
/// read back out as Data + a real filename/extension for the upload request.
private struct VideoFilePayload: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { payload in
            SentTransferredFile(payload.url)
        } importing: { received in
            let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}
