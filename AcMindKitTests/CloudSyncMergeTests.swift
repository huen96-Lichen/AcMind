import XCTest
@testable import AcMindKit

final class CloudSyncMergeTests: XCTestCase {

    func testTwoDeviceSyncKeepsNewestConflictAndUnionOfCards() async throws {
        let cloud = InMemoryCloudStore()
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = older.addingTimeInterval(100)
        let deviceAStorage = InMemoryCloudSyncStorage(cards: [
            KnowledgeCard(id: "shared", sourceItemId: "a", canonicalTitle: "旧版本", updatedAt: older),
            KnowledgeCard(id: "only-a", sourceItemId: "a", canonicalTitle: "A 独有", updatedAt: older)
        ])
        let deviceBStorage = InMemoryCloudSyncStorage(cards: [
            KnowledgeCard(id: "shared", sourceItemId: "b", canonicalTitle: "新版本", updatedAt: newer),
            KnowledgeCard(id: "only-b", sourceItemId: "b", canonicalTitle: "B 独有", updatedAt: newer)
        ])
        let deviceB = makeService(storage: deviceBStorage, cloud: cloud, suite: "device-b")
        let deviceA = makeService(storage: deviceAStorage, cloud: cloud, suite: "device-a")

        await deviceB.push()
        await deviceA.sync()

        let cardsOnA = await deviceAStorage.listKnowledgeCards()
        let cardsInCloud = try JSONDecoder().decode(
            [KnowledgeCard].self,
            from: Data(try XCTUnwrap(cloud.string(forKey: "com.acmind.sync.knowledgeCards")).utf8)
        )
        XCTAssertEqual(Set(cardsOnA.map(\.id)), ["shared", "only-a", "only-b"])
        XCTAssertEqual(cardsOnA.first(where: { $0.id == "shared" })?.canonicalTitle, "新版本")
        XCTAssertEqual(Set(cardsInCloud.map(\.id)), ["shared", "only-a", "only-b"])
        let status = await deviceA.getSyncStatus()
        XCTAssertNil(status.lastErrorMessage)
    }

    func testCorruptRemoteDataStopsPushAndReportsActionableError() async throws {
        let cloud = InMemoryCloudStore(values: ["com.acmind.sync.knowledgeCards": "not-json"])
        let storage = InMemoryCloudSyncStorage(cards: [
            KnowledgeCard(id: "local", sourceItemId: "local", canonicalTitle: "本地卡片")
        ])
        let service = makeService(storage: storage, cloud: cloud, suite: "corrupt")

        await service.sync()

        let status = await service.getSyncStatus()
        XCTAssertEqual(cloud.string(forKey: "com.acmind.sync.knowledgeCards"), "not-json")
        XCTAssertEqual(status.lastErrorMessage, "云端知识卡片数据损坏，已停止推送以避免覆盖。")
        XCTAssertNil(status.lastSyncDate)
    }

