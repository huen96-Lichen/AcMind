#if DEBUG
import CoreGraphics
import Foundation

enum DebugPreviewLaunchCommand: Equatable {
    case settings(SettingsPreviewLaunchOptions)
    case acworkExportScreenshots
    case acworkLayoutAudit
    case workbenchV2Audit
    case workbenchV2BackgroundVerify
    case companionSixPagesExport
    case toolWorkspace(ToolWorkspacePreviewLaunchOptions)
    case productPanel(ProductPanelPreviewLaunchOptions)
    case agent(AgentPreviewLaunchOptions)
    case systemStatus(SystemStatusPreviewLaunchOptions)

    static func resolve(arguments: [String] = ProcessInfo.processInfo.arguments) -> DebugPreviewLaunchCommand? {
        if arguments.contains("--settings-preview") {
            return .settings(SettingsPreviewLaunchOptions(arguments: arguments))
        }
        if arguments.contains("--acwork-export-screenshots") {
            return .acworkExportScreenshots
        }
        if arguments.contains("--acwork-layout-audit") {
            return .acworkLayoutAudit
        }
        if arguments.contains("--acwork-workbench-v2-audit") {
            return .workbenchV2Audit
        }
        if arguments.contains("--acwork-workbench-v2-background-verify") {
            return .workbenchV2BackgroundVerify
        }
        if arguments.contains("--companion-six-pages-export") {
            return .companionSixPagesExport
        }
        if arguments.contains("--tool-workspace-preview") {
            return .toolWorkspace(ToolWorkspacePreviewLaunchOptions(arguments: arguments))
        }
        if arguments.contains("--product-panel-preview") {
            return .productPanel(ProductPanelPreviewLaunchOptions(arguments: arguments))
        }
        if arguments.contains("--agent-preview") {
            return .agent(AgentPreviewLaunchOptions(arguments: arguments))
        }
        if arguments.contains("--system-status-preview") {
            return .systemStatus(SystemStatusPreviewLaunchOptions(arguments: arguments))
        }
        return nil
    }

    static func isCompanionSixPagesExport(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains("--companion-six-pages-export")
    }
}

struct SettingsPreviewLaunchOptions: Equatable {
    let exportPath: String?
    let isNarrow: Bool

    var contentWidth: CGFloat {
        isNarrow ? 880 : 1280
    }

    init(arguments: [String]) {
        exportPath = arguments.first(where: { $0.hasPrefix("--settings-preview-export=") })
            .map { String($0.dropFirst("--settings-preview-export=".count)) }
        isNarrow = arguments.contains("--settings-preview-narrow")
    }
}

struct ToolWorkspacePreviewLaunchOptions: Equatable {
    let isNarrow: Bool

    var contentWidth: CGFloat {
        isNarrow ? 900 : 1200
    }

    var contentHeight: CGFloat {
        isNarrow ? 720 : 800
    }

    init(arguments: [String]) {
        isNarrow = arguments.contains("--tool-workspace-preview-narrow")
    }
}

struct ProductPanelPreviewLaunchOptions: Equatable {
    let isNarrow: Bool

    var contentWidth: CGFloat {
        isNarrow ? ProductPanelTokens.Layout.narrowWidth : ProductPanelTokens.Layout.defaultWidth
    }

    var contentHeight: CGFloat {
        isNarrow ? 960 : 900
    }

    init(arguments: [String]) {
        isNarrow = arguments.contains("--product-panel-preview-narrow")
    }
}

struct AgentPreviewLaunchOptions: Equatable {
    let exportPath: String?
    let isNarrow: Bool
    let sidebarSelection: String

    var contentWidth: CGFloat {
        isNarrow ? 880 : 1280
    }

    var contentHeight: CGFloat {
        isNarrow ? 1180 : 980
    }

    init(arguments: [String]) {
        exportPath = arguments.first(where: { $0.hasPrefix("--agent-preview-export=") })
            .map { String($0.dropFirst("--agent-preview-export=".count)) }
        isNarrow = arguments.contains("--agent-preview-narrow")
        if arguments.contains("--agent-preview-tool-call") {
            sidebarSelection = "toolCall"
        } else if arguments.contains("--agent-preview-automation") {
            sidebarSelection = "automation"
        } else {
            sidebarSelection = "quickAsk"
        }
    }
}

struct SystemStatusPreviewLaunchOptions: Equatable {
    let isNarrow: Bool

    var contentWidth: CGFloat {
        isNarrow ? 880 : 1280
    }

    var contentHeight: CGFloat {
        isNarrow ? 1120 : 980
    }

    init(arguments: [String]) {
        isNarrow = arguments.contains("--system-status-preview-narrow")
    }
}
#endif
