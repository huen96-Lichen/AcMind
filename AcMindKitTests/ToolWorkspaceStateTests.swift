import XCTest

final class ToolWorkspaceStateTests: XCTestCase {
    func testToolsViewUsesSingleCanvasWorkspace() throws {
        let toolsView = try readSource("Features/Native/Tools/ToolsView.swift")

        XCTAssertTrue(toolsView.contains("headerActions"))
        XCTAssertTrue(toolsView.contains("leadingRailWidth: 0"))
        XCTAssertTrue(toolsView.contains("trailingRailWidth: 0"))
        XCTAssertTrue(toolsView.contains("分类筛选"))
        XCTAssertTrue(toolsView.contains("工具库"))
        XCTAssertTrue(toolsView.contains("最近使用"))
        XCTAssertTrue(toolsView.contains("sortModeMenu"))
        XCTAssertTrue(toolsView.contains("@AppStorage(\"ToolsView.sortMode\")"))
        XCTAssertTrue(toolsView.contains("@AppStorage(\"ToolsView.selectedCategory\")"))
        XCTAssertTrue(toolsView.contains("@AppStorage(\"ToolsView.searchQuery\")"))
        XCTAssertTrue(toolsView.contains("restoreWorkspaceState()"))
        XCTAssertTrue(toolsView.contains("displayedTools"))
        XCTAssertTrue(toolsView.contains("ToolCard(tool: tool, isSelected: viewModel.activeToolRoute == tool.route)"))
        XCTAssertTrue(toolsView.contains("RecentToolsSection("))
    }

    func testToolsViewUsesSharedBackdropAndCardSurfaces() throws {
        let source = try readSource("Features/Native/Tools/ToolsView.swift")

        XCTAssertTrue(source.contains("AppVisualBackdrop()"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"分类筛选\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"工具库\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"最近使用\""))
        XCTAssertTrue(source.contains(".background(Color.clear)"))
        XCTAssertFalse(source.contains(".background(AppSurfaceTokens.background)"))
    }

    func testEveryRegisteredToolRouteHasSheetAndPersistenceMapping() throws {
        let source = try readSource("Features/Native/Tools/ToolsView.swift")
        let routeNames = try toolRouteCaseNames(in: source)

        XCTAssertFalse(routeNames.isEmpty)
        for routeName in routeNames {
            XCTAssertTrue(
                source.contains("route: .\(routeName)"),
                "ToolRoute.\(routeName) should be visible in ToolRegistry.defaultTools"
            )
            XCTAssertTrue(
                source.contains("case .\(routeName):"),
                "ToolRoute.\(routeName) should be handled by id/tool sheet switches"
            )
            XCTAssertTrue(
                source.contains("case \"\(routeName)\": self = .\(routeName)"),
                "ToolRoute.\(routeName) should round-trip through RecentToolsStore"
            )
        }
    }

    func testWorkbenchViewShowsProjectNoteArchiveWorkflow() throws {
        let workbenchView = try readSource("Features/Native/Workbench/WorkbenchView.swift")

        XCTAssertTrue(workbenchView.contains("工作流"))
        XCTAssertTrue(workbenchView.contains("项目、笔记、归档分开看"))
        XCTAssertTrue(workbenchView.contains("工作台总览"))
        XCTAssertTrue(workbenchView.contains("AppVisualBackdrop()"))
        XCTAssertTrue(workbenchView.contains("今日整理"))
        XCTAssertTrue(workbenchView.contains("项目笔记"))
        XCTAssertTrue(workbenchView.contains("Obsidian"))
        XCTAssertTrue(workbenchView.contains("待归档"))
        XCTAssertTrue(workbenchView.contains("工作台总览"))
    }

    func testWebDigestPanelUsesSharedSurfaceCards() throws {
        let source = try readSource("Features/Native/Tools/WebDigestPanel.swift")

        XCTAssertTrue(source.contains("AppVisualBackdrop()"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"轻量网页精读\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"URL 输入\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"Markdown 输出\""))
        XCTAssertTrue(source.contains("defuddle"))
        XCTAssertFalse(source.contains("RoundedRectangle(cornerRadius: 16)"))
    }

    func testAdvancedToolPanelsUseSharedBackdropAndCards() throws {
        let source = try readSource("Features/Native/Tools/ToolAdvancedPanels.swift")

        XCTAssertTrue(source.contains("AppVisualBackdrop()"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"转换流程\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"识别流程\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"处理流程\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"改名流程\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"SRT → FCPXML 转换器\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"内容转换\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"操作\""))
        XCTAssertFalse(source.contains(".background(AppSurfaceTokens.background)"))
    }

