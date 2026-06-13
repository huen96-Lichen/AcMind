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
                detail: "开启后还没有完成过同步，可以手动触发一次。",
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

// MARK: - Cloud Sync Service

public actor CloudSyncService: CloudSyncServiceProtocol {

    private let storage: StorageServiceProtocol

    private static let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let userDefaults = UserDefaults.standard
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

    public init(storage: StorageServiceProtocol) {
        self.storage = storage

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: Self.ubiquitousStore,
            queue: nil
        ) { [weak self] _ in
            Task {
                await self?.handleExternalChange()
            }
        }
        Self.ubiquitousStore.synchronize()
    }

    // MARK: - Sync

    public func sync() async {
        guard await isSyncEnabled() else { return }
        guard !syncInProgress else { return }

        syncInProgress = true
        lastErrorMessage = nil
        Self.ubiquitousStore.synchronize()

        await pull()
        await push()

        if lastErrorMessage == nil {
            lastSync = Date()
        }
        syncInProgress = false
    }

    public func pull() async {
        guard await isSyncEnabled() else { return }
        await mergePersonalWords()
        await mergeKnowledgeCards()
        await mergeDistilledNotes()
        await mergeAgentTasks()
        await mergeSettings()
    }

    public func push() async {
        guard await isSyncEnabled() else { return }
        await pushPersonalWords()
        await pushKnowledgeCards()
        await pushDistilledNotes()
        await pushAgentTasks()
        await pushSettings()
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

    private func handleExternalChange() {
        Task { await pull() }
    }

    // MARK: - Personal Dictionary Sync

    private func mergePersonalWords() async {
        guard let json = Self.ubiquitousStore.string(forKey: personalDictionaryKey),
              let data = json.data(using: .utf8),
              let remoteWords = try? JSONDecoder().decode([PersonalWord].self, from: data) else {
            return
        }

        let localWords = await PersonalDictionaryService.shared.getAllWords()

        var merged: [String: PersonalWord] = [:]
        for word in localWords {
            merged[word.word.lowercased()] = word
        }
        for remoteWord in remoteWords {
            let key = remoteWord.word.lowercased()
            if let existing = merged[key] {
                if remoteWord.priority.rawValue > existing.priority.rawValue {
                    merged[key] = remoteWord
                }
            } else {
                merged[key] = remoteWord
            }
        }

        let mergedWords = Array(merged.values)
        try? await PersonalDictionaryService.shared.clearDictionary()
        for word in mergedWords {
            try? await PersonalDictionaryService.shared.addWord(
                word.word,
                category: word.category,
                priority: word.priority
            )
        }
        lastSyncByType[.personalDictionary] = Date()
    }

    private func pushPersonalWords() async {
        let localWords = await PersonalDictionaryService.shared.getAllWords()
        guard let data = try? JSONEncoder().encode(localWords),
              let json = String(data: data, encoding: .utf8) else { return }
        Self.ubiquitousStore.set(json, forKey: personalDictionaryKey)
        lastSyncByType[.personalDictionary] = Date()
    }

    // MARK: - Knowledge Cards Sync

    private func mergeKnowledgeCards() async {
        guard let json = Self.ubiquitousStore.string(forKey: knowledgeCardsKey),
              let data = json.data(using: .utf8),
              let remoteCards = try? JSONDecoder().decode([KnowledgeCard].self, from: data) else {
            return
        }

        let localCards = (try? await storage.listKnowledgeCards(status: nil)) ?? []

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
            try? await storage.updateKnowledgeCard(card)
        }
        lastSyncByType[.knowledgeCards] = Date()
    }

    private func pushKnowledgeCards() async {
        let localCards = (try? await storage.listKnowledgeCards(status: nil)) ?? []
        guard let data = try? JSONEncoder().encode(localCards),
              let json = String(data: data, encoding: .utf8) else { return }
        guard isWithinSizeLimit(json) else {
            recordSyncFailure("知识卡片超过 iCloud 同步大小限制，请精简内容后重试。")
            return
        }
        Self.ubiquitousStore.set(json, forKey: knowledgeCardsKey)
        lastSyncByType[.knowledgeCards] = Date()
    }

    // MARK: - Distilled Notes Sync

    private func mergeDistilledNotes() async {
        guard let json = Self.ubiquitousStore.string(forKey: distilledNotesKey),
              let data = json.data(using: .utf8),
              let remoteNotes = try? JSONDecoder().decode([DistilledNote].self, from: data) else {
            return
        }

        let localNotes = (try? await storage.listDistilledNotes()) ?? []

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
            try? await storage.updateDistilledNote(note)
        }
        lastSyncByType[.distilledNotes] = Date()
    }

    private func pushDistilledNotes() async {
        let localNotes = (try? await storage.listDistilledNotes()) ?? []
        guard let data = try? JSONEncoder().encode(localNotes),
              let json = String(data: data, encoding: .utf8) else { return }
        guard isWithinSizeLimit(json) else {
            recordSyncFailure("蒸馏笔记超过 iCloud 同步大小限制，请精简内容后重试。")
            return
        }
        Self.ubiquitousStore.set(json, forKey: distilledNotesKey)
        lastSyncByType[.distilledNotes] = Date()
    }

    // MARK: - Agent Tasks Sync

    private func mergeAgentTasks() async {
        guard let json = Self.ubiquitousStore.string(forKey: agentTasksKey),
              let data = json.data(using: .utf8),
              let remoteTasks = try? JSONDecoder().decode([ScheduledAgentTask].self, from: data) else {
            return
        }

        let localTasks = (try? await storage.listScheduledAgentTasks()) ?? []

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
            try? await storage.insertScheduledAgentTask(task)
        }
        lastSyncByType[.agentTasks] = Date()
    }

    private func pushAgentTasks() async {
        let localTasks = (try? await storage.listScheduledAgentTasks()) ?? []
        guard let data = try? JSONEncoder().encode(localTasks),
              let json = String(data: data, encoding: .utf8) else { return }
        guard isWithinSizeLimit(json) else { return }
        Self.ubiquitousStore.set(json, forKey: agentTasksKey)
        lastSyncByType[.agentTasks] = Date()
    }

    // MARK: - Settings Sync

    private func mergeSettings() async {
        guard let json = Self.ubiquitousStore.string(forKey: settingsKey),
              let data = json.data(using: .utf8),
              let remoteSettings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return
        }

        guard let settingsData = try? JSONEncoder().encode(remoteSettings),
              let settingsJson = String(data: settingsData, encoding: .utf8) else {
            return
        }
        try? await storage.setSetting(key: "settings.backup", value: settingsJson)
        lastSyncByType[.settings] = Date()
    }

    private func pushSettings() async {
        guard let settingsJson = try? await storage.getSetting(key: "settings.backup") else { return }
        let preferences = SettingsLocalPreferences.loadOrDefault(from: userDefaults)
        guard let sanitizedJson = Self.sanitizedSettingsBackupJSON(
            from: settingsJson,
            preferences: preferences
        ) else {
            return
        }

        Self.ubiquitousStore.set(sanitizedJson, forKey: settingsKey)
        lastSyncByType[.settings] = Date()
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
