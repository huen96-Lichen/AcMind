import Foundation
import SwiftUI

// MARK: - Capsule Action Type

/// 胶囊功能类型
public enum CapsuleActionType: String, Codable, CaseIterable, Sendable, Identifiable {
    case screenshot       // 截图
    case scrollScreenshot // 滚动截图
    case voiceNote        // 录音笔记
    case urlToText        // URL转文字稿
    case scheduleAnalysis // 日程表分析
    case clipboard        // 剪贴板采集
    case quickText        // 快速文本
    case fileCapture      // 文件采集

    public var id: String { rawValue }

    public var defaultIcon: String {
        switch self {
        case .screenshot: return "camera.fill"
        case .scrollScreenshot: return "scroll"
        case .voiceNote: return "mic.fill"
        case .urlToText: return "link"
        case .scheduleAnalysis: return "calendar.badge.clock"
        case .clipboard: return "doc.on.clipboard"
        case .quickText: return "square.and.pencil"
        case .fileCapture: return "folder"
        }
    }

    public var defaultTitle: String {
        switch self {
        case .screenshot: return "截图"
        case .scrollScreenshot: return "滚动截图"
        case .voiceNote: return "录音笔记"
        case .urlToText: return "URL转文字"
        case .scheduleAnalysis: return "日程分析"
        case .clipboard: return "剪贴板"
        case .quickText: return "快速文本"
        case .fileCapture: return "文件采集"
        }
    }

    public var defaultColor: Color {
        switch self {
        case .screenshot: return .blue
        case .scrollScreenshot: return .indigo
        case .voiceNote: return .red
        case .urlToText: return .purple
        case .scheduleAnalysis: return .orange
        case .clipboard: return .green
        case .quickText: return .cyan
        case .fileCapture: return .brown
        }
    }
}

// MARK: - Capsule Action Config

/// 单个功能配置
public struct CapsuleActionConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let type: CapsuleActionType
    public var isEnabled: Bool
    public var order: Int

    public init(
        id: UUID = UUID(),
        type: CapsuleActionType,
        isEnabled: Bool = true,
        order: Int = 0
    ) {
        self.id = id
        self.type = type
        self.isEnabled = isEnabled
        self.order = order
    }

    public static func `default`(type: CapsuleActionType, order: Int) -> CapsuleActionConfig {
        CapsuleActionConfig(type: type, isEnabled: true, order: order)
    }
}

// MARK: - Desktop Capsule Settings

/// 桌面胶囊配置
public struct DesktopCapsuleSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var showOnLaunch: Bool
    public var actions: [CapsuleActionConfig]
    public var position: CGPoint
    public var lastWebpageURL: URL?

    public init(
        isEnabled: Bool = true,
        showOnLaunch: Bool = true,
        actions: [CapsuleActionConfig] = [],
        position: CGPoint = .zero,
        lastWebpageURL: URL? = nil
    ) {
        self.isEnabled = isEnabled
        self.showOnLaunch = showOnLaunch
        self.actions = actions
        self.position = position
        self.lastWebpageURL = lastWebpageURL
    }

    /// 默认配置 - 包含常用功能
    public static var `default`: DesktopCapsuleSettings {
        DesktopCapsuleSettings(
            isEnabled: true,
            showOnLaunch: true,
            actions: [
                .default(type: .screenshot, order: 0),
                .default(type: .scrollScreenshot, order: 1),
                .default(type: .voiceNote, order: 2),
                .default(type: .urlToText, order: 3),
                .default(type: .scheduleAnalysis, order: 4)
            ],
            position: .zero
        )
    }

    /// 获取启用的功能（按顺序）
    public var enabledActions: [CapsuleActionConfig] {
        actions
            .filter { $0.isEnabled }
            .sorted { $0.order < $1.order }
    }
}

public extension Notification.Name {
    static let desktopCapsuleSettingsDidChange = Notification.Name("desktop.capsule.settings.didChange")
}
