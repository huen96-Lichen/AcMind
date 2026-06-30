import XCTest
@testable import AcMindKit

final class AIRuntimeServiceLoggingTests: XCTestCase {
    func testAiCallLogsAreSuppressedWhenDisabled() async throws {
        let defaults = makeDefaults(aiCallLogEnabled: false, errorLogEnabled: true)
        let sink = RecordingAIRuntimeLoggingSink()
        let service = AIRuntimeService(
            storage: LoggingTestStorageStub(),
            settingsDefaults: defaults,
            loggingSink: sink
        )
        service.installTestProvider(id: "mock", provider: SuccessAIProvider())

        _ = try await service.chat(
            messages: [ChatMessage(sessionId: "test", role: .user, content: "hello")],
            providerId: "mock",
            model: "mock-model"
        )

        XCTAssertTrue(sink.events.isEmpty)
    }

    func testAiCallLogsEmitStartAndSuccessWhenEnabled() async throws {
        let defaults = makeDefaults(aiCallLogEnabled: true, errorLogEnabled: true)
        let sink = RecordingAIRuntimeLoggingSink()
        let service = AIRuntimeService(
            storage: LoggingTestStorageStub(),
            settingsDefaults: defaults,
            loggingSink: sink
        )
        service.installTestProvider(id: "mock", provider: SuccessAIProvider())

        _ = try await service.chat(
            messages: [ChatMessage(sessionId: "test", role: .user, content: "hello")],
            providerId: "mock",
            model: "mock-model"
        )

        XCTAssertEqual(sink.events.count, 2)
        XCTAssertTrue(sink.events[0].contains("chat start provider=mock model=mock-model"))
        XCTAssertTrue(sink.events[1].contains("chat success provider=mock model=mock-model"))
    }

    func testErrorLogsAreSuppressedWhenDisabled() async throws {
        let defaults = makeDefaults(aiCallLogEnabled: true, errorLogEnabled: false)
        let sink = RecordingAIRuntimeLoggingSink()
        let service = AIRuntimeService(
            storage: LoggingTestStorageStub(),
            settingsDefaults: defaults,
            loggingSink: sink
        )
        service.installTestProvider(id: "mock", provider: FailingAIProvider())

        do {
            _ = try await service.chat(
                messages: [ChatMessage(sessionId: "test", role: .user, content: "hello")],
                providerId: "mock",
                model: "mock-model"
            )
            XCTFail("Expected chat to throw")
        } catch {
        }

        XCTAssertEqual(sink.events.count, 1)
        XCTAssertTrue(sink.events[0].contains("chat start provider=mock model=mock-model"))
    }

    func testErrorLogsEmitFailureWhenEnabled() async throws {
        let defaults = makeDefaults(aiCallLogEnabled: true, errorLogEnabled: true)
        let sink = RecordingAIRuntimeLoggingSink()
        let service = AIRuntimeService(
            storage: LoggingTestStorageStub(),
            settingsDefaults: defaults,
            loggingSink: sink
        )
        service.installTestProvider(id: "mock", provider: FailingAIProvider())

        do {
            _ = try await service.chat(
                messages: [ChatMessage(sessionId: "test", role: .user, content: "hello")],
                providerId: "mock",
                model: "mock-model"
            )
            XCTFail("Expected chat to throw")
        } catch {
        }

        XCTAssertEqual(sink.events.count, 2)
        XCTAssertTrue(sink.events[0].contains("chat start provider=mock model=mock-model"))
        XCTAssertTrue(sink.events[1].contains("chat failed provider=mock model=mock-model"))
    }

    func testChatStreamLogsAreSuppressedWhenDisabled() async throws {
        let defaults = makeDefaults(aiCallLogEnabled: false, errorLogEnabled: true)
        let sink = RecordingAIRuntimeLoggingSink()
        let service = AIRuntimeService(
            storage: LoggingTestStorageStub(),
            settingsDefaults: defaults,
            loggingSink: sink
        )
        service.installTestProvider(id: "mock", provider: StreamingAIProvider(), modelId: "mock-model")

        let stream = service.chatStream(
            messages: [ChatMessage(sessionId: "test", role: .user, content: "hello")]
        )
        let responses = try await collect(stream)

        XCTAssertEqual(responses.map(\.content), ["chunk-1", "chunk-2"])
        XCTAssertTrue(sink.events.isEmpty)
    }

