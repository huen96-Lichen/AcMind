import Foundation

// MARK: - Sync Data Type

public enum SyncDataType: String, Codable, Sendable, CaseIterable {
    case personalDictionary
    case knowledgeCards
    case distilledNotes
    case agentTasks
    case settings

    public var displayName: String {
        switch self {
        case .personalDictionary: return "个人词典"
        case .knowledgeCards: return "知识卡片"
        case .distilledNotes: return "蒸馏笔记"
        case .agentTasks: return "Agent 任务"
        case .settings: return "设置"
        }
    }
}

// MARK: - Sync Status

public struct SyncStatus: Sendable, Equatable {
    public let isEnabled: Bool
    public let lastSyncDate: Date?
    public let syncInProgress: Bool
    public let lastSyncByType: [SyncDataType: Date]
    public let pendingChanges: Int
    public let lastErrorMessage: String?

    public init(
        isEnabled: Bool = false,
        lastSyncDate: Date? = nil,
        syncInProgress: Bool = false,
        lastSyncByType: [SyncDataType: Date] = [:],
        pendingChanges: Int = 0,
        lastErrorMessage: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.lastSyncDate = lastSyncDate
        self.syncInProgress = syncInProgress
        self.lastSyncByType = lastSyncByType
        self.pendingChanges = pendingChanges
        self.lastErrorMessage = lastErrorMessage
    }
}

public struct CloudSyncStatusSummary: Sendable, Equatable {
    public let title: String
    public let detail: String
    public let canRetry: Bool
    public let retryTitle: String?

    public init(title: String, detail: String, canRetry: Bool, retryTitle: String?) {
        self.title = title
        self.detail = detail
        self.canRetry = canRetry
        self.retryTitle = retryTitle
    }

    public static func make(from status: SyncStatus, now: Date = Date()) -> CloudSyncStatusSummary {
        guard status.isEnabled else {
            return CloudSyncStatusSummary(
                title: "云同步未开启",
                detail: "开启后会同步个人词典、知识卡片、蒸馏笔记、Agent 任务和设置。",
                canRetry: false,
                retryTitle: nil
            )
        }

        if status.syncInProgress {
            return CloudSyncStatusSummary(
                title: "云同步进行中",
                detail: "正在拉取和推送最新数据，请稍候。",
                canRetry: false,
                retryTitle: nil
            )
        }

        if let error = status.lastErrorMessage, error.isEmpty == false {
            return CloudSyncStatusSummary(
                title: "云同步需要重试",
                detail: error,
                canRetry: true,
                retryTitle: "重试同步"
            )
        }

        guard let lastSyncDate = status.lastSyncDate else {
            return CloudSyncStatusSummary(
                title: "云同步待首次运行",
                detail: "开启后尚未完成过同步，可以手动触发一次。",
                canRetry: true,
                retryTitle: "立即同步"
            )
        }

        let typeCount = status.lastSyncByType.count
        let typeText = typeCount > 0 ? " · 已覆盖 \(typeCount) 类数据" : ""
        return CloudSyncStatusSummary(
            title: "云同步正常",
            detail: "最近同步于 \(relativeTime(from: lastSyncDate, to: now))\(typeText)",
            canRetry: false,
            retryTitle: nil
        )
    }

    private static func relativeTime(from date: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 {
            return "刚刚"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) 分钟前"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) 小时前"
        }
        return "\(hours / 24) 天前"
    }
}

// MARK: - Cloud Sync Service Protocol

public protocol CloudSyncServiceProtocol: Sendable {
    func sync() async
    func pull() async
    func push() async
    func isSyncEnabled() async -> Bool
    func setSyncEnabled(_ enabled: Bool) async
    func lastSyncDate() async -> Date?
    func getSyncStatus() async -> SyncStatus
}

public protocol CloudKeyValueStore: Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
    @discardableResult func synchronize() -> Bool
    func observeExternalChanges(_ handler: @escaping @Sendable () -> Void)
}

public final class UbiquitousCloudKeyValueStore: CloudKeyValueStore, @unchecked Sendable {
    public static let shared = UbiquitousCloudKeyValueStore()

    private let store: NSUbiquitousKeyValueStore
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []

