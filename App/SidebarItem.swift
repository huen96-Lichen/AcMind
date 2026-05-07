import Foundation
import AcMindKit

public enum SidebarItem: String, CaseIterable, Identifiable, Sendable {
    case agent = "agent"
    case inbox = "inbox"
    case clipboard = "clipboard"
    case schedule = "schedule"
    case workbench = "workbench"
    case tools = "tools"
    case settings = "settings"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .agent: return "Agent"
        case .inbox: return "收集箱"
        case .clipboard: return "剪贴板"
        case .schedule: return "日程"
        case .workbench: return "工作台"
        case .tools: return "工具"
        case .settings: return "设置"
        }
    }

    public var title: String { displayName }

    public var icon: String {
        switch self {
        case .agent: return "bubble.left.fill"
        case .inbox: return "tray.fill"
        case .clipboard: return "doc.on.clipboard"
        case .schedule: return "calendar"
        case .workbench: return "square.grid.2x2"
        case .tools: return "wrench.fill"
        case .settings: return "gearshape.fill"
        }
    }

    public var shortcut: KeyboardShortcut? {
        switch self {
        case .agent: return KeyboardShortcut(key: "1", modifiers: [.command])
        case .inbox: return KeyboardShortcut(key: "2", modifiers: [.command])
        case .clipboard: return KeyboardShortcut(key: "3", modifiers: [.command])
        case .schedule: return KeyboardShortcut(key: "4", modifiers: [.command])
        case .workbench: return KeyboardShortcut(key: "5", modifiers: [.command])
        case .tools: return KeyboardShortcut(key: "6", modifiers: [.command])
        case .settings: return KeyboardShortcut(key: ",", modifiers: [.command])
        }
    }
}
