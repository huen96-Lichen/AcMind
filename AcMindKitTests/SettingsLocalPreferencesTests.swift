import XCTest
@testable import AcMindKit

final class SettingsLocalPreferencesTests: XCTestCase {
    func testSaveAndLoadRoundTripPreservesFeatureFlags() throws {
        let suiteName = "AcMind.SettingsLocalPreferencesTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let expected = SettingsLocalPreferences(
            autoBackupEnabled: false,
            lastAutoBackupAt: Date(timeIntervalSince1970: 12345),
            restoreWindowPosition: false,
            notificationsEnabled: true,
            taskCompletedNotificationsEnabled: false,
            updateAvailableNotificationsEnabled: true,
            captureOnlyWhenAppActive: true,
            captureScreenshotEnabled: false,
            captureAutoRedactionEnabled: false,
            captureCensorModeRawValue: CensorMode.blur.rawValue,
            captureScreenshotCornerRadius: 12,
            captureScreenshotMaxWidth: 1280,
            captureScreenshotMaxHeight: 720,
            companionCaptureAutoSaveToInbox: false,
            companionCaptureOpenDetailAfterCapture: true,
            companionCaptureShowNotification: false,
            voiceInputEnabled: false,
            localFirstMode: false,
            sensitiveContentNotUpload: false,
            apiKeyUsesKeychain: false,
            aiCallLogEnabled: false,
            errorLogEnabled: true
        )

        expected.save(to: defaults)

        let loaded = SettingsLocalPreferences.load(from: defaults)
        XCTAssertEqual(loaded, expected)
        XCTAssertFalse(SettingsLocalPreferences.isCaptureScreenshotEnabled(from: defaults))
        XCTAssertFalse(SettingsLocalPreferences.isVoiceInputEnabled(from: defaults))
        XCTAssertFalse(SettingsLocalPreferences.loadOrDefault(from: defaults).restoreWindowPosition)
    }

    func testClipboardCapturePolicyHonorsAppActivityPreference() {
        XCTAssertTrue(ClipboardService.shouldCaptureAutomatically(captureOnlyWhenAppActive: false, isAppActive: false))
        XCTAssertTrue(ClipboardService.shouldCaptureAutomatically(captureOnlyWhenAppActive: false, isAppActive: true))
        XCTAssertFalse(ClipboardService.shouldCaptureAutomatically(captureOnlyWhenAppActive: true, isAppActive: false))
        XCTAssertTrue(ClipboardService.shouldCaptureAutomatically(captureOnlyWhenAppActive: true, isAppActive: true))
    }

    func testLocalFirstModePrefersLocalProviderWhenAvailable() async throws {
        let suiteName = "AcMind.LocalFirstModeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = SettingsLocalPreferences(localFirstMode: true)
        preferences.save(to: defaults)

        let runtime = AIRuntimeService(
            storage: InMemoryStorageStub(),
            settingsDefaults: defaults
        )

        let cloudProvider = ProviderConfig(
            id: "cloud-provider",
            name: "Cloud Provider",
            providerType: .ollama,
            tier: .cloudLight,
            baseURL: "http://127.0.0.1:11434",
            modelId: "cloud-model"
        )
        let localProvider = ProviderConfig(
            id: "local-provider",
            name: "Local Provider",
            providerType: .ollama,
            tier: .localLight,
            baseURL: "http://127.0.0.1:11435",
            modelId: "local-model"
        )

        try await runtime.addProvider(cloudProvider)
        try await runtime.addProvider(localProvider)

        XCTAssertEqual(runtime.preferredProviderId(), "local-provider")
    }

    func testApiKeyStorageModeUsesUserDefaultsWhenKeychainDisabled() async throws {
        let suiteName = "AcMind.ApiKeyStorageTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        SettingsLocalPreferences(apiKeyUsesKeychain: false).save(to: defaults)

        let store = SecretStore(settingsDefaults: defaults)
        try await store.saveAPIKey("local-test-key", for: "provider-x")

        let loadedKey = await store.getAPIKey(for: "provider-x")
        XCTAssertEqual(loadedKey, "local-test-key")
        XCTAssertEqual(
            defaults.dictionary(forKey: "acmind.provider.apiKeys.v1")?["provider-x"] as? String,
            "local-test-key"
        )

        try await store.deleteAPIKey(for: "provider-x")
        let deletedKey = await store.getAPIKey(for: "provider-x")
        XCTAssertNil(deletedKey)
    }

    func testUpdateAvailableNotificationsArePurePreferenceOnly() throws {
        let suiteName = "AcMind.UpdateNotificationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var prefs = SettingsLocalPreferences()
        prefs.updateAvailableNotificationsEnabled = false
        prefs.save(to: defaults)

        let loaded = SettingsLocalPreferences.load(from: defaults)
        XCTAssertNotNil(loaded)
        XCTAssertFalse(loaded!.updateAvailableNotificationsEnabled)
    }

    func testCaptureAutoRedactionIsPurePreferenceOnly() throws {
        let suiteName = "AcMind.CaptureAutoRedactionTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var prefs = SettingsLocalPreferences()
        prefs.captureAutoRedactionEnabled = false
        prefs.save(to: defaults)

        let loaded = SettingsLocalPreferences.load(from: defaults)
        XCTAssertNotNil(loaded)
        XCTAssertFalse(loaded!.captureAutoRedactionEnabled)
    }
}

