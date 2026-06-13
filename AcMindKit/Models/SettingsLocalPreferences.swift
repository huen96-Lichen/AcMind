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
    public var captureAutoRedactionEnabled: Bool = true
    public var captureCensorModeRawValue: Int = CensorMode.pixelate.rawValue
    public var captureScreenshotCornerRadius: Double = 0
    public var captureScreenshotMaxWidth: Double = 0
    public var captureScreenshotMaxHeight: Double = 0
    public var companionCaptureAutoSaveToInbox: Bool = true
    public var companionCaptureOpenDetailAfterCapture: Bool = false
    public var companionCaptureShowNotification: Bool = true
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
        captureAutoRedactionEnabled: Bool = true,
        captureCensorModeRawValue: Int = CensorMode.pixelate.rawValue,
        captureScreenshotCornerRadius: Double = 0,
        captureScreenshotMaxWidth: Double = 0,
        captureScreenshotMaxHeight: Double = 0,
        companionCaptureAutoSaveToInbox: Bool = true,
        companionCaptureOpenDetailAfterCapture: Bool = false,
        companionCaptureShowNotification: Bool = true,
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
        self.captureAutoRedactionEnabled = captureAutoRedactionEnabled
        self.captureCensorModeRawValue = captureCensorModeRawValue
        self.captureScreenshotCornerRadius = captureScreenshotCornerRadius
        self.captureScreenshotMaxWidth = captureScreenshotMaxWidth
        self.captureScreenshotMaxHeight = captureScreenshotMaxHeight
        self.companionCaptureAutoSaveToInbox = companionCaptureAutoSaveToInbox
        self.companionCaptureOpenDetailAfterCapture = companionCaptureOpenDetailAfterCapture
        self.companionCaptureShowNotification = companionCaptureShowNotification
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

    public var captureCensorMode: CensorMode {
        get { CensorMode(rawValue: captureCensorModeRawValue) ?? .pixelate }
        set { captureCensorModeRawValue = newValue.rawValue }
    }

    public static func isCaptureScreenshotEnabled(from defaults: UserDefaults = .standard) -> Bool {
        loadOrDefault(from: defaults).captureScreenshotEnabled
    }

    public static func isVoiceInputEnabled(from defaults: UserDefaults = .standard) -> Bool {
        loadOrDefault(from: defaults).voiceInputEnabled
    }
}

