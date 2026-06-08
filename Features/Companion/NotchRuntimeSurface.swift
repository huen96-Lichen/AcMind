import SwiftUI
import AcMindKit

enum NotchRuntimeSurfaceKind: String {
    case voice
    case screenshot
    case music
    case schedule
    case agent
    case systemStatus
    case idle

    var contentID: CompanionRuntimeContentID? {
        switch self {
        case .voice: return .voice
        case .screenshot: return .screenshot
        case .music: return .music
        case .schedule: return .schedule
        case .agent: return .agent
        case .systemStatus: return .systemStatus
        case .idle: return nil
        }
    }
}

struct NotchRuntimeSurface: Equatable {
    let kind: NotchRuntimeSurfaceKind
    let title: String
    let subtitle: String
    let symbol: String
    let accentColor: Color
    let priority: NotchV2SurfacePriority

    static let idle = NotchRuntimeSurface(
        kind: .idle,
        title: "Agent 待命",
        subtitle: "当前状态 · 总览",
        symbol: "sparkles",
        accentColor: NotchV2DesignTokens.secondaryText,
        priority: .defaultState
    )
}

enum NotchRuntimeSurfaceScope {
    case collapsed
    case primary
}

struct NotchRuntimeSurfaceContext {
    let displaySettings: CompanionDisplaySettings
    let selectedPage: NotchV2Page
    let voiceSurfaceState: NotchV2VoiceSurfaceState
    let isCapturing: Bool
    let playbackState: PlaybackState
    let status: CompanionStatus
    let lastTranscription: CompanionVoiceTranscription?
    let batteryInfo: BatteryInfo
    let microphonePermissionStatus: AppPermissionStatus
    let screenRecordingPermissionStatus: AppPermissionStatus
    let accessibilityPermissionStatus: AppPermissionStatus

    func isModuleEnabled(_ module: DynamicContinentModuleID) -> Bool {
        displaySettings.enabledDynamicModules.contains(module)
    }

    func allows(_ contentID: CompanionRuntimeContentID, scope: NotchRuntimeSurfaceScope) -> Bool {
        let allowedSet = switch scope {
        case .collapsed:
            displaySettings.collapsedVisibleContents
        case .primary:
            displaySettings.primarySurfaceContents
        }
        return allowedSet.contains(contentID)
    }
}

enum NotchRuntimeSurfaceDispatcher {
    static let orderedContentIDs: [CompanionRuntimeContentID] = [
        .voice,
        .screenshot,
        .systemStatus,
        .music,
        .schedule,
        .agent
    ]

    static func resolve(context: NotchRuntimeSurfaceContext, scope: NotchRuntimeSurfaceScope) -> NotchRuntimeSurface {
        for provider in providers {
            if let surface = provider(context, scope) {
                return surface
            }
        }
        return .idle
    }

    private static let providers: [@Sendable (NotchRuntimeSurfaceContext, NotchRuntimeSurfaceScope) -> NotchRuntimeSurface?] = [
        voiceSurface,
        screenshotSurface,
        musicSurface,
        systemStatusSurface,
        scheduleSurface,
        agentSurface
    ]

    private static func voiceSurface(context: NotchRuntimeSurfaceContext, scope: NotchRuntimeSurfaceScope) -> NotchRuntimeSurface? {
        guard context.voiceSurfaceState.isActive, context.allows(.voice, scope: scope) else { return nil }
        return NotchRuntimeSurface(
            kind: .voice,
            title: context.voiceSurfaceState.displayTitle ?? "说入法",
            subtitle: context.voiceSurfaceState.displaySubtitle ?? "等待输入",
            symbol: context.voiceSurfaceState.displayIcon,
            accentColor: voiceAccent(for: context.voiceSurfaceState),
            priority: context.voiceSurfaceState.surfacePriority
        )
    }

    private static func screenshotSurface(context: NotchRuntimeSurfaceContext, scope: NotchRuntimeSurfaceScope) -> NotchRuntimeSurface? {
        guard context.isCapturing, context.allows(.screenshot, scope: scope) else { return nil }
        return NotchRuntimeSurface(
            kind: .screenshot,
            title: "截图处理中",
            subtitle: "正在截取当前屏幕",
            symbol: "camera.viewfinder",
            accentColor: .orange,
            priority: .screenshot
        )
    }

