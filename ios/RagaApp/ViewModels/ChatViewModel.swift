import Foundation

/// Backs the Chat tab's single flat, team-wide channel. There's no
/// websocket/push infra in this app yet, so "live" updates come from a
/// short polling loop the view drives via `.task` (see ChatView) — this
/// store just exposes the load/send/react/pin primitives it calls.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessageItem] = []
    @Published private(set) var pinnedMessages: [ChatMessageItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await APIClient.shared.fetchChatMessages(userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await loadPinned(userId: userId)
    }

    func loadPinned(userId: String) async {
        guard let pinned = try? await APIClient.shared.fetchPinnedChatMessages(userId: userId) else { return }
        pinnedMessages = pinned
    }

    /// Used by the polling loop — silently skips errors/spinner so a flaky
    /// poll doesn't flash an alert or the empty state every few seconds.
    func refreshQuietly(userId: String) async {
        if let latest = try? await APIClient.shared.fetchChatMessages(userId: userId) {
            messages = latest
        }
        await loadPinned(userId: userId)
    }

    func send(content: String, attachments: [ChatOutgoingAttachment], userId: String) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else { return }
        do {
            let created = try await APIClient.shared.sendChatMessage(content: trimmed, attachments: attachments, userId: userId)
            messages.append(created)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func react(messageId: String, emoji: String, userId: String) async {
        do {
            let updated = try await APIClient.shared.reactToChatMessage(id: messageId, emoji: emoji, userId: userId)
            replace(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setPinned(messageId: String, pinned: Bool, userId: String) async {
        do {
            let updated = try await APIClient.shared.setChatMessagePinned(id: messageId, pinned: pinned, userId: userId)
            replace(updated)
            await loadPinned(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replace(_ updated: ChatMessageItem) {
        if let index = messages.firstIndex(where: { $0.id == updated.id }) {
            messages[index] = updated
        }
    }
}
