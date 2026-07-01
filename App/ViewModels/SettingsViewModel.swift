import Foundation
import SwiftUI
import AppKit
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
    nonisolated(unsafe) private var didBecomeActiveObserver: NSObjectProtocol?

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
    @Published public var voiceDefaultProvider: String = STTProvider.appleSpeech.rawValue
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
    @Published public var translationLanguage: String = "zh"
    @Published public var correctionRules: [CorrectionRule] = []
    @Published public var muteSystemAudioDuringRecording: Bool = false

    // Capture Settings
    @Published public var captureOnlyWhenAppActive: Bool = false
    @Published public var captureScreenshotEnabled: Bool = true
    @Published public var captureAutoRedactionEnabled: Bool = true
    @Published public var captureCensorMode: CensorMode = .pixelate
    @Published public var captureScreenshotCornerRadius: Double = 0
    @Published public var captureScreenshotMaxWidth: Double = 0
    @Published public var captureScreenshotMaxHeight: Double = 0
    @Published public var screenshotPresets: [ScreenshotPreset] = ScreenshotPreset.defaultPresets
    @Published public var selectedScreenshotPresetID: String = ScreenshotPreset.defaultPresets.first?.id ?? "default-save"
    @Published public var companionCaptureOpenDetailAfterCapture: Bool = false
    @Published public var companionCaptureShowNotification: Bool = true
    @Published public var voiceInputEnabled: Bool = true
    @Published public var localFirstMode: Bool = true
    @Published public var sensitiveContentNotUpload: Bool = true
    @Published public var apiKeyUsesKeychain: Bool = true
    @Published public var aiCallLogEnabled: Bool = true
    @Published public var errorLogEnabled: Bool = true
    private var lastAutoBackupAt: Date?
    @Published public var lastBackupAtText: String = "尚未备份"
    public var lastBackupAtDate: Date? { lastAutoBackupAt }

    // 随身设置
    @Published public var companionEnabled: Bool = true
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
    @Published public var isApplyingCompanionSettings: Bool = false

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
    @Published public var usageBurnSnapshot: UsageBurnSnapshot = .empty
    @Published public var isLoading = false
    @Published public var isCheckingForUpdates = false
    @Published public var errorMessage: String?
    @Published public var showError = false

    // MARK: - Initialization

    public init(settings: SettingsServiceProtocol? = nil, storage: StorageServiceProtocol? = nil) {
        self.storage = storage ?? StorageService()
        self.permissionManager = PermissionManager()
        self.settings = settings ?? SettingsService(
            storage: self.storage,
            permissionManager: self.permissionManager
        )

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshPermissionStatesFromManager()
            }
        }

        // 加载设置
        Task {
            await loadSettings()
            await loadPermissions()
            await loadProviders()
            await loadUsageSummary()
            await loadUsageBurnSnapshot()
            await loadCompanionSettings()
        }
    }

    deinit {
        if let observer = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
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
        voiceDefaultProvider = STTProvider.selectableIdentifier(from: voiceSettings.defaultProvider)
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
        translationLanguage = voiceSettings.translationLanguage
        correctionRules = voiceSettings.correctionRules
        muteSystemAudioDuringRecording = voiceSettings.muteSystemAudioDuringRecording

        loadLocalPreferences()
    }

    // MARK: - Companion Settings

    public func loadCompanionSettings() async {
        isApplyingCompanionSettings = true
        defer { isApplyingCompanionSettings = false }

        let config = await CompanionConfigurationStore.load(from: storage)
        apply(companionConfiguration: config)

        companionShortcuts = await loadCompanionShortcuts()

        // 从 PermissionManager 获取真实权限状态
        await permissionManager.refreshAll()
        refreshPermissionStatesFromManager()
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
                defaultProvider: STTProvider.selectableIdentifier(from: voiceDefaultProvider),
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
                preferredLanguage: preferredLanguage,
                translationLanguage: translationLanguage,
                correctionRules: correctionRules,
                muteSystemAudioDuringRecording: muteSystemAudioDuringRecording
            )
            try await settings.updateVoiceSettings(voiceSettings)

            // 保存随身配置
            let prevConfig = await CompanionConfigurationStore.load(from: storage)
            let prevVoiceShortcut = prevConfig.voiceShortcut
            await saveCompanionSettings()
            if prevVoiceShortcut != companionVoiceShortcut {
                (NSApp.delegate as? AppDelegate)?.unregisterVoiceShortcut(prevVoiceShortcut)
                (NSApp.delegate as? AppDelegate)?.registerVoiceShortcut(companionVoiceShortcut)
            }
            saveLocalPreferences()
            await performAutomaticBackupIfNeeded()

        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func saveCompanionSettings() async {
        let config = CompanionConfiguration(
            companionEnabled: companionEnabled,
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
            try await CompanionConfigurationStore.save(config, to: storage)
            try await saveCompanionShortcuts()
            NotificationCenter.default.post(name: .companionConfigurationDidChange, object: nil)
            NotificationCenter.default.post(name: .companionShortcutsDidChange, object: nil)
        } catch {
            showError(message: "保存随身配置失败: \(error.localizedDescription)")
        }
    }

    private func apply(companionConfiguration config: CompanionConfiguration) {
        companionEnabled = config.companionEnabled
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
            preferredLanguage: preferredLanguage,
            translationLanguage: translationLanguage,
            correctionRules: correctionRules,
            muteSystemAudioDuringRecording: muteSystemAudioDuringRecording,
            enablePunctuationAppend: enablePunctuationAppend,
            injectionStrategy: injectionStrategy
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
        refreshPermissionStatesFromManager()
    }

    public func loadPermissions() async {
        await permissionManager.refreshAll()
        refreshPermissionStatesFromManager()
    }

    public func requestPermission(_ permission: SystemPermission) async {
        let kind = permission.toAppPermissionKind
        await permissionManager.request(kind)
        refreshPermissionStatesFromManager()
    }

    public func openSystemPreferences(for permission: SystemPermission) async {
        permissionManager.openSettingsFor(permission.toAppPermissionKind)
    }

    private func refreshPermissionStatesFromManager() {
        let microphone = permissionManager.statuses[.microphone] ?? .unknown
        let screenRecording = permissionManager.statuses[.screenRecording] ?? .unknown
        let accessibility = permissionManager.statuses[.accessibility] ?? .unknown
        let fullDiskAccess = permissionManager.statuses[.fullDiskAccess] ?? .unknown
        let notifications = permissionManager.statuses[.notifications] ?? .unknown

        microphoneStatus = microphone
        screenRecordingStatus = screenRecording
        accessibilityStatus = accessibility
        fullDiskAccessStatus = fullDiskAccess
        notificationsStatus = notifications

        microphonePermissionStatus = mapToCompanionStatus(microphone)
        accessibilityPermissionStatus = mapToCompanionStatus(accessibility)
        screenRecordingPermissionStatus = mapToCompanionStatus(screenRecording)
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

    public func loadUsageBurnSnapshot() async {
        usageBurnSnapshot = await UsageBurnMonitor.shared.snapshot()
    }

    public func addProvider(_ config: ProviderConfig, apiKey: String? = nil) async {
        do {
            try await settings.addProvider(config, apiKey: apiKey)
            await loadProviders()
            await loadUsageSummary()
            await loadUsageBurnSnapshot()
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func updateProvider(_ config: ProviderConfig, apiKey: String? = nil) async {
        do {
            try await settings.updateProvider(config, apiKey: apiKey)
            await loadProviders()
            await loadUsageSummary()
            await loadUsageBurnSnapshot()
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func removeProvider(id: String) async {
        do {
            try await settings.removeProvider(id: id)
            await loadProviders()
            await loadUsageSummary()
            await loadUsageBurnSnapshot()
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

    public func checkForUpdates() async {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        if updateAvailableNotificationsEnabled {
            ToastManager.shared.show(.info, "正在检查更新...")
        }

        do {
            let latestVersion = try await fetchLatestReleaseVersion()
            let currentVersion = Self.currentAppVersion()

            guard let latestVersion, !latestVersion.isEmpty else {
                if updateAvailableNotificationsEnabled {
                    ToastManager.shared.show(.warning, "没有找到可用的发布版本")
                }
                return
            }

            if Self.isVersion(latestVersion, newerThan: currentVersion) {
                if updateAvailableNotificationsEnabled {
                    ToastManager.shared.show(.success, "发现新版本 \(latestVersion)")
                }
                openReleasesPage()
            } else {
                if updateAvailableNotificationsEnabled {
                    ToastManager.shared.show(.success, "当前已是最新版本 \(currentVersion)")
                }
            }
        } catch {
            if updateAvailableNotificationsEnabled {
                ToastManager.shared.show(.error, "检查更新失败: \(error.localizedDescription)")
            }
        }
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
        AcWork Diagnostics
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

    private func fetchLatestReleaseVersion() async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let tagsOutput = try Self.gitRemoteTags(
                        remote: "https://github.com/huen96-Lichen/AcMind.git"
                    )
                    let latestTag = Self.latestSemanticVersion(from: tagsOutput)
                    continuation.resume(returning: latestTag)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated private static func gitRemoteTags(remote: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["ls-remote", "--tags", remote]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "AcMind.UpdateCheck",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "无法读取远端标签"]
            )
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "AcMind.UpdateCheck",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法解析远端标签输出"]
            )
        }
        return output
    }

    nonisolated private static func latestSemanticVersion(from gitOutput: String) -> String? {
        let tags = gitOutput
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { return nil }
                let ref = String(parts[1])
                guard ref.hasPrefix("refs/tags/") else { return nil }
                let tag = ref.replacingOccurrences(of: "refs/tags/", with: "")
                    .replacingOccurrences(of: "^{}", with: "")
                return tag.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "vV")) }
            .filter { !$0.isEmpty }

        return tags.max { lhs, rhs in
            Self.compareVersion(lhs, rhs) == .orderedAscending
        }
    }

    nonisolated private static func currentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    nonisolated private static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = normalizedVersionParts(candidate)
        let currentParts = normalizedVersionParts(current)
        let count = max(candidateParts.count, currentParts.count)

        for index in 0..<count {
            let lhs = index < candidateParts.count ? candidateParts[index] : 0
            let rhs = index < currentParts.count ? currentParts[index] : 0
            if lhs != rhs {
                return lhs > rhs
            }
        }

        return false
    }

    nonisolated private static func compareVersion(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = normalizedVersionParts(lhs)
        let right = normalizedVersionParts(rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r {
                return l < r ? .orderedAscending : .orderedDescending
            }
        }

        return .orderedSame
    }

    nonisolated private static func normalizedVersionParts(_ version: String) -> [Int] {
        version
            .split(whereSeparator: { !"0123456789".contains($0) })
            .compactMap { Int($0) }
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
        let bytes = buffer.prefix(max(0, Int(size) - 1)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
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
            let fileURL = folder.appendingPathComponent("AcWork-backup-\(formatter.string(from: Date())).json")
            try data.write(to: fileURL, options: [.atomic])
            let now = Date()
            lastAutoBackupAt = now
            lastBackupAtText = Self.formatBackupDate(now)
            saveLocalPreferences()
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
            panel.message = "选择 AcWork 备份 JSON 文件"

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
            captureAutoRedactionEnabled: captureAutoRedactionEnabled,
            captureCensorModeRawValue: captureCensorMode.rawValue,
            captureScreenshotCornerRadius: captureScreenshotCornerRadius,
            captureScreenshotMaxWidth: captureScreenshotMaxWidth,
            captureScreenshotMaxHeight: captureScreenshotMaxHeight,
            screenshotPresets: normalizedScreenshotPresets(),
            selectedScreenshotPresetID: selectedScreenshotPresetID,
            companionCaptureAutoSaveToInbox: companionCaptureAutoSaveToInbox,
            companionCaptureOpenDetailAfterCapture: companionCaptureOpenDetailAfterCapture,
            companionCaptureShowNotification: companionCaptureShowNotification,
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
    }

    private static func formatBackupDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
            defaultProvider: STTProvider.selectableIdentifier(from: voiceDefaultProvider),
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
            preferredLanguage: preferredLanguage,
            translationLanguage: translationLanguage,
            correctionRules: correctionRules,
            muteSystemAudioDuringRecording: muteSystemAudioDuringRecording
        )

        let companionConfiguration = CompanionConfiguration(
            companionEnabled: companionEnabled,
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
                captureAutoRedactionEnabled: captureAutoRedactionEnabled,
                captureCensorModeRawValue: captureCensorMode.rawValue,
                captureScreenshotCornerRadius: captureScreenshotCornerRadius,
                captureScreenshotMaxWidth: captureScreenshotMaxWidth,
                captureScreenshotMaxHeight: captureScreenshotMaxHeight,
                screenshotPresets: normalizedScreenshotPresets(),
                selectedScreenshotPresetID: selectedScreenshotPresetID,
                companionCaptureAutoSaveToInbox: companionCaptureAutoSaveToInbox,
                companionCaptureOpenDetailAfterCapture: companionCaptureOpenDetailAfterCapture,
                companionCaptureShowNotification: companionCaptureShowNotification,
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

        voiceDefaultProvider = STTProvider.selectableIdentifier(from: snapshot.voiceSettings.defaultProvider)
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
        translationLanguage = snapshot.voiceSettings.translationLanguage
        correctionRules = snapshot.voiceSettings.correctionRules
        companionCapsuleEnabled = snapshot.companionConfiguration.capsuleEnabled
        companionCapsuleShowOnLaunch = snapshot.companionConfiguration.capsuleShowOnLaunch
        companionCapsulePosition = CompanionCapsulePosition(rawValue: snapshot.companionConfiguration.capsulePosition) ?? .topCenter
        companionCapsuleExpanded = snapshot.companionConfiguration.capsuleExpandedByDefault
        companionVoiceEnabled = snapshot.companionConfiguration.voiceEnabled
        companionVoiceShortcut = snapshot.companionConfiguration.voiceShortcut
        companionVoiceOutputMode = VoiceOutputMode(rawValue: snapshot.companionConfiguration.voiceOutputMode) ?? .copyToClipboard
        companionVoiceSaveToInbox = snapshot.companionConfiguration.voiceSaveToInbox
        companionEnabled = snapshot.companionConfiguration.companionEnabled
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
        lastBackupAtText = preferences.lastAutoBackupAt.map(Self.formatBackupDate) ?? "尚未备份"
        restoreWindowPosition = preferences.restoreWindowPosition
        notificationsEnabled = preferences.notificationsEnabled
        taskCompletedNotificationsEnabled = preferences.taskCompletedNotificationsEnabled
        updateAvailableNotificationsEnabled = preferences.updateAvailableNotificationsEnabled
        captureOnlyWhenAppActive = preferences.captureOnlyWhenAppActive
        captureScreenshotEnabled = preferences.captureScreenshotEnabled
        captureAutoRedactionEnabled = preferences.captureAutoRedactionEnabled
        captureCensorMode = preferences.captureCensorMode
        captureScreenshotCornerRadius = preferences.captureScreenshotCornerRadius
        captureScreenshotMaxWidth = preferences.captureScreenshotMaxWidth
        captureScreenshotMaxHeight = preferences.captureScreenshotMaxHeight
        screenshotPresets = preferences.screenshotPresets.isEmpty ? ScreenshotPreset.defaultPresets : preferences.screenshotPresets
        selectedScreenshotPresetID = preferences.selectedScreenshotPresetID
        normalizeSelectedScreenshotPreset()
        companionCaptureAutoSaveToInbox = preferences.companionCaptureAutoSaveToInbox
        companionCaptureOpenDetailAfterCapture = preferences.companionCaptureOpenDetailAfterCapture
        companionCaptureShowNotification = preferences.companionCaptureShowNotification
        voiceInputEnabled = preferences.voiceInputEnabled
        localFirstMode = preferences.localFirstMode
        sensitiveContentNotUpload = preferences.sensitiveContentNotUpload
        apiKeyUsesKeychain = preferences.apiKeyUsesKeychain
        aiCallLogEnabled = preferences.aiCallLogEnabled
        errorLogEnabled = preferences.errorLogEnabled
    }

    public var selectedScreenshotPreset: ScreenshotPreset {
        screenshotPresets.first(where: { $0.id == selectedScreenshotPresetID })
            ?? screenshotPresets.first
            ?? ScreenshotPreset.defaultPresets[0]
    }

    public func selectScreenshotPreset(id: String) {
        guard let preset = screenshotPresets.first(where: { $0.id == id }) else { return }
        selectedScreenshotPresetID = preset.id
        applyScreenshotPreset(preset)
    }

    public func applyCurrentScreenshotSettingsToSelectedPreset() {
        guard let index = screenshotPresets.firstIndex(where: { $0.id == selectedScreenshotPresetID }) else { return }
        screenshotPresets[index] = makeScreenshotPreset(from: screenshotPresets[index])
    }

    public func restoreDefaultScreenshotPresets() {
        let state = SettingsLocalPreferences.restoredDefaultScreenshotPresetState()
        screenshotPresets = state.presets
        selectedScreenshotPresetID = state.selectedPresetID
        applyScreenshotPreset(selectedScreenshotPreset)
    }

    public func createBlankScreenshotPreset() {
        let state = SettingsLocalPreferences.createBlankScreenshotPresetState(from: screenshotPresets)
        screenshotPresets = state.presets
        selectedScreenshotPresetID = state.selectedPresetID
        applyScreenshotPreset(selectedScreenshotPreset)
    }

    public func duplicateSelectedScreenshotPreset() {
        let state = SettingsLocalPreferences.duplicateSelectedScreenshotPresetState(
            from: screenshotPresets,
            selectedPresetID: selectedScreenshotPresetID
        )
        screenshotPresets = state.presets
        selectedScreenshotPresetID = state.selectedPresetID
        applyScreenshotPreset(selectedScreenshotPreset)
    }

    public func renameSelectedScreenshotPreset(to newName: String) {
        screenshotPresets = SettingsLocalPreferences.renameSelectedScreenshotPresetState(
            from: screenshotPresets,
            selectedPresetID: selectedScreenshotPresetID,
            newName: newName
        )
    }

    public func updateSelectedScreenshotPresetOutputAction(_ action: ScreenshotPresetOutputAction) {
        screenshotPresets = SettingsLocalPreferences.updateSelectedScreenshotPresetOutputActionState(
            from: screenshotPresets,
            selectedPresetID: selectedScreenshotPresetID,
            action: action
        )
    }

    public func deleteSelectedScreenshotPreset() {
        let state = SettingsLocalPreferences.deleteSelectedScreenshotPresetState(
            from: screenshotPresets,
            selectedPresetID: selectedScreenshotPresetID
        )
        screenshotPresets = state.presets
        selectedScreenshotPresetID = state.selectedPresetID
        applyScreenshotPreset(selectedScreenshotPreset)
    }

    private func applyScreenshotPreset(_ preset: ScreenshotPreset) {
        captureAutoRedactionEnabled = preset.captureAutoRedactionEnabled
        captureCensorMode = preset.captureCensorMode
        captureScreenshotCornerRadius = preset.captureScreenshotCornerRadius
        captureScreenshotMaxWidth = preset.captureScreenshotMaxWidth
        captureScreenshotMaxHeight = preset.captureScreenshotMaxHeight
    }

    private func makeScreenshotPreset(from source: ScreenshotPreset) -> ScreenshotPreset {
        ScreenshotPreset(
            id: source.id,
            name: source.name,
            captureAutoRedactionEnabled: captureAutoRedactionEnabled,
            captureCensorModeRawValue: captureCensorMode.rawValue,
            captureScreenshotCornerRadius: captureScreenshotCornerRadius,
            captureScreenshotMaxWidth: captureScreenshotMaxWidth,
            captureScreenshotMaxHeight: captureScreenshotMaxHeight,
            defaultOutputAction: source.defaultOutputAction
        )
    }

    private func normalizedScreenshotPresets() -> [ScreenshotPreset] {
        let presets = screenshotPresets.isEmpty ? ScreenshotPreset.defaultPresets : screenshotPresets
        return presets.map { preset in
            preset.id == selectedScreenshotPresetID ? makeScreenshotPreset(from: preset) : preset
        }
    }

    private func normalizeSelectedScreenshotPreset() {
        if screenshotPresets.contains(where: { $0.id == selectedScreenshotPresetID }) == false {
            selectedScreenshotPresetID = screenshotPresets.first?.id ?? ScreenshotPreset.defaultPresets.first?.id ?? "default-save"
        }
        applyScreenshotPreset(selectedScreenshotPreset)
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
            throw NSError(domain: "AcMind.Settings", code: 1, userInfo: [NSLocalizedDescriptionKey: "元数据头模板不是有效的 UTF-8 文本"])
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = object as? [String: Any] else {
            throw NSError(domain: "AcMind.Settings", code: 2, userInfo: [NSLocalizedDescriptionKey: "元数据头模板必须是 JSON 对象"])
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
        case .translate: return .translate
        }
    }
}

private extension VoiceOutputMode {
    var asSayInputOutputMode: SayInputOutputMode {
        switch self {
        case .copyToClipboard: return .copyToClipboard
        case .autoPaste: return .autoPaste
        case .ask: return .ask
        case .translate: return .translate
        }
    }
}
