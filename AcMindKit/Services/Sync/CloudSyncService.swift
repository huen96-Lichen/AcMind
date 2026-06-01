import Foundation

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

    public static let shared = CloudSyncService()

    private static let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private static let userDefaults = UserDefaults.standard
    private var lastSync: Date?

    private let personalDictionaryKey = "com.acmind.sync.personalDictionary"
    private let syncEnabledKey = "com.acmind.cloudSync.enabled"

    private init() {
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
        Self.ubiquitousStore.synchronize()
        await pull()
        await push()
        lastSync = Date()
    }

    public func pull() async {
        guard await isSyncEnabled() else { return }
        await mergePersonalWords()
    }

    public func push() async {
        guard await isSyncEnabled() else { return }
        let localWords = await PersonalDictionaryService.shared.getAllWords()
        guard let data = try? JSONEncoder().encode(localWords),
              let json = String(data: data, encoding: .utf8) else { return }
        Self.ubiquitousStore.set(json, forKey: personalDictionaryKey)
    }

    // MARK: - Configuration

    public func isSyncEnabled() async -> Bool {
        return Self.userDefaults.bool(forKey: syncEnabledKey)
    }

    public func setSyncEnabled(_ enabled: Bool) async {
        Self.userDefaults.set(enabled, forKey: syncEnabledKey)
        if enabled {
            await sync()
        }
    }

    public func lastSyncDate() async -> Date? {
        return lastSync
    }

    // MARK: - External Change

    private func handleExternalChange() {
        Task { await pull() }
    }

    // MARK: - Merge

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
    }
}
