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

    public init(
        isEnabled: Bool = false,
        lastSyncDate: Date? = nil,
        syncInProgress: Bool = false,
        lastSyncByType: [SyncDataType: Date] = [:],
        pendingChanges: Int = 0
    ) {
        self.isEnabled = isEnabled
        self.lastSyncDate = lastSyncDate
        self.syncInProgress = syncInProgress
        self.lastSyncByType = lastSyncByType
        self.pendingChanges = pendingChanges
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
}

// MARK: - Cloud Sync Service

public actor CloudSyncService: CloudSyncServiceProtocol {

    private let storage: StorageServiceProtocol

    private static let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let userDefaults = UserDefaults.standard
    private var lastSync: Date?
    private var syncInProgress = false
    private var lastSyncByType: [SyncDataType: Date] = [:]

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
        Self.ubiquitousStore.synchronize()

        await pull()
        await push()

        lastSync = Date()
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
            lastSyncByType: lastSyncByType
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
        guard isWithinSizeLimit(json) else { return }
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
        guard isWithinSizeLimit(json) else { return }
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
        Self.ubiquitousStore.set(settingsJson, forKey: settingsKey)
        lastSyncByType[.settings] = Date()
    }
}
