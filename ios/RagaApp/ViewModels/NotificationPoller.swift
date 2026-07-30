import Foundation

/// App-wide watcher for "new since last check" content, independent of
/// which tab is on screen — unlike ChatView's own polling loop (which only
/// runs while Chat is visible), this keeps running for as long as the app
/// process is alive so a chat message, board reminder/announcement, or
/// video upload fires a notification no matter what the user is looking at.
///
/// There's no push/APNs infrastructure here, so this is the substitute:
/// poll, diff against what was seen last time, and fire a local
/// notification (via LocalNotificationService) for anything new that
/// wasn't authored by the current user.
@MainActor
final class NotificationPoller {
    private var seenChatMessageIds: Set<String> = []
    private var seenReminderIds: Set<String> = []
    private var seenUpdateIds: Set<String> = []
    private var seenVideoIds: Set<String> = []
    /// First poll after start() just establishes a baseline — otherwise
    /// logging in (or switching profiles) would fire a notification for
    /// every pre-existing message/reminder/video all at once.
    private var hasBaseline = false
    private var pollTask: Task<Void, Never>?

    private let pollInterval: Duration = .seconds(6)

    func start(userId: String) {
        stop()
        hasBaseline = false
        seenChatMessageIds = []
        seenReminderIds = []
        seenUpdateIds = []
        seenVideoIds = []
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll(userId: userId)
                try? await Task.sleep(for: self?.pollInterval ?? .seconds(6))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func poll(userId: String) async {
        async let chatResult = try? APIClient.shared.fetchChatMessages(userId: userId)
        async let remindersResult = try? APIClient.shared.fetchReminders(category: nil, userId: userId)
        async let updatesResult = try? APIClient.shared.fetchUpdates(userId: userId)
        async let videosResult = try? APIClient.shared.fetchVideos(set: "All", userId: userId)

        let (chat, reminders, updates, videos) = await (chatResult, remindersResult, updatesResult, videosResult)

        if let chat { handleChat(chat, userId: userId) }
        if let reminders { handleReminders(reminders, userId: userId) }
        if let updates { handleUpdates(updates, userId: userId) }
        if let videos { handleVideos(videos, userId: userId) }
        hasBaseline = true
    }

    private func handleChat(_ messages: [ChatMessageItem], userId: String) {
        let newOnes = messages.filter { !seenChatMessageIds.contains($0.id) }
        seenChatMessageIds = Set(messages.map(\.id))
        guard hasBaseline else { return }
        for message in newOnes where message.author.id != userId {
            let preview = message.content.isEmpty
                ? (message.attachments.isEmpty ? "" : "Sent \(message.attachments.count == 1 ? "an attachment" : "\(message.attachments.count) attachments")")
                : message.content
            LocalNotificationService.shared.notify(title: "\(message.author.name) in Chat", body: preview)
        }
    }

    private func handleReminders(_ reminders: [ReminderItem], userId: String) {
        let newOnes = reminders.filter { !seenReminderIds.contains($0.id) }
        seenReminderIds = Set(reminders.map(\.id))
        guard hasBaseline else { return }
        for reminder in newOnes where reminder.createdBy.id != userId {
            LocalNotificationService.shared.notify(
                title: "New \(reminder.type.label) from \(reminder.createdBy.name)",
                body: reminder.title
            )
        }
    }

    private func handleUpdates(_ updates: [UpdateItem], userId: String) {
        let newOnes = updates.filter { !seenUpdateIds.contains($0.id) }
        seenUpdateIds = Set(updates.map(\.id))
        guard hasBaseline else { return }
        for update in newOnes where update.author.id != userId {
            LocalNotificationService.shared.notify(
                title: "\(update.tag.label) from \(update.author.name)",
                body: update.content
            )
        }
    }

    private func handleVideos(_ videos: [VideoItem], userId: String) {
        let newOnes = videos.filter { !seenVideoIds.contains($0.id) }
        seenVideoIds = Set(videos.map(\.id))
        guard hasBaseline else { return }
        for video in newOnes where video.uploadedBy.id != userId {
            LocalNotificationService.shared.notify(
                title: "New video from \(video.uploadedBy.name)",
                body: video.title
            )
        }
    }
}
