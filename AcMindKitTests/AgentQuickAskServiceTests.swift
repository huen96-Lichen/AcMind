import XCTest
@testable import AcMindKit

final class AgentQuickAskServiceTests: XCTestCase {
    func testAskUsesProviderAndPreservesQuestion() async throws {
        let provider = ProviderConfig(
            id: "provider-1",
            name: "Test Provider",
            providerType: .openAICompatible,
            tier: .localLight,
            baseURL: "https://example.com",
            modelId: "gpt-test",
            enabled: true
        )

        let aiRuntime = AgentQuickAskAIRuntimeMock(
            providers: [provider],
            response: ChatResponse(content: "你可以先拆成三步。", model: "gpt-test", providerId: "provider-1")
        )

        let service = AgentQuickAskService(aiRuntime: aiRuntime)
        let response = try await service.ask(
            question: "我该怎么开始？",
            providerId: "provider-1",
            model: "gpt-test",
            context: "项目目标是尽快验证方向"
        )

        XCTAssertEqual(response.content, "你可以先拆成三步。")
        XCTAssertEqual(aiRuntime.lastProviderId, "provider-1")
        XCTAssertEqual(aiRuntime.lastModel, "gpt-test")
        XCTAssertEqual(aiRuntime.lastMessages?.first?.role, .system)
        XCTAssertTrue(aiRuntime.lastMessages?.last?.content.contains("我该怎么开始？") == true)
        XCTAssertTrue(aiRuntime.lastMessages?.last?.content.contains("项目目标是尽快验证方向") == true)
    }

    func testAskPersistsQuickAskHistory() async throws {
        let provider = ProviderConfig(
            id: "provider-1",
            name: "Test Provider",
            providerType: .openAICompatible,
            tier: .localLight,
            baseURL: "https://example.com",
            modelId: "gpt-test",
            enabled: true
        )

        let storage = AgentQuickAskStorageMock()
        let aiRuntime = AgentQuickAskAIRuntimeMock(
            providers: [provider],
            response: ChatResponse(content: "先从问题定义开始。", model: "gpt-test", providerId: "provider-1")
        )

        let service = AgentQuickAskService(aiRuntime: aiRuntime, storage: storage)
        _ = try await service.ask(
            question: "我该怎么开始？",
            providerId: "provider-1",
            model: "gpt-test",
            context: "项目目标是尽快验证方向"
        )

        let sessions = storage.sessions
        let messages = storage.messages
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(sessions.first?.metadata["kind"], "quickAsk")
        XCTAssertEqual(sessions.first?.title, "我该怎么开始？")
        XCTAssertEqual(messages.first?.role, .user)
        XCTAssertEqual(messages.last?.role, .assistant)
        XCTAssertTrue(messages.first?.content.contains("项目目标是尽快验证方向") == true)
        XCTAssertTrue(messages.last?.content.contains("先从问题定义开始。") == true)
    }
}

private final class AgentQuickAskAIRuntimeMock: AIRuntimeProtocol, @unchecked Sendable {
    var providers: [ProviderConfig]
    var response: ChatResponse
    private(set) var lastMessages: [ChatMessage]?
    private(set) var lastProviderId: String?
    private(set) var lastModel: String?

    init(
        providers: [ProviderConfig] = [],
        response: ChatResponse = ChatResponse(content: "mock-response")
    ) {
        self.providers = providers
        self.response = response
    }

    func listProviders() async -> [ProviderConfig] {
        providers
    }

    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}
    func healthCheck(providerId: String) async throws -> Bool { true }
    func listModels(providerId: String) async throws -> [String] { [] }
    func listJobs() async throws -> [ProcessJob] { [] }
    func cancelJob(id: String) async throws {}
    func runDistillation(sourceItem: SourceItem) async throws -> DistilledNote { throw AIError.noProvider }

    func chat(messages: [ChatMessage]) async throws -> ChatResponse {
        lastMessages = messages
        lastProviderId = nil
        lastModel = nil
        return response
    }

    func chat(messages: [ChatMessage], providerId: String, model: String?) async throws -> ChatResponse {
        lastMessages = messages
        lastProviderId = providerId
        lastModel = model
        return response
    }

    func chatStream(messages: [ChatMessage]) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(response)
            continuation.finish()
        }
    }
}

private final class AgentQuickAskStorageMock: StorageServiceProtocol, @unchecked Sendable {
    private(set) var sessions: [ChatSession] = []
    private(set) var messages: [ChatMessage] = []

    func insertSourceItem(_ item: SourceItem) async throws {}
    func getSourceItem(id: String) async throws -> SourceItem? { nil }
    func listSourceItems(filter: SourceItemFilter?) async throws -> [SourceItem] { [] }
    func updateSourceItem(_ item: SourceItem) async throws {}
    func deleteSourceItem(id: String) async throws {}

    func insertChatSession(_ session: ChatSession) async throws {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
    }

    func getChatSession(id: String) async throws -> ChatSession? {
        sessions.first { $0.id == id }
    }

    func listChatSessions(status: String?) async throws -> [ChatSession] {
        if let status {
            return sessions.filter { $0.status.rawValue == status }
        }
        return sessions
    }

    func updateChatSession(_ session: ChatSession) async throws {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
    }

    func deleteChatSession(id: String) async throws {
        sessions.removeAll { $0.id == id }
    }

    func insertChatMessage(_ message: ChatMessage) async throws {
        messages.append(message)
    }

    func listChatMessages(sessionId: String) async throws -> [ChatMessage] {
        messages.filter { $0.sessionId == sessionId }
    }

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
    func insertScheduledAgentTask(_ task: ScheduledAgentTask) async throws {}
    func getScheduledAgentTask(id: String) async throws -> ScheduledAgentTask? { nil }
    func listScheduledAgentTasks() async throws -> [ScheduledAgentTask] { [] }
    func deleteScheduledAgentTask(id: String) async throws {}
    func listProviders() async throws -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}
    func getSetting(key: String) async throws -> String? { nil }
    func insertScheduleEvent(_ event: ScheduleEvent) async throws {}
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {}
    func deleteScheduleEvent(id: String) async throws {}
    func listScheduleEvents() async throws -> [ScheduleEvent] { [] }
    func getScheduleEvent(id: String) async throws -> ScheduleEvent? { nil }
    func setSetting(key: String, value: String) async throws {}
    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { ":memory:" }
    func getDatabaseVersion() async throws -> Int { 1 }
}
