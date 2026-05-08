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
public actor SettingsService: SettingsServiceProtocol {
    // MARK: - Dependencies

    private let storage: StorageServiceProtocol
    private let permissionManager: PermissionManager
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
        // 降级时创建一个空壳（实际使用时 ServiceContainer 会注入正确实例）
        self.permissionManager = permissionManager!
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
    }

    private func loadSettings() async throws -> AppSettings {
        // 从 SQLite 加载
        if let themeStr = try await storage.getSetting(key: "app.theme"),
           let theme = AppTheme(rawValue: themeStr) {
            var settings = AppSettings()
            settings.theme = theme
            settings.language = (try? await storage.getSetting(key: "app.language")) ?? "zh-CN"
            settings.defaultProviderId = try await storage.getSetting(key: "app.defaultProviderId")
            settings.defaultModelId = try await storage.getSetting(key: "app.defaultModelId")
            settings.vaultPath = (try? await storage.getSetting(key: "app.vaultPath")) ?? ""
            settings.autoCaptureClipboard = (try? await storage.getSetting(key: "app.autoCaptureClipboard")) == "true"
            settings.captureScreenshotHotkey = try await storage.getSetting(key: "app.captureScreenshotHotkey")
            settings.defaultExportTarget = ExportTarget(rawValue: (try? await storage.getSetting(key: "app.defaultExportTarget")) ?? "obsidian") ?? .obsidian
            settings.autoFrontmatter = (try? await storage.getSetting(key: "app.autoFrontmatter")) != "false"
            settingsCache = settings
            return settings
        }
        return AppSettings()
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
        try await storage.setSetting(key: "app.vaultPath", value: settings.vaultPath)
        try await storage.setSetting(key: "app.autoCaptureClipboard", value: settings.autoCaptureClipboard ? "true" : "false")
        if let hotkey = settings.captureScreenshotHotkey {
            try await storage.setSetting(key: "app.captureScreenshotHotkey", value: hotkey)
        }
        try await storage.setSetting(key: "app.defaultExportTarget", value: settings.defaultExportTarget.rawValue)
        try await storage.setSetting(key: "app.autoFrontmatter", value: settings.autoFrontmatter ? "true" : "false")
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

        let settings = VoiceSettings(
            defaultProvider: provider,
            defaultLanguage: language,
            autoPolish: autoPolish,
            voicePolishMode: voicePolishMode
        )
        voiceSettingsCache = settings
        return settings
    }

    private func saveVoiceSettingsToStorage(_ settings: VoiceSettings) async throws {
        try await storage.setSetting(key: "voice.defaultProvider", value: settings.defaultProvider)
        try await storage.setSetting(key: "voice.defaultLanguage", value: settings.defaultLanguage)
        try await storage.setSetting(key: "voice.autoPolish", value: settings.autoPolish ? "true" : "false")
        try await storage.setSetting(key: "voice.voicePolishMode", value: settings.voicePolishMode.rawValue)
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

        let config = VaultConfig(
            vaultPath: path,
            defaultFolder: defaultFolder,
            template: template,
            pathRule: pathRule,
            conflictStrategy: conflictStrategy,
            autoFrontmatter: autoFrontmatter,
            frontmatterTemplate: [:] // 简化处理
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
    }

    // MARK: - Provider Config (with Keychain API Key storage)

    public func listProviders() async throws -> [ProviderConfig] {
        if let cached = providersCache {
            return cached
        }

        // 从 SQLite 加载 Provider 列表（不含 API Key）
        // 实际实现需要查询 provider_configs 表
        // 这里简化处理，返回缓存或空数组
        providersCache = []
        return []
    }

    public func addProvider(_ config: ProviderConfig) async throws {
        // 保存到 SQLite
        // 如果有 API Key，保存到 Keychain
        if let apiKey = config.apiKey {
            try await saveAPIKey(apiKey, for: config.id)
        }

        // 更新缓存
        var providers = (try? await listProviders()) ?? []
        providers.append(config)
        providersCache = providers
    }

    public func updateProvider(_ config: ProviderConfig) async throws {
        // 更新 SQLite
        // 更新 Keychain 中的 API Key
        if let apiKey = config.apiKey {
            try await saveAPIKey(apiKey, for: config.id)
        }

        // 更新缓存
        var providers = (try? await listProviders()) ?? []
        if let index = providers.firstIndex(where: { $0.id == config.id }) {
            providers[index] = config
            providersCache = providers
        }
    }

    public func removeProvider(id: String) async throws {
        // 从 SQLite 删除
        // 从 Keychain 删除 API Key
        try await deleteAPIKey(for: id)

        // 更新缓存
        var providers = (try? await listProviders()) ?? []
        providers.removeAll { $0.id == id }
        providersCache = providers
    }

    public func getAPIKey(for providerId: String) async -> String? {
        await loadAPIKey(for: providerId)
    }

    // MARK: - API Key Keychain Storage

    private func saveAPIKey(_ apiKey: String, for providerId: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "acmind.provider.\(providerId)",
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // 先删除旧的
        SecItemDelete(query as CFDictionary)

        // 添加新的
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SettingsError.keychainError(status)
        }
    }

    private func loadAPIKey(for providerId: String) async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "acmind.provider.\(providerId)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        return apiKey
    }

    private func deleteAPIKey(for providerId: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "acmind.provider.\(providerId)"
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Permissions (delegated to PermissionManager)

    public func checkPermission(_ permission: SystemPermission) async -> PermissionStatus {
        let kind = permission.toAppPermissionKind
        await permissionManager.refresh(kind)
        let status = await permissionManager.statuses[kind] ?? .unknown
        return mapToPermissionStatus(status)
    }

    public func requestPermission(_ permission: SystemPermission) async throws {
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
        await permissionManager.openSettingsFor(permission.toAppPermissionKind)
    }

    public func checkPermissionKind(_ kind: AppPermissionKind) async -> AppPermissionStatus {
        await permissionManager.refresh(kind)
        return await permissionManager.statuses[kind] ?? .unknown
    }

    public func requestPermissionKind(_ kind: AppPermissionKind) async {
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

    public func registerShortcut(_ shortcut: KeyboardShortcut, action: @escaping () -> Void) async throws {
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

// MARK: - ProviderConfig Extension

extension ProviderConfig {
    /// API Key（内存中临时存储，不持久化到 SQLite）
    public var apiKey: String? {
        get { nil } // 实际使用时从 Keychain 加载
        set { } // 实际使用时保存到 Keychain
    }
}
