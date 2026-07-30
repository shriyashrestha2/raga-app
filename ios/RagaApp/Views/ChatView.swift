import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Chat tab: one flat, team-wide channel. There's no push/websocket infra in
/// this app, so "live" is a short polling loop instead — cheap and simple
/// enough for a team of this size (see team-app-prd.md's Chat spec), and it
/// naturally starts/stops with the view via `.task(id:)`.
struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @State private var draft = ""
    @State private var pendingAttachments: [ChatOutgoingAttachment] = []
    @State private var showEmojiPicker = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var showPinnedSheet = false
    @State private var showAIAssistant = false
    @State private var scrollTarget: String?
    @FocusState private var composerFocused: Bool
    /// Mirrors `composerFocused` up to RootView so it can hide the bottom
    /// tab bar while typing, rather than letting the keyboard push it
    /// around.
    @Binding var isComposerFocused: Bool

    private let pollInterval: Duration = .seconds(4)
    private let maxAttachments = 5

    var body: some View {
        VStack(spacing: 0) {
            pinnedBanner
            messageList
            composer
        }
        .background(Color("AppBackground"))
        .onChange(of: composerFocused) { _, isFocused in
            isComposerFocused = isFocused
        }
        .task(id: appState.currentUserId) {
            guard let userId = appState.currentUserId else { return }
            await viewModel.load(userId: userId)
            while !Task.isCancelled {
                try? await Task.sleep(for: pollInterval)
                if Task.isCancelled { break }
                await viewModel.refreshQuietly(userId: userId)
            }
        }
        .onChange(of: photoPickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let attachment = await loadAttachment(from: item) {
                        pendingAttachments.append(attachment)
                    }
                }
                photoPickerItems = []
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItems, maxSelectionCount: maxAttachments, matching: .images)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            handleFileImporter(result)
        }
        .sheet(isPresented: $showPinnedSheet) {
            PinnedMessagesSheet(messages: viewModel.pinnedMessages) { message in
                showPinnedSheet = false
                scrollTarget = message.id
            }
        }
        .sheet(isPresented: $showAIAssistant) {
            AIAssistantSheet { message in
                draft = message
                composerFocused = true
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var pinnedBanner: some View {
        if !viewModel.pinnedMessages.isEmpty {
            Button {
                showPinnedSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                    Text(viewModel.pinnedMessages.count == 1 ? "1 pinned message" : "\(viewModel.pinnedMessages.count) pinned messages")
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(Color("AccentColor"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color("AccentColor").opacity(0.1))
            }
            .buttonStyle(.plain)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        EmptyStateView(
                            icon: "bubble.left.and.bubble.right",
                            title: "No messages yet",
                            message: "Say hello to the team."
                        )
                        .padding(.top, 40)
                    }
                    ForEach(viewModel.messages) { message in
                        ChatMessageBubbleView(
                            message: message,
                            isMe: message.author.id == appState.currentUserId,
                            canPin: appState.capabilities?.chat.canPinAny == true,
                            onReact: { emoji in
                                Task {
                                    guard let userId = appState.currentUserId else { return }
                                    await viewModel.react(messageId: message.id, emoji: emoji, userId: userId)
                                }
                            },
                            onTogglePin: {
                                Task {
                                    guard let userId = appState.currentUserId else { return }
                                    await viewModel.setPinned(messageId: message.id, pinned: !message.pinned, userId: userId)
                                }
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation { proxy.scrollTo(target, anchor: .center) }
                scrollTarget = nil
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastId = viewModel.messages.last?.id else { return }
        if animated {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if !pendingAttachments.isEmpty {
                pendingAttachmentsStrip
            }

            HStack(spacing: 10) {
                Menu {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Photo", systemImage: "photo")
                    }
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("File", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .disabled(pendingAttachments.count >= maxAttachments)

                if appState.capabilities?.aiAssistant.canAccess == true {
                    Button {
                        showAIAssistant = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showEmojiPicker = true
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .popover(isPresented: $showEmojiPicker) {
                    EmojiPickerGrid(emojis: ChatEmoji.picker) { emoji in
                        draft += emoji
                    }
                    .frame(width: 280)
                    .presentationCompactAdaptation(.popover)
                }

                TextField("Message the team...", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? Color("AccentColor") : .secondary)
                }
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color(.secondarySystemGroupedBackground)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                }
        )
    }

    private var pendingAttachmentsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pendingAttachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if let image = attachment.previewImage {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                VStack(spacing: 2) {
                                    Image(systemName: "doc.fill")
                                    Text(attachment.fileName)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .padding(4)
                            }
                        }
                        .frame(width: 64, height: 64)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button {
                            pendingAttachments.removeAll { $0.id == attachment.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
        }
        .frame(height: 64)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty
    }

    private func loadAttachment(from item: PhotosPickerItem) async -> ChatOutgoingAttachment? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        let utType = item.supportedContentTypes.first
        let mimeType = utType?.preferredMIMEType ?? "image/jpeg"
        let ext = utType?.preferredFilenameExtension ?? "jpg"
        return ChatOutgoingAttachment(
            fileName: "photo-\(Int(Date().timeIntervalSince1970)).\(ext)",
            mimeType: mimeType,
            data: data,
            previewImage: UIImage(data: data)
        )
    }

    private func handleFileImporter(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }
            let utType = UTType(filenameExtension: url.pathExtension)
            let mimeType = utType?.preferredMIMEType ?? "application/octet-stream"
            pendingAttachments.append(
                ChatOutgoingAttachment(fileName: url.lastPathComponent, mimeType: mimeType, data: data, previewImage: nil)
            )
        }
    }

    private func send() {
        guard let userId = appState.currentUserId else { return }
        let content = draft
        let attachments = pendingAttachments
        draft = ""
        pendingAttachments = []
        Task {
            await viewModel.send(content: content, attachments: attachments, userId: userId)
        }
    }
}

/// Read-only list of pinned messages — tapping one scrolls the main chat to
/// it and dismisses the sheet.
private struct PinnedMessagesSheet: View {
    let messages: [ChatMessageItem]
    let onSelect: (ChatMessageItem) -> Void

    var body: some View {
        NavigationStack {
            List(messages) { message in
                Button {
                    onSelect(message)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(message.author.name).font(.subheadline.bold())
                            if message.author.role.isBoardRole {
                                Text(message.author.role.label)
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color("AccentColor"))
                            }
                        }
                        if !message.content.isEmpty {
                            Text(message.content)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        } else if !message.attachments.isEmpty {
                            Text("Attachment")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Text(message.createdAt, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Pinned Messages")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
