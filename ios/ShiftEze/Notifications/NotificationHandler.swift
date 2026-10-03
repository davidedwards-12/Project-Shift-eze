import UIKit
import UserNotifications

/// Opens a reminder's cancel/restart page when it's tapped, and shows
/// reminders as banners even while the app is open.
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let link = (info["link"] as? String).flatMap(URL.init(string:))
        let fallback = (info["fallbackLink"] as? String).flatMap(URL.init(string:))
        guard let link else { return }
        await open(link, fallback: fallback)
    }

    /// Open the app deep link; if nothing handles it, the web page instead.
    @MainActor private func open(_ url: URL, fallback: URL?) {
        UIApplication.shared.open(url) { opened in
            if !opened, let fallback, fallback != url {
                UIApplication.shared.open(fallback)
            }
        }
    }
}