    private static func systemStatusSurface(context: NotchRuntimeSurfaceContext, scope: NotchRuntimeSurfaceScope) -> NotchRuntimeSurface? {
        guard context.allows(.systemStatus, scope: scope), context.isModuleEnabled(.systemStatus) else { return nil }
        guard needsSystemAttention(context: context) else { return nil }

        let message: String
        let accent: Color
        if context.microphonePermissionStatus != .authorized {
            message = "麦克风权限需要处理"
            accent = .orange
        } else if context.screenRecordingPermissionStatus != .authorized {
            message = "录屏权限需要处理"
            accent = .orange
        } else if context.accessibilityPermissionStatus != .authorized {
            message = "辅助功能权限需要处理"
            accent = .orange
        } else if context.batteryInfo.percentage <= 20, context.batteryInfo.isCharging == false {
            message = "电量较低"
            accent = .red
        } else {
            message = "系统状态存在异常"
            accent = .orange
        }

        return NotchRuntimeSurface(
            kind: .systemStatus,
            title: "系统提醒",
            subtitle: message,
            symbol: "waveform.path.ecg",
            accentColor: accent,
            priority: .systemEventHUD
        )
    }

    private static func musicSurface(context: NotchRuntimeSurfaceContext, scope: NotchRuntimeSurfaceScope) -> NotchRuntimeSurface? {
        guard context.playbackState.isPlaying,
              context.isModuleEnabled(.music),
              context.allows(.music, scope: scope) else { return nil }
        let title = context.playbackState.title.isEmpty ? "音乐播放中" : context.playbackState.title
        let artist = context.playbackState.artist.isEmpty ? "未知艺术家" : context.playbackState.artist
        return NotchRuntimeSurface(
            kind: .music,
            title: title,
            subtitle: "♪ \(artist)",
            symbol: "music.note",
            accentColor: NotchV2DesignTokens.accentPurple,
            priority: .music
        )
    }

    private static func scheduleSurface(context: NotchRuntimeSurfaceContext, scope: NotchRuntimeSurfaceScope) -> NotchRuntimeSurface? {
        guard context.isModuleEnabled(.schedule),
              context.allows(.schedule, scope: scope),
              context.selectedPage == .schedule else { return nil }
        return NotchRuntimeSurface(
            kind: .schedule,
            title: "今日日程",
            subtitle: "最近事项与下一步",
            symbol: "calendar.badge.clock",
            accentColor: .blue,
            priority: .defaultState
        )
    }

    private static func agentSurface(context: NotchRuntimeSurfaceContext, scope: NotchRuntimeSurfaceScope) -> NotchRuntimeSurface? {
        guard context.isModuleEnabled(.agent),
              context.allows(.agent, scope: scope) else { return nil }
        let subtitle: String
        if let transcription = context.lastTranscription?.text, transcription.isEmpty == false {
            subtitle = "最近转写已记录"
        } else if context.voiceSurfaceState.isActive {
            subtitle = context.voiceSurfaceState.displaySubtitle ?? "等待输入"
        } else if context.selectedPage == .agent {
            subtitle = "执行中心已展开"
        } else {
            subtitle = "准备接收新的输入"
        }
        return NotchRuntimeSurface(
            kind: .agent,
            title: "Agent 待命",
            subtitle: subtitle,
            symbol: "sparkles",
            accentColor: context.status.color,
            priority: .defaultState
        )
    }

    private static func needsSystemAttention(context: NotchRuntimeSurfaceContext) -> Bool {
        context.microphonePermissionStatus != .authorized ||
        context.screenRecordingPermissionStatus != .authorized ||
        context.accessibilityPermissionStatus != .authorized ||
        (context.batteryInfo.percentage <= 20 && context.batteryInfo.isCharging == false)
    }

    private static func voiceAccent(for state: NotchV2VoiceSurfaceState) -> Color {
        switch state {
        case .cancelled:
            return .red
        case .idle, .listening, .processing, .completed:
            return NotchV2DesignTokens.accentPurple
        }
    }
}
