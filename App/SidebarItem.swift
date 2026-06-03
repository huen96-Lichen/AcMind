import Foundation
import AcMindKit

public typealias AcMindKeyboardShortcut = KeyboardShortcut

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
    case settings = "settings"

    public var id: String { rawValue }

    public static var coreWorkflow: [SidebarItem] {
        [.home, .agent, .inbox, .clipboard, .schedule, .workbench]
    }

    public static var companionCapabilities: [SidebarItem] {
        [.dynamicContinent, .voiceEntry]
    }

    public static var systemItems: [SidebarItem] {
        [.settings]
    }

    public static var mainItems: [SidebarItem] {
        coreWorkflow + companionCapabilities + systemItems
    }

    public var displayName: String {
        switch self {
        case .home: return "首页"
        case .agent: return "Agent"
        case .inbox: return "收集箱"
        case .clipboard: return "剪贴板 & 手机同步"
        case .schedule: return "日程"
        case .workbench: return "工具台"
        case .dynamicContinent: return "灵动大陆 & 配置"
        case .systemStatus: return "本地状态"
        case .voiceEntry: return "说入法"
        case .settings: return "设置"
        }
    }

    public var title: String { displayName }

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
        case .settings: return "gearshape.fill"
        }
    }

    public var shortcut: KeyboardShortcut? {
        switch self {
        case .home: return nil
        case .agent: return KeyboardShortcut(key: "1", modifiers: [.command])
        case .inbox: return KeyboardShortcut(key: "2", modifiers: [.command])
        case .clipboard: return KeyboardShortcut(key: "3", modifiers: [.command])
        case .schedule: return KeyboardShortcut(key: "4", modifiers: [.command])
        case .workbench: return KeyboardShortcut(key: "5", modifiers: [.command])
        case .dynamicContinent: return KeyboardShortcut(key: "6", modifiers: [.command])
        case .systemStatus: return nil
        case .voiceEntry: return KeyboardShortcut(key: "8", modifiers: [.command])
        case .settings: return KeyboardShortcut(key: ",", modifiers: [.command])
        }
    }

    public enum Group: String, CaseIterable {
        case coreWorkflow = "核心工作流"
        case companionCapabilities = "伴随能力"
        case system = "系统"
    }

    public var group: Group {
        switch self {
        case .home, .agent, .inbox, .clipboard, .schedule, .workbench:
            return .coreWorkflow
        case .dynamicContinent, .systemStatus, .voiceEntry:
            return .companionCapabilities
        case .settings:
            return .system
        }
    }
}