    public init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
    }

    public func string(forKey key: String) -> String? { store.string(forKey: key) }
    public func set(_ value: String, forKey key: String) { store.set(value, forKey: key) }
    public func synchronize() -> Bool { store.synchronize() }

    public func observeExternalChanges(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        let observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: nil
        ) { _ in handler() }
        observers.append(observer)
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}

public protocol PersonalDictionarySyncStore: Sendable {
    func getAllWords() async -> [PersonalWord]
    func replaceWords(_ words: [PersonalWord]) async throws
}

extension PersonalDictionaryService: PersonalDictionarySyncStore {}

public protocol CloudSyncStorageProtocol: Sendable {
    func listKnowledgeCards() async throws -> [KnowledgeCard]
    func saveKnowledgeCard(_ card: KnowledgeCard) async throws
    func listDistilledNotes() async throws -> [DistilledNote]
    func saveDistilledNote(_ note: DistilledNote) async throws
    func listScheduledAgentTasks() async throws -> [ScheduledAgentTask]
    func saveScheduledAgentTask(_ task: ScheduledAgentTask) async throws
    func getSettingsSnapshot() async throws -> CloudSettingsSnapshot
    func saveSettingsSnapshot(_ snapshot: CloudSettingsSnapshot) async throws
}

public struct CloudSettingsSnapshot: Codable, Sendable, Equatable {
    public var settings: AppSettings
    public var updatedAt: Date?

    public init(settings: AppSettings, updatedAt: Date?) {
        self.settings = settings
        self.updatedAt = updatedAt
    }
}

private final class DefaultCloudSyncStorage: CloudSyncStorageProtocol, @unchecked Sendable {
    private let storage: StorageServiceProtocol
    private let settingsService: SettingsServiceProtocol

    init(storage: StorageServiceProtocol, settingsService: SettingsServiceProtocol) {
        self.storage = storage
        self.settingsService = settingsService
    }
    func listKnowledgeCards() async throws -> [KnowledgeCard] { try await storage.listKnowledgeCards(status: nil) }
    func saveKnowledgeCard(_ card: KnowledgeCard) async throws { try await storage.updateKnowledgeCard(card) }
    func listDistilledNotes() async throws -> [DistilledNote] { try await storage.listDistilledNotes() }
    func saveDistilledNote(_ note: DistilledNote) async throws { try await storage.updateDistilledNote(note) }
    func listScheduledAgentTasks() async throws -> [ScheduledAgentTask] { try await storage.listScheduledAgentTasks() }
    func saveScheduledAgentTask(_ task: ScheduledAgentTask) async throws { try await storage.insertScheduledAgentTask(task) }
    func getSettingsSnapshot() async throws -> CloudSettingsSnapshot {
        let settings = await settingsService.getSettings()
        let updatedAt = try await storage.getSetting(key: "app.updatedAt")
            .flatMap(Double.init)
            .map(Date.init(timeIntervalSince1970:))
        return CloudSettingsSnapshot(settings: settings, updatedAt: updatedAt)
    }
    func saveSettingsSnapshot(_ snapshot: CloudSettingsSnapshot) async throws {
        try await settingsService.updateSettings(snapshot.settings)
        if let updatedAt = snapshot.updatedAt {
            try await storage.setSetting(key: "app.updatedAt", value: String(updatedAt.timeIntervalSince1970))
        }
    }
}

// MARK: - Cloud Sync Service