    func testCoreToolPanelsUseSharedBackdropAndCards() throws {
        let source = try readSource("Features/Native/Tools/ToolPanels.swift")

        XCTAssertTrue(source.contains("AppVisualBackdrop()"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"格式总览\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"编解码流程\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"整理流程\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"对比流程\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"字幕列表\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"导出操作\""))
        XCTAssertFalse(source.contains(".background(AppSurfaceTokens.background)"))
    }

    func testCompletionToolPanelsUseSharedBackdropAndCards() throws {
        let source = try readSource("Features/Native/Tools/ToolCompletionPanels.swift")

        XCTAssertTrue(source.contains("AppVisualBackdrop()"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"批量下载流程\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"视频下载流程\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"接口测试流程\""))
        XCTAssertTrue(source.contains("WorkspacePageShell("))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"当前状态\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"条目信息\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"详细字段\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"可用操作\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"简介\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"暂无选中项\""))
        XCTAssertFalse(source.contains(".background(AppSurfaceTokens.background)"))
    }

    func testModelManagementPanelUsesDetailSurfaceCards() throws {
        let source = try readSource("Features/Native/Tools/ToolCompletionPanels.swift")

        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"条目信息\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"详细字段\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"可用操作\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"简介\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"暂无选中项\""))
        XCTAssertTrue(source.contains("ModelManagementListRow("))
        XCTAssertTrue(source.contains("WorkspacePageShell("))
    }

    func testToolWorkspacePreviewUsesSharedBackdrop() throws {
        let source = try readSource("Features/Native/Tools/ToolWorkspacePreview.swift")

        XCTAssertTrue(source.contains("AppSurfaceBackdrop()"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"工具台 / 工作台\""))
        XCTAssertTrue(source.contains("ToolsView(viewModel: toolsViewModel)"))
        XCTAssertTrue(source.contains("WorkbenchView(viewModel: workbenchViewModel)"))
        XCTAssertFalse(source.contains("AppSurfaceTokens.background.ignoresSafeArea()"))
    }

    func testWorkbenchViewUsesSharedAcWorkShell() throws {
        let source = try readSource("Features/Native/Workbench/WorkbenchView.swift")

        XCTAssertTrue(source.contains("AcWorkShell("))
        XCTAssertTrue(source.contains("title: \"工作台\""))
        XCTAssertTrue(source.contains("leadingRailWidth: 184"))
        XCTAssertTrue(source.contains("trailingRailWidth: 0"))
        XCTAssertTrue(source.contains("windowWidthOffset: 0"))
        XCTAssertTrue(source.contains("Button(action: { viewModel.presentNewProjectEditor() })"))
        XCTAssertTrue(source.contains("Button(action: { viewModel.presentNewNoteEditor() })"))
    }

    func testSystemStatusViewKeepsBackdropVisible() throws {
        let source = try readSource("Features/Native/SystemStatus/SystemStatusView.swift")

        XCTAssertTrue(source.contains("WorkspacePageShell("))
        XCTAssertTrue(source.contains(".background(Color.clear)"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"系统总览\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"进程占用 Top 5\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"状态指示\""))
        XCTAssertFalse(source.contains(".background(AppSurfaceTokens.background.ignoresSafeArea())"))
    }

    func testHomeAndSettingsUseSharedBackdropSurfaces() throws {
        let homeSource = try readSource("Features/Native/Home/WorkspaceHomeView.swift")
        let settingsSource = try readSource("Features/Native/Settings/SettingsView.swift")
        let appSource = try readSource("App/AcMindApp.swift")

        XCTAssertTrue(homeSource.contains(".background(AppVisualBackdrop())"))
        XCTAssertTrue(settingsSource.contains(".background(AppSurfaceTokens.contentBackground)"))
        XCTAssertTrue(settingsSource.contains("leadingRailWidth: 208"))
        XCTAssertTrue(settingsSource.contains("SettingsNavigationRow("))
        XCTAssertTrue(settingsSource.contains("compactToolbar: true"))
        XCTAssertFalse(settingsSource.contains(".frame(minWidth: AppSurfaceTokens.Layout.minimumWindowWidth"))
        XCTAssertTrue(appSource.contains("minWidth: AppSurfaceTokens.Layout.minimumWindowWidth"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func toolRouteCaseNames(in source: String) throws -> [String] {
        guard let enumStart = source.range(of: "enum ToolRoute:")?.lowerBound,
              let enumEnd = source[enumStart...].range(of: "\nenum ToolCategory")?.lowerBound else {
            return []
        }

        let enumSource = String(source[enumStart..<enumEnd])
        let caseRegex = try NSRegularExpression(pattern: #"^\s*case\s+([A-Za-z0-9_]+)\s*$"#, options: [.anchorsMatchLines])
        let enumRange = NSRange(enumSource.startIndex..<enumSource.endIndex, in: enumSource)
        return caseRegex.matches(in: enumSource, range: enumRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: enumSource) else { return nil }
            return String(enumSource[range])
        }
    }
}
