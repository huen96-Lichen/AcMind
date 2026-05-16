import Foundation

public protocol SettingsServiceProtocol: Sendable {
    func setup() async throws
    func save() async

    // App Settings
    func getSettings() async -> AppSettings
    func updateSettings(_ settings: AppSettings) async throws

    // Voice Settings
    func getVoiceSettings() async -> VoiceSettings
    func updateVoiceSettings(_ settings: VoiceSettings) async throws

    // Vault Config
    func getVaultConfig() async -> VaultConfig
    func updateVaultConfig(_ config: VaultConfig) async throws
    func validateVaultPath(_ path: String) async -> Bool
    func selectVaultPath() async -> String?

    // Permissions
    func checkPermission(_ permission: SystemPermission) async -> PermissionStatus
    func requestPermission(_ permission: SystemPermission) async throws
    func openSystemPreferences(for permission: SystemPermission) async

    // Permissions (new API)
    func checkPermissionKind(_ kind: AppPermissionKind) async -> AppPermissionStatus
    func requestPermissionKind(_ kind: AppPermissionKind) async

    // Shortcuts
    func registerShortcut(_ shortcut: KeyboardShortcut, action: @escaping @Sendable () -> Void) async throws
    func unregisterShortcut(_ shortcut: KeyboardShortcut) async throws
    func getRegisteredShortcuts() async -> [KeyboardShortcut]
    func unregisterAllShortcuts() async

    // Providers
    func listProviders() async throws -> [ProviderConfig]
    func addProvider(_ config: ProviderConfig) async throws
    func updateProvider(_ config: ProviderConfig) async throws
    func removeProvider(id: String) async throws
    func getAPIKey(for providerId: String) async -> String?
}
