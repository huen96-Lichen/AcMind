import Foundation
import AppKit
import UserNotifications

public enum AppNotificationPriority: Sendable, Equatable {
    case normal
    case important
}

public enum AppNotificationDeliveryChannel: String, Sendable, Equatable {
    case inlineToast
    case systemNotification
    case appleScriptFallback
    case suppressed
}

public enum AppInlineNotificationStyle: String, Sendable, Codable, Equatable {
    case success
    case error
    case warning
    case info
}

public struct AppNotificationFocusSnapshot: Sendable, Equatable {
    public var bundleIdentifier: String?
    public var applicationName: String?
    public var source: String

    public init(bundleIdentifier: String?, applicationName: String?, source: String) {
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.source = source
    }

    public var isAcMindFocused: Bool {
        AppNotificationFocusClassifier.isAcMindFocused(bundleIdentifier: bundleIdentifier, applicationName: applicationName)
    }

    public var isFocusSensitive: Bool {
        AppNotificationFocusClassifier.isFocusSensitive(bundleIdentifier: bundleIdentifier, applicationName: applicationName)
    }
}

public enum AppNotificationFocusClassifier {
    private static let focusSensitiveBundleIdentifiers: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.cursor.Cursor"
    ]

    private static let focusSensitiveApplicationNames: Set<String> = [
        "Terminal",
        "iTerm2",
        "Ghostty",
        "Visual Studio Code",
        "Code",
        "Code - Insiders",
        "Cursor"
    ]

    public static func isAcMindFocused(bundleIdentifier: String?, applicationName: String?) -> Bool {
        let normalizedBundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedBundleIdentifier == Bundle.main.bundleIdentifier {
            return true
        }

        let normalizedName = applicationName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedName == mainApplicationName
    }

    public static func isFocusSensitive(bundleIdentifier: String?, applicationName: String?) -> Bool {
        if let bundleIdentifier, focusSensitiveBundleIdentifiers.contains(bundleIdentifier) {
            return true
        }

        if let applicationName, focusSensitiveApplicationNames.contains(applicationName) {
            return true
        }

        return false
    }

    private static var mainApplicationName: String? {
        let info = Bundle.main.infoDictionary
        return info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
            ?? info?[kCFBundleNameKey as String] as? String
    }
}

public struct AppNotificationPlan: Sendable, Equatable {
    public var channel: AppNotificationDeliveryChannel
    public var focus: AppNotificationFocusSnapshot
    public var authorizationStatus: UNAuthorizationStatus
    public var force: Bool

    public init(
        channel: AppNotificationDeliveryChannel,
        focus: AppNotificationFocusSnapshot,
        authorizationStatus: UNAuthorizationStatus,
        force: Bool
    ) {
        self.channel = channel
        self.focus = focus
        self.authorizationStatus = authorizationStatus
        self.force = force
    }
}

public enum AppNotificationStrategy {
    public static func plan(
        focus: AppNotificationFocusSnapshot,
        authorizationStatus: UNAuthorizationStatus,
        force: Bool
    ) -> AppNotificationPlan {
        if force == false && focus.isAcMindFocused {
            return AppNotificationPlan(
                channel: .inlineToast,
                focus: focus,
                authorizationStatus: authorizationStatus,
                force: force
            )
        }

        if force == false && focus.isFocusSensitive {
            return AppNotificationPlan(
                channel: .suppressed,
                focus: focus,
                authorizationStatus: authorizationStatus,
                force: force
            )
        }

        if authorizationStatus == .authorized || authorizationStatus == .provisional {
            return AppNotificationPlan(
                channel: .systemNotification,
                focus: focus,
                authorizationStatus: authorizationStatus,
                force: force
            )
        }

        return AppNotificationPlan(
            channel: .appleScriptFallback,
            focus: focus,
            authorizationStatus: authorizationStatus,
            force: force
        )
    }

    public static var strategySummary: String {
        "AcWork 前台优先内联提示；终端 / 编辑器前台默认静默；系统通知不可用时回退 AppleScript；重要通知可强制发送。"
    }
}

public enum AppNotificationFocusDetector {
    public static func currentSnapshot() async -> AppNotificationFocusSnapshot {
        let workspaceSnapshot = await MainActor.run {
            NSWorkspace.shared.frontmostApplication.map {
                AppNotificationFocusSnapshot(
                    bundleIdentifier: $0.bundleIdentifier,
                    applicationName: $0.localizedName,
                    source: "NSWorkspace"
                )
            }
        }

        if let workspaceSnapshot {
            return workspaceSnapshot
        }

        if let scriptSnapshot = appleScriptSnapshot() {
            return scriptSnapshot
        }

        return AppNotificationFocusSnapshot(bundleIdentifier: nil, applicationName: nil, source: "unknown")
    }

    private static func appleScriptSnapshot() -> AppNotificationFocusSnapshot? {
        let scripts = [
            "tell application \"System Events\" to get bundle identifier of first application process whose frontmost is true",
            "tell application \"System Events\" to get name of first application process whose frontmost is true"
        ]

        let bundleIdentifier = runAppleScript(scripts[0])
        let applicationName = runAppleScript(scripts[1])

        guard bundleIdentifier != nil || applicationName != nil else {
            return nil
        }

        return AppNotificationFocusSnapshot(
            bundleIdentifier: bundleIdentifier,
            applicationName: applicationName,
            source: "AppleScript"
        )
    }

    private static func runAppleScript(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

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
    private static let logger = AcMindLogger(category: .notifications)
    private static let inlineToastNotificationName = Notification.Name.acmindInlineToastRequested

    public static func shouldNotifyTaskCompleted(with settings: AppNotificationSettings) -> Bool {
        settings.notificationsEnabled && settings.taskCompletedNotificationsEnabled
    }

    public static func notifyTaskCompleted(
        title: String,
        body: String,
        settings: AppNotificationSettings,
        force: Bool = false
    ) async {
        guard shouldNotifyTaskCompleted(with: settings) else { return }

        let focus = await AppNotificationFocusDetector.currentSnapshot()
        let center = UNUserNotificationCenter.current()
        let authorization = await center.notificationSettings().authorizationStatus
        let plan = AppNotificationStrategy.plan(
            focus: focus,
            authorizationStatus: authorization,
            force: force
        )

        switch plan.channel {
        case .inlineToast:
            await postInlineToast(title: title, body: body, style: .success)
            logger.info("使用内联提示替代系统通知", file: "AppNotificationService")
            return
        case .suppressed:
            logger.info("通知在当前前台上下文中被抑制", file: "AppNotificationService")
            return
        case .systemNotification:
            break
        case .appleScriptFallback:
            if await sendAppleScriptNotification(title: title, body: body) {
                logger.info("使用 AppleScript 回退发送通知", file: "AppNotificationService")
                return
            }
            logger.warning("AppleScript 通知回退失败，尝试系统通知", file: "AppNotificationService")
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
            logger.error("发送本地通知失败: \(error.localizedDescription)", file: "AppNotificationService")
            if force == false {
                await postInlineToast(title: title, body: body, style: .warning)
            }
        }
    }

    public static var strategySummary: String {
        AppNotificationStrategy.strategySummary
    }

    private static func postInlineToast(title: String, body: String, style: AppInlineNotificationStyle) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: inlineToastNotificationName,
                object: nil,
                userInfo: [
                    "title": title,
                    "body": body,
                    "style": style.rawValue
                ]
            )
        }
    }

    private static func sendAppleScriptNotification(title: String, body: String) async -> Bool {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\""

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                process.standardOutput = Pipe()
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
