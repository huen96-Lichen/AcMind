import XCTest
@testable import AcMindKit

@MainActor
final class AgentTaskBoardServiceTests: XCTestCase {
    var storage: MockTaskStorage!
    var service: AgentTaskBoardService!

    override func setUp() async throws {
        try await super.setUp()
        storage = MockTaskStorage()
        service = AgentTaskBoardService(storage: storage)
    }

    override func tearDown() async throws {
        service = nil
        storage = nil
        try await super.tearDown()
    }

    func testCreateAndGetTask() async throws {
        let expectation = expectation(forNotification: .agentTaskBoardDidChange, object: nil, handler: nil)
        let id = "task-\(UUID().uuidString)"
        let task = AgentTask(id: id, title: "Build feature X", description: "Implement the new feature")

        let created = try await service.createTask(task)
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(created.id, id)
        XCTAssertEqual(created.title, "Build feature X")
        XCTAssertEqual(created.status, .pending)

        let retrieved = try await service.getTask(id: id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, id)
        XCTAssertEqual(retrieved?.title, "Build feature X")
        XCTAssertEqual(retrieved?.description, "Implement the new feature")
        XCTAssertNotNil(retrieved?.createdAt)
    }

    func testListTasksWithFilter() async throws {
        let id1 = "task-\(UUID().uuidString)"
        let id2 = "task-\(UUID().uuidString)"

        _ = try await service.createTask(AgentTask(id: id1, title: "Pending Task", status: .pending))
        _ = try await service.createTask(AgentTask(id: id2, title: "Running Task", status: .running))

        let pendingTasks = try await service.listTasks(filter: TaskFilter(statuses: [.pending]))
        XCTAssertTrue(pendingTasks.allSatisfy { $0.status == .pending })
        XCTAssertTrue(pendingTasks.contains { $0.id == id1 })
        XCTAssertFalse(pendingTasks.contains { $0.id == id2 })
    }

    func testTaskStatusTransitions() async throws {
        let id = "task-\(UUID().uuidString)"
        _ = try await service.createTask(AgentTask(id: id, title: "Lifecycle Task"))

        let initial = try await service.getTask(id: id)
        XCTAssertEqual(initial?.status, .pending)
        XCTAssertNil(initial?.startedAt)

        let runningExpectation = expectation(forNotification: .agentTaskBoardDidChange, object: nil, handler: nil)
        try await service.startTask(id: id)
        await fulfillment(of: [runningExpectation], timeout: 1.0)
        let running = try await service.getTask(id: id)
        XCTAssertEqual(running?.status, .running)
        XCTAssertNotNil(running?.startedAt)

        let completedExpectation = expectation(forNotification: .agentTaskBoardDidChange, object: nil, handler: nil)
        try await service.completeTask(id: id)
        await fulfillment(of: [completedExpectation], timeout: 1.0)
        let completed = try await service.getTask(id: id)
        XCTAssertEqual(completed?.status, .completed)
        XCTAssertNotNil(completed?.completedAt)
    }

    func testRetryTask() async throws {
        let id = "task-\(UUID().uuidString)"
        _ = try await service.createTask(AgentTask(id: id, title: "Retryable Task", maxRetries: 3))

        try await service.failTask(id: id, error: "network timeout")
        let failed = try await service.getTask(id: id)
        XCTAssertEqual(failed?.status, .failed)
        XCTAssertEqual(failed?.errorMessage, "network timeout")
        XCTAssertEqual(failed?.retryCount, 1)

        try await service.retryTask(id: id)
        let retried = try await service.getTask(id: id)
        XCTAssertEqual(retried?.status, .pending)
        XCTAssertNil(retried?.errorMessage)
        XCTAssertEqual(retried?.retryCount, 1)
    }

    func testDeleteTaskRemovesItFromPersistedIndex() async throws {
        let id = "task-\(UUID().uuidString)"
        _ = try await service.createTask(AgentTask(id: id, title: "Delete Me"))

        let beforeDelete = try await service.listTasks(filter: nil)
        XCTAssertTrue(beforeDelete.contains { $0.id == id })

        try await service.deleteTask(id: id)

        let afterDelete = try await service.listTasks(filter: nil)
        XCTAssertFalse(afterDelete.contains { $0.id == id })
        let deletedTask = try await service.getTask(id: id)
        XCTAssertNil(deletedTask)
    }

    func testTaskClosureSummaryShowsTimelineAndNextActionForRunningTask() {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let startedAt = Date(timeIntervalSince1970: 1_700_000_060)
        let task = AgentTask(
            id: "task-running",
            title: "整理会议纪要",
            status: .running,
            steps: [
                TaskStep(title: "读取转写", status: .completed, order: 0, completedAt: startedAt),
                TaskStep(title: "生成摘要", status: .running, order: 1, startedAt: startedAt)
            ],
            currentStepIndex: 1,
            createdAt: createdAt,
            updatedAt: startedAt,
            startedAt: startedAt
        )

        let summary = AgentTaskClosureSummary.make(from: task)

        XCTAssertEqual(summary.title, "整理会议纪要")
        XCTAssertEqual(summary.stateLabel, "执行中")
        XCTAssertEqual(summary.nextActionTitle, "继续执行")
        XCTAssertEqual(summary.timeline.map(\.title), ["已创建", "已开始", "读取转写", "生成摘要"])
        XCTAssertEqual(summary.timeline.last?.status, .running)
    }

    func testTaskClosureSummaryShowsRetryActionForFailedTaskWithinRetryLimit() {
        let task = AgentTask(
            id: "task-failed",
            title: "同步知识卡片",
            status: .failed,
            errorMessage: "网络超时",
            retryCount: 1,
            maxRetries: 3
        )

        let summary = AgentTaskClosureSummary.make(from: task)

        XCTAssertEqual(summary.stateLabel, "失败")
        XCTAssertEqual(summary.detail, "网络超时")
        XCTAssertEqual(summary.nextActionTitle, "重试任务")
        XCTAssertTrue(summary.canRetry)
    }

    func testTaskClosureSummaryShowsArchiveActionForCompletedTaskWithProducts() {
        let task = AgentTask(
            id: "task-completed",
            title: "生成周报",
            status: .completed,
            products: [
                TaskProduct(name: "周报.md", type: .markdown)
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_000_120)
        )

        let summary = AgentTaskClosureSummary.make(from: task)

        XCTAssertEqual(summary.stateLabel, "已完成")
        XCTAssertEqual(summary.detail, "已生成 1 个产物")
        XCTAssertEqual(summary.nextActionTitle, "归档为沉淀")
        XCTAssertFalse(summary.canRetry)
    }
}

final class MockTaskStorage: StorageServiceProtocol, @unchecked Sendable {
    private var settings: [String: String] = [:]

    func setSetting(key: String, value: String) async throws {
        settings[key] = value
    }

    func getSetting(key: String) async throws -> String? {
        return settings[key]
    }

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
    func insertScheduledAgentTask(_ task: ScheduledAgentTask) async throws {}
    func getScheduledAgentTask(id: String) async throws -> ScheduledAgentTask? { nil }
    func listScheduledAgentTasks() async throws -> [ScheduledAgentTask] { [] }
    func deleteScheduledAgentTask(id: String) async throws {}
    func listProviders() async throws -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}
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
