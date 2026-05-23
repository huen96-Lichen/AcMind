import Foundation
import AcMindKit

public enum SidebarItem: String, CaseIterable, Identifiable, Sendable {
    case dynamicSurface = "dynamicSurface"
    case agent = "agent"
    case inbox = "inbox"
    case clipboard = "clipboard"
    case schedule = "schedule"
    case workbench = "workbench"
    case systemMonitor = "systemMonitor"
    case tools = "tools"
    case companion = "companion"
    case config = "config"
    case settings = "settings"

    public var id: String { rawValue }

    public static var mainItems: [SidebarItem] {
        [.dynamicSurface, .agent, .inbox, .clipboard, .schedule, .workbench, .systemMonitor, .companion, .config, .settings]
    }

    public static var primaryNavItems: [SidebarItem] {
        [.dynamicSurface, .agent, .inbox, .clipboard, .schedule, .workbench, .systemMonitor, .companion, .config, .settings]
    }

    public var displayName: String {
        switch self {
        case .dynamicSurface: return "灵动胶囊/大陆"
        case .agent: return "Agent"
        case .inbox: return "收集箱"
        case .clipboard: return "剪贴板"
        case .schedule: return "日程"
        case .workbench: return "工作台"
        case .systemMonitor: return "本机状态"
        case .tools: return "工具"
        case .companion: return "说入法"
        case .config: return "配置"
        case .settings: return "设置"
        }
    }

    public var title: String { displayName }

    public var icon: String {
        switch self {
        case .dynamicSurface: return "capsule.portrait.fill"
        case .agent: return "bubble.left.fill"
        case .inbox: return "tray.fill"
        case .clipboard: return "doc.on.clipboard"
        case .schedule: return "calendar"
        case .workbench: return "square.grid.2x2"
        case .systemMonitor: return "cpu"
        case .tools: return "wrench.fill"
        case .companion: return "mic.fill"
        case .config: return "slider.horizontal.3"
        case .settings: return "gearshape.fill"
        }
    }

    public var shortcut: KeyboardShortcut? {
        switch self {
        case .dynamicSurface: return KeyboardShortcut(key: "8", modifiers: [.command])
        case .agent: return KeyboardShortcut(key: "1", modifiers: [.command])
        case .inbox: return KeyboardShortcut(key: "2", modifiers: [.command])
        case .clipboard: return KeyboardShortcut(key: "3", modifiers: [.command])
        case .schedule: return KeyboardShortcut(key: "4", modifiers: [.command])
        case .workbench: return KeyboardShortcut(key: "5", modifiers: [.command])
        case .systemMonitor: return KeyboardShortcut(key: "6", modifiers: [.command])
        case .tools: return nil
        case .companion: return KeyboardShortcut(key: "7", modifiers: [.command])
        case .config: return KeyboardShortcut(key: "9", modifiers: [.command])
        case .settings: return KeyboardShortcut(key: ",", modifiers: [.command])
        }
    }
}
