import XCTest

final class ToolWorkspaceStateTests: XCTestCase {
    func testToolsViewSurfacesTheThreeStageWorkflow() throws {
        let toolsView = try readSource("Features/Native/Tools/ToolsView.swift")
        let workflowState = try readSource("Features/Native/Tools/ToolWorkspaceState.swift")

        XCTAssertTrue(toolsView.contains("工具工作流"))
        XCTAssertTrue(toolsView.contains("ToolWorkspaceStageRail"))
        XCTAssertTrue(toolsView.contains("ToolStageHeader"))
        XCTAssertTrue(toolsView.contains("selectionSummary"))
        XCTAssertTrue(toolsView.contains("configurationSummary"))
        XCTAssertTrue(toolsView.contains("reviewSummary"))
        XCTAssertTrue(workflowState.contains("enum ToolWorkspaceFlow"))
        XCTAssertTrue(workflowState.contains("static func activeStage"))
        XCTAssertTrue(workflowState.contains("static func selectionSummary"))
        XCTAssertTrue(workflowState.contains("static func configurationSummary"))
        XCTAssertTrue(workflowState.contains("static func reviewSummary"))
    }

    func testToolsViewUsesSharedBackdropAndCardSurfaces() throws {
        let source = try readSource("Features/Native/Tools/ToolsView.swift")

        XCTAssertTrue(source.contains("AppVisualBackdrop()"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"工具概览\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"分类筛选\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"结果区\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"最近使用\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"最近控制\""))
        XCTAssertTrue(source.contains(".background(Color.clear)"))
        XCTAssertFalse(source.contains(".background(AppSurfaceTokens.background)"))
    }

    func testWorkbenchViewShowsProjectNoteArchiveWorkflow() throws {
        let workbenchView = try readSource("Features/Native/Workbench/WorkbenchView.swift")

        XCTAssertTrue(workbenchView.contains("工作流"))
        XCTAssertTrue(workbenchView.contains("项目、笔记、归档分开看"))
        XCTAssertTrue(workbenchView.contains("工作台摘要"))
        XCTAssertTrue(workbenchView.contains("AppVisualBackdrop()"))
        XCTAssertTrue(workbenchView.contains("今日整理"))
        XCTAssertTrue(workbenchView.contains("项目笔记"))
        XCTAssertTrue(workbenchView.contains("Obsidian"))
        XCTAssertTrue(workbenchView.contains("待归档"))
        XCTAssertTrue(workbenchView.contains("工作台摘要"))
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
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"格式概览\""))
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
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"系统摘要\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"进程占用 Top 5\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"状态指示\""))
        XCTAssertFalse(source.contains(".background(AppSurfaceTokens.background.ignoresSafeArea())"))
    }

    func testHomeAndSettingsUseSharedBackdropSurfaces() throws {
        let homeSource = try readSource("Features/Native/Home/WorkspaceHomeView.swift")
        let settingsSource = try readSource("Features/Native/Settings/SettingsView.swift")

        XCTAssertTrue(homeSource.contains(".background(AppVisualBackdrop())"))
        XCTAssertTrue(settingsSource.contains(".background(AppSurfaceTokens.secondarySidebarBackground)"))
        XCTAssertTrue(settingsSource.contains("AppSurfaceCard(title: \"当前分类\""))
        XCTAssertTrue(settingsSource.contains("AppSurfaceCard(title: \"视图状态\""))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
