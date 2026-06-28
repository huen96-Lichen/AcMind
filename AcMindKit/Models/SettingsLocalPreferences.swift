import Foundation

public enum ScreenshotPresetOutputAction: String, Codable, Sendable, CaseIterable, Identifiable {
    case saveToInbox
    case copyToClipboard
    case pinToDesktop

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .saveToInbox: return "保存到收集箱"
        case .copyToClipboard: return "复制到剪贴板"
        case .pinToDesktop: return "Pin 到桌面"
        }
    }
}

public struct ScreenshotPreset: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var captureAutoRedactionEnabled: Bool
    public var captureCensorModeRawValue: Int
    public var captureScreenshotCornerRadius: Double
    public var captureScreenshotMaxWidth: Double
    public var captureScreenshotMaxHeight: Double
    public var defaultOutputActionRawValue: String

    public init(
        id: String,
        name: String,
        captureAutoRedactionEnabled: Bool,
        captureCensorModeRawValue: Int,
        captureScreenshotCornerRadius: Double,
        captureScreenshotMaxWidth: Double,
        captureScreenshotMaxHeight: Double,
        defaultOutputAction: ScreenshotPresetOutputAction
    ) {
        self.id = id
        self.name = name
        self.captureAutoRedactionEnabled = captureAutoRedactionEnabled
        self.captureCensorModeRawValue = captureCensorModeRawValue
        self.captureScreenshotCornerRadius = captureScreenshotCornerRadius
        self.captureScreenshotMaxWidth = captureScreenshotMaxWidth
        self.captureScreenshotMaxHeight = captureScreenshotMaxHeight
        self.defaultOutputActionRawValue = defaultOutputAction.rawValue
    }

    public var defaultOutputAction: ScreenshotPresetOutputAction {
        get { ScreenshotPresetOutputAction(rawValue: defaultOutputActionRawValue) ?? ScreenshotPresetOutputAction.saveToInbox }
        set { defaultOutputActionRawValue = newValue.rawValue }
    }

    public var captureCensorMode: CensorMode {
        get { CensorMode(rawValue: captureCensorModeRawValue) ?? .pixelate }
        set { captureCensorModeRawValue = newValue.rawValue }
    }

    public static func blankPreset(id: String = UUID().uuidString, name: String = "新建预设") -> ScreenshotPreset {
        ScreenshotPreset(
            id: id,
            name: name,
            captureAutoRedactionEnabled: false,
            captureCensorModeRawValue: CensorMode.pixelate.rawValue,
            captureScreenshotCornerRadius: 0,
            captureScreenshotMaxWidth: 0,
            captureScreenshotMaxHeight: 0,
            defaultOutputAction: .saveToInbox
        )
    }

    public static let defaultPresets: [ScreenshotPreset] = [
        ScreenshotPreset(
            id: "default-save",
            name: "默认保存",
            captureAutoRedactionEnabled: true,
            captureCensorModeRawValue: CensorMode.pixelate.rawValue,
            captureScreenshotCornerRadius: 0,
            captureScreenshotMaxWidth: 0,
            captureScreenshotMaxHeight: 0,
            defaultOutputAction: .saveToInbox
        ),
        ScreenshotPreset(
            id: "copy-first",
            name: "复制优先",
            captureAutoRedactionEnabled: false,
            captureCensorModeRawValue: CensorMode.blur.rawValue,
            captureScreenshotCornerRadius: 0,
            captureScreenshotMaxWidth: 0,
            captureScreenshotMaxHeight: 0,
            defaultOutputAction: .copyToClipboard
        ),
        ScreenshotPreset(
            id: "privacy-first",
            name: "隐私优先",
            captureAutoRedactionEnabled: true,
            captureCensorModeRawValue: CensorMode.pixelate.rawValue,
            captureScreenshotCornerRadius: 6,
            captureScreenshotMaxWidth: 0,
            captureScreenshotMaxHeight: 0,
            defaultOutputAction: .saveToInbox
        )
    ]
}

public extension SettingsLocalPreferences {
    static func nextBlankScreenshotPresetName(in presets: [ScreenshotPreset]) -> String {
        let baseName = "新建预设"
        let existingNames = Set((presets.isEmpty ? ScreenshotPreset.defaultPresets : presets).map(\.name))
        guard existingNames.contains(baseName) else { return baseName }

        var index = 2
        while existingNames.contains("\(baseName) \(index)") {
            index += 1
        }
        return "\(baseName) \(index)"
    }

    static func restoredDefaultScreenshotPresetState() -> (presets: [ScreenshotPreset], selectedPresetID: String) {
        let presets = ScreenshotPreset.defaultPresets
        return (presets, presets.first?.id ?? "default-save")
    }

    static func createBlankScreenshotPresetState(
        from presets: [ScreenshotPreset]
    ) -> (presets: [ScreenshotPreset], selectedPresetID: String) {
        var updated = presets.isEmpty ? ScreenshotPreset.defaultPresets : presets
        let preset = ScreenshotPreset.blankPreset(name: nextBlankScreenshotPresetName(in: updated))
        updated.append(preset)
        return (updated, preset.id)
    }

