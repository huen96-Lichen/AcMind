import XCTest
@testable import AcMindKit

@MainActor
final class KnowledgeServiceNewFeatureTests: XCTestCase {

    var storage: StorageService!
    var knowledgeService: KnowledgeService!

    override func setUp() async throws {
        try await super.setUp()
        storage = StorageService()
        try await storage.setup()
        knowledgeService = KnowledgeService(storage: storage)
    }

    override func tearDown() async throws {
        knowledgeService = nil
        storage = nil
        try await super.tearDown()
    }

    private func makeSourceItem(title: String) async throws -> String {
        let item = SourceItem(
            id: UUID().uuidString,
            type: .text,
            source: .manual,
            status: .inbox,
            title: title,
            createdAt: Date()
        )
        try await storage.insertSourceItem(item)
        return item.id
    }

    private func makeCard(
        title: String,
        tags: [String] = [],
        category: String? = nil,
        status: KnowledgeCardStatus = .active
    ) async throws -> String {
        let sourceId = try await makeSourceItem(title: title)
        let card = KnowledgeCard(
            id: UUID().uuidString,
            sourceItemId: sourceId,
            canonicalTitle: title,
            category: category,
            tags: tags,
            status: status,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await storage.insertKnowledgeCard(card)
        return card.id
    }

    func testListTags() async throws {
        let uid = UUID().uuidString.prefix(8)
        let tag1 = "tag-\(uid)-swift"
        let tag2 = "tag-\(uid)-ios"
        let tag3 = "tag-\(uid)-macos"
        let tag4 = "tag-\(uid)-python"
        _ = try await makeCard(title: "卡片A-\(uid)", tags: [tag1, tag2])
        _ = try await makeCard(title: "卡片B-\(uid)", tags: [tag1, tag3])
        _ = try await makeCard(title: "卡片C-\(uid)", tags: [tag4])

        try await knowledgeService.setup()

        let tagCounts = try await knowledgeService.listTags()
        XCTAssertEqual(tagCounts[tag1], 2)
        XCTAssertEqual(tagCounts[tag2], 1)
        XCTAssertEqual(tagCounts[tag3], 1)
        XCTAssertEqual(tagCounts[tag4], 1)
    }

    func testGetCardsByTag() async throws {
        _ = try await makeCard(title: "Swift基础", tags: ["swift"])
        _ = try await makeCard(title: "Python基础", tags: ["python"])
        _ = try await makeCard(title: "Swift进阶", tags: ["swift", "advanced"])

        try await knowledgeService.setup()

        let swiftCards = try await knowledgeService.getCardsByTag("swift")
        XCTAssertTrue(swiftCards.count >= 2)
        XCTAssertTrue(swiftCards.contains { $0.canonicalTitle == "Swift基础" })
        XCTAssertTrue(swiftCards.contains { $0.canonicalTitle == "Swift进阶" })
    }

    func testRenameTag() async throws {
        _ = try await makeCard(title: "重命名A", tags: ["old-tag"])
        _ = try await makeCard(title: "重命名B", tags: ["old-tag", "other"])

        try await knowledgeService.setup()
        try await knowledgeService.renameTag(from: "old-tag", to: "new-tag")

        let newTagCards = try await knowledgeService.getCardsByTag("new-tag")
        XCTAssertTrue(newTagCards.count >= 2)

        let oldTagCards = try await knowledgeService.getCardsByTag("old-tag")
        XCTAssertEqual(oldTagCards.count, 0)
    }

    func testMergeTags() async throws {
        _ = try await makeCard(title: "合并A", tags: ["merge-tag1"])
        _ = try await makeCard(title: "合并B", tags: ["merge-tag2"])
        _ = try await makeCard(title: "合并C", tags: ["merge-tag3", "keep-other"])

        try await knowledgeService.setup()
        try await knowledgeService.mergeTags(["merge-tag1", "merge-tag2", "merge-tag3"], into: "merged-result")

        let mergedCards = try await knowledgeService.getCardsByTag("merged-result")
        XCTAssertTrue(mergedCards.count >= 3)
    }

    func testBatchDelete() async throws {
        let id1 = try await makeCard(title: "删除X")
        let id2 = try await makeCard(title: "删除Y")
        let id3 = try await makeCard(title: "保留Z")

        try await knowledgeService.setup()

        try await knowledgeService.batchDelete(ids: [id1, id2])

        let deleted1 = try await knowledgeService.getCard(id: id1)
        XCTAssertEqual(deleted1?.status, .deleted)

        let deleted2 = try await knowledgeService.getCard(id: id2)
        XCTAssertEqual(deleted2?.status, .deleted)

        let kept = try await knowledgeService.getCard(id: id3)
        XCTAssertEqual(kept?.status, .active)
    }

    func testListCardsHidesDeletedCardsByDefaultButKeepsExplicitDeletedFilter() async throws {
        let activeID = try await makeCard(title: "默认可见")
        let deletedID = try await makeCard(title: "删除后隐藏")

        try await knowledgeService.setup()
        try await knowledgeService.deleteCard(id: deletedID)

        let defaultCards = try await knowledgeService.listCards(filter: nil)
        XCTAssertTrue(defaultCards.contains { $0.id == activeID })
        XCTAssertFalse(defaultCards.contains { $0.id == deletedID })

        let deletedCards = try await knowledgeService.listCards(filter: KnowledgeCardFilter(status: .deleted))
        XCTAssertTrue(deletedCards.contains { $0.id == deletedID })
    }

    func testGetGraphData() async throws {
        let cardId1 = try await makeCard(title: "图节点A", tags: ["graph"])
        let cardId2 = try await makeCard(title: "图节点B", tags: ["graph"])

        let edge = KnowledgeEdge(
            id: UUID().uuidString,
            fromKnowledgeCardId: cardId1,
            toKnowledgeCardId: cardId2,
            relationType: "related",
            status: .confirmed,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await storage.insertKnowledgeEdge(edge)

        try await knowledgeService.setup()

        let graph = try await knowledgeService.getGraphData()
        XCTAssertTrue(graph.nodes.contains { $0.title == "图节点A" })
        XCTAssertTrue(graph.nodes.contains { $0.title == "图节点B" })

        let graphEdge = graph.edges.first { $0.sourceId == cardId1 && $0.targetId == cardId2 }
        XCTAssertNotNil(graphEdge)
        XCTAssertEqual(graphEdge?.relationType, "related")
    }

    func testKnowledgeClosureSummaryShowsActiveCardNextAction() {
        let card = KnowledgeCard(
            id: "card-active",
            sourceItemId: "source-1",
            distilledOutputId: "note-1",
            canonicalTitle: "SwiftUI 状态整理",
            summary: "整理状态管理经验",
            tags: ["swiftui", "state"],
            status: .active,
            vaultFilePath: "Notes/SwiftUI.md",
            referenceCount: 2,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let summary = KnowledgeClosureSummary.make(from: card)

        XCTAssertEqual(summary.title, "SwiftUI 状态整理")
        XCTAssertEqual(summary.stateLabel, "活跃")
        XCTAssertEqual(summary.detail, "整理状态管理经验")
        XCTAssertEqual(summary.nextActionTitle, "继续关联")
        XCTAssertEqual(summary.timeline.map(\.title), ["已捕获", "已蒸馏", "已写入 Vault", "已被引用"])
    }

    func testKnowledgeClosureSummaryShowsArchiveAndRestoreActions() {
        let archived = KnowledgeCard(
            id: "card-archived",
            sourceItemId: "source-2",
            canonicalTitle: "旧方案",
            status: .archived
        )
        let deleted = KnowledgeCard(
            id: "card-deleted",
            sourceItemId: "source-3",
            canonicalTitle: "废弃资料",
            status: .deleted
        )

        let archivedSummary = KnowledgeClosureSummary.make(from: archived)
        let deletedSummary = KnowledgeClosureSummary.make(from: deleted)

        XCTAssertEqual(archivedSummary.stateLabel, "已归档")
        XCTAssertEqual(archivedSummary.nextActionTitle, "恢复为活跃")
        XCTAssertEqual(deletedSummary.stateLabel, "已删除")
        XCTAssertNil(deletedSummary.nextActionTitle)
    }

    func testKnowledgeClosureSummaryHighlightsSuggestedEdges() {
        let card = KnowledgeCard(
            id: "card-edge",
            sourceItemId: "source-4",
            canonicalTitle: "相关知识",
            status: .active
        )
        let edges = [
            KnowledgeEdge(
                fromKnowledgeCardId: "card-edge",
                toKnowledgeCardId: "card-other",
                relationType: "related",
                status: .suggested
            )
        ]

        let summary = KnowledgeClosureSummary.make(from: card, edges: edges)

        XCTAssertEqual(summary.nextActionTitle, "确认关联")
        XCTAssertTrue(summary.timeline.contains { $0.title == "待确认关联" })
    }
}