private final class InMemoryStorageStub: StorageServiceProtocol, @unchecked Sendable {
    private var settings: [String: String] = [:]

    func insertSourceItem(_ item: SourceItem) async throws {}
    func getSourceItem(id: String) async throws -> SourceItem? { nil }
    func listSourceItems(filter: SourceItemFilter?) async throws -> [SourceItem] { [] }
    func updateSourceItem(_ item: SourceItem) async throws {}
    func deleteSourceItem(id: String) async throws {}

    func insertChatSession(_ session: ChatSession) async throws {}
    func getChatSession(id: String) async throws -> ChatSession? { nil }
    func listChatSessions(status: String?) async throws -> [ChatSession] { [] }
    func updateChatSession(_ session: ChatSession) async throws {}
    func deleteChatSession(id: String) async throws {}
    func insertChatMessage(_ message: ChatMessage) async throws {}
    func listChatMessages(sessionId: String) async throws -> [ChatMessage] { [] }

    func insertDistilledNote(_ note: DistilledNote) async throws {}
    func updateDistilledNote(_ note: DistilledNote) async throws {}
    func deleteDistilledNote(id: String) async throws {}
    func listDistilledNotes() async throws -> [DistilledNote] { [] }

    func insertExportRecord(_ record: ExportRecord) async throws {}
    func listExportRecords() async throws -> [ExportRecord] { [] }

    func insertKnowledgeCard(_ card: KnowledgeCard) async throws {}
    func updateKnowledgeCard(_ card: KnowledgeCard) async throws {}
    func listKnowledgeCards(status: KnowledgeCardStatus?) async throws -> [KnowledgeCard] { [] }

    func insertKnowledgeEdge(_ edge: KnowledgeEdge) async throws {}
    func listKnowledgeEdges(fromCardId: String?, toCardId: String?) async throws -> [KnowledgeEdge] { [] }
    func deleteKnowledgeEdge(id: String) async throws {}

    func insertClipboardItem(_ item: ClipboardItem) async throws {}
    func listClipboardItems(limit: Int?) async throws -> [ClipboardItem] { [] }
    func updateClipboardItem(_ item: ClipboardItem) async throws {}
    func deleteClipboardItem(id: String) async throws {}

    func listProviders() async -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}

    func getSetting(key: String) async throws -> String? { settings[key] }
    func insertScheduleEvent(_ event: ScheduleEvent) async throws {}
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {}
    func deleteScheduleEvent(id: String) async throws {}
    func listScheduleEvents() async throws -> [ScheduleEvent] { [] }
    func getScheduleEvent(id: String) async throws -> ScheduleEvent? { nil }
    func setSetting(key: String, value: String) async throws { settings[key] = value }

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { ":memory:" }
    func getDatabaseVersion() async throws -> Int { 1 }
}