public actor CloudSyncService: CloudSyncServiceProtocol {

    private let storage: CloudSyncStorageProtocol
    private let cloudStore: CloudKeyValueStore
    private let personalDictionary: PersonalDictionarySyncStore
    private let userDefaults: UserDefaults
    private let now: @Sendable () -> Date
    private var lastSync: Date?
    private var syncInProgress = false
    private var lastSyncByType: [SyncDataType: Date] = [:]
    private var lastErrorMessage: String?

    private let personalDictionaryKey = "com.acmind.sync.personalDictionary"
    private let knowledgeCardsKey = "com.acmind.sync.knowledgeCards"
    private let distilledNotesKey = "com.acmind.sync.distilledNotes"
    private let agentTasksKey = "com.acmind.sync.agentTasks"
    private let settingsKey = "com.acmind.sync.settings"
    private let syncEnabledKey = "com.acmind.cloudSync.enabled"

    public init(storage: StorageServiceProtocol, settingsService: SettingsServiceProtocol? = nil) {
        let resolvedSettingsService = settingsService ?? SettingsService(storage: storage)
        self.storage = DefaultCloudSyncStorage(storage: storage, settingsService: resolvedSettingsService)
        self.cloudStore = UbiquitousCloudKeyValueStore.shared
        self.personalDictionary = PersonalDictionaryService.shared
        self.userDefaults = .standard
        self.now = { Date() }
        cloudStore.observeExternalChanges { [weak self] in
            Task { await self?.handleExternalChange() }
        }
        cloudStore.synchronize()
    }

    public init(
        syncStorage: CloudSyncStorageProtocol,
        cloudStore: CloudKeyValueStore,
        personalDictionary: PersonalDictionarySyncStore,
        userDefaults: UserDefaults,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.storage = syncStorage
        self.cloudStore = cloudStore
        self.personalDictionary = personalDictionary
        self.userDefaults = userDefaults
        self.now = now
        cloudStore.observeExternalChanges { [weak self] in
            Task { await self?.handleExternalChange() }
        }
        cloudStore.synchronize()
    }

    // MARK: - Sync

    public func sync() async {
        guard await isSyncEnabled() else { return }
        guard !syncInProgress else { return }

        syncInProgress = true
        lastErrorMessage = nil
        cloudStore.synchronize()

        do {
            try await pullAll()
            try await pushAll()
            lastSync = now()
        } catch {
            recordSyncFailure(error.localizedDescription)
        }
        syncInProgress = false
    }

    public func pull() async {
        guard await isSyncEnabled() else { return }
        lastErrorMessage = nil
        do { try await pullAll() } catch { recordSyncFailure(error.localizedDescription) }
    }

    public func push() async {
        guard await isSyncEnabled() else { return }
        lastErrorMessage = nil
        do { try await pushAll() } catch { recordSyncFailure(error.localizedDescription) }
    }

    private func pullAll() async throws {
        try await mergePersonalWords()
        try await mergeKnowledgeCards()
        try await mergeDistilledNotes()
        try await mergeAgentTasks()
        try await mergeSettings()
    }

    private func pushAll() async throws {
        try await pushPersonalWords()
        try await pushKnowledgeCards()
        try await pushDistilledNotes()
        try await pushAgentTasks()
        try await pushSettings()
    }

    // MARK: - Configuration

    public func isSyncEnabled() async -> Bool {
        return userDefaults.bool(forKey: syncEnabledKey)
    }

    public func setSyncEnabled(_ enabled: Bool) async {
        userDefaults.set(enabled, forKey: syncEnabledKey)
        if enabled {
            await sync()
        }
    }

    public func lastSyncDate() async -> Date? {
        return lastSync
    }

    public func getSyncStatus() async -> SyncStatus {
        SyncStatus(
            isEnabled: await isSyncEnabled(),
            lastSyncDate: lastSync,
            syncInProgress: syncInProgress,
            lastSyncByType: lastSyncByType,
            lastErrorMessage: lastErrorMessage
        )
    }

    public func getLastSyncDate(for type: SyncDataType) async -> Date? {
        lastSyncByType[type]
    }

    // MARK: - Capacity Protection

    private func isWithinSizeLimit(_ json: String, limitKB: Int = 900) -> Bool {
        let sizeBytes = json.utf8.count
        return sizeBytes <= limitKB * 1024
    }

    private func recordSyncFailure(_ message: String) {
        lastErrorMessage = message
    }

    // MARK: - External Change

    private func handleExternalChange() async {
        await pull()
    }

    // MARK: - Personal Dictionary Sync

    private func mergePersonalWords() async throws {
        guard let json = cloudStore.string(forKey: personalDictionaryKey) else { return }
        let remoteWords = try decode([PersonalWord].self, json: json, type: .personalDictionary)

        let localWords = await personalDictionary.getAllWords()

        var merged: [String: PersonalWord] = [:]
        for word in localWords {
            merged[word.word.lowercased()] = word
        }
        for remoteWord in remoteWords {
            let key = remoteWord.word.lowercased()
            if let existing = merged[key] {
                merged[key] = preferredWord(existing, remoteWord)
            } else {
                merged[key] = remoteWord
            }
        }

        let mergedWords = Array(merged.values)
        try await personalDictionary.replaceWords(mergedWords)
        lastSyncByType[.personalDictionary] = now()
    }

    private func pushPersonalWords() async throws {
        let localWords = await personalDictionary.getAllWords()
        let json = try encode(localWords, type: .personalDictionary)
        try setCloudValue(json, forKey: personalDictionaryKey, type: .personalDictionary)
    }

    // MARK: - Knowledge Cards Sync

    private func mergeKnowledgeCards() async throws {
        guard let json = cloudStore.string(forKey: knowledgeCardsKey) else { return }
        let remoteCards = try decode([KnowledgeCard].self, json: json, type: .knowledgeCards)

        let localCards = try await storage.listKnowledgeCards()

        var merged: [String: KnowledgeCard] = [:]
        for card in localCards {
            merged[card.id] = card
        }
        for remoteCard in remoteCards {
            if let existing = merged[remoteCard.id] {
                if remoteCard.updatedAt > existing.updatedAt {
                    merged[remoteCard.id] = remoteCard
                }
            } else {
                merged[remoteCard.id] = remoteCard
            }
        }

        for card in merged.values {
            try await storage.saveKnowledgeCard(card)
        }
        lastSyncByType[.knowledgeCards] = now()
    }

    private func pushKnowledgeCards() async throws {
        let json = try encode(await storage.listKnowledgeCards(), type: .knowledgeCards)
        try setCloudValue(json, forKey: knowledgeCardsKey, type: .knowledgeCards)
    }

    // MARK: - Distilled Notes Sync

    private func mergeDistilledNotes() async throws {
        guard let json = cloudStore.string(forKey: distilledNotesKey) else { return }
        let remoteNotes = try decode([DistilledNote].self, json: json, type: .distilledNotes)

        let localNotes = try await storage.listDistilledNotes()

        var merged: [String: DistilledNote] = [:]
        for note in localNotes {
            merged[note.id] = note
        }
        for remoteNote in remoteNotes {
            if let existing = merged[remoteNote.id] {
                if remoteNote.updatedAt > existing.updatedAt {
                    merged[remoteNote.id] = remoteNote
                }
            } else {
                merged[remoteNote.id] = remoteNote
            }
        }

        for note in merged.values {
            try await storage.saveDistilledNote(note)
        }
        lastSyncByType[.distilledNotes] = now()
    }

    private func pushDistilledNotes() async throws {
        let json = try encode(await storage.listDistilledNotes(), type: .distilledNotes)
        try setCloudValue(json, forKey: distilledNotesKey, type: .distilledNotes)
    }

    // MARK: - Agent Tasks Sync

    private func mergeAgentTasks() async throws {
        guard let json = cloudStore.string(forKey: agentTasksKey) else { return }
        let remoteTasks = try decode([ScheduledAgentTask].self, json: json, type: .agentTasks)

        let localTasks = try await storage.listScheduledAgentTasks()

        var merged: [String: ScheduledAgentTask] = [:]
        for task in localTasks {
            merged[task.id] = task
        }
        for remoteTask in remoteTasks {
            if let existing = merged[remoteTask.id] {
                if remoteTask.updatedAt > existing.updatedAt {
                    merged[remoteTask.id] = remoteTask
                }
            } else {
                merged[remoteTask.id] = remoteTask
            }
        }

        for task in merged.values {
            try await storage.saveScheduledAgentTask(task)
        }
        lastSyncByType[.agentTasks] = now()
    }

    private func pushAgentTasks() async throws {
        let json = try encode(await storage.listScheduledAgentTasks(), type: .agentTasks)
        try setCloudValue(json, forKey: agentTasksKey, type: .agentTasks)
    }

    // MARK: - Settings Sync

    private func mergeSettings() async throws {
        guard let json = cloudStore.string(forKey: settingsKey) else { return }
        let remoteSnapshot = try decodeSettingsSnapshot(json)
        let localSnapshot = try await storage.getSettingsSnapshot()
        let remoteDate = remoteSnapshot.updatedAt ?? .distantPast
        let localDate = localSnapshot.updatedAt ?? .distantPast
        guard remoteDate >= localDate else { return }

        var merged = remoteSnapshot
        let preferences = SettingsLocalPreferences.loadOrDefault(from: userDefaults)
        if preferences.sensitiveContentNotUpload {
            merged.settings.defaultProviderId = localSnapshot.settings.defaultProviderId
            merged.settings.defaultModelId = localSnapshot.settings.defaultModelId
            merged.settings.vaultPath = localSnapshot.settings.vaultPath
            merged.settings.captureScreenshotHotkey = localSnapshot.settings.captureScreenshotHotkey
        }
        try await storage.saveSettingsSnapshot(merged)
        lastSyncByType[.settings] = now()
    }

    private func pushSettings() async throws {
        let localSnapshot = try await storage.getSettingsSnapshot()
        let preferences = SettingsLocalPreferences.loadOrDefault(from: userDefaults)
        let sanitized = Self.sanitizedSettingsBackup(localSnapshot.settings, preferences: preferences)
        let sanitizedJson = try encode(
            CloudSettingsSnapshot(settings: sanitized, updatedAt: localSnapshot.updatedAt),
            type: .settings
        )
        try setCloudValue(sanitizedJson, forKey: settingsKey, type: .settings)
    }

    private func decodeSettingsSnapshot(_ json: String) throws -> CloudSettingsSnapshot {
        if let snapshot = try? decode(CloudSettingsSnapshot.self, json: json, type: .settings) {
            return snapshot
        }
        let legacySettings = try decode(AppSettings.self, json: json, type: .settings)
        return CloudSettingsSnapshot(settings: legacySettings, updatedAt: nil)
    }

    private func preferredWord(_ lhs: PersonalWord, _ rhs: PersonalWord) -> PersonalWord {
        if lhs.priority != rhs.priority { return lhs.priority.rawValue > rhs.priority.rawValue ? lhs : rhs }
        if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount ? lhs : rhs }
        return (lhs.lastUsed ?? .distantPast) >= (rhs.lastUsed ?? .distantPast) ? lhs : rhs
    }

    private func encode<T: Encodable>(_ value: T, type: SyncDataType) throws -> String {
        guard let json = String(data: try JSONEncoder().encode(value), encoding: .utf8) else {
            throw CloudSyncError.encodingFailed(type)
        }
        return json
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String, type syncType: SyncDataType) throws -> T {
        guard let data = json.data(using: .utf8) else { throw CloudSyncError.invalidRemoteData(syncType) }
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw CloudSyncError.invalidRemoteData(syncType) }
    }

    private func setCloudValue(_ json: String, forKey key: String, type: SyncDataType) throws {
        guard isWithinSizeLimit(json) else { throw CloudSyncError.sizeLimitExceeded(type) }
        cloudStore.set(json, forKey: key)
        lastSyncByType[type] = now()
    }

    nonisolated static func sanitizedSettingsBackupJSON(
        from json: String,
        preferences: SettingsLocalPreferences
    ) -> String? {
        guard let data = json.data(using: .utf8),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return nil
        }

        let sanitized = sanitizedSettingsBackup(settings, preferences: preferences)
        guard let encoded = try? JSONEncoder().encode(sanitized) else {
            return nil
        }

        return String(data: encoded, encoding: .utf8)
    }

    nonisolated static func sanitizedSettingsBackup(
        _ settings: AppSettings,
        preferences: SettingsLocalPreferences
    ) -> AppSettings {
        guard preferences.sensitiveContentNotUpload else {
            return settings
        }

        var sanitized = settings
        sanitized.defaultProviderId = nil
        sanitized.defaultModelId = nil
        sanitized.vaultPath = ""
        sanitized.captureScreenshotHotkey = nil
        return sanitized
    }
}

public enum CloudSyncError: LocalizedError, Sendable, Equatable {
    case encodingFailed(SyncDataType)
    case invalidRemoteData(SyncDataType)
    case sizeLimitExceeded(SyncDataType)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let type): return "\(type.displayName)编码失败，请重试。"
        case .invalidRemoteData(let type): return "云端\(type.displayName)数据损坏，已停止推送以避免覆盖。"
        case .sizeLimitExceeded(let type): return "\(type.displayName)超过 iCloud 同步大小限制，请精简内容后重试。"
        }
    }
}
