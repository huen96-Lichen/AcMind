import Foundation

public actor SettingsMigrationService {
    public struct MigrationResult: Sendable, Equatable {
        public let migrated: Bool
        public let currentVersion: Int
        public let appliedVersions: [Int]

        public init(migrated: Bool, currentVersion: Int, appliedVersions: [Int]) {
            self.migrated = migrated
            self.currentVersion = currentVersion
            self.appliedVersions = appliedVersions
        }
    }

    private struct MigrationStep {
        let version: Int
        let description: String
        let run: () async throws -> Bool
    }

    private let defaults: UserDefaults
    private let storage: StorageServiceProtocol
    private let versionKey = "settings.migration.version.v1"

    public init(defaults: UserDefaults = .standard, storage: StorageServiceProtocol) {
        self.defaults = defaults
        self.storage = storage
    }

    public func runIfNeeded() async throws -> MigrationResult {
        let steps = migrationSteps()
        let startingVersion = currentVersion()
        var appliedVersions: [Int] = []
        var didChange = false
        var latestVersion = startingVersion

        for step in steps where step.version > startingVersion {
            let changed = try await step.run()
            didChange = didChange || changed
            appliedVersions.append(step.version)
            latestVersion = step.version
            defaults.set(latestVersion, forKey: versionKey)
        }

        return MigrationResult(
            migrated: didChange,
            currentVersion: latestVersion,
            appliedVersions: appliedVersions
        )
    }

    private func currentVersion() -> Int {
        guard let version = defaults.object(forKey: versionKey) as? Int else {
            return 0
        }
        return max(0, version)
    }

    private func migrationSteps() -> [MigrationStep] {
        [
            MigrationStep(version: 1, description: "Merge legacy local preferences into SettingsLocalPreferences blob") { [weak self] in
                guard let self else { return false }
                return try await self.migrateLocalPreferences()
            },
            MigrationStep(version: 2, description: "Promote legacy hotkeys into canonical storage") { [weak self] in
                guard let self else { return false }
                return try await self.migrateHotkeys()
            },
            MigrationStep(version: 3, description: "Normalize legacy voice polish settings") { [weak self] in
                guard let self else { return false }
                return try await self.migrateVoicePolishMode()
            }
        ]
    }

    private func migrateLocalPreferences() async throws -> Bool {
        let currentBlobExists = defaults.data(forKey: SettingsLocalPreferences.storageKey) != nil
        let legacyPreferences = legacyLocalPreferences()
        let legacyKeys = legacyLocalPreferenceKeys
        let hadLegacyKeys = legacyKeys.contains { defaults.object(forKey: $0) != nil }

        if currentBlobExists == false, let legacyPreferences {
            legacyPreferences.save(to: defaults)
        }

        if hadLegacyKeys {
            legacyKeys.forEach { defaults.removeObject(forKey: $0) }
        }

        return (currentBlobExists == false && legacyPreferences != nil) || hadLegacyKeys
    }

    private func migrateHotkeys() async throws -> Bool {
        var didChange = false

        if let legacyHotkey = defaults.string(forKey: "AppSettings.captureScreenshotHotkey")?.trimmedNonEmpty
            ?? defaults.string(forKey: "captureScreenshotHotkey")?.trimmedNonEmpty {
            let existing = try await storage.getSetting(key: "app.captureScreenshotHotkey")?.trimmedNonEmpty
            if existing == nil {
                try await storage.setSetting(key: "app.captureScreenshotHotkey", value: legacyHotkey)
                didChange = true
            }
            defaults.removeObject(forKey: "AppSettings.captureScreenshotHotkey")
            defaults.removeObject(forKey: "captureScreenshotHotkey")
            didChange = true
        }

        if let legacyVoiceShortcut = defaults.string(forKey: "companionVoiceShortcut")?.trimmedNonEmpty {
            let currentConfig = await CompanionConfigurationStore.load(from: storage)
            if currentConfig.voiceShortcut.trimmedNonEmpty == CompanionConfiguration.default.voiceShortcut {
                var updated = currentConfig
                updated.voiceShortcut = legacyVoiceShortcut
                try await CompanionConfigurationStore.save(updated, to: storage)
                didChange = true
            }
            defaults.removeObject(forKey: "companionVoiceShortcut")
            didChange = true
        }

        return didChange
    }

    private func migrateVoicePolishMode() async throws -> Bool {
        let newKey = "voice.voicePolishMode"
        let legacyKey = "voice.polishMode"

        guard let legacyRaw = try await storage.getSetting(key: legacyKey)?.trimmedNonEmpty else {
            return false
        }

        let existingNewValue = try await storage.getSetting(key: newKey)?.trimmedNonEmpty
        if existingNewValue == nil {
            let migrated = migrateVoicePolishModeValue(from: legacyRaw)
            try await storage.setSetting(key: newKey, value: migrated)
        }

        try await storage.deleteSetting(key: legacyKey)
        return true
    }

    private func migrateVoicePolishModeValue(from rawValue: String) -> String {
        if let newMode = VoicePolishMode(rawValue: rawValue) {
            return newMode.rawValue
        }

        if let legacyMode = PolishMode(rawValue: rawValue) {
            return legacyMode.asVoicePolishMode.rawValue
        }

        return rawValue
    }

    private var legacyLocalPreferenceKeys: [String] {
        [
            "autoBackupEnabled",
            "lastAutoBackupAt",
            "restoreWindowPosition",
            "notificationsEnabled",
            "taskCompletedNotificationsEnabled",
            "updateAvailableNotificationsEnabled",
            "captureOnlyWhenAppActive",
            "captureScreenshotEnabled",
            "captureAutoRedactionEnabled",
            "captureCensorModeRawValue",
            "captureScreenshotCornerRadius",
            "captureScreenshotMaxWidth",
            "captureScreenshotMaxHeight",
            "companionCaptureAutoSaveToInbox",
            "companionCaptureOpenDetailAfterCapture",
            "companionCaptureShowNotification",
            "voiceInputEnabled",
            "localFirstMode",
            "sensitiveContentNotUpload",
            "apiKeyUsesKeychain",
            "aiCallLogEnabled",
            "errorLogEnabled"
        ]
    }

    private func legacyLocalPreferences() -> SettingsLocalPreferences? {
        var preferences = SettingsLocalPreferences()
        var foundLegacyValue = false

        if let value = defaults.object(forKey: "autoBackupEnabled") as? Bool {
            preferences.autoBackupEnabled = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "lastAutoBackupAt") as? Date {
            preferences.lastAutoBackupAt = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "restoreWindowPosition") as? Bool {
            preferences.restoreWindowPosition = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "notificationsEnabled") as? Bool {
            preferences.notificationsEnabled = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "taskCompletedNotificationsEnabled") as? Bool {
            preferences.taskCompletedNotificationsEnabled = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "updateAvailableNotificationsEnabled") as? Bool {
            preferences.updateAvailableNotificationsEnabled = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "captureOnlyWhenAppActive") as? Bool {
            preferences.captureOnlyWhenAppActive = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "captureScreenshotEnabled") as? Bool {
            preferences.captureScreenshotEnabled = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "captureAutoRedactionEnabled") as? Bool {
            preferences.captureAutoRedactionEnabled = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "captureCensorModeRawValue") as? Int {
            preferences.captureCensorModeRawValue = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "captureScreenshotCornerRadius") as? Double {
            preferences.captureScreenshotCornerRadius = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "captureScreenshotMaxWidth") as? Double {
            preferences.captureScreenshotMaxWidth = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "captureScreenshotMaxHeight") as? Double {
            preferences.captureScreenshotMaxHeight = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "companionCaptureAutoSaveToInbox") as? Bool {
            preferences.companionCaptureAutoSaveToInbox = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "companionCaptureOpenDetailAfterCapture") as? Bool {
            preferences.companionCaptureOpenDetailAfterCapture = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "companionCaptureShowNotification") as? Bool {
            preferences.companionCaptureShowNotification = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "voiceInputEnabled") as? Bool {
            preferences.voiceInputEnabled = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "localFirstMode") as? Bool {
            preferences.localFirstMode = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "sensitiveContentNotUpload") as? Bool {
            preferences.sensitiveContentNotUpload = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "apiKeyUsesKeychain") as? Bool {
            preferences.apiKeyUsesKeychain = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "aiCallLogEnabled") as? Bool {
            preferences.aiCallLogEnabled = value
            foundLegacyValue = true
        }
        if let value = defaults.object(forKey: "errorLogEnabled") as? Bool {
            preferences.errorLogEnabled = value
            foundLegacyValue = true
        }

        return foundLegacyValue ? preferences : nil
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