public extension SettingsLocalPreferences {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        autoBackupEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoBackupEnabled) ?? true
        lastAutoBackupAt = try container.decodeIfPresent(Date.self, forKey: .lastAutoBackupAt)
        restoreWindowPosition = try container.decodeIfPresent(Bool.self, forKey: .restoreWindowPosition) ?? true
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        taskCompletedNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .taskCompletedNotificationsEnabled) ?? true
        updateAvailableNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .updateAvailableNotificationsEnabled) ?? true
        captureOnlyWhenAppActive = try container.decodeIfPresent(Bool.self, forKey: .captureOnlyWhenAppActive) ?? false
        captureScreenshotEnabled = try container.decodeIfPresent(Bool.self, forKey: .captureScreenshotEnabled) ?? true
        captureAutoRedactionEnabled = try container.decodeIfPresent(Bool.self, forKey: .captureAutoRedactionEnabled) ?? true
        captureCensorModeRawValue = try container.decodeIfPresent(Int.self, forKey: .captureCensorModeRawValue) ?? CensorMode.pixelate.rawValue
        captureScreenshotCornerRadius = try container.decodeIfPresent(Double.self, forKey: .captureScreenshotCornerRadius) ?? 0
        captureScreenshotMaxWidth = try container.decodeIfPresent(Double.self, forKey: .captureScreenshotMaxWidth) ?? 0
        captureScreenshotMaxHeight = try container.decodeIfPresent(Double.self, forKey: .captureScreenshotMaxHeight) ?? 0
        companionCaptureAutoSaveToInbox = try container.decodeIfPresent(Bool.self, forKey: .companionCaptureAutoSaveToInbox) ?? true
        companionCaptureOpenDetailAfterCapture = try container.decodeIfPresent(Bool.self, forKey: .companionCaptureOpenDetailAfterCapture) ?? false
        companionCaptureShowNotification = try container.decodeIfPresent(Bool.self, forKey: .companionCaptureShowNotification) ?? true
        voiceInputEnabled = try container.decodeIfPresent(Bool.self, forKey: .voiceInputEnabled) ?? true
        localFirstMode = try container.decodeIfPresent(Bool.self, forKey: .localFirstMode) ?? true
        sensitiveContentNotUpload = try container.decodeIfPresent(Bool.self, forKey: .sensitiveContentNotUpload) ?? true
        apiKeyUsesKeychain = try container.decodeIfPresent(Bool.self, forKey: .apiKeyUsesKeychain) ?? true
        aiCallLogEnabled = try container.decodeIfPresent(Bool.self, forKey: .aiCallLogEnabled) ?? true
        errorLogEnabled = try container.decodeIfPresent(Bool.self, forKey: .errorLogEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(autoBackupEnabled, forKey: .autoBackupEnabled)
        try container.encodeIfPresent(lastAutoBackupAt, forKey: .lastAutoBackupAt)
        try container.encode(restoreWindowPosition, forKey: .restoreWindowPosition)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(taskCompletedNotificationsEnabled, forKey: .taskCompletedNotificationsEnabled)
        try container.encode(updateAvailableNotificationsEnabled, forKey: .updateAvailableNotificationsEnabled)
        try container.encode(captureOnlyWhenAppActive, forKey: .captureOnlyWhenAppActive)
        try container.encode(captureScreenshotEnabled, forKey: .captureScreenshotEnabled)
        try container.encode(captureAutoRedactionEnabled, forKey: .captureAutoRedactionEnabled)
        try container.encode(captureCensorModeRawValue, forKey: .captureCensorModeRawValue)
        try container.encode(captureScreenshotCornerRadius, forKey: .captureScreenshotCornerRadius)
        try container.encode(captureScreenshotMaxWidth, forKey: .captureScreenshotMaxWidth)
        try container.encode(captureScreenshotMaxHeight, forKey: .captureScreenshotMaxHeight)
        try container.encode(companionCaptureAutoSaveToInbox, forKey: .companionCaptureAutoSaveToInbox)
        try container.encode(companionCaptureOpenDetailAfterCapture, forKey: .companionCaptureOpenDetailAfterCapture)
        try container.encode(companionCaptureShowNotification, forKey: .companionCaptureShowNotification)
        try container.encode(voiceInputEnabled, forKey: .voiceInputEnabled)
        try container.encode(localFirstMode, forKey: .localFirstMode)
        try container.encode(sensitiveContentNotUpload, forKey: .sensitiveContentNotUpload)
        try container.encode(apiKeyUsesKeychain, forKey: .apiKeyUsesKeychain)
        try container.encode(aiCallLogEnabled, forKey: .aiCallLogEnabled)
        try container.encode(errorLogEnabled, forKey: .errorLogEnabled)
    }

    private enum CodingKeys: String, CodingKey {
        case autoBackupEnabled
        case lastAutoBackupAt
        case restoreWindowPosition
        case notificationsEnabled
        case taskCompletedNotificationsEnabled
        case updateAvailableNotificationsEnabled
        case captureOnlyWhenAppActive
        case captureScreenshotEnabled
        case captureAutoRedactionEnabled
        case captureCensorModeRawValue
        case captureScreenshotCornerRadius
        case captureScreenshotMaxWidth
        case captureScreenshotMaxHeight
        case companionCaptureAutoSaveToInbox
        case companionCaptureOpenDetailAfterCapture
        case companionCaptureShowNotification
        case voiceInputEnabled
        case localFirstMode
        case sensitiveContentNotUpload
        case apiKeyUsesKeychain
        case aiCallLogEnabled
        case errorLogEnabled
    }
}
