import AppKit
import XCTest
@testable import AcMindKit

final class NativeAIPipelineTests: XCTestCase {
    func testAIModelCatalogProvidesDefaultCapabilitiesAndFallbacks() {
        let preferences = AIModelCatalog.defaultPreferences()
        XCTAssertEqual(preferences.count, 6)
        XCTAssertTrue(preferences.contains { $0.category == .complexTask && $0.isEnabled == false })

        let speechOptions = AIModelCatalog.options(for: .speechToText, providers: [])
        XCTAssertTrue(speechOptions.contains { $0.providerId == AIModelCatalog.speechFallbackProviderId })
    }

    func testAIModelCatalogNormalizesMissingSelectionToFallback() {
        let preferences = [
            AIModelCategoryPreference(
                category: .textCleanup,
                selectedProviderId: "missing.provider",
                selectedModelId: "missing-model",
                fallbackProviderId: AIModelCatalog.cleanupFallbackProviderId,
                fallbackModelId: "RuleBased Cleanup",
                isEnabled: true
            )
        ]

        let normalized = AIModelCatalog.normalize(preferences, providers: [])
        let cleanup = normalized.first(where: { $0.category == .textCleanup })
        XCTAssertEqual(cleanup?.selectedProviderId, AIModelCatalog.cleanupFallbackProviderId)
        XCTAssertEqual(cleanup?.fallbackProviderId, AIModelCatalog.cleanupFallbackProviderId)
    }

    func testTaskRouterResolvesCategoryModelWithFallback() {
        let router = TaskRouter()
        let preferences = AIModelCatalog.defaultPreferences()

        let option = router.resolveModelOption(
            for: .speechToText,
            preferences: preferences,
            providers: []
        )

        XCTAssertEqual(option?.providerId, AIModelCatalog.speechFallbackProviderId)
        XCTAssertEqual(option?.displayName, "Apple Speech")
    }

    func testTaskRouterChoosesNativeRecognitionBeforeCleanup() {
        let router = TaskRouter()

        let audio = SourceItem(type: .audio, source: .voice, status: .captured)
        XCTAssertEqual(router.route(sourceItem: audio).taskType, .speechToText)

        let image = SourceItem(type: .screenshot, source: .screenshot, status: .captured)
        XCTAssertEqual(router.route(sourceItem: image).taskType, .imageOCR)

        let text = SourceItem(type: .text, source: .manual, status: .captured, previewText: "今天需要整理 AcMind AI 管家推进计划")
        XCTAssertEqual(router.route(sourceItem: text).taskType, .textCleanup)

        let longText = SourceItem(type: .text, source: .manual, status: .captured, previewText: String(repeating: "复杂资料 ", count: 500))
        XCTAssertEqual(router.route(sourceItem: longText).taskType, .summarize)
    }

    func testRuleBasedCleanupProducesStructuredMarkdown() async throws {
        let provider = RuleBasedCleanupProvider()
        let request = AIRequest(
            taskType: .textCleanup,
            inputText: "明天需要完成 AcMind Swift 原生 AI 管家计划，并保存到 Obsidian。",
            metadata: [AIMetadataKey.outputType: AcMindOutputType.markdownNote.rawValue]
        )

        let response = try await provider.run(request)

        XCTAssertEqual(response.providerId, provider.id)
        XCTAssertEqual(response.category, .task)
        XCTAssertTrue(response.tags.contains("AcMind"))
        XCTAssertTrue(response.markdown?.contains("## 摘要") == true)
        XCTAssertTrue(response.markdown?.contains("- [ ]") == true)
    }

