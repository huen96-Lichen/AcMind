import Foundation
import SwiftUI

public typealias AcMindKeyboardShortcut = KeyboardShortcut

public enum AcWorkBrand {
    public static let displayName = "AcWork"

    // Keep internal identifiers stable while the user-facing brand migrates.
    public static let legacyInternalName = "AcMind"
}

public enum AcWorkInspectorPresentation: Sendable, Equatable {
    case fixed
    case sheet
    case hidden
}

public enum AcWorkResponsiveLayout {
    public static let inspectorThreshold: CGFloat = 1320
    public static let minimumWindowWidth: CGFloat = 1180

    public static func inspectorPresentation(
        windowWidth: CGFloat,
        hasInspector: Bool
    ) -> AcWorkInspectorPresentation {
        guard hasInspector else { return .hidden }
        return windowWidth >= inspectorThreshold ? .fixed : .sheet
    }
}

public enum SidebarItem: String, CaseIterable, Identifiable, Sendable {
    case home = "home"
    case agent = "agent"
    case inbox = "inbox"
    case clipboard = "clipboard"
    case schedule = "schedule"
    case workbench = "workbench"
    case dynamicContinent = "dynamicContinent"
    case systemStatus = "systemStatus"
    case voiceEntry = "voiceEntry"
    case modelManagement = "modelManagement"
    case settings = "settings"

    public var id: String { rawValue }

    public static var coreWorkflow: [SidebarItem] {
        [.home, .agent, .inbox, .schedule]
    }

    public static var processingItems: [SidebarItem] {
        [.workbench]
    }

    public static var companionCapabilities: [SidebarItem] {
        [.dynamicContinent, .voiceEntry]
    }

    public static var systemItems: [SidebarItem] {
        [.systemStatus, .modelManagement, .settings]
    }

    public static var mainItems: [SidebarItem] {
        coreWorkflow + processingItems + companionCapabilities + systemItems
    }

    public static var shortcutItems: [SidebarItem] {
        [.home, .agent, .inbox, .schedule, .workbench, .dynamicContinent, .voiceEntry, .systemStatus, .modelManagement, .settings]
    }

    public var displayName: String {
        switch self {
        case .home: return "工作台"
        case .agent: return "Agent"
        case .inbox: return "收集箱"
        case .clipboard: return "剪贴板 & 手机同步"
        case .schedule: return "日程"
        case .workbench: return "工具台"
        case .dynamicContinent: return "灵动大陆"
        case .systemStatus: return "状态"
        case .voiceEntry: return "说入法"
        case .modelManagement: return "模型"
        case .settings: return "设置"
        }
    }

    public var compactName: String {
        switch self {
        case .home: return "工作"
        case .agent: return "Agent"
        case .inbox: return "收集"
        case .clipboard: return "同步"
        case .schedule: return "日程"
        case .workbench: return "工具"
        case .dynamicContinent: return "灵动"
        case .systemStatus: return "状态"
        case .voiceEntry: return "语音"
        case .modelManagement: return "模型"
        case .settings: return "设置"
        }
    }

    public var title: String { displayName }

    public var commandTitle: String {
        switch self {
        case .home: return "前往工作台"
        case .agent: return "前往 Agent"
        case .inbox: return "前往收集箱"
        case .clipboard: return "前往收集箱"
        case .schedule: return "前往日程"
        case .workbench: return "前往工具台"
        case .dynamicContinent: return "前往灵动大陆"
        case .systemStatus: return "前往状态"
        case .voiceEntry: return "前往说入法"
        case .modelManagement: return "前往模型"
        case .settings: return "前往设置"
        }
    }

    public var icon: String {
        switch self {
        case .home: return "house.fill"
        case .agent: return "bubble.left.fill"
        case .inbox: return "tray.fill"
        case .clipboard: return "doc.on.clipboard"
        case .schedule: return "calendar"
        case .workbench: return "square.grid.2x2"
        case .dynamicContinent: return "capsule.portrait.fill"
        case .systemStatus: return "cpu"
        case .voiceEntry: return "mic.fill"
        case .modelManagement: return "cpu.fill"
        case .settings: return "gearshape.fill"
        }
    }

    public var shortcut: KeyboardShortcut? {
        switch self {
        case .home: return KeyboardShortcut(key: "1", modifiers: [.command])
        case .agent: return KeyboardShortcut(key: "2", modifiers: [.command])
        case .inbox: return KeyboardShortcut(key: "3", modifiers: [.command])
        case .clipboard: return nil
        case .schedule: return KeyboardShortcut(key: "4", modifiers: [.command])
        case .workbench: return KeyboardShortcut(key: "5", modifiers: [.command])
        case .dynamicContinent: return KeyboardShortcut(key: "6", modifiers: [.command])
        case .voiceEntry: return KeyboardShortcut(key: "7", modifiers: [.command])
        case .systemStatus: return KeyboardShortcut(key: "8", modifiers: [.command])
        case .modelManagement: return KeyboardShortcut(key: "9", modifiers: [.command])
        case .settings: return KeyboardShortcut(key: ",", modifiers: [.command])
        }
    }

    public enum Group: String, CaseIterable {
        case coreWorkflow = "工作"
        case processing = "处理"
        case companionCapabilities = "随身能力"
        case system = "系统"

        public var displayName: String { rawValue }
    }

    public var group: Group {
        switch self {
        case .home, .agent, .inbox, .clipboard, .schedule:
            return .coreWorkflow
        case .workbench:
            return .processing
        case .dynamicContinent, .voiceEntry:
            return .companionCapabilities
        case .systemStatus, .modelManagement, .settings:
            return .system
        }
    }
}
