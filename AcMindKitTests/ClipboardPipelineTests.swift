import XCTest
@testable import AcMindKit

final class ClipboardPipelineTests: XCTestCase {

    // MARK: - Input Chain Status Tests

    func testClipboardPipelineStatusTracksSuccessfulFlow() async throws {
        let pipeline = ClipboardPipeline(
            assetStore: AssetStore(),
            storage: MockStorageService()
        )
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 1,
            sourceApp: "TextEdit",
            textContent: "Hello from clipboard"
        ))

        XCTAssertEqual(pipeline.statusSnapshot().phase, .idle)

        try await pipeline.process(&context)

        let status = pipeline.statusSnapshot()
        XCTAssertEqual(status.source, .clipboard)
        XCTAssertEqual(status.phase, .succeeded)
        XCTAssertEqual(status.stepLabel, "分发完成")
        XCTAssertEqual(status.detail, "剪贴板内容已入库并分发")
        XCTAssertNil(status.lastErrorMessage)
        XCTAssertNil(status.nextActionTitle)
    }

    func testClipboardPipelineStatusTracksIgnoredFlow() async throws {
        let pipeline = ClipboardPipeline(
            assetStore: AssetStore(),
            storage: MockStorageService(),
            cleaningRulesEvaluator: { _, _ in .ignore }
        )
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 2,
            sourceApp: "Password Manager",
            textContent: "sensitive value"
        ))

        try await pipeline.process(&context)

        let status = pipeline.statusSnapshot()
        XCTAssertEqual(status.source, .clipboard)
        XCTAssertEqual(status.phase, .ignored)
        XCTAssertEqual(status.stepLabel, "内容转换")
        XCTAssertEqual(status.detail, "内容已按清理规则忽略")
        XCTAssertNil(status.lastErrorMessage)
    }

    func testRecordingHotkeyStatusStartsIdleAndTracksRegisteredActions() async {
        let service = RecordingHotkeyService()

        var status = await service.statusSnapshot()
        XCTAssertEqual(status.source, .recordingHotkey)
        XCTAssertEqual(status.phase, .idle)
        XCTAssertEqual(status.stepLabel, "等待录音")
        XCTAssertEqual(status.detail, "录音开始后启用快捷键")
        XCTAssertEqual(status.activeControlCount, 0)
        XCTAssertEqual(status.nextActionTitle, "开始录音")

        await service.registerHandler(for: .cancel) {}
        status = await service.statusSnapshot()

        XCTAssertEqual(status.activeControlCount, 1)
        XCTAssertEqual(status.phase, .idle)
    }

    func testRecordingHotkeyStatusTracksListeningAndStop() async throws {
        let service = RecordingHotkeyService(eventHandlerInstaller: {})
        await service.registerHandler(for: .cancel) {}

        try await service.startListening()

        var status = await service.statusSnapshot()
        XCTAssertEqual(status.phase, .listening)
        XCTAssertEqual(status.stepLabel, "录音中")
        XCTAssertEqual(status.activeControlCount, 1)
        XCTAssertEqual(status.nextActionTitle, "停止录音")

        await service.stopListening()
        status = await service.statusSnapshot()

        XCTAssertEqual(status.phase, .idle)
        XCTAssertEqual(status.activeControlCount, 0)
        XCTAssertEqual(status.nextActionTitle, "开始录音")
    }

    func testRecordingHotkeyInstallFailureRollsBackListeningState() async {
        let expectedError = NSError(
            domain: "RecordingHotkeyServiceTests",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "事件监听不可用"]
        )
        let service = RecordingHotkeyService(eventHandlerInstaller: {
            throw expectedError
        })

        do {
            try await service.startListening()
            XCTFail("Expected listener installation to fail")
        } catch {
            XCTAssertEqual((error as NSError).code, expectedError.code)
        }

        let status = await service.statusSnapshot()
        let isRecording = await service.isCurrentlyRecording()
        XCTAssertFalse(isRecording)
        XCTAssertEqual(status.phase, .failed)
        XCTAssertEqual(status.detail, "录音快捷键监听启动失败")
        XCTAssertEqual(status.lastErrorMessage, "事件监听不可用")
        XCTAssertEqual(status.nextActionTitle, "重试监听")
    }

    // MARK: - DiscoveryStage Tests

    func testDiscoveryStageDetectsURL() async throws {
        let stage = DiscoveryStage(assetStore: AssetStore())
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 1,
            sourceApp: "Safari",
            textContent: "https://example.com"
        ))

        try await stage.process(&context)

        XCTAssertNotNil(context.item)
        XCTAssertEqual(context.item?.type, .url)
        XCTAssertEqual(context.item?.content, "https://example.com")
    }

    func testDiscoveryStageDetectsPlainText() async throws {
        let stage = DiscoveryStage(assetStore: AssetStore())
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 1,
            sourceApp: "TextEdit",
            textContent: "Hello world"
        ))

        try await stage.process(&context)

        XCTAssertNotNil(context.item)
        XCTAssertEqual(context.item?.type, .text)
    }

    func testDiscoveryStageDetectsCode() async throws {
        let stage = DiscoveryStage(assetStore: AssetStore())
        let code = """
        func hello() -> String {
            return "Hello"
        }

        class MyClass {
            var value: Int = 0
        }
        """
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 1,
            sourceApp: "Xcode",
            textContent: code
        ))

        try await stage.process(&context)

        XCTAssertNotNil(context.item)
        XCTAssertEqual(context.item?.type, .code)
        XCTAssertNotNil(context.item?.codeLanguage)
    }

    func testDiscoveryStageDetectsRichText() async throws {
        let stage = DiscoveryStage(assetStore: AssetStore())
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 1,
            sourceApp: "Safari",
            textContent: "Hello World",
            htmlContent: "<p><strong>Hello</strong> World</p>"
        ))

        try await stage.process(&context)

        XCTAssertNotNil(context.item)
        XCTAssertEqual(context.item?.type, .richText)
        XCTAssertNotNil(context.item?.htmlContent)
    }

    func testDiscoveryStageDetectsFiles() async throws {
        let stage = DiscoveryStage(assetStore: AssetStore())
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 1,
            sourceApp: "Finder",
            fileURLs: ["/tmp/test.txt", "/tmp/test2.txt"]
        ))

        try await stage.process(&context)

        XCTAssertNotNil(context.item)
        XCTAssertEqual(context.item?.type, .file)
    }

    // MARK: - TransformationStage Tests

    func testTransformationStageDetectsPhoneNumber() async throws {
        let stage = TransformationStage()
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 1,
            sourceApp: nil,
            textContent: "联系我：13812345678"
        ))
        context.item = ClipboardItem(
            type: .text,
            content: "联系我：13812345678",
            textContent: "联系我：13812345678"
        )

        try await stage.process(&context)

        XCTAssertTrue(context.item?.isSensitive ?? false)
    }

    func testTransformationStageDetectsIDCard() async throws {
        let stage = TransformationStage()
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 1,
            sourceApp: nil,
            textContent: "110101199001011234"
        ))
        context.item = ClipboardItem(
            type: .text,
            content: "110101199001011234",
            textContent: "110101199001011234"
        )

        try await stage.process(&context)

        XCTAssertTrue(context.item?.isSensitive ?? false)
    }

    func testTransformationStageDetectsEmail() async throws {
        let stage = TransformationStage()
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 1,
            sourceApp: nil,
            textContent: "user@example.com"
        ))
        context.item = ClipboardItem(
            type: .text,
            content: "user@example.com",
            textContent: "user@example.com"
        )

        try await stage.process(&context)

        XCTAssertTrue(context.item?.isSensitive ?? false)
    }

    func testTransformationStageNormalTextNotSensitive() async throws {
        let stage = TransformationStage()
        var context = PipelineContext(rawContent: RawClipboardContent(
            changeCount: 1,
            sourceApp: nil,
            textContent: "Hello world, this is normal text"
        ))
        context.item = ClipboardItem(
            type: .text,
            content: "Hello world, this is normal text",
            textContent: "Hello world, this is normal text"
        )

        try await stage.process(&context)

        XCTAssertFalse(context.item?.isSensitive ?? false)
    }

    // MARK: - ValidationStage Tests

    func testValidationStageDeduplicatesContent() async throws {
        let stage = ValidationStage()

        let item1 = ClipboardItem(type: .text, content: "Hello", textContent: "Hello")
        let item2 = ClipboardItem(type: .text, content: "Hello", textContent: "Hello")

        var ctx1 = PipelineContext(rawContent: RawClipboardContent(changeCount: 1, sourceApp: nil))
        ctx1.item = item1
        try await stage.process(&ctx1)
        XCTAssertFalse(ctx1.shouldIgnore)

        var ctx2 = PipelineContext(rawContent: RawClipboardContent(changeCount: 2, sourceApp: nil))
        ctx2.item = item2
        try await stage.process(&ctx2)
        XCTAssertTrue(ctx2.shouldIgnore)
    }

    func testValidationStageDetectsPasteEcho() async throws {
        let stage = ValidationStage()

        let item = ClipboardItem(type: .text, content: "Test content", textContent: "Test content")
        let hash = stage.computeHash(for: item)
        stage.recordPasteHash(hash)

        var ctx = PipelineContext(rawContent: RawClipboardContent(changeCount: 1, sourceApp: nil))
        ctx.item = item
        try await stage.process(&ctx)

        XCTAssertTrue(ctx.shouldIgnore)
    }

    func testValidationStageAllowsDifferentContent() async throws {
        let stage = ValidationStage()

        let item1 = ClipboardItem(type: .text, content: "Hello", textContent: "Hello")
        let item2 = ClipboardItem(type: .text, content: "World", textContent: "World")

        var ctx1 = PipelineContext(rawContent: RawClipboardContent(changeCount: 1, sourceApp: nil))
        ctx1.item = item1
        try await stage.process(&ctx1)

        var ctx2 = PipelineContext(rawContent: RawClipboardContent(changeCount: 2, sourceApp: nil))
        ctx2.item = item2
        try await stage.process(&ctx2)

        XCTAssertFalse(ctx2.shouldIgnore)
    }

    // MARK: - PasteQueue Tests

    func testPasteQueueBasicOperations() {
        let queue = PasteQueue()

        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(queue.count, 0)

        queue.enqueue(clipboardItemId: "item1")
        XCTAssertEqual(queue.count, 1)

        queue.enqueue(clipboardItemId: "item2")
        XCTAssertEqual(queue.count, 2)

        let first = queue.dequeue()
        XCTAssertEqual(first?.clipboardItemId, "item1")
        XCTAssertEqual(queue.count, 1)

        let second = queue.dequeue()
        XCTAssertEqual(second?.clipboardItemId, "item2")
        XCTAssertTrue(queue.isEmpty)

        let empty = queue.dequeue()
        XCTAssertNil(empty)
    }

    func testPasteQueueBatchEnqueue() {
        let queue = PasteQueue()
        queue.enqueueBatch(clipboardItemIds: ["a", "b", "c"])

        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(queue.dequeue()?.clipboardItemId, "a")
        XCTAssertEqual(queue.dequeue()?.clipboardItemId, "b")
        XCTAssertEqual(queue.dequeue()?.clipboardItemId, "c")
    }

    func testPasteQueueRemove() {
        let queue = PasteQueue()
        queue.enqueueBatch(clipboardItemIds: ["a", "b", "c"])

        let items = queue.items
        queue.remove(id: items[1].id)

        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.peek()?.clipboardItemId, "a")
    }

    func testPasteQueueClear() {
        let queue = PasteQueue()
        queue.enqueueBatch(clipboardItemIds: ["a", "b", "c"])

        queue.clear()
        XCTAssertTrue(queue.isEmpty)
    }

    // MARK: - CleaningRulesStore Tests

    func testCleaningRulesEvaluateWithNoRules() {
        let store = CleaningRulesStore(storage: MockStorageService())

        let result = store.evaluate(text: "my password is 123", sourceApp: nil)

        if case .pass = result {
            // Expected - no rules loaded
        } else {
            XCTFail("Expected pass with no rules")
        }
    }

    func testCleaningRulesIgnoreRule() async {
        let store = CleaningRulesStore(storage: MockStorageService())
        let rule = CleaningRule(
            name: "Ignore passwords",
            matchType: .contains,
            pattern: "password",
            action: .ignore
        )
        await store.addRule(rule)

        let result = store.evaluate(text: "my password is 123", sourceApp: nil)

        if case .ignore = result {
            // Expected
        } else {
            XCTFail("Expected ignore for matching rule")
        }
    }

    func testCleaningRulesReplaceRule() async {
        let store = CleaningRulesStore(storage: MockStorageService())
        let rule = CleaningRule(
            name: "Replace digits",
            matchType: .regex,
            pattern: "\\d+",
            action: .replace,
            replacement: "***"
        )
        await store.addRule(rule)

        let result = store.evaluate(text: "code 12345", sourceApp: nil)

        if case .clean(let cleaned) = result {
            XCTAssertEqual(cleaned, "***")
        } else {
            XCTFail("Expected clean with replacement")
        }
    }

    func testCleaningRulesNonMatchingPasses() async {
        let store = CleaningRulesStore(storage: MockStorageService())
        let rule = CleaningRule(
            name: "Ignore passwords",
            matchType: .contains,
            pattern: "password",
            action: .ignore
        )
        await store.addRule(rule)

        let result = store.evaluate(text: "hello world", sourceApp: nil)

        if case .pass = result {
            // Expected
        } else {
            XCTFail("Expected pass when rule doesn't match")
        }
    }

    // MARK: - CleaningRule Model Tests

    func testCleaningRuleCodable() throws {
        let rule = CleaningRule(
            name: "Test Rule",
            matchType: .regex,
            pattern: "\\d+",
            action: .replace,
            replacement: "***"
        )

        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(CleaningRule.self, from: data)

        XCTAssertEqual(decoded.name, rule.name)
        XCTAssertEqual(decoded.matchType, rule.matchType)
        XCTAssertEqual(decoded.pattern, rule.pattern)
        XCTAssertEqual(decoded.action, rule.action)
        XCTAssertEqual(decoded.replacement, rule.replacement)
    }

    // MARK: - ClipboardTag Model Tests

    func testClipboardTagColorConversion() {
        let tag = ClipboardTag(name: "Test", color: "#FF0000")
        let color = tag.swiftColor
        XCTAssertNotNil(color)
    }

    func testClipboardTagCodable() throws {
        let tag = ClipboardTag(name: "Work", color: "#00FF00")

        let data = try JSONEncoder().encode(tag)
        let decoded = try JSONDecoder().decode(ClipboardTag.self, from: data)

        XCTAssertEqual(decoded.name, tag.name)
        XCTAssertEqual(decoded.color, tag.color)
    }
}

// MARK: - Mock

private final class MockStorageService: StorageServiceProtocol {
    func setup() async throws {}
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
    func insertClipboardTag(_ tag: ClipboardTag) async throws {}
    func listClipboardTags() async throws -> [ClipboardTag] { [] }
    func deleteClipboardTag(id: String) async throws {}
    func listClipboardItemsByTag(_ tagName: String, limit: Int?) async throws -> [ClipboardItem] { [] }
    func addTagToClipboardItem(itemId: String, tagName: String) async throws {}
    func removeTagFromClipboardItem(itemId: String, tagName: String) async throws {}
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
    func getSetting(key: String) async throws -> String? { nil }
    func setSetting(key: String, value: String) async throws {}
    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { "" }
    func getDatabaseVersion() async throws -> Int { 0 }
}
