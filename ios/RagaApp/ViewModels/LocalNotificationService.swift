import Foundation
import UserNotifications

/// Thin wrapper around UNUserNotificationCenter. These are LOCAL
/// notifications, not push — there's no APNs/server-push infrastructure in
/// this app (no push tokens, no backend fan-out), so NotificationPoller
/// detects "new since last poll" content client-side and fires these
/// directly instead.
final class LocalNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // nil trigger delivers immediately.
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Without this, UNUserNotificationCenter silently suppresses banners
    /// while the app is in the foreground — we want them visible regardless
    /// of which tab the user is on.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
