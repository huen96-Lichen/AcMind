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
    private let aiRuntime: AIRuntimeProtocol
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
    @Published public var rememberWorkspaceLayout: Bool = true

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
    @Published public var companionVoiceShortcut: String = "⌥Space"
    @Published public var companionVoiceTriggerMode: CompanionVoiceTriggerMode = .both
    @Published public var companionVoiceProvider: STTProvider = .appleSpeech
    @Published public var companionVoiceModel: String = "auto"
    @Published public var companionVoiceHoldToTalkEnabled: Bool = true
    @Published public var companionVoiceHoldThreshold: Double = 0.38
    @Published public var companionVoiceRouteMode: CompanionVoiceRouteMode = .smart
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
    @Published public var providerEditingID: String?
    @Published public var providerDraftName: String = ""
    @Published public var providerDraftBaseURL: String = ""
    @Published public var providerDraftModelId: String = ""
    @Published public var providerDraftAPIKey: String = ""
    @Published public var providerDraftProviderType: ProviderType = .ollama
    @Published public var providerDraftTier: ProviderTier = .localLight
    @Published public var providerDraftEnabled: Bool = true
    @Published public var providerAPIKeyPresence: [String: Bool] = [:]
    @Published public var providerHealthStates: [String: ProviderHealthState] = [:]

    // AI Model Preferences
    @Published public var aiModelPreferences: [AIModelCategoryPreference] = AIModelCatalog.defaultPreferences()
    @Published public var selectedAIModelCategory: AIModelCategory = .speechToText
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showError = false
    @Published public var saveStatusMessage: String?

    // MARK: - Initialization

    public init(settings: SettingsServiceProtocol? = nil, storage: StorageServiceProtocol? = nil) {
        self.settings = settings ?? ServiceContainer.shared.settingsService
        self.storage = storage ?? ServiceContainer.shared.storageService
        self.aiRuntime = ServiceContainer.shared.aiRuntime
        self.permissionManager = ServiceContainer.shared.permissionManager

        // 加载设置
        Task {
            await loadSettings()
            await loadPermissions()
            await loadProviders()
            await loadAIModelPreferences()
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
        rememberWorkspaceLayout = (UserDefaults.standard.object(forKey: Self.rememberWorkspaceLayoutKey) as? Bool) ?? true

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

        autoRedactFaces = (try? await storage.getSetting(key: Self.autoRedactFacesKey)) != "false"
        autoDetectPII = (try? await storage.getSetting(key: Self.autoDetectPIIKey)) != "false"
        scrollCaptureAutoScroll = (try? await storage.getSetting(key: Self.scrollCaptureAutoScrollKey)) != "false"
        scrollCaptureSpeed = Double((try? await storage.getSetting(key: Self.scrollCaptureSpeedKey)) ?? "3") ?? 3
        scrollCaptureMaxHeight = Int((try? await storage.getSetting(key: Self.scrollCaptureMaxHeightKey)) ?? "30000") ?? 30000
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
                companionVoiceShortcut = config.voiceShortcut
                companionVoiceTriggerMode = CompanionVoiceTriggerMode(rawValue: config.voiceTriggerMode) ?? .both
                companionVoiceProvider = STTProvider(rawValue: config.voiceProvider) ?? .appleSpeech
                companionVoiceModel = config.voiceModel
                companionVoiceHoldToTalkEnabled = config.voiceHoldToTalkEnabled
                companionVoiceHoldThreshold = config.voiceHoldThreshold
                companionVoiceRouteMode = CompanionVoiceRouteMode(rawValue: config.voiceRouteMode) ?? .smart
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
                companionVoiceShortcut = config.voiceShortcut
                companionVoiceTriggerMode = CompanionVoiceTriggerMode(rawValue: config.voiceTriggerMode) ?? .both
                companionVoiceProvider = STTProvider(rawValue: config.voiceProvider) ?? .appleSpeech
                companionVoiceModel = config.voiceModel
                companionVoiceHoldToTalkEnabled = config.voiceHoldToTalkEnabled
                companionVoiceHoldThreshold = config.voiceHoldThreshold
                companionVoiceRouteMode = CompanionVoiceRouteMode(rawValue: config.voiceRouteMode) ?? .smart
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
            companionVoiceShortcut = config.voiceShortcut
            companionVoiceTriggerMode = CompanionVoiceTriggerMode(rawValue: config.voiceTriggerMode) ?? .both
            companionVoiceProvider = STTProvider(rawValue: config.voiceProvider) ?? .appleSpeech
            companionVoiceModel = config.voiceModel
            companionVoiceHoldToTalkEnabled = config.voiceHoldToTalkEnabled
            companionVoiceHoldThreshold = config.voiceHoldThreshold
            companionVoiceRouteMode = CompanionVoiceRouteMode(rawValue: config.voiceRouteMode) ?? .smart
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
            try await storage.setSetting(key: Self.rememberWorkspaceLayoutKey, value: rememberWorkspaceLayout ? "true" : "false")
            UserDefaults.standard.set(rememberWorkspaceLayout, forKey: Self.rememberWorkspaceLayoutKey)

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

            try await storage.setSetting(key: Self.autoRedactFacesKey, value: autoRedactFaces ? "true" : "false")
            try await storage.setSetting(key: Self.autoDetectPIIKey, value: autoDetectPII ? "true" : "false")
            try await storage.setSetting(key: Self.scrollCaptureAutoScrollKey, value: scrollCaptureAutoScroll ? "true" : "false")
            try await storage.setSetting(key: Self.scrollCaptureSpeedKey, value: String(scrollCaptureSpeed))
            try await storage.setSetting(key: Self.scrollCaptureMaxHeightKey, value: String(scrollCaptureMaxHeight))

            // 保存随身配置
            await saveCompanionSettings()
            try await settings.updateAIModelCategoryPreferences(aiModelPreferences)
            saveStatusMessage = "设置已保存"

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
            voiceShortcut: companionVoiceShortcut,
            voiceTriggerMode: companionVoiceTriggerMode.rawValue,
            voiceProvider: companionVoiceProvider.rawValue,
            voiceModel: companionVoiceModel,
            voiceHoldToTalkEnabled: companionVoiceHoldToTalkEnabled,
            voiceHoldThreshold: companionVoiceHoldThreshold,
            voiceRouteMode: companionVoiceRouteMode.rawValue,
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
            NotificationCenter.default.post(name: .companionVoiceConfigurationDidChange, object: nil)
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
            await refreshProviderMetadata()
            normalizeAIModelPreferences()
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func loadAIModelPreferences() async {
        aiModelPreferences = await settings.getAIModelCategoryPreferences()
        normalizeAIModelPreferences()
    }

    public func addProvider(_ config: ProviderConfig) async {
        do {
            try await settings.addProvider(config)
            await loadProviders()
            NotificationCenter.default.post(name: .acmindProvidersDidChange, object: nil)
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func updateProvider(_ config: ProviderConfig) async {
        do {
            try await settings.updateProvider(config)
            await loadProviders()
            NotificationCenter.default.post(name: .acmindProvidersDidChange, object: nil)
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func removeProvider(id: String) async {
        do {
            try await settings.removeProvider(id: id)
            await loadProviders()
            NotificationCenter.default.post(name: .acmindProvidersDidChange, object: nil)
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func applyProviderPreset(_ preset: ProviderPreset) {
        providerEditingID = nil
        providerDraftName = preset.name
        providerDraftBaseURL = preset.baseURL
        providerDraftModelId = preset.modelId
        providerDraftProviderType = preset.providerType
        providerDraftTier = preset.tier
        providerDraftAPIKey = ""
        providerDraftEnabled = true
    }

    public func beginEditingProvider(_ provider: ProviderConfig) {
        providerEditingID = provider.id
        providerDraftName = provider.name
        providerDraftBaseURL = provider.baseURL
        providerDraftModelId = provider.modelId
        providerDraftProviderType = provider.providerType
        providerDraftTier = provider.tier
        providerDraftAPIKey = ""
        providerDraftEnabled = provider.enabled
    }

    public func resetProviderDraft() {
        providerEditingID = nil
        providerDraftName = ""
        providerDraftBaseURL = ""
        providerDraftModelId = ""
        providerDraftAPIKey = ""
        providerDraftProviderType = .ollama
        providerDraftTier = .localLight
        providerDraftEnabled = true
    }

    public func saveDraftProvider() async {
        let name = providerDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = providerDraftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelId = providerDraftModelId.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = providerDraftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            showError(message: "请先填写 Provider 名称")
            return
        }
        guard !modelId.isEmpty else {
            showError(message: "请先填写模型 ID")
            return
        }

        let requiresAPIKey = providerRequiresAPIKey(providerDraftProviderType)
        let hasExistingAPIKey = providerEditingID.flatMap { providerAPIKeyPresence[$0] } ?? false
        if requiresAPIKey && apiKey.isEmpty && !hasExistingAPIKey {
            showError(message: "当前 Provider 需要填写 API Key")
            return
        }

        let providerId = providerEditingID ?? "provider.\(UUID().uuidString)"
        let existingProvider = providerEditingID.flatMap { editingID in
            providers.first(where: { $0.id == editingID })
        }
        let config = ProviderConfig(
            id: providerId,
            name: name,
            providerType: providerDraftProviderType,
            tier: providerDraftTier,
            baseURL: baseURL,
            apiKeyRef: resolveAPIKeyRef(for: providerId, apiKey: apiKey, existingRef: existingProvider?.apiKeyRef),
            modelId: modelId,
            enabled: providerDraftEnabled,
            capabilities: providerCapabilities(for: providerDraftProviderType)
        )

        do {
            if providerEditingID == nil {
                try await settings.addProvider(config)
                if !apiKey.isEmpty {
                    do {
                        try await settings.saveProviderAPIKey(apiKey, for: providerId)
                    } catch {
                        try? await settings.removeProvider(id: providerId)
                        throw error
                    }
                }
            } else {
                try await settings.updateProvider(config)
                if !apiKey.isEmpty {
                    try await settings.saveProviderAPIKey(apiKey, for: providerId)
                }
            }
            providerEditingID = nil
            await loadProviders()
            providerDraftAPIKey = ""
            NotificationCenter.default.post(name: .acmindProvidersDidChange, object: nil)
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func deleteProvider(id: String) async {
        do {
            try await settings.removeProvider(id: id)
            if providerEditingID == id {
                resetProviderDraft()
            }
            await loadProviders()
            NotificationCenter.default.post(name: .acmindProvidersDidChange, object: nil)
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func clearProviderAPIKey(for providerID: String) async {
        do {
            try await settings.deleteProviderAPIKey(for: providerID)
            await loadProviders()
            NotificationCenter.default.post(name: .acmindProvidersDidChange, object: nil)
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    public func checkProviderHealth(_ providerID: String) async {
        guard let provider = providers.first(where: { $0.id == providerID }) else { return }
        if provider.enabled == false {
            providerHealthStates[providerID] = .disabled
            return
        }

        providerHealthStates[providerID] = .checking
        do {
            let isHealthy = try await aiRuntime.healthCheck(providerId: providerID)
            providerHealthStates[providerID] = isHealthy ? .healthy : .unhealthy("服务返回异常")
        } catch {
            providerHealthStates[providerID] = .unhealthy(error.localizedDescription)
        }
    }

    public func setProviderEnabled(_ providerID: String, enabled: Bool) async {
        guard var provider = providers.first(where: { $0.id == providerID }) else { return }
        provider.enabled = enabled
        await updateProvider(provider)
        if enabled {
            providerHealthStates[providerID] = .unknown
        } else {
            providerHealthStates[providerID] = .disabled
        }
    }

    public func providerHealthState(for providerID: String) -> ProviderHealthState {
        providerHealthStates[providerID] ?? .unknown
    }

    public func providerHasKey(_ providerID: String) -> Bool {
        providerAPIKeyPresence[providerID] ?? false
    }

    public func selectAIModelCategory(_ category: AIModelCategory) {
        selectedAIModelCategory = category
    }

    public func aiModelPreference(for category: AIModelCategory) -> AIModelCategoryPreference {
        aiModelPreferences.first(where: { $0.category == category }) ?? AIModelCatalog.defaultPreference(for: category)
    }

    public func updateAIModelPreference(
        category: AIModelCategory,
        selectedProviderId: String,
        selectedModelId: String?,
        fallbackProviderId: String,
        fallbackModelId: String?,
        isEnabled: Bool
    ) {
        let updated = AIModelCategoryPreference(
            category: category,
            selectedProviderId: selectedProviderId,
            selectedModelId: selectedModelId,
            fallbackProviderId: fallbackProviderId,
            fallbackModelId: fallbackModelId,
            isEnabled: isEnabled
        )

        if let index = aiModelPreferences.firstIndex(where: { $0.category == category }) {
            aiModelPreferences[index] = updated
        } else {
            aiModelPreferences.append(updated)
        }
        normalizeAIModelPreferences()
    }

    public func selectAIModelOption(_ option: AIModelOption, for category: AIModelCategory) {
        let preference = aiModelPreference(for: category)
        updateAIModelPreference(
            category: category,
            selectedProviderId: option.providerId,
            selectedModelId: option.modelId,
            fallbackProviderId: preference.fallbackProviderId,
            fallbackModelId: preference.fallbackModelId,
            isEnabled: option.isAvailable
        )
    }

    public func selectAIModelFallbackOption(_ option: AIModelOption, for category: AIModelCategory) {
        let preference = aiModelPreference(for: category)
        updateAIModelPreference(
            category: category,
            selectedProviderId: preference.selectedProviderId,
            selectedModelId: preference.selectedModelId,
            fallbackProviderId: option.providerId,
            fallbackModelId: option.modelId,
            isEnabled: preference.isEnabled
        )
    }

    public func setAIModelCategoryEnabled(_ enabled: Bool, for category: AIModelCategory) {
        let preference = aiModelPreference(for: category)
        updateAIModelPreference(
            category: category,
            selectedProviderId: preference.selectedProviderId,
            selectedModelId: preference.selectedModelId,
            fallbackProviderId: preference.fallbackProviderId,
            fallbackModelId: preference.fallbackModelId,
            isEnabled: enabled
        )
    }

    public func testAIModelSelection(for category: AIModelCategory) async {
        guard let option = selectedAIModelOption(for: category) else {
            saveStatusMessage = "\(category.displayName) 暂无可测试模型"
            return
        }

        if option.isSystemDefault {
            saveStatusMessage = "\(category.displayName) 使用系统内置模型，无需额外测试"
            return
        }

        if option.isAvailable {
            await checkProviderHealth(option.providerId)
            saveStatusMessage = "\(category.displayName) 模型测试完成"
        } else {
            saveStatusMessage = "\(category.displayName) 模型不可用，已准备回退"
        }
    }

    public func availableAIModelOptions(for category: AIModelCategory) -> [AIModelOption] {
        AIModelCatalog.options(for: category, providers: providers)
    }

    public func selectedAIModelOption(for category: AIModelCategory) -> AIModelOption? {
        AIModelCatalog.selection(for: category, preferences: aiModelPreferences, options: availableAIModelOptions(for: category))
    }

    public func fallbackAIModelOption(for category: AIModelCategory) -> AIModelOption? {
        AIModelCatalog.fallbackOption(for: category, preferences: aiModelPreferences, options: availableAIModelOptions(for: category))
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

    private static let rememberWorkspaceLayoutKey = "AppSettings.rememberWorkspaceLayout"
    private static let autoRedactFacesKey = "capture.autoRedactFaces"
    private static let autoDetectPIIKey = "capture.autoDetectPII"
    private static let scrollCaptureAutoScrollKey = "capture.scrollCaptureAutoScroll"
    private static let scrollCaptureSpeedKey = "capture.scrollCaptureSpeed"
    private static let scrollCaptureMaxHeightKey = "capture.scrollCaptureMaxHeight"

    private func providerCapabilities(for type: ProviderType) -> [String] {
        switch type {
        case .ollama, .local:
            return ["chat", "stream", "local"]
        case .openAICompatible:
            return ["chat", "stream", "compatible"]
        case .openAI, .anthropic, .google:
            return ["chat", "stream", "cloud"]
        }
    }

    private func providerRequiresAPIKey(_ type: ProviderType) -> Bool {
        switch type {
        case .ollama, .local:
            return false
        case .openAICompatible:
            return false
        case .openAI, .anthropic, .google:
            return true
        }
    }

    private func resolveAPIKeyRef(for providerID: String, apiKey: String, existingRef: String?) -> String? {
        if !apiKey.isEmpty {
            return providerID
        }
        if let existingRef {
            return existingRef
        }
        return providerAPIKeyPresence[providerID] == true ? providerID : nil
    }

    private func refreshProviderMetadata() async {
        var presence: [String: Bool] = [:]
        for provider in providers {
            presence[provider.id] = await settings.getAPIKey(for: provider.id) != nil
        }
        providerAPIKeyPresence = presence
        let retainedHealthStates = providerHealthStates.filter { presence[$0.key] != nil }
        providerHealthStates = Dictionary(uniqueKeysWithValues: retainedHealthStates.map { ($0.key, $0.value) })

        if let editingID = providerEditingID,
           providers.contains(where: { $0.id == editingID }) == false {
            resetProviderDraft()
        }
    }

    private func normalizeAIModelPreferences() {
        aiModelPreferences = AIModelCatalog.normalize(aiModelPreferences, providers: providers)
        if !aiModelPreferences.contains(where: { $0.category == selectedAIModelCategory }) {
            selectedAIModelCategory = AIModelCategory.allCases.first ?? .speechToText
        }
    }
}

public enum ProviderHealthState: Sendable, Equatable {
    case unknown
    case checking
    case healthy
    case unhealthy(String)
    case disabled

    public var label: String {
        switch self {
        case .unknown: return "未检查"
        case .checking: return "检查中"
        case .healthy: return "正常"
        case .unhealthy: return "异常"
        case .disabled: return "已停用"
        }
    }

    public var detail: String? {
        switch self {
        case .unhealthy(let message):
            return message
        default:
            return nil
        }
    }
}
