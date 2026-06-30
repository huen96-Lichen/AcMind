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

    func testScreenshotSnapshotFallsBackToDefaultPresetAndHotkeyText() throws {
        let suiteName = "AcMind.ScreenshotSnapshotTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let customPreset = ScreenshotPreset(
            id: "custom-copy",
            name: "自定义复制",
            captureAutoRedactionEnabled: false,
            captureCensorModeRawValue: CensorMode.blur.rawValue,
            captureScreenshotCornerRadius: 8,
            captureScreenshotMaxWidth: 1440,
            captureScreenshotMaxHeight: 900,
            defaultOutputAction: .copyToClipboard
        )

        SettingsLocalPreferences(
            screenshotPresets: [customPreset],
            selectedScreenshotPresetID: "missing-preset"
        ).save(to: defaults)

        let snapshot = SettingsLocalPreferences.screenshotSnapshot(
            from: AppSettings(captureScreenshotHotkey: "⌘⇧4"),
            defaults: defaults
        )

        XCTAssertEqual(snapshot.activePreset.id, customPreset.id)
        XCTAssertEqual(snapshot.activePreset.defaultOutputAction, .copyToClipboard)
        XCTAssertEqual(snapshot.hotkeyLabel, "全局热键：⌘⇧4")
    }

    func testScreenshotSnapshotUsesUnboundLabelWhenHotkeyMissing() throws {
        let suiteName = "AcMind.ScreenshotSnapshotFallbackTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let snapshot = SettingsLocalPreferences.screenshotSnapshot(defaults: defaults)
        XCTAssertEqual(snapshot.hotkeyLabel, "全局热键：未设置")
        XCTAssertEqual(snapshot.activePreset.id, ScreenshotPreset.defaultPresets.first?.id)
    }

    func testSaveAndLoadRoundTripPreservesScreenshotPresets() throws {
        let suiteName = "AcMind.ScreenshotPresetRoundTripTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let presets = [
            ScreenshotPreset(
                id: "roundtrip-save",
                name: "Roundtrip Save",
                captureAutoRedactionEnabled: true,
                captureCensorModeRawValue: CensorMode.pixelate.rawValue,
                captureScreenshotCornerRadius: 4,
                captureScreenshotMaxWidth: 0,
                captureScreenshotMaxHeight: 0,
                defaultOutputAction: .saveToInbox
            ),
            ScreenshotPreset(
                id: "roundtrip-copy",
                name: "Roundtrip Copy",
                captureAutoRedactionEnabled: false,
                captureCensorModeRawValue: CensorMode.blur.rawValue,
                captureScreenshotCornerRadius: 0,
                captureScreenshotMaxWidth: 1920,
                captureScreenshotMaxHeight: 1080,
                defaultOutputAction: .copyToClipboard
            )
        ]

        let expected = SettingsLocalPreferences(
            captureScreenshotEnabled: false,
            captureAutoRedactionEnabled: false,
            captureCensorModeRawValue: CensorMode.blur.rawValue,
            captureScreenshotCornerRadius: 10,
            captureScreenshotMaxWidth: 1280,
            captureScreenshotMaxHeight: 720,
            screenshotPresets: presets,
            selectedScreenshotPresetID: "roundtrip-copy"
        )

        expected.save(to: defaults)

        let loaded = SettingsLocalPreferences.load(from: defaults)
        XCTAssertEqual(loaded?.screenshotPresets, presets)
        XCTAssertEqual(loaded?.selectedScreenshotPresetID, "roundtrip-copy")
        XCTAssertEqual(loaded?.captureScreenshotCornerRadius, 10)
        XCTAssertEqual(loaded?.captureScreenshotMaxWidth, 1280)
        XCTAssertEqual(loaded?.captureScreenshotMaxHeight, 720)
    }

    func testDefaultScreenshotPresetsExposeExpectedNamesAndActions() {
        let presets = ScreenshotPreset.defaultPresets
        XCTAssertEqual(presets.count, 3)
        XCTAssertEqual(presets.map(\.name), ["默认保存", "复制优先", "隐私优先"])
        XCTAssertEqual(presets.map(\.defaultOutputAction), [.saveToInbox, .copyToClipboard, .saveToInbox])
        XCTAssertEqual(presets[0].captureAutoRedactionEnabled, true)
        XCTAssertEqual(presets[1].captureAutoRedactionEnabled, false)
        XCTAssertEqual(presets[2].captureScreenshotCornerRadius, 6)
    }

    func testBlankScreenshotPresetUsesNeutralDefaults() {
        let preset = ScreenshotPreset.blankPreset(name: "临时预设")
        XCTAssertEqual(preset.name, "临时预设")
        XCTAssertEqual(preset.defaultOutputAction, .saveToInbox)
        XCTAssertTrue(preset.captureAutoRedactionEnabled == false)
        XCTAssertEqual(preset.captureCensorMode, .pixelate)
        XCTAssertEqual(preset.captureScreenshotCornerRadius, 0)
        XCTAssertEqual(preset.captureScreenshotMaxWidth, 0)
        XCTAssertEqual(preset.captureScreenshotMaxHeight, 0)
    }

    func testScreenshotPresetStateHelpersMaintainSelectionAndDefaults() {
        let customPreset = ScreenshotPreset(
            id: "custom",
            name: "自定义预设",
            captureAutoRedactionEnabled: false,
            captureCensorModeRawValue: CensorMode.blur.rawValue,
            captureScreenshotCornerRadius: 8,
            captureScreenshotMaxWidth: 1440,
            captureScreenshotMaxHeight: 900,
            defaultOutputAction: .copyToClipboard
        )

        let blankName = SettingsLocalPreferences.nextBlankScreenshotPresetName(in: [customPreset])
        XCTAssertEqual(blankName, "新建预设")

        let restored = SettingsLocalPreferences.restoredDefaultScreenshotPresetState()
        XCTAssertEqual(restored.presets.map(\.name), ["默认保存", "复制优先", "隐私优先"])
        XCTAssertEqual(restored.selectedPresetID, "default-save")

        let created = SettingsLocalPreferences.createBlankScreenshotPresetState(from: [customPreset])
        XCTAssertEqual(created.presets.count, 2)
        XCTAssertEqual(created.presets.last?.name, "新建预设")
        XCTAssertEqual(created.selectedPresetID, created.presets.last?.id)

        let duplicated = SettingsLocalPreferences.duplicateSelectedScreenshotPresetState(
            from: [customPreset],
            selectedPresetID: customPreset.id
        )
        XCTAssertEqual(duplicated.presets.count, 2)
        XCTAssertEqual(duplicated.presets.last?.name, "自定义预设 副本")
        XCTAssertEqual(duplicated.selectedPresetID, duplicated.presets.last?.id)

        let deleted = SettingsLocalPreferences.deleteSelectedScreenshotPresetState(
            from: duplicated.presets,
            selectedPresetID: duplicated.selectedPresetID
        )
        XCTAssertEqual(deleted.presets.count, 1)
        XCTAssertEqual(deleted.selectedPresetID, customPreset.id)

        let renamed = SettingsLocalPreferences.renameSelectedScreenshotPresetState(
            from: [customPreset],
            selectedPresetID: customPreset.id,
            newName: "  新名字  "
        )
        XCTAssertEqual(renamed.first?.name, "新名字")

        let updatedAction = SettingsLocalPreferences.updateSelectedScreenshotPresetOutputActionState(
            from: [customPreset],
            selectedPresetID: customPreset.id,
            action: .pinToDesktop
        )
        XCTAssertEqual(updatedAction.first?.defaultOutputAction, .pinToDesktop)
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