    func testAppleVisionOCRProviderRejectsBlankImageResult() async throws {
        let imageURL = try makeBlankPNG()
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let provider = AppleVisionOCRProvider()
        let request = AIRequest(taskType: .imageOCR, fileURL: imageURL)

        do {
            _ = try await provider.run(request)
            XCTFail("Blank images should not produce a successful OCR response")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testPipelinePreservesSourceMetadataAndExportsMarkdown() async throws {
        let storage = StorageService()
        try await storage.setup()

        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMindPipelineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let item = SourceItem(
            id: UUID().uuidString,
            type: .text,
            source: .manual,
            status: .captured,
            title: "Pipeline Test",
            previewText: "今天记录一个关于 AcMind AI 管家的想法，需要后续整理。",
            createdAt: Date()
        )
        try await storage.insertSourceItem(item)

        let service = NativeAIPipelineService(storage: storage)
        let config = ExportConfig(
            target: .obsidian,
            vaultPath: vaultURL.path,
            defaultFolder: "00_Inbox",
            pathRule: .flat,
            conflictStrategy: .rename,
            autoFrontmatter: true
        )

        let result = try await service.process(sourceItem: item, exportConfig: config)

        XCTAssertEqual(result.sourceItem.source, item.source)
        XCTAssertEqual(result.sourceItem.createdAt.timeIntervalSince1970, item.createdAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(result.sourceItem.status, .distilled)
        XCTAssertEqual(result.sourceItem.metadata[AIMetadataKey.providerId], RuleBasedCleanupProvider().id)
        XCTAssertEqual(result.sourceItem.metadata[AIMetadataKey.outputType], AcMindOutputType.markdownNote.rawValue)
        XCTAssertFalse(result.sourceItem.bestProcessableText.isEmpty)

        let record = try XCTUnwrap(result.exportRecord)
        XCTAssertTrue(record.relativeFilePath.hasPrefix("00_Inbox/"))
        XCTAssertTrue(record.relativeFilePath.hasSuffix(".md"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent(record.relativeFilePath).path))
    }

    func testDailyReviewWritesExpectedVaultPath() async throws {
        let storage = StorageService()
        try await storage.setup()

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let item = SourceItem(
            id: UUID().uuidString,
            type: .text,
            source: .manual,
            status: .distilled,
            title: "日报素材",
            previewText: "今日完成了原生 AI Pipeline。",
            metadata: [AIMetadataKey.inboxCategory: InboxCategory.idea.rawValue],
            createdAt: date
        )
        try await storage.insertSourceItem(item)

        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMindDailyReviewTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let service = NativeAIPipelineService(storage: storage)
        let fileURL = try await service.createDailyReview(for: date, vaultPath: vaultURL.path)

        XCTAssertEqual(fileURL.lastPathComponent, "2027-01-15.md")
        XCTAssertTrue(fileURL.path.contains("03_Reviews/Daily"))
        let content = try String(contentsOf: fileURL)
        XCTAssertTrue(content.contains("# 2027-01-15 日报"))
        XCTAssertTrue(content.contains("日报素材"))
    }

    func testDailyReviewScheduleIsVisiblePausableAndDeletable() async throws {
        let storage = StorageService()
        try await storage.setup()
        let service = NativeAIPipelineService(storage: storage)

        let task = try await service.registerDailyReviewTask(
            cronExpression: "0 22 * * *",
            vaultPath: "/tmp/acmind-vault",
            enabled: false
        )

        XCTAssertFalse(task.enabled)
        XCTAssertEqual(task.skillName, "acmind.dailyReview")
        XCTAssertEqual(task.inputParams["requiresUserConsent"], "true")
        let tasks = try await storage.listScheduledAgentTasks()
        XCTAssertTrue(tasks.contains { $0.id == task.id })

        let enabled = try await service.setScheduledTask(task, enabled: true)
        XCTAssertTrue(enabled.enabled)

        try await service.deleteScheduledTask(id: task.id)
        let deletedTask = try await storage.getScheduledAgentTask(id: task.id)
        XCTAssertNil(deletedTask)
    }

    private func makeBlankPNG() throws -> URL {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 32, height: 32)).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "NativeAIPipelineTests", code: 1)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("blank-\(UUID().uuidString).png")
        try png.write(to: url)
        return url
    }
}