    func testPersonalDictionaryMergePreservesWinningEntryMetadata() async throws {
        let remoteWord = PersonalWord(
            id: UUID(), word: "AcMind", category: .product, priority: .critical,
            usageCount: 42, lastUsed: Date(timeIntervalSince1970: 200), createdAt: Date(timeIntervalSince1970: 100)
        )
        let localWord = PersonalWord(
            id: UUID(), word: "acmind", category: .custom, priority: .normal,
            usageCount: 1, lastUsed: nil, createdAt: Date(timeIntervalSince1970: 50)
        )
        let cloud = InMemoryCloudStore(values: [
            "com.acmind.sync.personalDictionary": String(
                data: try JSONEncoder().encode([remoteWord]), encoding: .utf8
            )!
        ])
        let dictionary = InMemoryDictionary(words: [localWord])
        let service = makeService(
            storage: InMemoryCloudSyncStorage(), cloud: cloud, suite: "dictionary", dictionary: dictionary
        )

        await service.pull()

        let words = await dictionary.getAllWords()
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words.first?.id, remoteWord.id)
        XCTAssertEqual(words.first?.usageCount, 42)
        XCTAssertEqual(words.first?.createdAt, remoteWord.createdAt)
    }

    func testNewerRemoteSettingsApplyWithoutWipingLocalSensitiveFields() async throws {
        let local = CloudSettingsSnapshot(
            settings: AppSettings(
                theme: .light,
                language: "zh-CN",
                defaultProviderId: "local-provider",
                defaultModelId: "local-model",
                vaultPath: "/Local/Vault",
                captureScreenshotHotkey: "local-hotkey"
            ),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let remote = CloudSettingsSnapshot(
            settings: AppSettings(
                theme: .dark,
                language: "en-US",
                defaultProviderId: nil,
                defaultModelId: nil,
                vaultPath: "",
                captureScreenshotHotkey: nil
            ),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let cloud = InMemoryCloudStore(values: [
            "com.acmind.sync.settings": String(data: try JSONEncoder().encode(remote), encoding: .utf8)!
        ])
        let storage = InMemoryCloudSyncStorage(settingsSnapshot: local)
        let service = makeService(storage: storage, cloud: cloud, suite: "remote-settings")

        await service.pull()

        let merged = await storage.getSettingsSnapshot()
        XCTAssertEqual(merged.settings.theme, .dark)
        XCTAssertEqual(merged.settings.language, "en-US")
        XCTAssertEqual(merged.settings.defaultProviderId, "local-provider")
        XCTAssertEqual(merged.settings.defaultModelId, "local-model")
        XCTAssertEqual(merged.settings.vaultPath, "/Local/Vault")
        XCTAssertEqual(merged.settings.captureScreenshotHotkey, "local-hotkey")
        XCTAssertEqual(merged.updatedAt, remote.updatedAt)
    }

    func testNewerLocalSettingsWinAndArePushedToCloud() async throws {
        let local = CloudSettingsSnapshot(
            settings: AppSettings(theme: .dark, language: "zh-CN"),
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let remote = CloudSettingsSnapshot(
            settings: AppSettings(theme: .light, language: "en-US"),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let cloud = InMemoryCloudStore(values: [
            "com.acmind.sync.settings": String(data: try JSONEncoder().encode(remote), encoding: .utf8)!
        ])
        let storage = InMemoryCloudSyncStorage(settingsSnapshot: local)
        let service = makeService(storage: storage, cloud: cloud, suite: "local-settings")

        await service.sync()

        let cloudJSON = try XCTUnwrap(cloud.string(forKey: "com.acmind.sync.settings"))
        let pushed = try JSONDecoder().decode(CloudSettingsSnapshot.self, from: Data(cloudJSON.utf8))
        XCTAssertEqual(pushed.settings.theme, .dark)
        XCTAssertEqual(pushed.settings.language, "zh-CN")
        XCTAssertEqual(pushed.updatedAt, local.updatedAt)

        let status = await service.getSyncStatus()
        XCTAssertNotNil(status.lastSyncByType[.settings])
    }

    func testPendingChangesReflectLocalUpdatesAfterSync() async throws {
        let cloud = InMemoryCloudStore()
        let storage = InMemoryCloudSyncStorage()
        let dictionary = InMemoryDictionary()
        let service = makeService(storage: storage, cloud: cloud, suite: "pending", dictionary: dictionary)

        await service.sync()

        let updatedAt = Date(timeIntervalSince1970: 1_800_000_200)
        await dictionary.replaceWords([
            PersonalWord(
                word: "AcMind",
                category: .product,
                priority: .critical,
                usageCount: 7,
                lastUsed: updatedAt,
                createdAt: updatedAt
            )
        ])

        await storage.saveKnowledgeCard(
            KnowledgeCard(
                id: "pending-card",
                sourceItemId: "pending-source",
                canonicalTitle: "待同步知识",
                updatedAt: updatedAt
            )
        )
        await storage.saveDistilledNote(
            DistilledNote(
                id: "pending-note",
                sourceItemId: "pending-source",
                title: "待同步蒸馏",
                updatedAt: updatedAt
            )
        )
        await storage.saveScheduledAgentTask(
            ScheduledAgentTask(
                id: "pending-task",
                name: "待同步任务",
                cronExpression: "0 9 * * *",
                skillName: "pending",
                updatedAt: updatedAt
            )
        )
        await storage.saveSettingsSnapshot(
            CloudSettingsSnapshot(
                settings: AppSettings(theme: .dark, language: "zh-CN"),
                updatedAt: updatedAt
            )
        )

        let status = await service.getSyncStatus()
        XCTAssertGreaterThanOrEqual(status.pendingChanges, 5)

        let summary = CloudSyncStatusSummary.make(from: status, now: updatedAt.addingTimeInterval(60))
        XCTAssertTrue(summary.detail.contains("待同步"))
        XCTAssertTrue(summary.detail.contains("5") || summary.detail.contains("\(status.pendingChanges)"))
    }

    func testScheduledAgentTaskHasUpdatedAt() {
        let now = Date()
        let task = ScheduledAgentTask(
            name: "每日汇总",
            cronExpression: "0 9 * * *",
            skillName: "meeting-summary",
            inputParams: ["range": "yesterday"],
            updatedAt: now
        )

        XCTAssertEqual(task.updatedAt, now)
    }

    func testScheduledAgentTaskCoding() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_100_000)
        let lastRunAt = Date(timeIntervalSince1970: 1_700_050_000)

        let original = ScheduledAgentTask(
            id: "test-task-id-001",
            name: "周报生成",
            cronExpression: "0 18 * * 5",
            skillName: "weekly-report",
            inputParams: ["team": "engineering"],
            enabled: true,
            lastRunAt: lastRunAt,
            lastRunStatus: "success",
            lastRunTaskId: "run-001",
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScheduledAgentTask.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.cronExpression, original.cronExpression)
        XCTAssertEqual(decoded.skillName, original.skillName)
        XCTAssertEqual(decoded.inputParams, original.inputParams)
        XCTAssertEqual(decoded.enabled, original.enabled)
        XCTAssertEqual(decoded.lastRunStatus, original.lastRunStatus)
        XCTAssertEqual(decoded.lastRunTaskId, original.lastRunTaskId)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, original.createdAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(decoded.updatedAt.timeIntervalSince1970, original.updatedAt.timeIntervalSince1970, accuracy: 1)
    }

    private func makeService(
        storage: InMemoryCloudSyncStorage,
        cloud: InMemoryCloudStore,
        suite: String,
        dictionary: InMemoryDictionary = InMemoryDictionary()
    ) -> CloudSyncService {
        let suiteName = "CloudSyncMergeTests.\(suite).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: "com.acmind.cloudSync.enabled")
        return CloudSyncService(
            syncStorage: storage,
            cloudStore: cloud,
            personalDictionary: dictionary,
            userDefaults: defaults,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
    }
}

private final class InMemoryCloudStore: CloudKeyValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String]

    init(values: [String: String] = [:]) { self.values = values }
    func string(forKey key: String) -> String? { lock.withLock { values[key] } }
    func set(_ value: String, forKey key: String) { lock.withLock { values[key] = value } }
    func synchronize() -> Bool { true }
    func observeExternalChanges(_ handler: @escaping @Sendable () -> Void) {}
}

