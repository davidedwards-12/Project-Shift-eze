import Foundation
import RotationEngine
import UserNotifications

enum ReminderScheduler {
    /// Reminders show at this hour on their day
    static let hour = 9
    
    private static var center: UNUserNotificationCenter { .current() }
    
    @discardableResult
    static func requestPermissionIfNeeded() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        guard status == .notDetermined else { return status == .authorized || status == .provisional }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }
    
    static func reschedule(_ reminders: [Reminder], now: Date = .now) async {
        center.removeAllPendingNotificationRequests()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        for reminder in reminders {
            let request = UNNotificationRequest(
                identifier: reminder.id,
                content: content(for: reminder),
                trigger: trigger(for: reminder.day, now: now)
            )
            try? await center.add(request)
        }
    }
    
    static func content(for reminder: Reminder) -> UNMutableNotificationContent {
        let action = reminder.action
        let content = UNMutableNotificationContent()
        switch action.kind {
        case .cancel:
            content.title = "Cancel \(action.service) by \(action.date.short)"
            content.body = "Your plan doesn't need it next month. Tap to cancel through \(action.billedThrough)"
        case .start, .restart:
            content.title = "\(action.kind.rawValue) \(action.service) today"
            content.body = reminder.titles.isEmpty
            ? "It's in your plan for this month."
            : "For \(reminder.titles.formatted()). Check it's still on \(action.service) first."
        case .keep:
            break
        }
        content.sound = .default
        // Read by NotificationHandler when the reminder is tapped.
        content.userInfo = [
            "link": action.iosLink ?? action.link ?? "",
            "fallbackLink": action.link ?? "",
        ]
        return content
    }
    
    /// 9am on the day, or a minute from now if that's already passed today.
    static func trigger(for day: CalendarDate, now: Date) -> UNNotificationTrigger {
        let components = DateComponents(year: day.year, month: day.month, day: day.day, hour: hour)
        if let fireDate = Calendar.current.date(from: components), fireDate > now {
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }
        return UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
    }
}
