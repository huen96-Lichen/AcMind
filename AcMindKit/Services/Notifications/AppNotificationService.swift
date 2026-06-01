import Foundation
import UserNotifications

public struct AppNotificationSettings: Sendable, Equatable {
    public var notificationsEnabled: Bool
    public var taskCompletedNotificationsEnabled: Bool

    public init(
        notificationsEnabled: Bool = true,
        taskCompletedNotificationsEnabled: Bool = true
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.taskCompletedNotificationsEnabled = taskCompletedNotificationsEnabled
    }
}

public enum AppNotificationService {
    public static func shouldNotifyTaskCompleted(with settings: AppNotificationSettings) -> Bool {
        settings.notificationsEnabled && settings.taskCompletedNotificationsEnabled
    }

    public static func notifyTaskCompleted(title: String, body: String, settings: AppNotificationSettings) async {
        guard shouldNotifyTaskCompleted(with: settings) else { return }

        let center = UNUserNotificationCenter.current()
        let authorization = await center.notificationSettings().authorizationStatus
        guard authorization == .authorized || authorization == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "acmind.task.completed.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            print("⚠️ 发送本地通知失败: \(error.localizedDescription)")
        }
    }
}
