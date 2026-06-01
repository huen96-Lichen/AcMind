import Foundation

/// 仅保存在本地的设置项。
///
/// 这些值不属于服务端/数据库主配置，但会影响入口行为、自动备份和一些本地运行开关。
public struct SettingsLocalPreferences: Codable, Sendable, Equatable {
    public static let storageKey = "SettingsViewModel.localPreferences"

    public var autoBackupEnabled: Bool = true
    public var lastAutoBackupAt: Date? = nil
    public var restoreWindowPosition: Bool = true
    public var notificationsEnabled: Bool = true
    public var taskCompletedNotificationsEnabled: Bool = true
    public var updateAvailableNotificationsEnabled: Bool = true
    public var captureOnlyWhenAppActive: Bool = false
    public var captureScreenshotEnabled: Bool = true
    public var voiceInputEnabled: Bool = true
    public var localFirstMode: Bool = true
    public var sensitiveContentNotUpload: Bool = true
    public var apiKeyUsesKeychain: Bool = true
    public var aiCallLogEnabled: Bool = true
    public var errorLogEnabled: Bool = true

    public init(
        autoBackupEnabled: Bool = true,
        lastAutoBackupAt: Date? = nil,
        restoreWindowPosition: Bool = true,
        notificationsEnabled: Bool = true,
        taskCompletedNotificationsEnabled: Bool = true,
        updateAvailableNotificationsEnabled: Bool = true,
        captureOnlyWhenAppActive: Bool = false,
        captureScreenshotEnabled: Bool = true,
        voiceInputEnabled: Bool = true,
        localFirstMode: Bool = true,
        sensitiveContentNotUpload: Bool = true,
        apiKeyUsesKeychain: Bool = true,
        aiCallLogEnabled: Bool = true,
        errorLogEnabled: Bool = true
    ) {
        self.autoBackupEnabled = autoBackupEnabled
        self.lastAutoBackupAt = lastAutoBackupAt
        self.restoreWindowPosition = restoreWindowPosition
        self.notificationsEnabled = notificationsEnabled
        self.taskCompletedNotificationsEnabled = taskCompletedNotificationsEnabled
        self.updateAvailableNotificationsEnabled = updateAvailableNotificationsEnabled
        self.captureOnlyWhenAppActive = captureOnlyWhenAppActive
        self.captureScreenshotEnabled = captureScreenshotEnabled
        self.voiceInputEnabled = voiceInputEnabled
        self.localFirstMode = localFirstMode
        self.sensitiveContentNotUpload = sensitiveContentNotUpload
        self.apiKeyUsesKeychain = apiKeyUsesKeychain
        self.aiCallLogEnabled = aiCallLogEnabled
        self.errorLogEnabled = errorLogEnabled
    }

    public static func load(from defaults: UserDefaults = .standard) -> SettingsLocalPreferences? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SettingsLocalPreferences.self, from: data)
    }

    public static func loadOrDefault(from defaults: UserDefaults = .standard) -> SettingsLocalPreferences {
        load(from: defaults) ?? SettingsLocalPreferences()
    }

    public func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    public static func isCaptureScreenshotEnabled(from defaults: UserDefaults = .standard) -> Bool {
        loadOrDefault(from: defaults).captureScreenshotEnabled
    }

    public static func isVoiceInputEnabled(from defaults: UserDefaults = .standard) -> Bool {
        loadOrDefault(from: defaults).voiceInputEnabled
    }
}
