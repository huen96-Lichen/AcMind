import XCTest
@testable import AcMindKit

@MainActor
final class SettingsServiceVaultConfigTests: XCTestCase {

    func testAgentModelRouterHonorsRoutingStrategy() async throws {
        let costRouter = AgentModelRouter(strategy: .costPriority)
        let qualityRouter = AgentModelRouter(strategy: .qualityPriority)
        let privacyRouter = AgentModelRouter(strategy: .privacyPriority)

        let request = ModelRouteRequest(taskType: .simpleChat, inputLength: 8_000, complexity: .medium)

        let costRoute = try await costRouter.route(request: request)
        let qualityRoute = try await qualityRouter.route(request: request)
        let privacyRoute = try await privacyRouter.route(request: request)

        XCTAssertEqual(costRoute.providerId, "ollama", "costRoute=\(costRoute.providerId)/\(costRoute.modelId) reason=\(costRoute.reason)")
        XCTAssertEqual(costRoute.modelId, "llama3", "costRoute=\(costRoute.providerId)/\(costRoute.modelId) reason=\(costRoute.reason)")
        XCTAssertEqual(qualityRoute.providerId, "openai", "qualityRoute=\(qualityRoute.providerId)/\(qualityRoute.modelId) reason=\(qualityRoute.reason)")
        XCTAssertEqual(qualityRoute.modelId, "gpt-4o", "qualityRoute=\(qualityRoute.providerId)/\(qualityRoute.modelId) reason=\(qualityRoute.reason)")
        XCTAssertEqual(privacyRoute.providerId, "ollama", "privacyRoute=\(privacyRoute.providerId)/\(privacyRoute.modelId) reason=\(privacyRoute.reason)")
        XCTAssertTrue(privacyRoute.reason.contains("隐私优先"), "privacyRoute reason=\(privacyRoute.reason)")
        XCTAssertTrue(costRoute.reason.contains("策略: 低成本"), "costRoute reason=\(costRoute.reason)")
        XCTAssertTrue(qualityRoute.reason.contains("策略: 高质量"), "qualityRoute reason=\(qualityRoute.reason)")
    }

    func testModelRoutingStrategyRoundTripThroughStorage() async throws {
        let storage = SettingsStorageStub()
        let permissionManager = PermissionManager()
        let firstService = SettingsService(storage: storage, permissionManager: permissionManager)

        var settings = AppSettings()
        settings.theme = .dark
        settings.language = "en"
        settings.defaultProviderId = "anthropic"
        settings.defaultModelId = "claude-sonnet-4-20250514"
        settings.modelRoutingStrategy = .privacyPriority
        settings.vaultPath = "/tmp/acmind-vault"
        settings.autoCaptureClipboard = false
        settings.captureScreenshotHotkey = "⌘⇧5"
        settings.defaultExportTarget = .markdown
        settings.autoFrontmatter = false

        try await firstService.updateSettings(settings)

        XCTAssertEqual(storage.settings["app.modelRoutingStrategy"], "privacyPriority")

        let secondService = SettingsService(storage: storage, permissionManager: permissionManager)
        let loaded = await secondService.getSettings()

        XCTAssertEqual(loaded.theme, .dark)
        XCTAssertEqual(loaded.language, "en")
        XCTAssertEqual(loaded.defaultProviderId, "anthropic")
        XCTAssertEqual(loaded.defaultModelId, "claude-sonnet-4-20250514")
        XCTAssertEqual(loaded.modelRoutingStrategy, .privacyPriority)
        XCTAssertEqual(loaded.vaultPath, "/tmp/acmind-vault")
        XCTAssertFalse(loaded.autoCaptureClipboard)
        XCTAssertEqual(loaded.captureScreenshotHotkey, "⌘⇧5")
        XCTAssertEqual(loaded.defaultExportTarget, .markdown)
        XCTAssertFalse(loaded.autoFrontmatter)
    }

