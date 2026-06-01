import Foundation

public enum SettingsBackupPolicy {
    public static func shouldPerformAutomaticBackup(enabled: Bool, lastAutoBackupAt: Date?, now: Date) -> Bool {
        guard enabled else { return false }
        guard let lastAutoBackupAt else { return true }

        return now.timeIntervalSince(lastAutoBackupAt) >= 7 * 24 * 60 * 60
    }
}
