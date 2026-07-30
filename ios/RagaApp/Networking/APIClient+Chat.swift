import Foundation

extension APIClient {
    func fetchChatMessages(userId: String) async throws -> [ChatMessageItem] {
        try await get("chat", userId: userId)
    }

    func fetchPinnedChatMessages(userId: String) async throws -> [ChatMessageItem] {
        try await get("chat/pinned", userId: userId)
    }

    @discardableResult
    func sendChatMessage(content: String, attachments: [ChatOutgoingAttachment], userId: String) async throws -> ChatMessageItem {
        let files = attachments.map {
            MultipartFile(fieldName: "attachments", fileName: $0.fileName, mimeType: $0.mimeType, data: $0.data)
        }
        let fields = content.isEmpty ? [:] : ["content": content]
        return try await postMultipart("chat", fields: fields, files: files, userId: userId)
    }

    /// Sets the caller's reaction: reacting again with the same emoji clears
    /// it, a different emoji replaces it — see backend/src/routes/chat.ts's
    /// POST /chat/:id/react.
    @discardableResult
    func reactToChatMessage(id: String, emoji: String, userId: String) async throws -> ChatMessageItem {
        try await post("chat/\(id)/react", body: ["emoji": emoji], userId: userId)
    }

    /// Board-only on the server — see permissions.ts's canPinChatMessage.
    @discardableResult
    func setChatMessagePinned(id: String, pinned: Bool, userId: String) async throws -> ChatMessageItem {
        try await patch("chat/\(id)/pin", body: ["pinned": pinned], userId: userId)
    }
}
