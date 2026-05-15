import Foundation
import SwiftUI
import AcMindKit

// MARK: - Settings View Model

/// 设置页面视图模型
/// 职责：
/// 1. 从 SettingsService 加载设置
/// 2. 提供双向绑定给 SwiftUI 视图
/// 3. 处理设置保存
/// 4. 管理权限和快捷键状态
@MainActor
public final class SettingsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let settings: SettingsServiceProtocol
    private let storage: StorageServiceProtocol
    private let permissionManager: PermissionManager

    // MARK: - Published Properties

    // App Settings
    @Published public var theme: AppTheme = .system
    @Published public var language: String = "zh-CN"
    @Published public var defaultProviderId: String = ""
    @Published public var defaultModelId: String = ""
    @Published public var vaultPath: String = ""
    @Published public var autoCaptureClipboard: Bool = true
    @Published public var captureScreenshotHotkey: String = ""
    @Published public var defaultExportTarget: ExportTarget = .obsidian
    @Published public var autoFrontmatter: Bool = true

    // Vault Config
    @Published public var vaultDefaultFolder: String = "Inbox"
    @Published public var vaultPathRule: VaultConfig.VaultPathRule = .categoryDate
    @Published public var vaultConflictStrategy: ConflictStrategy = .rename

    // Voice Settings
    @Published public var voiceDefaultProvider: String = "whisper"
    @Published public var voiceDefaultLanguage: String = "zh"
    @Published public var voiceAutoPolish: Bool = true
    @Published public var voicePolishMode: VoicePolishMode = .light
    @Published public var aiPromptStyle: AIPromptStyle = .general

    // Capture Settings
    @Published public var autoRedactFaces: Bool = true
    @Published public var autoDetectPII: Bool = true
    @Published public var enabledRedactionTypes: Set<RedactionType> = Set(RedactionType.allCases)
    @Published public var censorMode: CensorMode = .pixelate
    @Published public var scrollCaptureAutoScroll: Bool = true
    @Published public var scrollCaptureSpeed: Double = 3
    @Published public var scrollCaptureMaxHeight: Int = 30000

    // 随身设置
    @Published public var companionCapsuleEnabled: Bool = true
    @Published public var companionCapsulePosition: CompanionCapsulePosition = .topCenter
    @Published public var companionCapsuleExpanded: Bool = false
    @Published public var companionVoiceEnabled: Bool = true
    @Published public var companionVoiceOutputMode: VoiceOutputMode = .copyToClipboard
    @Published public var companionVoiceSaveToInbox: Bool = true
    @Published public var companionShortcutsEnabled: Bool = true
    @Published public var companionCaptureEnabled: Bool = true
    @Published public var companionCollapsedContentSettings: CompanionCollapsedContentSettings = .default

    // 随身权限状态 (new types)
    @Published public var microphonePermissionStatus: CompanionPermissionStatus = .notDetermined
    @Published public var accessibilityPermissionStatus: CompanionPermissionStatus = .notDetermined
    @Published public var screenRecordingPermissionStatus: CompanionPermissionStatus = .notDetermined

    // Permissions (new types)
    @Published public var microphoneStatus: AppPermissionStatus = .unknown
    @Published public var screenRecordingStatus: AppPermissionStatus = .unknown
    @Published public var accessibilityStatus: AppPermissionStatus = .unknown
    @Published public var fullDiskAccessStatus: AppPermissionStatus = .unknown
    @Published public var notificationsStatus: AppPermissionStatus = .unknown

    // Providers
    @Published public var providers: [ProviderConfig] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showError = false

    // MARK: - Initialization

    public init(settings: SettingsServiceProtocol? = nil, storage: StorageServiceProtocol? = nil) {
        self.settings = settings ?? ServiceContainer.shared.settingsService
        self.storage = storage ?? ServiceContainer.shared.storageService
        self.permissionManager = ServiceContainer.shared.permissionManager

        // 加载设置
        Task {
            await loadSettings()
            await loadPermissions()
            await loadProviders()
            await loadCompanionSettings()
        }
    }

    // MARK: - Load Settings

    public func loadSettings() async {
        isLoading = true
        defer { isLoading = false }

        // App Settings
        let appSettings = await settings.getSettings()
        theme = appSettings.theme
        language = appSettings.language
        defaultProviderId = appSettings.defaultProviderId ?? ""
        defaultModelId = appSettings.defaultModelId ?? ""
        vaultPath = appSettings.vaultPath
        autoCaptureClipboard = appSettings.autoCaptureClipboard
        captureScreenshotHotkey = appSettings.captureScreenshotHotkey ?? ""
        defaultExportTarget = appSettings.defaultExportTarget
        autoFrontmatter = appSettings.autoFrontmatter

        // Vault Config
        let vaultConfig = await settings.getVaultConfig()
        vaultDefaultFolder = vaultConfig.defaultFolder
        vaultPathRule = vaultConfig.pathRule
        vaultConflictStrategy = vaultConfig.conflictStrategy

        // Voice Settings
        let voiceSettings = await settings.getVoiceSettings()
        voiceDefaultProvider = voiceSettings.defaultProvider
        voiceDefaultLanguage = voiceSettings.defaultLanguage
        voiceAutoPolish = voiceSettings.autoPolish
        voicePolishMode = voiceSettings.voicePolishMode
    }

    // MARK: - Companion Settings

    public func loadCompanionSettings() async {
        do {
            if let jsonString = try await storage.getSetting(key: "companion_config"),
               let jsonData = jsonString.data(using: .utf8),
               let config = try? JSONDecoder().decode(CompanionConfiguration.self, from: jsonData) {
                companionCapsuleEnabled = config.capsuleEnabled
                companionCapsulePosition = CompanionCapsulePosition(rawValue: config.capsulePosition) ?? .topCenter
                companionCapsuleExpanded = config.capsuleExpandedByDefault
                companionVoiceEnabled = config.voiceEnabled
                companionVoiceOutputMode = VoiceOutputMode(rawValue: config.voiceOutputMode) ?? .copyToClipboard
                companionVoiceSaveToInbox = config.voiceSaveToInbox
                companionShortcutsEnabled = config.shortcutsEnabled
                companionCaptureEnabled = config.captureEnabled
            } else {
                let config = CompanionConfiguration.default
                companionCapsuleEnabled = config.capsuleEnabled
                companionCapsulePosition = CompanionCapsulePosition(rawValue: config.capsulePosition) ?? .topCenter
                companionCapsuleExpanded = config.capsuleExpandedByDefault
                companionVoiceEnabled = config.voiceEnabled
                companionVoiceOutputMode = VoiceOutputMode(rawValue: config.voiceOutputMode) ?? .copyToClipboard
                companionVoiceSaveToInbox = config.voiceSaveToInbox
                companionShortcutsEnabled = config.shortcutsEnabled
                companionCaptureEnabled = config.captureEnabled
            }

            if let data = UserDefaults.standard.data(forKey: CompanionCollapsedContentStorage.key),
               let decoded = try? JSONDecoder().decode(CompanionCollapsedContentSettings.self, from: data) {
                companionCollapsedContentSettings = decoded
            } else {
                companionCollapsedContentSettings = .default
            }
        } catch {
            let config = CompanionConfiguration.default
            companionCapsuleEnabled = config.capsuleEnabled
            companionCapsulePosition = CompanionCapsulePosition(rawValue: config.capsulePosition) ?? .topCenter
            companionCapsuleExpanded = config.capsuleExpandedByDefault
            companionVoiceEnabled = config.voiceEnabled
            companionVoiceOutputMode = VoiceOutputMode(rawValue: config.voiceOutputMode) ?? .copyToClipboard
            companionVoiceSaveToInbox = config.voiceSaveToInbox
            companionShortcutsEnabled = config.shortcutsEnabled
            companionCaptureEnabled = config.captureEnabled
            companionCollapsedContentSettings = .default
        }

        // 从 PermissionManager 获取真实权限状态
        await permissionManager.refreshAll()
        microphonePermissionStatus = mapToCompanionStatus(permissionManager.statuses[.microphone] ?? .unknown)
        accessibilityPermissionStatus = mapToCompanionStatus(permissionManager.statuses[.accessibility] ?? .unknown)
        screenRecordingPermissionStatus = mapToCompanionStatus(permissionManager.statuses[.screenRecording] ?? .unknown)
    }

    // MARK: - Save Settings

    public func saveSettings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // App Settings
            var appSettings = AppSettings()
            appSettings.theme = theme
            appSettings.language = language
            appSettings.defaultProviderId = defaultProviderId.isEmpty ? nil : defaultProviderId
            appSettings.defaultModelId = defaultModelId.isEmpty ? nil : defaultModelId
            appSettings.vaultPath = vaultPath
            appSettings.autoCaptureClipboard = autoCaptureClipboard
            appSettings.captureScreenshotHotkey = captureScreenshotHotkey.isEmpty ? nil : captureScreenshotHotkey
            appSettings.defaultExportTarget = defaultExportTarget
            appSettings.autoFrontmatter = autoFrontmatter
            try await settings.updateSettings(appSettings)

            // Vault Config
            var vaultConfig = VaultConfig()
            vaultConfig.vaultPath = vaultPath
            vaultConfig.defaultFolder = vaultDefaultFolder
            vaultConfig.pathRule = vaultPathRule
            vaultConfig.conflictStrategy = vaultConflictStrategy
            vaultConfig.autoFrontmatter = autoFrontmatter
            try await settings.updateVaultConfig(vaultConfig)

            // Voice Settings
            let voiceSettings = VoiceSettings(
                defaultProvider: voiceDefaultProvider,
                defaultLanguage: voiceDefaultLanguage,
                autoPolish: voiceAutoPolish,
                voicePolishMode: voicePolishMode
            )
            try await settings.updateVoiceSettings(voiceSettings)

            // 保存随身配置
            await saveCompanionSettings()

        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func saveCompanionSettings() async {
            let config = CompanionConfiguration(
            capsuleEnabled: companionCapsuleEnabled,
            capsulePosition: companionCapsulePosition.rawValue,
            capsuleExpandedByDefault: companionCapsuleExpanded,
            voiceEnabled: companionVoiceEnabled,
            voiceShortcut: "⌥Space",
            voiceOutputMode: companionVoiceOutputMode.rawValue,
            voiceSaveToInbox: companionVoiceSaveToInbox,
            shortcutsEnabled: companionShortcutsEnabled,
            captureEnabled: companionCaptureEnabled
        )
        do {
            let jsonData = try JSONEncoder().encode(config)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            try await storage.setSetting(key: "companion_config", value: jsonString)

            let collapsedData = try JSONEncoder().encode(companionCollapsedContentSettings)
            UserDefaults.standard.set(collapsedData, forKey: CompanionCollapsedContentStorage.key)
            NotificationCenter.default.post(name: .companionCollapsedContentSettingsChanged, object: nil)
        } catch {
            showError(message: "保存随身配置失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Vault Path

    public func selectVaultPath() async {
        if let path = await settings.selectVaultPath() {
            vaultPath = path
            await saveSettings()
        }
    }

    public func validateVaultPath() -> Bool {
        !vaultPath.isEmpty && FileManager.default.fileExists(atPath: vaultPath)
    }

    // MARK: - Permissions

    /// 刷新所有权限状态（从 PermissionManager 读取最新状态）
    public func refreshPermissionsFromManager() {
        microphoneStatus = permissionManager.statuses[.microphone] ?? .unknown
        screenRecordingStatus = permissionManager.statuses[.screenRecording] ?? .unknown
        accessibilityStatus = permissionManager.statuses[.accessibility] ?? .unknown
        fullDiskAccessStatus = permissionManager.statuses[.fullDiskAccess] ?? .unknown
        notificationsStatus = permissionManager.statuses[.notifications] ?? .unknown
    }

    public func loadPermissions() async {
        await permissionManager.refreshAll()
        refreshPermissionsFromManager()
    }

    public func requestPermission(_ permission: SystemPermission) async {
        let kind = permission.toAppPermissionKind
        await permissionManager.request(kind)
        refreshPermissionsFromManager()
    }

    public func openSystemPreferences(for permission: SystemPermission) async {
        permissionManager.openSettingsFor(permission.toAppPermissionKind)
    }

    // MARK: - Providers

    public func loadProviders() async {
        do {
            providers = try await settings.listProviders()
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func addProvider(_ config: ProviderConfig) async {
        do {
            try await settings.addProvider(config)
            await loadProviders()
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func updateProvider(_ config: ProviderConfig) async {
        do {
            try await settings.updateProvider(config)
            await loadProviders()
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func removeProvider(id: String) async {
        do {
            try await settings.removeProvider(id: id)
            await loadProviders()
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    // MARK: - Error Handling

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    public func clearError() {
        errorMessage = nil
        showError = false
    }

    // MARK: - Status Mapping

    private func mapToCompanionStatus(_ status: AppPermissionStatus) -> CompanionPermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied, .failed:
            return .denied
        case .restricted:
            return .restricted
        case .unknown, .notDetermined, .requesting, .needsSystemSettings:
            return .notDetermined
        }
    }
}