    func testUpdateSettingsPostsSettingsDidChangeNotification() async throws {
        let storage = SettingsStorageStub()
        let permissionManager = PermissionManager()
        let service = SettingsService(storage: storage, permissionManager: permissionManager)

        let expectation = expectation(forNotification: .settingsDidChange, object: nil, handler: nil)

        var settings = AppSettings()
        settings.captureScreenshotHotkey = "⌘⇧5"

        try await service.updateSettings(settings)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testVaultFrontmatterTemplateRoundTripThroughStorage() async throws {
        let storage = SettingsStorageStub()
        let permissionManager = PermissionManager()
        let firstService = SettingsService(storage: storage, permissionManager: permissionManager)

        let config = VaultConfig(
            vaultPath: "/tmp/acmind-vault",
            defaultFolder: "Inbox",
            template: "## {{title}}",
            pathRule: .sourceType,
            conflictStrategy: .rename,
            autoFrontmatter: true,
            frontmatterTemplate: [
                "vault_tag": "AcMind",
                "review_status": "ready"
            ]
        )

        try await firstService.updateVaultConfig(config)

        XCTAssertEqual(storage.settings["vault.frontmatterTemplate"], #"{"review_status":"ready","vault_tag":"AcMind"}"#)

        let secondService = SettingsService(storage: storage, permissionManager: permissionManager)
        let loaded = await secondService.getVaultConfig()

        XCTAssertEqual(loaded.vaultPath, "/tmp/acmind-vault")
        XCTAssertEqual(loaded.defaultFolder, "Inbox")
        XCTAssertEqual(loaded.template, "## {{title}}")
        XCTAssertEqual(loaded.pathRule, .sourceType)
        XCTAssertEqual(loaded.conflictStrategy, .rename)
        XCTAssertTrue(loaded.autoFrontmatter)
        XCTAssertEqual(loaded.frontmatterTemplate["vault_tag"], "AcMind")
        XCTAssertEqual(loaded.frontmatterTemplate["review_status"], "ready")
    }

    func testProviderConfigRoundTripThroughStorage() async throws {
        let storage = SettingsStorageStub()
        let permissionManager = PermissionManager()
        let service = SettingsService(storage: storage, permissionManager: permissionManager)

        let provider = ProviderConfig(
            id: "provider-a",
            name: "Local Ollama",
            providerType: .ollama,
            tier: .localLight,
            baseURL: "http://127.0.0.1:11434",
            modelId: "llama3",
            enabled: true,
            capabilities: ["chat", "summarize"]
        )

        try await service.addProvider(provider, apiKey: nil)
        let loadedProviders = try await service.listProviders()
        XCTAssertEqual(loadedProviders, [provider])

        var updated = provider
        updated.modelId = "llama3.1"
        updated.enabled = false

        try await service.updateProvider(updated, apiKey: nil)

        let reloaded = try await service.listProviders()
        XCTAssertEqual(reloaded.first?.modelId, "llama3.1")
        XCTAssertEqual(reloaded.first?.enabled, false)

        try await service.removeProvider(id: provider.id)
        let remainingProviders = try await service.listProviders()
        XCTAssertTrue(remainingProviders.isEmpty)
    }

    func testRemovingDefaultProviderClearsDefaultSelection() async throws {
        let storage = SettingsStorageStub()
        let permissionManager = PermissionManager()
        let service = SettingsService(storage: storage, permissionManager: permissionManager)

        var settings = AppSettings()
        settings.defaultProviderId = "provider-a"
        settings.defaultModelId = "llama3"
        try await service.updateSettings(settings)

        let provider = ProviderConfig(
            id: "provider-a",
            name: "Local Ollama",
            providerType: .ollama,
            tier: .localLight,
            baseURL: "http://127.0.0.1:11434",
            modelId: "llama3",
            enabled: true
        )
        try await service.addProvider(provider, apiKey: nil)
        try await service.removeProvider(id: provider.id)

        let loaded = await service.getSettings()
        XCTAssertNil(loaded.defaultProviderId)
        XCTAssertNil(loaded.defaultModelId)
        XCTAssertNil(storage.settings["app.defaultProviderId"])
        XCTAssertNil(storage.settings["app.defaultModelId"])
    }

    func testDisablingDefaultProviderClearsDefaultSelection() async throws {
        let storage = SettingsStorageStub()
        let permissionManager = PermissionManager()
        let service = SettingsService(storage: storage, permissionManager: permissionManager)

        var settings = AppSettings()
        settings.defaultProviderId = "provider-b"
        settings.defaultModelId = "qwen2.5"
        try await service.updateSettings(settings)

        let provider = ProviderConfig(
            id: "provider-b",
            name: "Cloud Provider",
            providerType: .openAICompatible,
            tier: .cloudLight,
            baseURL: "https://example.com",
            modelId: "qwen2.5",
            enabled: true
        )
        try await service.addProvider(provider, apiKey: nil)

        var disabledProvider = provider
        disabledProvider.enabled = false
        try await service.updateProvider(disabledProvider, apiKey: nil)

        let loaded = await service.getSettings()
        XCTAssertNil(loaded.defaultProviderId)
        XCTAssertNil(loaded.defaultModelId)
        XCTAssertNil(storage.settings["app.defaultProviderId"])
        XCTAssertNil(storage.settings["app.defaultModelId"])
    }

    func testSelectableSpeechProvidersOnlyIncludeRoutableProviders() {
        let providers = Set(STTProvider.selectableCases)

        XCTAssertTrue(providers.contains(.appleSpeech))
        XCTAssertTrue(providers.contains(.whisperKit))
        XCTAssertTrue(providers.contains(.openAI))
        XCTAssertFalse(providers.contains(.googleCloud))
        XCTAssertFalse(providers.contains(.groq))
        XCTAssertFalse(providers.contains(.freeModel))
    }

    func testVoiceSettingsNormalizeLegacyAndUnsupportedProviders() async throws {
        let storage = SettingsStorageStub()
        storage.settings["voice.defaultProvider"] = "qwen3ASR"
        let firstService = SettingsService(storage: storage, permissionManager: PermissionManager())

        let loadedLegacy = await firstService.getVoiceSettings()
        XCTAssertEqual(loadedLegacy.defaultProvider, STTProvider.qwen3ASR.rawValue)

        let secondStorage = SettingsStorageStub()
        secondStorage.settings["voice.defaultProvider"] = STTProvider.groq.rawValue
        let secondService = SettingsService(storage: secondStorage, permissionManager: PermissionManager())

        let loadedUnsupported = await secondService.getVoiceSettings()
        XCTAssertEqual(loadedUnsupported.defaultProvider, STTProvider.appleSpeech.rawValue)

        var settings = VoiceSettings(defaultProvider: STTProvider.googleCloud.rawValue)
        try await secondService.updateVoiceSettings(settings)
        XCTAssertEqual(secondStorage.settings["voice.defaultProvider"], STTProvider.appleSpeech.rawValue)
        let cachedUnsupported = await secondService.getVoiceSettings()
        XCTAssertEqual(cachedUnsupported.defaultProvider, STTProvider.appleSpeech.rawValue)

        settings.defaultProvider = "whisper"
        try await secondService.updateVoiceSettings(settings)
        XCTAssertEqual(secondStorage.settings["voice.defaultProvider"], STTProvider.openAI.rawValue)
        let cachedLegacy = await secondService.getVoiceSettings()
        XCTAssertEqual(cachedLegacy.defaultProvider, STTProvider.openAI.rawValue)
    }
}

private final class SettingsStorageStub: StorageServiceProtocol, @unchecked Sendable {
    var settings: [String: String] = [:]
    var providers: [ProviderConfig] = []

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

    func listProviders() async -> [ProviderConfig] { providers }
    func addProvider(_ config: ProviderConfig) async throws { providers.append(config) }
    func updateProvider(_ config: ProviderConfig) async throws {
        if let index = providers.firstIndex(where: { $0.id == config.id }) {
            providers[index] = config
        } else {
            providers.append(config)
        }
    }
    func removeProvider(id: String) async throws {
        providers.removeAll { $0.id == id }
    }

    func getSetting(key: String) async throws -> String? {
        settings[key]
    }
    func deleteSetting(key: String) async throws {
        settings.removeValue(forKey: key)
    }

    func insertScheduleEvent(_ event: ScheduleEvent) async throws {}
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {}
    func deleteScheduleEvent(id: String) async throws {}
    func listScheduleEvents() async throws -> [ScheduleEvent] { [] }
    func getScheduleEvent(id: String) async throws -> ScheduleEvent? { nil }
    func setSetting(key: String, value: String) async throws {
        settings[key] = value
    }

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { ":memory:" }
    func getDatabaseVersion() async throws -> Int { 1 }
}
