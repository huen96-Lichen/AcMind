import Foundation
import Security
import AppKit

// MARK: - Settings Service

/// 设置服务实现
/// 职责：
/// 1. AppSettings/VaultConfig/VoiceSettings 的持久化（SQLite）
/// 2. ProviderConfig 的 CRUD（SQLite + Keychain 存储 API Key）
/// 3. 权限管理（委托给 PermissionManager）
/// 4. 快捷键管理（委托给 HotkeyManager）
public actor SettingsService: SettingsServiceProtocol, HotCornerSettingsStore {
    // MARK: - Dependencies

    private let storage: StorageServiceProtocol
    private let permissionManager: PermissionManager?
    private let hotkeyManager: HotkeyManager

    // MARK: - Cache

    private var settingsCache: AppSettings?
    private var vaultConfigCache: VaultConfig?
    private var voiceSettingsCache: VoiceSettings?
    private var providersCache: [ProviderConfig]?

    // MARK: - Initialization

    public init(
        storage: StorageServiceProtocol? = nil,
        permissionManager: PermissionManager? = nil,
        hotkeyManager: HotkeyManager? = nil
    ) {
        self.storage = storage ?? StorageService()
        // PermissionManager 必须从 @MainActor 上下文注入
        // 兼容路径下允许为 nil（实际使用时 ServiceContainer 会注入正确实例）
        self.permissionManager = permissionManager
        self.hotkeyManager = hotkeyManager ?? HotkeyManager()
    }

    // MARK: - Setup

    public func setup() async throws {
        // 加载所有设置到缓存
        _ = try await loadSettings()
        _ = try await loadVaultConfig()
        _ = try await loadVoiceSettings()
        _ = try await listProviders()

        // 初始化快捷键管理器
        try await hotkeyManager.setup()
    }

    public func save() async {
        // 持久化所有缓存的设置
        if let settings = settingsCache {
            try? await saveSettingsToStorage(settings)
        }
        if let vaultConfig = vaultConfigCache {
            try? await saveVaultConfigToStorage(vaultConfig)
        }
        if let voiceSettings = voiceSettingsCache {
            try? await saveVoiceSettingsToStorage(voiceSettings)
        }
    }

    // MARK: - App Settings

    public func getSettings() async -> AppSettings {
        if let cached = settingsCache {
            return cached
        }
        return (try? await loadSettings()) ?? AppSettings()
    }

    public func updateSettings(_ settings: AppSettings) async throws {
        settingsCache = settings
        try await saveSettingsToStorage(settings)
        await MainActor.run {
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    public func getHotCornerSettings() async -> HotCornerSettings {
        if let cached = settingsCache?.hotCornerSettings {
            return cached
        }
        return (try? await loadHotCornerSettings()) ?? .defaultSettings
    }

    public func updateHotCornerSettings(_ settings: HotCornerSettings) async throws {
        if var cached = settingsCache {
            cached.hotCornerSettings = settings
            settingsCache = cached
            try await saveSettingsToStorage(cached)
            await MainActor.run {
                NotificationCenter.default.post(name: .hotCornersDidChange, object: nil)
            }
            return
        }

        var appSettings = AppSettings()
        appSettings.hotCornerSettings = settings
        settingsCache = appSettings
        try await saveSettingsToStorage(appSettings)
        await MainActor.run {
            NotificationCenter.default.post(name: .hotCornersDidChange, object: nil)
        }
    }

    private func loadSettings() async throws -> AppSettings {
        // 从 SQLite 加载
        var settings = AppSettings()

        if let themeStr = try await storage.getSetting(key: "app.theme"),
           let theme = AppTheme(rawValue: themeStr) {
            settings.theme = theme
        }

        settings.language = (try? await storage.getSetting(key: "app.language")) ?? "zh-CN"
        settings.defaultProviderId = try await storage.getSetting(key: "app.defaultProviderId")
        settings.defaultModelId = try await storage.getSetting(key: "app.defaultModelId")
        settings.modelRoutingStrategy = ModelRoutingStrategy(rawValue: (try? await storage.getSetting(key: "app.modelRoutingStrategy")) ?? "automatic") ?? .automatic
        settings.vaultPath = (try? await storage.getSetting(key: "app.vaultPath")) ?? ""
        settings.autoCaptureClipboard = (try? await storage.getSetting(key: "app.autoCaptureClipboard")) == "true"
        settings.captureScreenshotHotkey = try await storage.getSetting(key: "app.captureScreenshotHotkey")
        settings.defaultExportTarget = ExportTarget(rawValue: (try? await storage.getSetting(key: "app.defaultExportTarget")) ?? "obsidian") ?? .obsidian
        settings.autoFrontmatter = (try? await storage.getSetting(key: "app.autoFrontmatter")) != "false"
        settings.hotCornerSettings = (try? await loadHotCornerSettings()) ?? .defaultSettings

        settingsCache = settings
        return settings
    }

    private func saveSettingsToStorage(_ settings: AppSettings) async throws {
        try await storage.setSetting(key: "app.theme", value: settings.theme.rawValue)
        try await storage.setSetting(key: "app.language", value: settings.language)
        if let providerId = settings.defaultProviderId {
            try await storage.setSetting(key: "app.defaultProviderId", value: providerId)
        }
        if let modelId = settings.defaultModelId {
            try await storage.setSetting(key: "app.defaultModelId", value: modelId)
        }
        try await storage.setSetting(key: "app.modelRoutingStrategy", value: settings.modelRoutingStrategy.rawValue)
        try await storage.setSetting(key: "app.vaultPath", value: settings.vaultPath)
        try await storage.setSetting(key: "app.autoCaptureClipboard", value: settings.autoCaptureClipboard ? "true" : "false")
        if let hotkey = settings.captureScreenshotHotkey {
            try await storage.setSetting(key: "app.captureScreenshotHotkey", value: hotkey)
        }
        try await storage.setSetting(key: "app.defaultExportTarget", value: settings.defaultExportTarget.rawValue)
        try await storage.setSetting(key: "app.autoFrontmatter", value: settings.autoFrontmatter ? "true" : "false")
        try await saveHotCornerSettingsToStorage(settings.hotCornerSettings)
    }

    private func loadHotCornerSettings() async throws -> HotCornerSettings? {
        guard let raw = try await storage.getSetting(key: "app.hotCornerSettings") else {
            return nil
        }

        guard let data = raw.data(using: .utf8) else {
            return nil
        }

        return try JSONDecoder().decode(HotCornerSettings.self, from: data)
    }

    private func saveHotCornerSettingsToStorage(_ settings: HotCornerSettings) async throws {
        let data = try JSONEncoder().encode(settings)
        let raw = String(decoding: data, as: UTF8.self)
        try await storage.setSetting(key: "app.hotCornerSettings", value: raw)
    }

    // MARK: - Voice Settings

    public func getVoiceSettings() async -> VoiceSettings {
        if let cached = voiceSettingsCache {
            return cached
        }
        return (try? await loadVoiceSettings()) ?? VoiceSettings()
    }

    public func updateVoiceSettings(_ settings: VoiceSettings) async throws {
        voiceSettingsCache = settings
        try await saveVoiceSettingsToStorage(settings)
    }

    private func loadVoiceSettings() async throws -> VoiceSettings {
        let provider = (try? await storage.getSetting(key: "voice.defaultProvider")) ?? "whisper"
        let language = (try? await storage.getSetting(key: "voice.defaultLanguage")) ?? "zh"
        let autoPolish = (try? await storage.getSetting(key: "voice.autoPolish")) == "true"
        let voicePolishMode = try await loadVoicePolishMode()
        let triggerMode = try await loadSayInputTriggerMode()
        let silenceTimeout = (try? await storage.getSetting(key: "voice.silenceTimeout")).flatMap(Double.init) ?? 3.0
        let enableSilenceDetection = (try? await storage.getSetting(key: "voice.enableSilenceDetection")) == "true"
        let outputMode = try await loadSayInputOutputMode()
        let saveToInbox = (try? await storage.getSetting(key: "voice.saveToInbox")) != "false" // 默认 true
        let allowContinuation = (try? await storage.getSetting(key: "voice.allowContinuation")) != "false" // 默认 true
        let continuationWindow = (try? await storage.getSetting(key: "voice.continuationWindow")).flatMap(Double.init) ?? 12.0
        let translationLanguage = (try? await storage.getSetting(key: "voice.translationLanguage")) ?? "zh"

        let settings = VoiceSettings(
            defaultProvider: provider,
            defaultLanguage: language,
            autoPolish: autoPolish,
            voicePolishMode: voicePolishMode,
            triggerMode: triggerMode,
            silenceTimeout: silenceTimeout,
            enableSilenceDetection: enableSilenceDetection,
            outputMode: outputMode,
            saveToInbox: saveToInbox,
            allowContinuation: allowContinuation,
            continuationWindow: continuationWindow,
            translationLanguage: translationLanguage
        )
        voiceSettingsCache = settings
        return settings
    }

    private func saveVoiceSettingsToStorage(_ settings: VoiceSettings) async throws {
        try await storage.setSetting(key: "voice.defaultProvider", value: settings.defaultProvider)
        try await storage.setSetting(key: "voice.defaultLanguage", value: settings.defaultLanguage)
        try await storage.setSetting(key: "voice.autoPolish", value: settings.autoPolish ? "true" : "false")
        try await storage.setSetting(key: "voice.voicePolishMode", value: settings.voicePolishMode.rawValue)
        try await storage.setSetting(key: "voice.triggerMode", value: settings.triggerMode.rawValue)
        try await storage.setSetting(key: "voice.silenceTimeout", value: String(settings.silenceTimeout))
        try await storage.setSetting(key: "voice.enableSilenceDetection", value: settings.enableSilenceDetection ? "true" : "false")
        try await storage.setSetting(key: "voice.outputMode", value: settings.outputMode.rawValue)
        try await storage.setSetting(key: "voice.saveToInbox", value: settings.saveToInbox ? "true" : "false")
        try await storage.setSetting(key: "voice.allowContinuation", value: settings.allowContinuation ? "true" : "false")
        try await storage.setSetting(key: "voice.continuationWindow", value: String(settings.continuationWindow))
        try await storage.setSetting(key: "voice.translationLanguage", value: settings.translationLanguage)
    }
    
    private func loadSayInputTriggerMode() async throws -> SayInputTriggerMode {
        if let rawValue = try? await storage.getSetting(key: "voice.triggerMode"),
           let mode = SayInputTriggerMode(rawValue: rawValue) {
            return mode
        }
        return .hold
    }
    
    private func loadSayInputOutputMode() async throws -> SayInputOutputMode {
        if let rawValue = try? await storage.getSetting(key: "voice.outputMode"),
           let mode = SayInputOutputMode(rawValue: rawValue) {
            return mode
        }
        return .copyToClipboard
    }

    private func loadVoicePolishMode() async throws -> VoicePolishMode {
        if let newValue = try? await storage.getSetting(key: "voice.voicePolishMode"),
           let mode = VoicePolishMode(rawValue: newValue) {
            return mode
        }

        if let legacyValue = try? await storage.getSetting(key: "voice.polishMode") {
            if let legacySettingMode = PolishMode(rawValue: legacyValue) {
                return legacySettingMode.asVoicePolishMode
            }
            if let legacyVoiceMode = VoicePolishMode(rawValue: legacyValue) {
                return legacyVoiceMode
            }
        }

        return .light
    }

    // MARK: - Vault Config

    public func getVaultConfig() async -> VaultConfig {
        if let cached = vaultConfigCache {
            return cached
        }
        return (try? await loadVaultConfig()) ?? VaultConfig()
    }

    public func updateVaultConfig(_ config: VaultConfig) async throws {
        vaultConfigCache = config
        try await saveVaultConfigToStorage(config)
    }

    public func validateVaultPath(_ path: String) async -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    public func selectVaultPath() async -> String? {
        // 使用 AppKit 的文件选择器
        return await MainActor.run {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "选择 Vault"
            panel.message = "选择 Obsidian Vault 文件夹"

            guard panel.runModal() == .OK,
                  let url = panel.url else {
                return nil
            }
            return url.path
        }
    }

    private func loadVaultConfig() async throws -> VaultConfig {
        let path = (try? await storage.getSetting(key: "vault.path")) ?? ""
        let defaultFolder = (try? await storage.getSetting(key: "vault.defaultFolder")) ?? "Inbox"
        let template = (try? await storage.getSetting(key: "vault.template")) ?? ""
        let pathRule = VaultConfig.VaultPathRule(rawValue: (try? await storage.getSetting(key: "vault.pathRule")) ?? "categoryDate") ?? .categoryDate
        let conflictStrategy = ConflictStrategy(rawValue: (try? await storage.getSetting(key: "vault.conflictStrategy")) ?? "rename") ?? .rename
        let autoFrontmatter = (try? await storage.getSetting(key: "vault.autoFrontmatter")) != "false"
        let frontmatterTemplateText = (try? await storage.getSetting(key: "vault.frontmatterTemplate")) ?? "{}"

        let config = VaultConfig(
            vaultPath: path,
            defaultFolder: defaultFolder,
            template: template,
            pathRule: pathRule,
            conflictStrategy: conflictStrategy,
            autoFrontmatter: autoFrontmatter,
            frontmatterTemplate: decodeFrontmatterTemplate(frontmatterTemplateText)
        )
        vaultConfigCache = config
        return config
    }

    private func saveVaultConfigToStorage(_ config: VaultConfig) async throws {
        try await storage.setSetting(key: "vault.path", value: config.vaultPath)
        try await storage.setSetting(key: "vault.defaultFolder", value: config.defaultFolder)
        try await storage.setSetting(key: "vault.template", value: config.template)
        try await storage.setSetting(key: "vault.pathRule", value: config.pathRule.rawValue)
        try await storage.setSetting(key: "vault.conflictStrategy", value: config.conflictStrategy.rawValue)
        try await storage.setSetting(key: "vault.autoFrontmatter", value: config.autoFrontmatter ? "true" : "false")
        try await storage.setSetting(key: "vault.frontmatterTemplate", value: encodeFrontmatterTemplate(config.frontmatterTemplate))
    }

    private func encodeFrontmatterTemplate(_ template: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: template, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func decodeFrontmatterTemplate(_ text: String) -> [String: String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = object as? [String: Any] else {
            return [:]
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

    // MARK: - Provider Config (with Keychain API Key storage)

    public func listProviders() async throws -> [ProviderConfig] {
        if let cached = providersCache {
            return cached
        }
        let providers = try await storage.listProviders()
        providersCache = providers
        return providers
    }

    public func addProvider(_ config: ProviderConfig, apiKey: String? = nil) async throws {
        if let apiKey, apiKey.isEmpty == false {
            try await saveAPIKey(apiKey, for: config.id)
        }

        var configToSave = config
        configToSave.apiKeyRef = config.apiKeyRef ?? (apiKey?.isEmpty == false ? config.id : nil)
        try await storage.addProvider(configToSave)

        providersCache = (try? await storage.listProviders()) ?? []
    }

    public func updateProvider(_ config: ProviderConfig, apiKey: String? = nil) async throws {
        if let apiKey {
            if apiKey.isEmpty == false {
                try await saveAPIKey(apiKey, for: config.id)
            } else {
                try await deleteAPIKey(for: config.id)
            }
        }

        var configToSave = config
        if let apiKey {
            configToSave.apiKeyRef = apiKey.isEmpty ? nil : config.apiKeyRef ?? config.id
        }
        try await storage.updateProvider(configToSave)

        providersCache = (try? await storage.listProviders()) ?? []
    }

    public func removeProvider(id: String) async throws {
        try await deleteAPIKey(for: id)
        try await storage.removeProvider(id: id)
        providersCache = (try? await storage.listProviders()) ?? []
    }

    public func getAPIKey(for providerId: String) async -> String? {
        await loadAPIKey(for: providerId)
    }

    // MARK: - API Key Keychain Storage

    private func saveAPIKey(_ apiKey: String, for providerId: String) async throws {
        try await SecretStore.shared.saveAPIKey(apiKey, for: providerId)
    }

    private func loadAPIKey(for providerId: String) async -> String? {
        await SecretStore.shared.getAPIKey(for: providerId)
    }

    private func deleteAPIKey(for providerId: String) async throws {
        try await SecretStore.shared.deleteAPIKey(for: providerId)
    }

    // MARK: - Permissions (delegated to PermissionManager)

    public func checkPermission(_ permission: SystemPermission) async -> PermissionStatus {
        guard let permissionManager else { return .notDetermined }
        let kind = permission.toAppPermissionKind
        await permissionManager.refresh(kind)
        let status = await permissionManager.statuses[kind] ?? .unknown
        return mapToPermissionStatus(status)
    }

    public func requestPermission(_ permission: SystemPermission) async throws {
        guard let permissionManager else { throw PermissionError.denied(permission) }
        let kind = permission.toAppPermissionKind
        await permissionManager.request(kind)
        let status = await permissionManager.statuses[kind] ?? .unknown
        switch status {
        case .authorized:
            return
        case .denied, .needsSystemSettings:
            throw PermissionError.denied(permission)
        case .restricted:
            throw PermissionError.restricted(permission)
        default:
            break
        }
    }

    public func openSystemPreferences(for permission: SystemPermission) async {
        guard let permissionManager else { return }
        await permissionManager.openSettingsFor(permission.toAppPermissionKind)
    }

    public func checkPermissionKind(_ kind: AppPermissionKind) async -> AppPermissionStatus {
        guard let permissionManager else { return .unknown }
        await permissionManager.refresh(kind)
        return await permissionManager.statuses[kind] ?? .unknown
    }

    public func requestPermissionKind(_ kind: AppPermissionKind) async {
        guard let permissionManager else { return }
        await permissionManager.request(kind)
    }

    // MARK: - Permission Status Mapping

    private func mapToPermissionStatus(_ status: AppPermissionStatus) -> PermissionStatus {
        switch status {
        case .unknown, .notDetermined, .requesting:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied, .needsSystemSettings:
            return .denied
        case .restricted:
            return .restricted
        case .failed:
            return .denied
        }
    }

    // MARK: - Shortcuts (delegated to HotkeyManager)

    public func registerShortcut(_ shortcut: KeyboardShortcut, action: @escaping @Sendable () -> Void) async throws {
        try await hotkeyManager.registerShortcut(shortcut, action: action)
    }

    public func unregisterShortcut(_ shortcut: KeyboardShortcut) async throws {
        try await hotkeyManager.unregisterShortcut(shortcut)
    }

    public func getRegisteredShortcuts() async -> [KeyboardShortcut] {
        await hotkeyManager.getRegisteredShortcuts()
    }

    public func unregisterAllShortcuts() async {
        await hotkeyManager.unregisterAll()
    }
}

// MARK: - Errors

public enum SettingsError: Error, LocalizedError {
    case keychainError(OSStatus)
    case invalidVaultPath
    case providerNotFound
    case shortcutRegistrationFailed

    public var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain 错误: \(status)"
        case .invalidVaultPath:
            return "无效的 Vault 路径"
        case .providerNotFound:
            return "Provider 未找到"
        case .shortcutRegistrationFailed:
            return "快捷键注册失败"
        }
    }
}
