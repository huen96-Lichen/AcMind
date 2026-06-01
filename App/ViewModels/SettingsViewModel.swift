import Foundation
import SwiftUI
import AppKit
import Darwin
import UniformTypeIdentifiers
import AcMindKit

public struct SettingsUsageSummary: Equatable, Sendable {
    public var sourceItems: Int
    public var distilledNotes: Int
    public var exportRecords: Int
    public var clipboardItems: Int
    public var providers: Int

    public static let empty = SettingsUsageSummary(
        sourceItems: 0,
        distilledNotes: 0,
        exportRecords: 0,
        clipboardItems: 0,
        providers: 0
    )
}

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
    @Published public var modelRoutingStrategy: ModelRoutingStrategy = .automatic
    @Published public var vaultPath: String = ""
    @Published public var autoCaptureClipboard: Bool = true
    @Published public var captureScreenshotHotkey: String = ""
    @Published public var defaultExportTarget: ExportTarget = .obsidian
    @Published public var autoFrontmatter: Bool = true
    @Published public var autoBackupEnabled: Bool = true
    @Published public var restoreWindowPosition: Bool = true
    @Published public var notificationsEnabled: Bool = true
    @Published public var taskCompletedNotificationsEnabled: Bool = true
    @Published public var updateAvailableNotificationsEnabled: Bool = true

    // Vault Config
    @Published public var vaultDefaultFolder: String = "Inbox"
    @Published public var vaultPathRule: VaultConfig.VaultPathRule = .categoryDate
    @Published public var vaultConflictStrategy: ConflictStrategy = .rename
    @Published public var vaultFrontmatterTemplateText: String = "{}"

    // Voice Settings
    @Published public var voiceDefaultProvider: String = "whisper"
    @Published public var voiceDefaultLanguage: String = "zh"
    @Published public var voiceAutoPolish: Bool = true
    @Published public var voicePolishMode: VoicePolishMode = .light
    @Published public var voiceTriggerMode: SayInputTriggerMode = .hold
    @Published public var voiceSilenceTimeout: TimeInterval = 3.0
    @Published public var voiceEnableSilenceDetection: Bool = false
    @Published public var voiceOutputMode: SayInputOutputMode = .copyToClipboard
    @Published public var voiceSaveToInbox: Bool = true
    @Published public var voiceAllowContinuation: Bool = true
    @Published public var voiceContinuationWindow: TimeInterval = 12.0
    @Published public var aiPromptStyle: AIPromptStyle = .general
    @Published public var enablePunctuationAppend: Bool = false
    @Published public var injectionStrategy: String = "postToPid"
    @Published public var enableCloudSync: Bool = false
    @Published public var preferredLanguage: String = "auto"

    // Capture Settings
    @Published public var autoRedactFaces: Bool = true
    @Published public var autoDetectPII: Bool = true
    @Published public var enabledRedactionTypes: Set<RedactionType> = Set(RedactionType.allCases)
    @Published public var censorMode: CensorMode = .pixelate
    @Published public var scrollCaptureAutoScroll: Bool = true
    @Published public var scrollCaptureSpeed: Double = 3
    @Published public var scrollCaptureMaxHeight: Int = 30000
    @Published public var captureOnlyWhenAppActive: Bool = false
    @Published public var captureScreenshotEnabled: Bool = true
    @Published public var voiceInputEnabled: Bool = true
    @Published public var localFirstMode: Bool = true
    @Published public var sensitiveContentNotUpload: Bool = true
    @Published public var apiKeyUsesKeychain: Bool = true
    @Published public var aiCallLogEnabled: Bool = true
    @Published public var errorLogEnabled: Bool = true
    private var lastAutoBackupAt: Date?

    // 随身设置
    @Published public var companionCapsuleEnabled: Bool = true
    @Published public var companionCapsuleShowOnLaunch: Bool = true
    @Published public var companionCapsulePosition: CompanionCapsulePosition = .topCenter
    @Published public var companionCapsuleExpanded: Bool = false
    @Published public var companionVoiceEnabled: Bool = true
    @Published public var companionVoiceShortcut: String = "⌥Space"
    @Published public var companionVoiceOutputMode: VoiceOutputMode = .copyToClipboard
    @Published public var companionVoiceSaveToInbox: Bool = true
    @Published public var companionShortcutsEnabled: Bool = true
    @Published public var companionShortcuts: [CompanionShortcut] = CompanionShortcut.defaultShortcuts
    @Published public var companionCaptureEnabled: Bool = true
    @Published public var companionScreenshotShortcut: String = "⌘⇧4"
    @Published public var companionCaptureShortcut: String = "⌘⇧C"
    @Published public var companionAgentShortcut: String = "⌘1"
    @Published public var companionScheduleShortcut: String = "⌘4"
    @Published public var companionCaptureAutoSaveToInbox: Bool = true
    @Published public var companionCaptureTextEnabled: Bool = true
    @Published public var companionCaptureLinkEnabled: Bool = true
    @Published public var companionCaptureSaveDestinationIndex: Int = 0

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
    @Published public var usageSummary: SettingsUsageSummary = .empty
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
            await loadUsageSummary()
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
        modelRoutingStrategy = appSettings.modelRoutingStrategy
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
        vaultFrontmatterTemplateText = Self.encodeFrontmatterTemplate(vaultConfig.frontmatterTemplate)

        // Voice Settings
        let voiceSettings = await settings.getVoiceSettings()
        voiceDefaultProvider = voiceSettings.defaultProvider
        voiceDefaultLanguage = voiceSettings.defaultLanguage
        voiceAutoPolish = voiceSettings.autoPolish
        voicePolishMode = voiceSettings.voicePolishMode
        voiceTriggerMode = voiceSettings.triggerMode
        voiceSilenceTimeout = voiceSettings.silenceTimeout
        voiceEnableSilenceDetection = voiceSettings.enableSilenceDetection
        voiceOutputMode = voiceSettings.outputMode
        voiceSaveToInbox = voiceSettings.saveToInbox
        voiceAllowContinuation = voiceSettings.allowContinuation
        voiceContinuationWindow = voiceSettings.continuationWindow
        enablePunctuationAppend = voiceSettings.enablePunctuationAppend
        injectionStrategy = voiceSettings.injectionStrategy
        enableCloudSync = voiceSettings.enableCloudSync
        preferredLanguage = voiceSettings.preferredLanguage

        loadLocalPreferences()
    }

    // MARK: - Companion Settings

    public func loadCompanionSettings() async {
        do {
            if let jsonString = try await storage.getSetting(key: "companion_config"),
               let jsonData = jsonString.data(using: .utf8),
               let config = try? JSONDecoder().decode(CompanionConfiguration.self, from: jsonData) {
                companionCapsuleEnabled = config.capsuleEnabled
                companionCapsuleShowOnLaunch = config.capsuleShowOnLaunch
                companionCapsulePosition = CompanionCapsulePosition(rawValue: config.capsulePosition) ?? .topCenter
                companionCapsuleExpanded = config.capsuleExpandedByDefault
                companionVoiceEnabled = config.voiceEnabled
                companionVoiceShortcut = config.voiceShortcut
                companionVoiceOutputMode = VoiceOutputMode(rawValue: config.voiceOutputMode) ?? .copyToClipboard
                companionVoiceSaveToInbox = config.voiceSaveToInbox
                voiceOutputMode = companionVoiceOutputMode.asSayInputOutputMode
                voiceSaveToInbox = companionVoiceSaveToInbox
                companionShortcutsEnabled = config.shortcutsEnabled
                companionCaptureEnabled = config.captureEnabled
                companionScreenshotShortcut = config.captureScreenshotShortcut
                companionCaptureShortcut = config.captureShortcut
                companionAgentShortcut = config.agentShortcut
                companionScheduleShortcut = config.scheduleShortcut
                companionCaptureAutoSaveToInbox = config.captureAutoSaveToInbox
                companionCaptureTextEnabled = config.captureTextEnabled
                companionCaptureLinkEnabled = config.captureLinkEnabled
                companionCaptureSaveDestinationIndex = config.captureSaveDestinationIndex
            } else {
                let config = CompanionConfiguration.default
                companionCapsuleEnabled = config.capsuleEnabled
                companionCapsuleShowOnLaunch = config.capsuleShowOnLaunch
                companionCapsulePosition = CompanionCapsulePosition(rawValue: config.capsulePosition) ?? .topCenter
                companionCapsuleExpanded = config.capsuleExpandedByDefault
                companionVoiceEnabled = config.voiceEnabled
                companionVoiceShortcut = config.voiceShortcut
                companionVoiceOutputMode = VoiceOutputMode(rawValue: config.voiceOutputMode) ?? .copyToClipboard
                companionVoiceSaveToInbox = config.voiceSaveToInbox
                voiceOutputMode = companionVoiceOutputMode.asSayInputOutputMode
                voiceSaveToInbox = companionVoiceSaveToInbox
                companionShortcutsEnabled = config.shortcutsEnabled
                companionCaptureEnabled = config.captureEnabled
                companionScreenshotShortcut = config.captureScreenshotShortcut
                companionCaptureShortcut = config.captureShortcut
                companionAgentShortcut = config.agentShortcut
                companionScheduleShortcut = config.scheduleShortcut
                companionCaptureAutoSaveToInbox = config.captureAutoSaveToInbox
                companionCaptureTextEnabled = config.captureTextEnabled
                companionCaptureLinkEnabled = config.captureLinkEnabled
                companionCaptureSaveDestinationIndex = config.captureSaveDestinationIndex
            }
        } catch {
            let config = CompanionConfiguration.default
            companionCapsuleEnabled = config.capsuleEnabled
            companionCapsuleShowOnLaunch = config.capsuleShowOnLaunch
            companionCapsulePosition = CompanionCapsulePosition(rawValue: config.capsulePosition) ?? .topCenter
            companionCapsuleExpanded = config.capsuleExpandedByDefault
            companionVoiceEnabled = config.voiceEnabled
            companionVoiceShortcut = config.voiceShortcut
            companionVoiceOutputMode = VoiceOutputMode(rawValue: config.voiceOutputMode) ?? .copyToClipboard
            companionVoiceSaveToInbox = config.voiceSaveToInbox
            voiceOutputMode = companionVoiceOutputMode.asSayInputOutputMode
            voiceSaveToInbox = companionVoiceSaveToInbox
            companionShortcutsEnabled = config.shortcutsEnabled
            companionCaptureEnabled = config.captureEnabled
            companionScreenshotShortcut = config.captureScreenshotShortcut
            companionCaptureShortcut = config.captureShortcut
            companionAgentShortcut = config.agentShortcut
            companionScheduleShortcut = config.scheduleShortcut
            companionCaptureAutoSaveToInbox = config.captureAutoSaveToInbox
            companionCaptureTextEnabled = config.captureTextEnabled
            companionCaptureLinkEnabled = config.captureLinkEnabled
            companionCaptureSaveDestinationIndex = config.captureSaveDestinationIndex
        }

        companionShortcuts = await loadCompanionShortcuts()

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
            appSettings.modelRoutingStrategy = modelRoutingStrategy
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
            vaultConfig.frontmatterTemplate = try decodeFrontmatterTemplate(vaultFrontmatterTemplateText)
            try await settings.updateVaultConfig(vaultConfig)

            // Voice Settings
            let voiceSettings = VoiceSettings(
                defaultProvider: voiceDefaultProvider,
                defaultLanguage: voiceDefaultLanguage,
                autoPolish: voiceAutoPolish,
                voicePolishMode: voicePolishMode,
                triggerMode: voiceTriggerMode,
                silenceTimeout: voiceSilenceTimeout,
                enableSilenceDetection: voiceEnableSilenceDetection,
                outputMode: voiceOutputMode,
                saveToInbox: voiceSaveToInbox,
                allowContinuation: voiceAllowContinuation,
                continuationWindow: voiceContinuationWindow,
                enablePunctuationAppend: enablePunctuationAppend,
                injectionStrategy: injectionStrategy,
                enableCloudSync: enableCloudSync,
                preferredLanguage: preferredLanguage
            )
            try await settings.updateVoiceSettings(voiceSettings)

            // 保存随身配置
            await saveCompanionSettings()
            saveLocalPreferences()
            await performAutomaticBackupIfNeeded()

        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func saveCompanionSettings() async {
        let config = CompanionConfiguration(
            capsuleEnabled: companionCapsuleEnabled,
            capsuleShowOnLaunch: companionCapsuleShowOnLaunch,
            capsulePosition: companionCapsulePosition.rawValue,
                capsuleExpandedByDefault: companionCapsuleExpanded,
            voiceEnabled: companionVoiceEnabled,
            voiceShortcut: companionVoiceShortcut,
            voiceOutputMode: voiceOutputMode.asCompanionOutputMode.rawValue,
            voiceSaveToInbox: voiceSaveToInbox,
            shortcutsEnabled: companionShortcutsEnabled,
            captureEnabled: companionCaptureEnabled,
            captureScreenshotShortcut: companionScreenshotShortcut,
            captureShortcut: companionCaptureShortcut,
            agentShortcut: companionAgentShortcut,
            scheduleShortcut: companionScheduleShortcut,
            captureAutoSaveToInbox: companionCaptureAutoSaveToInbox,
            captureTextEnabled: companionCaptureTextEnabled,
                captureLinkEnabled: companionCaptureLinkEnabled,
                captureSaveDestinationIndex: companionCaptureSaveDestinationIndex
            )
            do {
                let jsonData = try JSONEncoder().encode(config)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
                try await storage.setSetting(key: "companion_config", value: jsonString)
                try await saveCompanionShortcuts()
        } catch {
            showError(message: "保存随身配置失败: \(error.localizedDescription)")
        }
    }

    private enum CompanionShortcutStorageKey {
        static let storage = "companion.shortcuts.v1"
    }

    private func loadCompanionShortcuts() async -> [CompanionShortcut] {
        do {
            if let jsonString = try await storage.getSetting(key: CompanionShortcutStorageKey.storage),
               let jsonData = jsonString.data(using: .utf8),
               let shortcuts = try? JSONDecoder().decode([CompanionShortcut].self, from: jsonData) {
                return shortcuts
            }
        } catch {
            // fall back to defaults
        }
        return CompanionShortcut.defaultShortcuts
    }

    private func saveCompanionShortcuts() async throws {
        let jsonData = try JSONEncoder().encode(companionShortcuts)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
        try await storage.setSetting(key: CompanionShortcutStorageKey.storage, value: jsonString)
    }

    public func currentSayInputConfiguration() -> SayInputConfiguration {
        SayInputConfiguration(
            autoPolish: voiceAutoPolish,
            polishMode: voicePolishMode,
            outputMode: voiceOutputMode,
            saveToInbox: voiceSaveToInbox,
            allowContinuation: voiceAllowContinuation,
            continuationWindow: voiceContinuationWindow,
            triggerMode: voiceTriggerMode,
            silenceTimeout: voiceSilenceTimeout,
            enableSilenceDetection: voiceEnableSilenceDetection,
            preferredLanguage: preferredLanguage
        )
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

    public func loadUsageSummary() async {
        do {
            async let sourceItemsTask = storage.listSourceItems(filter: nil)
            async let distilledNotesTask = storage.listDistilledNotes()
            async let exportRecordsTask = storage.listExportRecords()
            async let clipboardItemsTask = storage.listClipboardItems(limit: nil)
            async let providersTask = settings.listProviders()

            usageSummary = SettingsUsageSummary(
                sourceItems: (try await sourceItemsTask).count,
                distilledNotes: (try await distilledNotesTask).count,
                exportRecords: (try await exportRecordsTask).count,
                clipboardItems: (try await clipboardItemsTask).count,
                providers: (try await providersTask).count
            )
        } catch {
            usageSummary = .empty
        }
    }

    public func addProvider(_ config: ProviderConfig, apiKey: String? = nil) async {
        do {
            try await settings.addProvider(config, apiKey: apiKey)
            await loadProviders()
            await loadUsageSummary()
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func updateProvider(_ config: ProviderConfig, apiKey: String? = nil) async {
        do {
            try await settings.updateProvider(config, apiKey: apiKey)
            await loadProviders()
            await loadUsageSummary()
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func removeProvider(id: String) async {
        do {
            try await settings.removeProvider(id: id)
            await loadProviders()
            await loadUsageSummary()
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

    public func openLogsFolder() {
        let url = Self.applicationSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    public func openBackupsFolder() {
        let url = Self.applicationSupportDirectory.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    public func openReleasesPage() {
        guard let url = URL(string: "https://github.com/huen96-Lichen/AcMind/releases") else { return }
        NSWorkspace.shared.open(url)
    }

    public func openFeedbackPage() {
        guard let url = URL(string: "https://github.com/huen96-Lichen/AcMind/issues") else { return }
        NSWorkspace.shared.open(url)
    }

    public func openLicensePage() {
        guard let url = URL(string: "https://github.com/huen96-Lichen/AcMind/blob/main/LICENSE") else { return }
        NSWorkspace.shared.open(url)
    }

    public func copyDiagnosticsToPasteboard() {
        let diagnostics = """
        AcMind Diagnostics
        Time: \(ISO8601DateFormatter().string(from: Date()))
        App Version: \(diagnosticAppVersionString)
        macOS: \(diagnosticMacOSVersionString)
        Device: \(diagnosticDeviceModelString)
        Processor: \(diagnosticProcessorString)
        Memory: \(diagnosticMemoryString)
        Theme: \(theme.displayName)
        Language: \(language)
        Vault Path: \(vaultPath.isEmpty ? "未设置" : vaultPath)
        Default Provider: \(defaultProviderId.isEmpty ? "未设置" : defaultProviderId)
        Default Model: \(defaultModelId.isEmpty ? "未设置" : defaultModelId)
        Providers: \(usageSummary.providers)
        Companion Capsule: \(companionCapsuleEnabled ? "enabled" : "disabled")
        Companion Voice: \(companionVoiceEnabled ? "enabled" : "disabled")
        Auto Capture: \(autoCaptureClipboard ? "enabled" : "disabled")
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
    }

    public var diagnosticAppVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "未知"
        let build = info?["CFBundleVersion"] as? String ?? "未知"
        return "\(version) (\(build))"
    }

    public var diagnosticMacOSVersionString: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    public var diagnosticDeviceModelString: String {
        Self.sysctlString(for: "hw.model") ?? "未知设备"
    }

    public var diagnosticProcessorString: String {
        Self.sysctlString(for: "machdep.cpu.brand_string") ?? "Apple Silicon"
    }

    public var diagnosticMemoryString: String {
        let totalGB = ProcessInfo.processInfo.physicalMemory / 1_073_741_824
        return "\(totalGB) GB Unified Memory"
    }

    private static func sysctlString(for name: String) -> String? {
        var size: size_t = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
            return nil
        }
        return String(cString: buffer)
    }

    public func createBackup() async {
        let snapshot = makeBackupSnapshot()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(snapshot)
            let folder = Self.applicationSupportDirectory.appendingPathComponent("Backups", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let fileURL = folder.appendingPathComponent("AcMind-backup-\(formatter.string(from: Date())).json")
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            showError(message: "创建备份失败: \(error.localizedDescription)")
        }
    }

    public func restoreBackup() async {
        await MainActor.run {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.json]
            panel.prompt = "恢复备份"
            panel.message = "选择 AcMind 备份 JSON 文件"

            guard panel.runModal() == .OK, let url = panel.url else { return }

            do {
                let data = try Data(contentsOf: url)
                let snapshot = try JSONDecoder().decode(BackupSnapshot.self, from: data)
                applyBackupSnapshot(snapshot)
            } catch {
                showError(message: "恢复备份失败: \(error.localizedDescription)")
            }
        }
    }

    public var databaseDirectoryPath: String {
        storage.getDatabasePath()
    }

    public var assetsDirectoryPath: String {
        Self.applicationSupportDirectory
            .appendingPathComponent("assets", isDirectory: true)
            .path
    }

    // MARK: - Local Preferences

    private func loadLocalPreferences() {
        guard let decoded = SettingsLocalPreferences.load() else {
            return
        }

        applyLocalPreferences(decoded)
    }

    private func saveLocalPreferences() {
        let prefs = SettingsLocalPreferences(
            autoBackupEnabled: autoBackupEnabled,
            lastAutoBackupAt: lastAutoBackupAt,
            restoreWindowPosition: restoreWindowPosition,
            notificationsEnabled: notificationsEnabled,
            taskCompletedNotificationsEnabled: taskCompletedNotificationsEnabled,
            updateAvailableNotificationsEnabled: updateAvailableNotificationsEnabled,
            captureOnlyWhenAppActive: captureOnlyWhenAppActive,
            captureScreenshotEnabled: captureScreenshotEnabled,
            voiceInputEnabled: voiceInputEnabled,
            localFirstMode: localFirstMode,
            sensitiveContentNotUpload: sensitiveContentNotUpload,
            apiKeyUsesKeychain: apiKeyUsesKeychain,
            aiCallLogEnabled: aiCallLogEnabled,
            errorLogEnabled: errorLogEnabled
        )

        prefs.save()
    }

    private func performAutomaticBackupIfNeeded() async {
        guard SettingsBackupPolicy.shouldPerformAutomaticBackup(
            enabled: autoBackupEnabled,
            lastAutoBackupAt: lastAutoBackupAt,
            now: Date()
        ) else {
            return
        }

        await createBackup()
        lastAutoBackupAt = Date()
        saveLocalPreferences()
    }

    private struct BackupSnapshot: Codable {
        var appSettings: AppSettings
        var vaultConfig: VaultConfig
        var voiceSettings: VoiceSettings
        var companionConfiguration: CompanionConfiguration
        var companionShortcuts: [CompanionShortcut]
        var localPreferences: SettingsLocalPreferences
    }

    private func makeBackupSnapshot() -> BackupSnapshot {
        let appSettings = AppSettings(
            theme: theme,
            language: language,
            defaultProviderId: defaultProviderId.isEmpty ? nil : defaultProviderId,
            defaultModelId: defaultModelId.isEmpty ? nil : defaultModelId,
            modelRoutingStrategy: modelRoutingStrategy,
            vaultPath: vaultPath,
            autoCaptureClipboard: autoCaptureClipboard,
            captureScreenshotHotkey: captureScreenshotHotkey.isEmpty ? nil : captureScreenshotHotkey,
            defaultExportTarget: defaultExportTarget,
            autoFrontmatter: autoFrontmatter
        )

        let vaultConfig = VaultConfig(
            vaultPath: vaultPath,
            defaultFolder: vaultDefaultFolder,
            template: "",
            pathRule: vaultPathRule,
            conflictStrategy: vaultConflictStrategy,
            autoFrontmatter: autoFrontmatter,
            frontmatterTemplate: (try? decodeFrontmatterTemplate(vaultFrontmatterTemplateText)) ?? [:]
        )

        let voiceSettings = VoiceSettings(
            defaultProvider: voiceDefaultProvider,
            defaultLanguage: voiceDefaultLanguage,
            autoPolish: voiceAutoPolish,
            voicePolishMode: voicePolishMode,
            triggerMode: voiceTriggerMode,
            silenceTimeout: voiceSilenceTimeout,
            enableSilenceDetection: voiceEnableSilenceDetection,
            outputMode: voiceOutputMode,
            saveToInbox: voiceSaveToInbox,
            allowContinuation: voiceAllowContinuation,
            continuationWindow: voiceContinuationWindow,
            enablePunctuationAppend: enablePunctuationAppend,
            injectionStrategy: injectionStrategy,
            enableCloudSync: enableCloudSync,
            preferredLanguage: preferredLanguage
        )

        let companionConfiguration = CompanionConfiguration(
            capsuleEnabled: companionCapsuleEnabled,
            capsuleShowOnLaunch: companionCapsuleShowOnLaunch,
            capsulePosition: companionCapsulePosition.rawValue,
            capsuleExpandedByDefault: companionCapsuleExpanded,
            voiceEnabled: companionVoiceEnabled,
            voiceShortcut: companionVoiceShortcut,
            voiceOutputMode: voiceOutputMode.asCompanionOutputMode.rawValue,
            voiceSaveToInbox: voiceSaveToInbox,
            shortcutsEnabled: companionShortcutsEnabled,
            captureEnabled: companionCaptureEnabled,
            captureAutoSaveToInbox: companionCaptureAutoSaveToInbox,
            captureTextEnabled: companionCaptureTextEnabled,
            captureLinkEnabled: companionCaptureLinkEnabled,
            captureSaveDestinationIndex: companionCaptureSaveDestinationIndex
        )

        return BackupSnapshot(
            appSettings: appSettings,
            vaultConfig: vaultConfig,
            voiceSettings: voiceSettings,
            companionConfiguration: companionConfiguration,
            companionShortcuts: companionShortcuts,
            localPreferences: SettingsLocalPreferences(
                autoBackupEnabled: autoBackupEnabled,
                restoreWindowPosition: restoreWindowPosition,
                notificationsEnabled: notificationsEnabled,
                taskCompletedNotificationsEnabled: taskCompletedNotificationsEnabled,
                updateAvailableNotificationsEnabled: updateAvailableNotificationsEnabled,
                captureOnlyWhenAppActive: captureOnlyWhenAppActive,
                captureScreenshotEnabled: captureScreenshotEnabled,
                voiceInputEnabled: voiceInputEnabled,
                localFirstMode: localFirstMode,
                sensitiveContentNotUpload: sensitiveContentNotUpload,
                apiKeyUsesKeychain: apiKeyUsesKeychain,
                aiCallLogEnabled: aiCallLogEnabled,
                errorLogEnabled: errorLogEnabled
            )
        )
    }

    private func applyBackupSnapshot(_ snapshot: BackupSnapshot) {
        theme = snapshot.appSettings.theme
        language = snapshot.appSettings.language
        defaultProviderId = snapshot.appSettings.defaultProviderId ?? ""
        defaultModelId = snapshot.appSettings.defaultModelId ?? ""
        modelRoutingStrategy = snapshot.appSettings.modelRoutingStrategy
        vaultPath = snapshot.appSettings.vaultPath
        autoCaptureClipboard = snapshot.appSettings.autoCaptureClipboard
        captureScreenshotHotkey = snapshot.appSettings.captureScreenshotHotkey ?? ""
        defaultExportTarget = snapshot.appSettings.defaultExportTarget
        autoFrontmatter = snapshot.appSettings.autoFrontmatter

        vaultDefaultFolder = snapshot.vaultConfig.defaultFolder
        vaultPathRule = snapshot.vaultConfig.pathRule
        vaultConflictStrategy = snapshot.vaultConfig.conflictStrategy
        autoFrontmatter = snapshot.vaultConfig.autoFrontmatter
        vaultFrontmatterTemplateText = Self.encodeFrontmatterTemplate(snapshot.vaultConfig.frontmatterTemplate)

        voiceDefaultProvider = snapshot.voiceSettings.defaultProvider
        voiceDefaultLanguage = snapshot.voiceSettings.defaultLanguage
        voiceAutoPolish = snapshot.voiceSettings.autoPolish
        voicePolishMode = snapshot.voiceSettings.voicePolishMode
        voiceTriggerMode = snapshot.voiceSettings.triggerMode
        voiceSilenceTimeout = snapshot.voiceSettings.silenceTimeout
        voiceEnableSilenceDetection = snapshot.voiceSettings.enableSilenceDetection
        voiceOutputMode = snapshot.voiceSettings.outputMode
        voiceSaveToInbox = snapshot.voiceSettings.saveToInbox
        voiceAllowContinuation = snapshot.voiceSettings.allowContinuation
        voiceContinuationWindow = snapshot.voiceSettings.continuationWindow
        enablePunctuationAppend = snapshot.voiceSettings.enablePunctuationAppend
        injectionStrategy = snapshot.voiceSettings.injectionStrategy
        enableCloudSync = snapshot.voiceSettings.enableCloudSync
        preferredLanguage = snapshot.voiceSettings.preferredLanguage

        companionCapsuleEnabled = snapshot.companionConfiguration.capsuleEnabled
        companionCapsuleShowOnLaunch = snapshot.companionConfiguration.capsuleShowOnLaunch
        companionCapsulePosition = CompanionCapsulePosition(rawValue: snapshot.companionConfiguration.capsulePosition) ?? .topCenter
        companionCapsuleExpanded = snapshot.companionConfiguration.capsuleExpandedByDefault
        companionVoiceEnabled = snapshot.companionConfiguration.voiceEnabled
        companionVoiceShortcut = snapshot.companionConfiguration.voiceShortcut
        companionVoiceOutputMode = VoiceOutputMode(rawValue: snapshot.companionConfiguration.voiceOutputMode) ?? .copyToClipboard
        companionVoiceSaveToInbox = snapshot.companionConfiguration.voiceSaveToInbox
        companionShortcutsEnabled = snapshot.companionConfiguration.shortcutsEnabled
        companionCaptureEnabled = snapshot.companionConfiguration.captureEnabled
        companionScreenshotShortcut = snapshot.companionConfiguration.captureScreenshotShortcut
        companionCaptureShortcut = snapshot.companionConfiguration.captureShortcut
        companionAgentShortcut = snapshot.companionConfiguration.agentShortcut
        companionScheduleShortcut = snapshot.companionConfiguration.scheduleShortcut
        companionCaptureAutoSaveToInbox = snapshot.companionConfiguration.captureAutoSaveToInbox
        companionCaptureTextEnabled = snapshot.companionConfiguration.captureTextEnabled
        companionCaptureLinkEnabled = snapshot.companionConfiguration.captureLinkEnabled
        companionCaptureSaveDestinationIndex = snapshot.companionConfiguration.captureSaveDestinationIndex
        companionShortcuts = snapshot.companionShortcuts

        applyLocalPreferences(snapshot.localPreferences)

        Task {
            await saveSettings()
        }
    }

    private func applyLocalPreferences(_ preferences: SettingsLocalPreferences) {
        autoBackupEnabled = preferences.autoBackupEnabled
        lastAutoBackupAt = preferences.lastAutoBackupAt
        restoreWindowPosition = preferences.restoreWindowPosition
        notificationsEnabled = preferences.notificationsEnabled
        taskCompletedNotificationsEnabled = preferences.taskCompletedNotificationsEnabled
        updateAvailableNotificationsEnabled = preferences.updateAvailableNotificationsEnabled
        captureOnlyWhenAppActive = preferences.captureOnlyWhenAppActive
        captureScreenshotEnabled = preferences.captureScreenshotEnabled
        voiceInputEnabled = preferences.voiceInputEnabled
        localFirstMode = preferences.localFirstMode
        sensitiveContentNotUpload = preferences.sensitiveContentNotUpload
        apiKeyUsesKeychain = preferences.apiKeyUsesKeychain
        aiCallLogEnabled = preferences.aiCallLogEnabled
        errorLogEnabled = preferences.errorLogEnabled
    }

    private static func encodeFrontmatterTemplate(_ template: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: template, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func decodeFrontmatterTemplate(_ text: String) throws -> [String: String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [:] }

        guard let data = trimmed.data(using: .utf8) else {
            throw NSError(domain: "AcMind.Settings", code: 1, userInfo: [NSLocalizedDescriptionKey: "Frontmatter 模板不是有效的 UTF-8 文本"])
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = object as? [String: Any] else {
            throw NSError(domain: "AcMind.Settings", code: 2, userInfo: [NSLocalizedDescriptionKey: "Frontmatter 模板必须是 JSON 对象"])
        }

        var result: [String: String] = [:]
        for (key, value) in dict {
            if let string = value as? String {
                result[key] = string
            } else if let convertible = value as? CustomStringConvertible {
                result[key] = convertible.description
            } else {
                result[key] = "\(value)"
            }
        }
        return result
    }

    private static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("AcMind", isDirectory: true)
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

private extension SayInputOutputMode {
    var asCompanionOutputMode: VoiceOutputMode {
        switch self {
        case .copyToClipboard: return .copyToClipboard
        case .autoPaste: return .autoPaste
        case .ask: return .ask
        }
    }
}

private extension VoiceOutputMode {
    var asSayInputOutputMode: SayInputOutputMode {
        switch self {
        case .copyToClipboard: return .copyToClipboard
        case .autoPaste: return .autoPaste
        case .ask: return .ask
        }
    }
}
