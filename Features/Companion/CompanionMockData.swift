import Foundation

// MARK: - Companion Layer Mock Data
// 随身 Mock 数据

public enum CompanionMockData {

    // MARK: - Shortcuts

    public static let shortcuts: [CompanionShortcut] = [
        CompanionShortcut(
            action: "随身语音",
            shortcut: "⌥ Space",
            description: "在任意应用中唤起语音输入"
        ),
        CompanionShortcut(
            action: "快速收集",
            shortcut: "⌥ C",
            description: "快速保存当前内容到收集箱"
        ),
        CompanionShortcut(
            action: "截图捕获",
            shortcut: "⌥ S",
            description: "快速截图并保存"
        ),
        CompanionShortcut(
            action: "打开 Agent",
            shortcut: "⌥ A",
            description: "快速打开主窗口并聚焦 Agent"
        ),
        CompanionShortcut(
            action: "今日日程",
            shortcut: "⌥ T",
            description: "快速查看今日日程"
        )
    ]

    // MARK: - Voice Transcriptions

    public static let recentTranscriptions: [CompanionVoiceTranscription] = [
        CompanionVoiceTranscription(
            text: "记得下午三点开会讨论产品方案，需要准备演示文稿和数据分析报告。",
            timestamp: Date().addingTimeInterval(-3600),
            duration: 8.5
        ),
        CompanionVoiceTranscription(
            text: "这个想法很不错，我们可以考虑在下一个版本中实现，需要评估一下技术可行性。",
            timestamp: Date().addingTimeInterval(-7200),
            duration: 6.2
        ),
        CompanionVoiceTranscription(
            text: "明天要去图书馆借几本书，主要是关于人工智能和产品设计的。",
            timestamp: Date().addingTimeInterval(-14400),
            duration: 5.0
        )
    ]

    // MARK: - Configuration

    public static var mockConfiguration: CompanionConfiguration {
        CompanionConfiguration(
            capsuleEnabled: true,
            capsulePosition: "topCenter",
            capsuleExpandedByDefault: false,
            voiceEnabled: true,
            voiceShortcut: "⌥Space",
            voiceOutputMode: "copyToClipboard",
            voiceSaveToInbox: true,
            shortcutsEnabled: true,
            captureEnabled: true
        )
    }

    // MARK: - Permission Status

    public static let permissionStatuses: [String: CompanionPermissionStatus] = [
        "microphone": .notDetermined,
        "accessibility": .notDetermined,
        "screenRecording": .notDetermined
    ]

    // MARK: - Capture Types

    public static let captureTypes: [CompanionCaptureType] = [
        .screenshot,
        .clipboard,
        .selectedText,
        .webpage
    ]
}