    static func duplicateSelectedScreenshotPresetState(
        from presets: [ScreenshotPreset],
        selectedPresetID: String
    ) -> (presets: [ScreenshotPreset], selectedPresetID: String) {
        let resolvedPresets = presets.isEmpty ? ScreenshotPreset.defaultPresets : presets
        guard let source = resolvedPresets.first(where: { $0.id == selectedPresetID }) ?? resolvedPresets.first else {
            return (resolvedPresets, selectedPresetID)
        }

        var copy = source
        copy.id = UUID().uuidString
        copy.name = "\(source.name) 副本"

        var updated = resolvedPresets
        updated.append(copy)
        return (updated, copy.id)
    }

    static func deleteSelectedScreenshotPresetState(
        from presets: [ScreenshotPreset],
        selectedPresetID: String
    ) -> (presets: [ScreenshotPreset], selectedPresetID: String) {
        var updated = presets.isEmpty ? ScreenshotPreset.defaultPresets : presets
        guard updated.count > 1 else {
            let selectedID = updated.first?.id ?? ScreenshotPreset.defaultPresets.first?.id ?? "default-save"
            return (updated, selectedID)
        }

        updated.removeAll { $0.id == selectedPresetID }
        if updated.isEmpty {
            updated = ScreenshotPreset.defaultPresets
        }

        let selectedID = updated.first?.id ?? ScreenshotPreset.defaultPresets.first?.id ?? "default-save"
        return (updated, selectedID)
    }

    static func renameSelectedScreenshotPresetState(
        from presets: [ScreenshotPreset],
        selectedPresetID: String,
        newName: String
    ) -> [ScreenshotPreset] {
        var updated = presets.isEmpty ? ScreenshotPreset.defaultPresets : presets
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              let index = updated.firstIndex(where: { $0.id == selectedPresetID }) else {
            return updated
        }

        updated[index].name = trimmed
        return updated
    }

    static func updateSelectedScreenshotPresetOutputActionState(
        from presets: [ScreenshotPreset],
        selectedPresetID: String,
        action: ScreenshotPresetOutputAction
    ) -> [ScreenshotPreset] {
        var updated = presets.isEmpty ? ScreenshotPreset.defaultPresets : presets
        guard let index = updated.firstIndex(where: { $0.id == selectedPresetID }) else {
            return updated
        }

        updated[index].defaultOutputAction = action
        return updated
    }
}

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
    public var screenshotPresets: [ScreenshotPreset] = ScreenshotPreset.defaultPresets
    public var selectedScreenshotPresetID: String = ScreenshotPreset.defaultPresets.first?.id ?? "default-save"
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
        screenshotPresets: [ScreenshotPreset] = ScreenshotPreset.defaultPresets,
        selectedScreenshotPresetID: String = ScreenshotPreset.defaultPresets.first?.id ?? "default-save",
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
        self.screenshotPresets = screenshotPresets.isEmpty ? ScreenshotPreset.defaultPresets : screenshotPresets
        self.selectedScreenshotPresetID = selectedScreenshotPresetID
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

public struct ScreenshotPreferencesSnapshot: Sendable, Equatable {
    public let activePreset: ScreenshotPreset
    public let presets: [ScreenshotPreset]
    public let screenshotHotkeyText: String?

    public init(
        activePreset: ScreenshotPreset,
        presets: [ScreenshotPreset],
        screenshotHotkeyText: String?
    ) {
        self.activePreset = activePreset
        self.presets = presets
        self.screenshotHotkeyText = screenshotHotkeyText
    }

    public var hotkeyLabel: String {
        guard let hotkey = screenshotHotkeyText?.trimmingCharacters(in: .whitespacesAndNewlines),
              hotkey.isEmpty == false else {
            return "全局热键 未绑定"
        }
        return "全局热键 \(hotkey)"
    }
}

public extension SettingsLocalPreferences {
    static func screenshotSnapshot(
        from appSettings: AppSettings? = nil,
        defaults: UserDefaults = .standard
    ) -> ScreenshotPreferencesSnapshot {
        let preferences = loadOrDefault(from: defaults)
        let presets = preferences.screenshotPresets.isEmpty ? ScreenshotPreset.defaultPresets : preferences.screenshotPresets
        let activePreset = presets.first(where: { $0.id == preferences.selectedScreenshotPresetID })
            ?? presets.first
            ?? ScreenshotPreset.defaultPresets.first!
        return ScreenshotPreferencesSnapshot(
            activePreset: activePreset,
            presets: presets,
            screenshotHotkeyText: appSettings?.captureScreenshotHotkey
        )
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
        screenshotPresets = try container.decodeIfPresent([ScreenshotPreset].self, forKey: .screenshotPresets) ?? ScreenshotPreset.defaultPresets
        selectedScreenshotPresetID = try container.decodeIfPresent(String.self, forKey: .selectedScreenshotPresetID) ?? ScreenshotPreset.defaultPresets.first?.id ?? "default-save"
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
        try container.encode(screenshotPresets, forKey: .screenshotPresets)
        try container.encode(selectedScreenshotPresetID, forKey: .selectedScreenshotPresetID)
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
        case screenshotPresets
        case selectedScreenshotPresetID
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
