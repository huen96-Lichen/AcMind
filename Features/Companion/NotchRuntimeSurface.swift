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
        title: "当前状态总览",
        subtitle: "当前状态总览",
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

    fileprivate func allows(_ contentID: CompanionRuntimeContentID, scope: NotchRuntimeSurfaceScope) -> Bool {
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
    static func resolve(context: NotchRuntimeSurfaceContext, scope: NotchRuntimeSurfaceScope) -> NotchRuntimeSurface {
        for provider in orderedProviders(context: context, scope: scope) {
            if let surface = provider(context, scope) {
                return surface
            }
        }
        return .idle
    }

    private static let providers: [(contentID: CompanionRuntimeContentID, provider: @Sendable (NotchRuntimeSurfaceContext, NotchRuntimeSurfaceScope) -> NotchRuntimeSurface?)] = [
        (.voice, voiceSurface),
        (.screenshot, screenshotSurface),
        (.music, musicSurface),
        (.systemStatus, systemStatusSurface),
        (.schedule, scheduleSurface),
        (.agent, agentSurface)
    ]

    private static func orderedProviders(
        context: NotchRuntimeSurfaceContext,
        scope: NotchRuntimeSurfaceScope
    ) -> [@Sendable (NotchRuntimeSurfaceContext, NotchRuntimeSurfaceScope) -> NotchRuntimeSurface?] {
        let order = switch scope {
        case .collapsed:
            context.displaySettings.collapsedVisibleContentOrder
        case .primary:
            context.displaySettings.primarySurfaceContentOrder
        }

        return order.compactMap { contentID in
            providers.first(where: { $0.contentID == contentID })?.provider
        }
    }

    private static func voiceSurface(context: NotchRuntimeSurfaceContext, scope: NotchRuntimeSurfaceScope) -> NotchRuntimeSurface? {
        guard context.voiceSurfaceState.isActive, context.allows(.voice, scope: scope) else { return nil }
        return NotchRuntimeSurface(
            kind: .voice,
            title: context.voiceSurfaceState.displayTitle ?? "说入法",
            subtitle: ActivityStateLabelFormatter.activityLabel(
                isActive: context.voiceSurfaceState.isActive,
                activeLabel: context.voiceSurfaceState.displaySubtitle ?? "等待输入",
                idleLabel: "待命"
            ),
            symbol: context.voiceSurfaceState.displayIcon,
            accentColor: voiceAccent(for: context.voiceSurfaceState),
            priority: context.voiceSurfaceState.surfacePriority
        )
    }

    private static func screenshotSurface(context: NotchRuntimeSurfaceContext, scope: NotchRuntimeSurfaceScope) -> NotchRuntimeSurface? {
        guard context.isCapturing, context.allows(.screenshot, scope: scope) else { return nil }
        return NotchRuntimeSurface(
            kind: .screenshot,
            title: "截图进行中",
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
        if isPermissionNeedingAttention(context.microphonePermissionStatus) {
            message = "麦克风权限需要处理"
            accent = .orange
        } else if isPermissionNeedingAttention(context.screenRecordingPermissionStatus) {
            message = "录屏权限需要处理"
            accent = .orange
        } else if isPermissionNeedingAttention(context.accessibilityPermissionStatus) {
            message = "辅助功能权限需要处理"
            accent = .orange
        } else if context.batteryInfo.isAvailable, context.batteryInfo.percentage <= 20, context.batteryInfo.isCharging == false {
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
        guard context.isModuleEnabled(.music),
              context.allows(.music, scope: scope),
              context.playbackState.isPlaying || context.playbackState.title.isEmpty == false || context.playbackState.sourceLabel.isEmpty == false || context.playbackState.bundleIdentifier != nil else { return nil }

        let title = context.playbackState.title.isEmpty ? "音乐播放中" : context.playbackState.title
        let trackSummary = NowPlayingSourceLabelFormatter.trackSummaryLabel(
            artist: context.playbackState.artist,
            album: context.playbackState.album,
            bundleIdentifier: context.playbackState.bundleIdentifier,
            source: context.playbackState.sourceLabel
        )
        return NotchRuntimeSurface(
            kind: .music,
            title: title,
            subtitle: "♪ \(trackSummary)",
            symbol: "music.note",
            accentColor: context.playbackState.isPlaying ? NotchV2DesignTokens.accentPurple : NotchV2DesignTokens.secondaryText,
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
            subtitle = ActivityStateLabelFormatter.activityLabel(
                isActive: true,
                activeLabel: "执行中心已展开",
                idleLabel: "准备接收新的输入"
            )
        } else {
            subtitle = "准备接收新的输入"
        }
        return NotchRuntimeSurface(
            kind: .agent,
            title: "智能体空闲",
            subtitle: subtitle,
            symbol: "sparkles",
            accentColor: context.status.color,
            priority: .defaultState
        )
    }

    private static func needsSystemAttention(context: NotchRuntimeSurfaceContext) -> Bool {
        isPermissionNeedingAttention(context.microphonePermissionStatus) ||
        isPermissionNeedingAttention(context.screenRecordingPermissionStatus) ||
        isPermissionNeedingAttention(context.accessibilityPermissionStatus) ||
        (context.batteryInfo.isAvailable && context.batteryInfo.percentage <= 20 && context.batteryInfo.isCharging == false)
    }

    private static func isPermissionNeedingAttention(_ status: AppPermissionStatus) -> Bool {
        switch status {
        case .denied, .restricted, .needsSystemSettings:
            return true
        case .unknown, .notDetermined, .requesting, .authorized, .failed:
            return false
        }
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
