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
    @Published public var voicePolishMode: PolishMode = .standard
    
    // Permissions
    @Published public var microphoneStatus: PermissionStatus = .notDetermined
    @Published public var screenRecordingStatus: PermissionStatus = .notDetermined
    @Published public var accessibilityStatus: PermissionStatus = .notDetermined
    @Published public var fullDiskAccessStatus: PermissionStatus = .notDetermined
    @Published public var notificationsStatus: PermissionStatus = .notDetermined
    
    // Providers
    @Published public var providers: [ProviderConfig] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showError = false
    
    // MARK: - Initialization
    
    public init(settings: SettingsServiceProtocol? = nil) {
        self.settings = settings ?? ServiceContainer.shared.settingsService
        
        // 加载设置
        Task {
            await loadSettings()
            await loadPermissions()
            await loadProviders()
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
        voicePolishMode = voiceSettings.polishMode
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
                polishMode: voicePolishMode
            )
            try await settings.updateVoiceSettings(voiceSettings)
            
        } catch {
            showError(message: error.localizedDescription)
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
    
    public func loadPermissions() async {
        microphoneStatus = await settings.checkPermission(.microphone)
        screenRecordingStatus = await settings.checkPermission(.screenRecording)
        accessibilityStatus = await settings.checkPermission(.accessibility)
        fullDiskAccessStatus = await settings.checkPermission(.fullDiskAccess)
        notificationsStatus = await settings.checkPermission(.notifications)
    }
    
    public func requestPermission(_ permission: SystemPermission) async {
        do {
            try await settings.requestPermission(permission)
            await loadPermissions()
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    public func openSystemPreferences(for permission: SystemPermission) async {
        await settings.openSystemPreferences(for: permission)
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
}
