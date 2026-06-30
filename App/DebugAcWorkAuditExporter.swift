#if DEBUG
import AppKit
import AcMindKit
import SwiftUI

@MainActor
enum DebugAcWorkAuditExporter {
    static func exportPhaseOneScreenshots(
        outputDirectory: URL,
        serviceContainer: ServiceContainer,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) throws {
        print("[AcWorkExport] output directory ready: \(outputDirectory.path)")

        let appState = AppState.shared
        let pinActions = previewClipboardPinActions()
        let largeSize = NSSize(width: 1500, height: 920)
        let compactSize = NSSize(width: 1180, height: 720)

        if let single = screenshotExportSelection(arguments: arguments) {
            try exportSelectedScreenshot(
                single,
                outputDirectory: outputDirectory,
                largeSize: largeSize,
                compactSize: compactSize,
                appState: appState,
                serviceContainer: serviceContainer,
                pinActions: pinActions
            )
            return
        }

        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1500x920-workspace-populated.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1500x920-inbox-list.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .inbox,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1500x920-inbox-grid.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .inbox,
            viewMode: "grid"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1500x920-clipboard.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .clipboard,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1180x720-workspace.png"),
            size: compactSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1180x720-workspace-collapsed-sidebar.png"),
            size: compactSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil,
            sidebarCollapsed: true
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1180x720-inbox.png"),
            size: compactSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .inbox,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("1180x720-clipboard.png"),
            size: compactSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .populated,
            sidebarSelection: .clipboard,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("workspace-loading.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loading),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("workspace-empty.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .empty),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("workspace-error.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .error(message: "工作台加载失败")),
            inboxScenario: .populated,
            sidebarSelection: .home,
            viewMode: nil
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("inbox-loading.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .loading,
            sidebarSelection: .inbox,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("inbox-empty.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .empty,
            sidebarSelection: .inbox,
            viewMode: "list"
        )
        try exportContentViewScreenshot(
            outputDirectory.appendingPathComponent("inbox-error.png"),
            size: largeSize,
            appState: appState,
            container: serviceContainer,
            pinActions: pinActions,
            workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
            inboxScenario: .error,
            sidebarSelection: .inbox,
            viewMode: "list"
        )
    }

    static func exportLayoutAudit(
        outputDirectory: URL,
        serviceContainer: ServiceContainer
    ) throws {
        let screenshotsDirectory = outputDirectory.appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        print("[AcWorkAudit] output directory ready: \(outputDirectory.path)")

        let appState = AppState.shared
        let pinActions = previewClipboardPinActions()
        let sizes: [(name: String, size: NSSize)] = [
            ("min", AppWindowGeometry.minimumContentSize),
            ("default", AppWindowGeometry.defaultFrame.size),
            ("1440x960", NSSize(width: 1440, height: 960)),
            ("1728x1117", NSSize(width: 1728, height: 1117))
        ]

        var runtimeFrames = AuditRuntimeFrames(window: AuditWindowFrame(width: 1440, height: 960), components: [])

        for entry in sizes {
            let normalPath = screenshotsDirectory.appendingPathComponent("workbench-\(entry.name)-normal.png")
            let debugPath = screenshotsDirectory.appendingPathComponent("workbench-\(entry.name)-debug.png")

            try exportContentViewScreenshot(
                normalPath,
                size: entry.size,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil,
                showLayoutDebugOverlay: false
            )

            try exportContentViewScreenshot(
                debugPath,
                size: entry.size,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil,
                showLayoutDebugOverlay: true
            )

            if entry.name == "1440x960" {
                runtimeFrames = AuditRuntimeFrames(
                    window: AuditWindowFrame(width: Int(entry.size.width), height: Int(entry.size.height)),
                    components: LayoutDebugStore.shared.measurements.map {
                        AuditComponentFrame(
                            name: $0.name,
                            x: Int($0.frame.minX),
                            y: Int($0.frame.minY),
                            width: Int($0.frame.width),
                            height: Int($0.frame.height)
                        )
                    }
                )
            }
        }

        let jsonURL = outputDirectory.appendingPathComponent("AcWork_Workbench_Runtime_Frames.json")
        let data = try JSONEncoder.prettyPrinted.encode(runtimeFrames)
        try data.write(to: jsonURL)
        print("[AcWorkAudit] wrote \(jsonURL.path)")
    }

    private static func screenshotExportSelection(arguments: [String]) -> String? {
        arguments.first(where: { $0.hasPrefix("--acwork-export-screenshot=") })
            .map { String($0.dropFirst("--acwork-export-screenshot=".count)) }
    }

    private static func exportSelectedScreenshot(
        _ selection: String,
        outputDirectory: URL,
        largeSize: NSSize,
        compactSize: NSSize,
        appState: AppState,
        serviceContainer: ServiceContainer,
        pinActions: ClipboardPinActions
    ) throws {
        switch selection {
        case "workspace-populated":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1500x920-workspace-populated.png"),
                size: largeSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil
            )
        case "inbox-list":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1500x920-inbox-list.png"),
                size: largeSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .inbox,
                viewMode: "list"
            )
        case "inbox-grid":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1500x920-inbox-grid.png"),
                size: largeSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .inbox,
                viewMode: "grid"
            )
        case "clipboard":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1500x920-clipboard.png"),
                size: largeSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .clipboard,
                viewMode: "list"
            )
        case "workspace":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1180x720-workspace.png"),
                size: compactSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil
            )
        case "workspace-collapsed":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1180x720-workspace-collapsed-sidebar.png"),
                size: compactSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil,
                sidebarCollapsed: true
            )
        case "workspace-collapsed-hover-inbox":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1180x720-workspace-collapsed-sidebar-hover-inbox.png"),
                size: compactSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil,
                sidebarCollapsed: true,
                forcedHoverItem: .inbox
            )
        case "workspace-collapsed-hover-model":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1180x720-workspace-collapsed-sidebar-hover-model.png"),
                size: compactSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil,
                sidebarCollapsed: true,
                forcedHoverItem: .modelManagement
            )
        case "workspace-collapsed-hover-settings":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1180x720-workspace-collapsed-sidebar-hover-settings.png"),
                size: compactSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .home,
                viewMode: nil,
                sidebarCollapsed: true,
                forcedSettingsHover: true
            )
        case "inbox":
            try exportContentViewScreenshot(
                outputDirectory.appendingPathComponent("1180x720-inbox.png"),
                size: compactSize,
                appState: appState,
                container: serviceContainer,
                pinActions: pinActions,
                workspaceRepository: PreviewWorkspaceDashboardRepository(phase: .loaded),
                inboxScenario: .populated,
                sidebarSelection: .inbox,
                viewMode: "list"
            )
        default:
            throw NSError(domain: "AcWorkScreenshotExport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown screenshot selection: \(selection)"])
        }
    }

    private static func exportContentViewScreenshot(
        _ path: URL,
        size: NSSize,
        appState: AppState,
        container: ServiceContainer,
        pinActions: ClipboardPinActions,
        workspaceRepository: any WorkspaceDashboardRepositoryProtocol,
        inboxScenario: AcWorkPreviewScenario,
        sidebarSelection: SidebarItem,
        viewMode: String?,
        sidebarCollapsed: Bool = false,
        forcedHoverItem: SidebarItem? = nil,
        forcedSettingsHover: Bool = false,
        showLayoutDebugOverlay: Bool = false
    ) throws {
        appState.sidebarSelection = sidebarSelection
        appState.sidebarCollapsed = sidebarCollapsed
        appState.isAppReady = true
        appState.initializationPhase = .completed
        appState.mainWindowState = .normal
        appState.inboxWorkspaceSelection = "all"
        print("[AcWorkExport] rendering \(path.lastPathComponent) at \(Int(size.width))x\(Int(size.height))")

        let defaults = UserDefaults.standard
        defaults.set(viewMode ?? "grid", forKey: "acwork.inbox.viewMode")
        defaults.set("standard", forKey: "acwork.inbox.density")
        DebugSidebarPreviewState.forcedHoverItem = forcedHoverItem
        DebugSidebarPreviewState.isSettingsHovered = forcedSettingsHover
        defer {
            DebugSidebarPreviewState.forcedHoverItem = nil
            DebugSidebarPreviewState.isSettingsHovered = false
        }

        let rootView = ContentView(
            clipboardPinActions: pinActions,
            workspaceDashboardRepository: workspaceRepository,
            inboxPreviewScenario: inboxScenario
        )
        .environmentObject(appState)
        .environmentObject(container)
        .preferredColorScheme(.light)
        .transaction { transaction in
            transaction.disablesAnimations = true
        }

        LayoutDebugStore.shared.isOverlayVisible = showLayoutDebugOverlay
        defer { LayoutDebugStore.shared.isOverlayVisible = false }

        try DebugScreenshotRenderer.exportView(
            path,
            size: size,
            showLayoutDebugOverlay: showLayoutDebugOverlay,
            errorDomain: "AcWorkScreenshotExport",
            logPrefix: "AcWorkExport"
        ) {
            rootView
        }
    }

    private static func previewClipboardPinActions() -> ClipboardPinActions {
        ClipboardPinActions(
            showItem: { _ in },
            showAll: {},
            hideAll: {},
            closeAll: {},
            copyDiagnostics: {}
        )
    }
}
#endif
