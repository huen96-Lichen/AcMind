import Foundation

public enum SettingsStatusLabelFormatter {
    public static let unconfiguredModelText = "未配置模型"
    public static let unconfiguredProviderText = "未配置"
    public static let createBackupText = "创建备份"
    public static let restoreBackupText = "恢复备份"
    public static let autoBackupText = "自动备份（每周）"

    public static func binaryState(
        isEnabled: Bool,
        enabledText: String,
        disabledText: String
    ) -> String {
        isEnabled ? enabledText : disabledText
    }

    public static func savedState(
        isSaved: Bool,
        savedText: String = "已保存",
        unsavedText: String = "未保存"
    ) -> String {
        isSaved ? savedText : unsavedText
    }

    public static func configuredState(
        isConfigured: Bool,
        configuredText: String = "已配置",
        unconfiguredText: String = "未配置"
    ) -> String {
        isConfigured ? configuredText : unconfiguredText
    }

    public static func fallbackText(
        value: String,
        fallback: String = "未设置"
    ) -> String {
        value.isEmpty ? fallback : value
    }

    public static func permissionSummary(grantedCount: Int, totalCount: Int) -> String {
        "\(grantedCount)/\(totalCount) 已授权"
    }

    public static let localStorageText = "本地存储"

    public static func backupSectionDescription(autoBackupEnabled: Bool) -> String {
        autoBackupEnabled
            ? "自动备份已开启，每 7 天保存一次本地快照。"
            : "自动备份已关闭，仍可手动创建备份。"
    }

    public static func backupLastRunText(lastAutoBackupAt: Date?) -> String {
        guard let lastAutoBackupAt else {
            return "尚未备份"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastAutoBackupAt)
    }

    public static func backupTriggerText(
        enabled: Bool,
        lastAutoBackupAt: Date?,
        now: Date = Date()
    ) -> String {
        guard SettingsBackupPolicy.shouldPerformAutomaticBackup(
            enabled: enabled,
            lastAutoBackupAt: lastAutoBackupAt,
            now: now
        ) else {
            return enabled ? "下次自动备份尚未到期" : "自动备份已关闭"
        }

        return "已满足自动备份条件"
    }
}