    func testChatStreamLogsEmitStartAndSuccessWhenEnabled() async throws {
        let defaults = makeDefaults(aiCallLogEnabled: true, errorLogEnabled: true)
        let sink = RecordingAIRuntimeLoggingSink()
        let service = AIRuntimeService(
            storage: LoggingTestStorageStub(),
            settingsDefaults: defaults,
            loggingSink: sink
        )
        service.installTestProvider(id: "mock", provider: StreamingAIProvider(), modelId: "mock-model")

        let stream = service.chatStream(
            messages: [ChatMessage(sessionId: "test", role: .user, content: "hello")]
        )
        let responses = try await collect(stream)

        XCTAssertEqual(responses.map(\.content), ["chunk-1", "chunk-2"])
        XCTAssertEqual(sink.events.count, 2)
        XCTAssertTrue(sink.events[0].contains("chat stream start provider=mock model=mock-model"))
        XCTAssertTrue(sink.events[1].contains("chat stream success provider=mock model=mock-model chunks=2"))
    }

    private func makeDefaults(aiCallLogEnabled: Bool, errorLogEnabled: Bool) -> UserDefaults {
        let suiteName = "AcMind.AIRuntimeServiceLoggingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        SettingsLocalPreferences(
            aiCallLogEnabled: aiCallLogEnabled,
            errorLogEnabled: errorLogEnabled
        ).save(to: defaults)

        return defaults
    }

    private func collect(_ stream: AsyncThrowingStream<ChatResponse, Error>) async throws -> [ChatResponse] {
        var responses: [ChatResponse] = []
        for try await response in stream {
            responses.append(response)
        }
        return responses
    }

}

private final class RecordingAIRuntimeLoggingSink: AIRuntimeLoggingSink, @unchecked Sendable {
    private var messages: [String] = []
    private let lock = NSLock()

    var events: [String] {
        lock.lock()
        defer { lock.unlock() }
        return messages
    }

    func logAI(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        messages.append(message)
    }

    func logError(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        messages.append(message)
    }
}

private final class SuccessAIProvider: AIProvider, @unchecked Sendable {
    func chat(messages: [ChatMessage], config: ChatConfig) async throws -> ChatResponse {
        ChatResponse(
            content: "ok",
            model: config.model ?? "mock-model",
            usage: ChatUsage(promptTokens: 12, completionTokens: 34)
        )
    }

    func chatStream(messages: [ChatMessage], config: ChatConfig) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func listModels() async throws -> [String] { ["mock-model"] }
    func healthCheck() async throws -> Bool { true }
}

private final class FailingAIProvider: AIProvider, @unchecked Sendable {
    func chat(messages: [ChatMessage], config: ChatConfig) async throws -> ChatResponse {
        throw AIError.requestFailed("boom")
    }

    func chatStream(messages: [ChatMessage], config: ChatConfig) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func listModels() async throws -> [String] { [] }
    func healthCheck() async throws -> Bool { false }
}

private final class StreamingAIProvider: AIProvider, @unchecked Sendable {
    func chat(messages: [ChatMessage], config: ChatConfig) async throws -> ChatResponse {
        ChatResponse(content: "unused", model: config.model ?? "mock-model")
    }

    func chatStream(messages: [ChatMessage], config: ChatConfig) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(ChatResponse(content: "chunk-1", model: config.model ?? "mock-model", isStreaming: true))
            continuation.yield(ChatResponse(content: "chunk-2", model: config.model ?? "mock-model", isStreaming: true))
            continuation.finish()
        }
    }

    func listModels() async throws -> [String] { ["mock-model"] }
    func healthCheck() async throws -> Bool { true }
}

private final class LoggingTestStorageStub: StorageServiceProtocol, @unchecked Sendable {
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
