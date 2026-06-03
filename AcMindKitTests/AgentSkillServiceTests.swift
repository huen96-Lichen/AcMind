import XCTest
@testable import AcMindKit

@MainActor
final class AgentSkillServiceTests: XCTestCase {
    var storage: MockSkillStorage!
    var service: AgentSkillService!

    override func setUp() async throws {
        try await super.setUp()
        storage = MockSkillStorage()
        service = AgentSkillService(storage: storage)
    }

    override func tearDown() async throws {
        service = nil
        storage = nil
        try await super.tearDown()
    }

    func testSaveAndGetSkill() async throws {
        let id = "skill-\(UUID().uuidString)"
        let skill = AgentSkill(
            id: id,
            name: "Test Skill",
            category: .execution,
            description: "A test skill",
            content: "Skill content here",
            tags: ["test"]
        )

        try await service.saveSkill(skill)
        let retrieved = try await service.getSkill(id: id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, id)
        XCTAssertEqual(retrieved?.name, "Test Skill")
        XCTAssertEqual(retrieved?.category, .execution)
        XCTAssertEqual(retrieved?.description, "A test skill")
        XCTAssertEqual(retrieved?.content, "Skill content here")
        XCTAssertEqual(retrieved?.tags, ["test"])
    }

    func testListSkillsWithFilter() async throws {
        let id1 = "skill-\(UUID().uuidString)"
        let id2 = "skill-\(UUID().uuidString)"
        let id3 = "skill-\(UUID().uuidString)"

        try await service.saveSkill(AgentSkill(id: id1, name: "Exec Skill", category: .execution))
        try await service.saveSkill(AgentSkill(id: id2, name: "Workflow Skill", category: .workflow))
        try await service.saveSkill(AgentSkill(id: id3, name: "Project Skill", category: .project))

        let execOnly = try await service.listSkills(filter: SkillFilter(categories: [.execution]))
        XCTAssertTrue(execOnly.allSatisfy { $0.category == .execution })
        XCTAssertTrue(execOnly.contains { $0.id == id1 })
        XCTAssertFalse(execOnly.contains { $0.id == id2 })
    }

    func testGetSkillContext() async throws {
        let id = "skill-\(UUID().uuidString)"
        try await service.saveSkill(AgentSkill(
            id: id,
            name: "Swift Engineering",
            category: .execution,
            content: "Swift best practices",
            tags: ["swift"],
            triggerKeywords: ["swift", "build"]
        ))

        let context = try await service.getSkillContext(taskDescription: "build a Swift app")

        XCTAssertFalse(context.isEmpty)
        XCTAssertTrue(context.skills.contains { $0.id == id })
    }

    func testInitializeBuiltinSkills() async throws {
        try await service.initializeBuiltinSkills()

        let swiftSkill = try await service.getSkill(id: "builtin-swift-engineering")
        XCTAssertNotNil(swiftSkill)
        XCTAssertEqual(swiftSkill?.name, "Swift 原生工程规范")

        let uiSkill = try await service.getSkill(id: "builtin-acmind-ui")
        XCTAssertNotNil(uiSkill)
        XCTAssertEqual(uiSkill?.name, "AcMind UI 规范")

        let traeSkill = try await service.getSkill(id: "builtin-trae-task")
        XCTAssertNotNil(traeSkill)
        XCTAssertEqual(traeSkill?.name, "Trae 任务单生成")

        let codexSkill = try await service.getSkill(id: "builtin-codex-review")
        XCTAssertNotNil(codexSkill)
        XCTAssertEqual(codexSkill?.name, "Codex 核验")
    }
}

final class MockSkillStorage: StorageServiceProtocol, @unchecked Sendable {
    private var settings: [String: String] = [:]
    private var skillIds: [String] = []

    func setSetting(key: String, value: String) async throws {
        settings[key] = value
        if key.hasPrefix("skill_") && !key.contains("index") && !value.isEmpty {
            let id = String(key.dropFirst("skill_".count))
            if !skillIds.contains(id) {
                skillIds.append(id)
            }
        }
    }

    func getSetting(key: String) async throws -> String? {
        if key.hasPrefix("skill_index_") {
            let indexStr = String(key.dropFirst("skill_index_".count))
            guard let index = Int(indexStr), index == 0 else { return nil }
            return skillIds.joined(separator: ",")
        }
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
