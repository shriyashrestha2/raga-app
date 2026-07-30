import Foundation

extension APIClient {
    /// Board-only on the server — see permissions.ts's canUseAiAssistant.
    func draftAnnouncement(prompt: String, userId: String) async throws -> AIAssistantResponse {
        try await post("ai/draft", body: ["prompt": prompt], userId: userId)
    }
}
