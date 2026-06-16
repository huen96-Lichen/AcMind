import XCTest
@testable import AcMindKit

final class SettingsMigrationServiceTests: XCTestCase {
    func testRunIfNeededMigratesLegacyPreferencesHotkeysAndVoiceSettings() async throws {
        let suiteName = "AcMind.SettingsMigrationServiceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(false, forKey: "autoBackupEnabled")
        defaults.set(true, forKey: "captureOnlyWhenAppActive")
        defaults.set(false, forKey: "captureScreenshotEnabled")
        defaults.set(false, forKey: "captureAutoRedactionEnabled")
        defaults.set(12.5, forKey: "captureScreenshotCornerRadius")
        defaults.set(1280, forKey: "captureScreenshotMaxWidth")
        defaults.set(720, forKey: "captureScreenshotMaxHeight")
        defaults.set(false, forKey: "companionCaptureAutoSaveToInbox")
        defaults.set(true, forKey: "companionCaptureOpenDetailAfterCapture")
        defaults.set(false, forKey: "companionCaptureShowNotification")
        defaults.set(false, forKey: "voiceInputEnabled")
        defaults.set(false, forKey: "localFirstMode")
        defaults.set(false, forKey: "sensitiveContentNotUpload")
        defaults.set(false, forKey: "apiKeyUsesKeychain")
        defaults.set(false, forKey: "aiCallLogEnabled")
        defaults.set(true, forKey: "errorLogEnabled")
        defaults.set("⌃⌥S", forKey: "AppSettings.captureScreenshotHotkey")
        defaults.set("⌃⌥V", forKey: "companionVoiceShortcut")

        let storage = InMemoryStorageStub()
        try await storage.setSetting(key: "voice.polishMode", value: "balanced")

        let service = SettingsMigrationService(defaults: defaults, storage: storage)
        let result = try await service.runIfNeeded()

        XCTAssertTrue(result.migrated)
        XCTAssertEqual(result.currentVersion, 3)
        XCTAssertEqual(result.appliedVersions, [1, 2, 3])

        let migratedPreferences = SettingsLocalPreferences.load(from: defaults)
        XCTAssertEqual(
            migratedPreferences,
            SettingsLocalPreferences(
                autoBackupEnabled: false,
                restoreWindowPosition: true,
                notificationsEnabled: true,
                taskCompletedNotificationsEnabled: true,
                updateAvailableNotificationsEnabled: true,
                captureOnlyWhenAppActive: true,
                captureScreenshotEnabled: false,
                captureAutoRedactionEnabled: false,
                captureCensorModeRawValue: CensorMode.pixelate.rawValue,
                captureScreenshotCornerRadius: 12.5,
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
        )

        XCTAssertNil(defaults.object(forKey: "autoBackupEnabled"))
        XCTAssertNil(defaults.object(forKey: "captureOnlyWhenAppActive"))
        XCTAssertNil(defaults.object(forKey: "captureScreenshotEnabled"))
        XCTAssertNil(defaults.object(forKey: "captureAutoRedactionEnabled"))
        XCTAssertNil(defaults.object(forKey: "captureScreenshotCornerRadius"))
        XCTAssertNil(defaults.object(forKey: "captureScreenshotMaxWidth"))
        XCTAssertNil(defaults.object(forKey: "captureScreenshotMaxHeight"))
        XCTAssertNil(defaults.object(forKey: "companionCaptureAutoSaveToInbox"))
        XCTAssertNil(defaults.object(forKey: "companionCaptureOpenDetailAfterCapture"))
        XCTAssertNil(defaults.object(forKey: "companionCaptureShowNotification"))
        XCTAssertNil(defaults.object(forKey: "voiceInputEnabled"))
        XCTAssertNil(defaults.object(forKey: "localFirstMode"))
        XCTAssertNil(defaults.object(forKey: "sensitiveContentNotUpload"))
        XCTAssertNil(defaults.object(forKey: "apiKeyUsesKeychain"))
        XCTAssertNil(defaults.object(forKey: "aiCallLogEnabled"))
        XCTAssertNil(defaults.object(forKey: "errorLogEnabled"))
        XCTAssertNil(defaults.object(forKey: "AppSettings.captureScreenshotHotkey"))
        XCTAssertNil(defaults.object(forKey: "companionVoiceShortcut"))

        let migratedScreenshotHotkey = try await storage.getSetting(key: "app.captureScreenshotHotkey")
        XCTAssertEqual(migratedScreenshotHotkey, "⌃⌥S")
        let migratedCompanionConfigValue = try await storage.getSetting(key: "companion_config")
        let migratedCompanionConfig = try XCTUnwrap(migratedCompanionConfigValue)
        let migratedCompanionData = try XCTUnwrap(migratedCompanionConfig.data(using: .utf8))
        let decodedCompanionConfig = try JSONDecoder().decode(CompanionConfiguration.self, from: migratedCompanionData)
        XCTAssertEqual(decodedCompanionConfig.voiceShortcut, "⌃⌥V")
        XCTAssertEqual(decodedCompanionConfig, CompanionConfiguration(voiceShortcut: "⌃⌥V"))
        let migratedVoicePolishMode = try await storage.getSetting(key: "voice.voicePolishMode")
        let removedLegacyVoicePolishMode = try await storage.getSetting(key: "voice.polishMode")
        XCTAssertEqual(migratedVoicePolishMode, "balanced")
        XCTAssertNil(removedLegacyVoicePolishMode)
    }

    func testRunIfNeededIsIdempotentAfterMigrationCompletes() async throws {
        let suiteName = "AcMind.SettingsMigrationServiceIdempotenceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(true, forKey: "captureOnlyWhenAppActive")
        defaults.set("⌥Space", forKey: "AppSettings.captureScreenshotHotkey")
        defaults.set("⌘⇧V", forKey: "companionVoiceShortcut")

        let storage = InMemoryStorageStub()
        try await storage.setSetting(key: "voice.polishMode", value: "light")

        let service = SettingsMigrationService(defaults: defaults, storage: storage)
        let first = try await service.runIfNeeded()
        let second = try await service.runIfNeeded()

        XCTAssertTrue(first.migrated)
        XCTAssertFalse(second.migrated)
        XCTAssertEqual(second.currentVersion, 3)
        let migratedScreenshotHotkey = try await storage.getSetting(key: "app.captureScreenshotHotkey")
        XCTAssertEqual(migratedScreenshotHotkey, "⌥Space")
        let migratedCompanionConfigValue = try await storage.getSetting(key: "companion_config")
        let migratedCompanionConfig = try XCTUnwrap(migratedCompanionConfigValue)
        let migratedCompanionData = try XCTUnwrap(migratedCompanionConfig.data(using: .utf8))
        let decodedCompanionConfig = try JSONDecoder().decode(CompanionConfiguration.self, from: migratedCompanionData)
        XCTAssertEqual(decodedCompanionConfig.voiceShortcut, "⌘⇧V")
        XCTAssertEqual(decodedCompanionConfig, CompanionConfiguration(voiceShortcut: "⌘⇧V"))
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
    func setSetting(key: String, value: String) async throws { settings[key] = value }
    func deleteSetting(key: String) async throws { settings.removeValue(forKey: key) }

    func insertScheduleEvent(_ event: ScheduleEvent) async throws {}
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {}
    func deleteScheduleEvent(id: String) async throws {}
    func listScheduleEvents() async throws -> [ScheduleEvent] { [] }
    func getScheduleEvent(id: String) async throws -> ScheduleEvent? { nil }

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { ":memory:" }
    func getDatabaseVersion() async throws -> Int { 1 }
}