private actor InMemoryDictionary: PersonalDictionarySyncStore {
    private var words: [PersonalWord]
    init(words: [PersonalWord] = []) { self.words = words }
    func getAllWords() -> [PersonalWord] { words }
    func replaceWords(_ words: [PersonalWord]) { self.words = words }
}

private actor InMemoryCloudSyncStorage: CloudSyncStorageProtocol {
    private var cards: [String: KnowledgeCard]
    private var notes: [String: DistilledNote] = [:]
    private var tasks: [String: ScheduledAgentTask] = [:]
    private var settingsSnapshot = CloudSettingsSnapshot(settings: AppSettings(), updatedAt: nil)

    init(
        cards: [KnowledgeCard] = [],
        settingsSnapshot: CloudSettingsSnapshot = CloudSettingsSnapshot(settings: AppSettings(), updatedAt: nil)
    ) {
        self.cards = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        self.settingsSnapshot = settingsSnapshot
    }
    func listKnowledgeCards() -> [KnowledgeCard] { Array(cards.values) }
    func saveKnowledgeCard(_ card: KnowledgeCard) { cards[card.id] = card }
    func listDistilledNotes() -> [DistilledNote] { Array(notes.values) }
    func saveDistilledNote(_ note: DistilledNote) { notes[note.id] = note }
    func listScheduledAgentTasks() -> [ScheduledAgentTask] { Array(tasks.values) }
    func saveScheduledAgentTask(_ task: ScheduledAgentTask) { tasks[task.id] = task }
    func getSettingsSnapshot() -> CloudSettingsSnapshot { settingsSnapshot }
    func saveSettingsSnapshot(_ snapshot: CloudSettingsSnapshot) { settingsSnapshot = snapshot }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
