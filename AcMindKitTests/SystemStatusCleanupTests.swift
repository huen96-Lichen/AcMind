import XCTest

final class SystemStatusCleanupTests: XCTestCase {
    func testDynamicContinentNoLegacyStatusPanels() throws {
        let source = try readSource("Features/Native/DynamicContinent/DynamicContinentConfigView.swift")
        XCTAssertFalse(source.contains("采样通道"))
        XCTAssertFalse(source.contains("权限状态"))
        XCTAssertFalse(source.contains("系统事件"))
        XCTAssertTrue(source.contains("SettingsStatusLabelFormatter.binaryState"))
        XCTAssertTrue(source.contains("enabledText: \"已启用 · 停留"))
    }

    func testDynamicContinentConfigViewUsesLivePreviewSurfaceBlocks() throws {
        let source = try readSource("Features/Native/DynamicContinent/DynamicContinentConfigView.swift")
        XCTAssertTrue(source.contains("配置到预览"))
        XCTAssertTrue(source.contains("previewSurfaceCard("))
        XCTAssertTrue(source.contains("previewStatusStrip"))
        XCTAssertTrue(source.contains("previewContentIDs(for:"))
        XCTAssertTrue(source.contains("硬件提示"))
        XCTAssertTrue(source.contains("statusCard(title:"))
        XCTAssertTrue(source.contains("summaryBlock(title:"))
        XCTAssertTrue(source.contains("AppSurfaceCard(padding: 12)"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"视觉原则\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"展示模块\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"运行时编排\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"热区配置\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(padding: 0)"))
    }

    func testAgentDashboardUsesSharedActivityAndProcessingLabels() throws {
        let source = try readSource("Features/Native/Agent/AgentDashboardView.swift")
        XCTAssertTrue(source.contains("ActivityStateLabelFormatter.activityLabel"))
        XCTAssertTrue(source.contains("ToolStatusLabelFormatter.processingText"))
    }

    func testAgentDashboardUsesCollaborativeWorkspaceSections() throws {
        let source = try readSource("Features/Native/Agent/AgentDashboardView.swift")
        XCTAssertTrue(source.contains("当前协作工作区"))
        XCTAssertTrue(source.contains("当前任务"))
        XCTAssertTrue(source.contains("任务看板"))
        XCTAssertTrue(source.contains("最近结果"))
        XCTAssertTrue(source.contains("错误追溯"))
        XCTAssertTrue(source.contains("对话记录"))
        XCTAssertTrue(source.contains("执行反馈"))
        XCTAssertTrue(source.contains("当前会话"))
        XCTAssertTrue(source.contains("任务面板"))
        XCTAssertTrue(source.contains("待确认问题"))
        XCTAssertTrue(source.contains("权限确认"))
        XCTAssertTrue(source.contains("工具调用结果"))
        XCTAssertTrue(source.contains("追溯收件箱"))
        XCTAssertTrue(source.contains("AgentTraceRenderer.parse"))
        XCTAssertTrue(source.contains("metadataCard(items)"))
        XCTAssertTrue(source.contains("bulletListCard(items)"))
    }

    func testAgentDashboardAppliesPreviewSelectionOnAppear() throws {
        let source = try readSource("Features/Native/Agent/AgentDashboardView.swift")
        XCTAssertTrue(source.contains("previewSidebarSelection"))
        XCTAssertTrue(source.contains(".onAppear {"))
        XCTAssertTrue(source.contains("shouldLoadDashboardData"))
        XCTAssertTrue(source.contains("if shouldLoadDashboardData"))
        XCTAssertTrue(source.contains("if let answer = viewModel.quickAskAnswer"))
        XCTAssertTrue(source.contains("if viewModel.quickAskMessages.isEmpty == false"))
        XCTAssertTrue(source.contains("if viewModel.quickAskQuestion.trimmingCharacters"))
    }

    func testAgentDashboardUsesConversationComposerCard() throws {
        let source = try readSource("Features/Native/Agent/AgentDashboardView.swift")
        XCTAssertTrue(source.contains("ConversationComposerCard("))
        XCTAssertTrue(source.contains("composerStages"))
        XCTAssertTrue(source.contains("composerSuggestions"))
        XCTAssertTrue(source.contains("performComposerPrimaryAction()"))
    }

    func testAgentDashboardUsesSharedCardSurfaces() throws {
        let source = try readSource("Features/Native/Agent/AgentDashboardView.swift")
        XCTAssertTrue(source.contains(".background(AppVisualBackdrop())"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"当前会话\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"任务看板\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"最近结果\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"快捷功能\""))
        XCTAssertFalse(source.contains("cardBackgroundSoft"))
    }

    func testNotchAgentPageUsesComposerStyleQuickAsk() throws {
        let source = try readSource("Features/Companion/NotchV2AgentPage.swift")
        XCTAssertTrue(source.contains("quickAskComposer"))
        XCTAssertTrue(source.contains("notchComposerStage"))
        XCTAssertTrue(source.contains("quickComposerAction"))
        XCTAssertTrue(source.contains("TextEditor(text:"))
        XCTAssertTrue(source.contains("panelBackground.opacity(0.84)"))
        XCTAssertTrue(source.contains("panelBackground.opacity(0.82)"))
        XCTAssertFalse(source.contains("cardBackground.opacity(0.92)"))
    }

    func testSecondarySidebarUsesOptionalSelectionTags() throws {
        let source = try readSource("Components/SecondarySidebar.swift")
        XCTAssertTrue(source.contains("title: section.title"))
        XCTAssertTrue(source.contains("selectedItem = item.id"))
        XCTAssertTrue(source.contains(".buttonStyle(.plain)"))
        XCTAssertFalse(source.contains("List(selection:"))
        XCTAssertFalse(source.contains(".tag(item.id as String?)"))
    }

    func testPrimarySidebarMatchesAcWorkNavigationSections() throws {
        let source = try readSource("Features/Sidebar/SidebarView.swift")
        let appDelegateSource = try readSource("App/AppDelegate.swift")
        let dynamicContinentSource = try readSource("Features/Native/DynamicContinent/DynamicContinentConfigView.swift")
        XCTAssertTrue(source.contains("sidebarSection(title: SidebarItem.Group.coreWorkflow.displayName"))
        XCTAssertTrue(source.contains("sidebarSection(title: SidebarItem.Group.companionCapabilities.displayName"))
        XCTAssertTrue(source.contains("sidebarSection(title: SidebarItem.Group.system.displayName"))
        XCTAssertTrue(source.contains("sidebarBrandHeader"))
        XCTAssertTrue(source.contains("compactChrome"))
        XCTAssertTrue(source.contains("sidebarFooter"))
        XCTAssertTrue(source.contains("SidebarItemRow("))
        XCTAssertTrue(source.contains("SidebarFooterRow(status: footerStatus, isCompact: false)"))
        XCTAssertFalse(source.contains("AppSurfaceCard(title: title, subtitle: subtitle"))
        XCTAssertTrue(appDelegateSource.contains("showPreferredSurface(for: .home)"))
        XCTAssertTrue(dynamicContinentSource.contains("ForEach(SidebarItem.mainItems, id: \\.rawValue)"))
        XCTAssertTrue(dynamicContinentSource.contains("item == .clipboard ? SidebarItem.inbox.displayName : item.displayName"))
        XCTAssertTrue(dynamicContinentSource.contains("return SidebarItem.home.displayName"))
    }

    func testPrimarySidebarSupportsCollapsedNavigationRail() throws {
        let source = try readSource("Features/Sidebar/SidebarView.swift")
        let itemSource = try readSource("AcMindKit/Models/SidebarItem.swift")
        let contentSource = try readSource("App/ContentView.swift")
        let appStateSource = try readSource("App/AppState.swift")
        let appDelegateSource = try readSource("App/AppDelegate.swift")

        XCTAssertTrue(source.contains("if appState.sidebarCollapsed"))
        XCTAssertTrue(source.contains("expandedSidebar"))
        XCTAssertTrue(source.contains("collapsedSidebar"))
        XCTAssertTrue(source.contains("sidebarSection(title:"))
        XCTAssertTrue(source.contains("compactSection(items:"))
        XCTAssertTrue(source.contains("SidebarCompactItemRow("))
        XCTAssertTrue(source.contains("sidebarBrandHeader"))
        XCTAssertTrue(source.contains("sidebarChrome"))
        XCTAssertTrue(source.contains("compactChrome"))
        XCTAssertTrue(source.contains("appState.sidebarCollapsed ? 84 : AppSurfaceTokens.Layout.sidebarWidth"))
        XCTAssertTrue(source.contains("sidebarFooter"))
        XCTAssertTrue(source.contains("compactFooter"))
        XCTAssertTrue(source.contains("SidebarFooterRow(status: footerStatus, isCompact: false)"))
        XCTAssertTrue(source.contains("SidebarFooterRow(status: footerStatus, isCompact: true)"))
        XCTAssertTrue(source.contains("if (isHovered || isSelected), let shortcut = item.shortcut"))
        XCTAssertTrue(itemSource.contains("public var compactName: String"))
        XCTAssertTrue(itemSource.contains("case .clipboard: return \"同步\""))
        XCTAssertTrue(contentSource.contains("appState.sidebarCollapsed ? 84 : AppSurfaceTokens.Layout.sidebarWidth"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"主侧边栏\")"))
        XCTAssertTrue(source.contains(".accessibilitySortPriority(100)"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"\\(item.displayName)\\(isSelected ? \"，当前页面\" : \"\")\")"))
        XCTAssertTrue(source.contains("capabilityState: capabilityState(for: item)"))
        XCTAssertTrue(appStateSource.contains("public func navigate(to item: SidebarItem)"))
        XCTAssertTrue(appStateSource.contains("public func navigateToInbox(workspace selection: String? = \"all\")"))
        XCTAssertTrue(appDelegateSource.contains("appState.navigate(to: .home)"))
        XCTAssertTrue(appDelegateSource.contains("appState.navigate(to: .inbox)"))
        XCTAssertTrue(appDelegateSource.contains("appState.navigate(to: .agent)"))
        XCTAssertTrue(appDelegateSource.contains("appState.navigate(to: .schedule)"))
        XCTAssertTrue(appDelegateSource.contains("appState.navigate(to: .systemStatus)"))
        XCTAssertTrue(appDelegateSource.contains("appState.navigate(to: .settings)"))
    }

    func testAcWorkPreviewScenariosProvideDeterministicInboxStates() throws {
        let sharedSource = try readSource("Features/Native/Shared/WorkspaceSharedComponents.swift")
        let inboxViewSource = try readSource("Features/Native/Inbox/InboxView.swift")
        let inboxViewModelSource = try readSource("App/ViewModels/InboxViewModel.swift")
        let captureWorkspaceSource = try readSource("Features/Native/Shared/CaptureWorkspaceView.swift")

        XCTAssertTrue(sharedSource.contains("enum AcWorkPreviewScenario"))
        XCTAssertTrue(sharedSource.contains("case populated"))
        XCTAssertTrue(sharedSource.contains("case loading"))
        XCTAssertTrue(sharedSource.contains("case empty"))
        XCTAssertTrue(sharedSource.contains("case error"))
        XCTAssertTrue(sharedSource.contains("--acwork-preview="))
        XCTAssertTrue(sharedSource.contains("AcWorkHomePreviewSnapshot"))
        XCTAssertTrue(sharedSource.contains("static let fixedNow"))
        XCTAssertTrue(sharedSource.contains("acwork-preview-voice-standup"))
        XCTAssertTrue(sharedSource.contains("acwork-preview-clipboard-link"))
        XCTAssertTrue(sharedSource.contains("acwork-preview-phone-richtext"))
        XCTAssertTrue(sharedSource.contains("acwork-preview-screenshot-ocr"))
        XCTAssertTrue(sharedSource.contains("acwork-preview-agent-code"))
        XCTAssertTrue(sharedSource.contains("acwork-preview-manual-file"))
        XCTAssertTrue(sharedSource.contains("acwork-preview-video-reference"))

        XCTAssertTrue(inboxViewModelSource.contains("final class InboxCollectedItemRepository"))
        XCTAssertTrue(inboxViewModelSource.contains("private let previewScenario: AcWorkPreviewScenario?"))
        XCTAssertTrue(inboxViewModelSource.contains(".map(CollectedItem.init(sourceItem:))"))
        XCTAssertTrue(inboxViewModelSource.contains("AcWork Preview: 收集箱加载失败"))
        XCTAssertTrue(inboxViewSource.contains("previewScenario: AcWorkPreviewScenario? = AcWorkPreviewScenario.fromProcessArguments()"))
        XCTAssertTrue(inboxViewSource.contains("@StateObject private var viewModel: CollectedInboxViewModel"))
        XCTAssertTrue(inboxViewSource.contains("InboxCollectedItemRepository(previewScenario: previewScenario)"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.phase == .loading"))
        XCTAssertTrue(inboxViewSource.contains("errorState(message: errorMessage)"))
        XCTAssertTrue(captureWorkspaceSource.contains("previewScenario: AcWorkPreviewScenario? = AcWorkPreviewScenario.fromProcessArguments()"))
        XCTAssertTrue(captureWorkspaceSource.contains("InboxView("))
        XCTAssertTrue(captureWorkspaceSource.contains("clipboardPinActions: clipboardPinActions"))
        XCTAssertTrue(captureWorkspaceSource.contains("previewScenario: previewScenario"))
    }

    func testInboxViewUsesNativeCollectedItemCardsAndActions() throws {
        let inboxViewSource = try readSource("Features/Native/Inbox/InboxView.swift")
        let viewModelSource = try readSource("AcMindKit/Protocols/StorageServiceProtocol.swift")
        let shellSource = try readSource("Features/Native/Shared/AppSurfaceStyle.swift")

        XCTAssertTrue(inboxViewSource.contains("CollectedInboxItemCard("))
        XCTAssertTrue(inboxViewSource.contains("presentation: .list"))
        XCTAssertTrue(inboxViewSource.contains("presentation: .grid"))
        XCTAssertTrue(inboxViewSource.contains("density: viewModel.density"))
        XCTAssertTrue(inboxViewSource.contains("minHeight: density.rowHeight, maxHeight: density.rowHeight"))
        XCTAssertTrue(inboxViewSource.contains("minHeight: 188, maxHeight: 188"))
        XCTAssertTrue(inboxViewSource.contains(".flexible(minimum: 240, maximum: 300)"))
        XCTAssertTrue(inboxViewSource.contains("minimumColumnWidth: 240"))
        XCTAssertTrue(inboxViewSource.contains(".accessibilityHint(\"按 Return 或 Space 打开预览，按 Delete 删除。\")"))
        XCTAssertTrue(inboxViewSource.contains("Label(item.processingStatus.displayName, systemImage: item.processingStatus.accessibilityIconName)"))
        XCTAssertTrue(inboxViewSource.contains(".accessibilityLabel(\"状态：\\(item.processingStatus.displayName)\""))
        XCTAssertTrue(inboxViewSource.contains(".accessibilityLabel(\"清除搜索\")"))
        XCTAssertTrue(inboxViewSource.contains(".accessibilityHidden(true)"))
        XCTAssertTrue(inboxViewSource.contains("parts.append(\"已 Pin\")"))
        XCTAssertTrue(inboxViewSource.contains("parts.append(\"已收藏\")"))
        XCTAssertTrue(inboxViewSource.contains("parts.append(\"已加入批量选择\")"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.setViewMode(mode)"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.setDensity("))
        XCTAssertTrue(inboxViewSource.contains("headerActions: AnyView(addContentMenu)"))
        XCTAssertTrue(inboxViewSource.contains("Label(\"添加内容\", systemImage: \"plus\")"))
        XCTAssertTrue(inboxViewSource.contains(".companionShowQuickNote"))
        XCTAssertTrue(inboxViewSource.contains(".companionShowCapturePanel"))
        XCTAssertTrue(inboxViewSource.contains(".companionShowVoicePanel"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.filterState.sources.contains(.clipboard)"))
        XCTAssertTrue(inboxViewSource.contains("clipboardMonitoringControl"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.toggleClipboardMonitoring()"))
        XCTAssertFalse(inboxViewSource.contains("startWatching()"))
        XCTAssertTrue(inboxViewSource.contains(".keyboardShortcut(\"f\", modifiers: .command)"))
        XCTAssertTrue(inboxViewSource.contains(".focused($focusTarget, equals: .search)"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.cancelPendingTasks()"))
        XCTAssertTrue(inboxViewSource.contains("refreshTask?.cancel()"))
        XCTAssertTrue(inboxViewSource.contains("phase: .empty("))
        XCTAssertTrue(inboxViewSource.contains("phase: .failed(title: \"收集箱加载失败\""))
        XCTAssertTrue(inboxViewSource.contains("StateContainer("))
        XCTAssertTrue(inboxViewSource.contains("CollectedInboxFilterRail("))
        XCTAssertTrue(inboxViewSource.contains("items: viewModel.allItems"))
        XCTAssertTrue(inboxViewSource.contains("badge: \"\\(items.filter"))
        XCTAssertTrue(inboxViewSource.contains("ForEach(InboxQuickFilter.allCases"))
        XCTAssertTrue(inboxViewSource.contains("private let sourceFilters: [CollectionSource]"))
        XCTAssertTrue(inboxViewSource.contains("private let contentTypeFilters: [CollectedContentType]"))
        XCTAssertTrue(inboxViewSource.contains("private let statusFilters: [ProcessingStatus]"))
        XCTAssertFalse(inboxViewSource.contains("SecondarySidebarWithHeader("))
        XCTAssertFalse(inboxViewSource.contains("clipboardWorkspace"))
        XCTAssertTrue(inboxViewSource.contains("CollectedInboxInspector("))
        XCTAssertTrue(inboxViewSource.contains("private struct CollectedInboxInspector"))
        XCTAssertTrue(inboxViewSource.contains("summaryInspector"))
        XCTAssertTrue(inboxViewSource.contains("selectedInspector(for item: CollectedItem)"))
        XCTAssertTrue(inboxViewSource.contains("fixedActionFooter(for item: CollectedItem)"))
        XCTAssertTrue(inboxViewSource.contains("保存到知识库"))
        XCTAssertTrue(inboxViewSource.contains("导出 Markdown"))
        XCTAssertTrue(inboxViewSource.contains("@StateObject private var workflowCoordinator: CollectedItemWorkflowCoordinator"))
        XCTAssertTrue(inboxViewSource.contains("onWorkflow: performWorkflow"))
        XCTAssertTrue(inboxViewSource.contains("performBatchWorkflow(.sendToAgent)"))
        XCTAssertTrue(inboxViewSource.contains("performBatchWorkflow(.createTask)"))
        XCTAssertTrue(inboxViewSource.contains("performBatchWorkflow(.createSchedule)"))
        XCTAssertTrue(inboxViewSource.contains("performBatchWorkflow(.exportMarkdown)"))
        XCTAssertTrue(inboxViewSource.contains("CollectedInboxWorkflowFeedbackBanner("))
        XCTAssertTrue(inboxViewSource.contains("onAI: performAI"))
        XCTAssertTrue(inboxViewSource.contains("workflowCoordinator.performAI(action, item: item)"))
        XCTAssertTrue(inboxViewSource.contains("aiAction(\"自动标题\""))
        XCTAssertTrue(inboxViewSource.contains("aiAction(\"摘要\""))
        XCTAssertTrue(inboxViewSource.contains("aiAction(\"提取待办\""))
        XCTAssertTrue(inboxViewSource.contains("aiAction(\"提取日程\""))
        XCTAssertTrue(inboxViewSource.contains("aiAction(\"润色\""))
        XCTAssertTrue(inboxViewSource.contains("activeAIAction == action ? \"\\(title)处理中…\""))
        XCTAssertFalse(inboxViewSource.contains("inspectorAction(\"自动标题\", icon: \"textformat.size\", isEnabled: false)"))
        XCTAssertFalse(inboxViewSource.contains("inspectorAction(\"摘要\", icon: \"sparkles\", isEnabled: false)"))
        XCTAssertFalse(inboxViewSource.contains("inspectorAction(\"转任务\", icon: \"checkmark.square\", isEnabled: false)"))
        XCTAssertFalse(inboxViewSource.contains("inspectorAction(\"导出 Markdown\", icon: \"doc.plaintext\", isEnabled: false)"))
        XCTAssertTrue(inboxViewSource.contains("CollectedInboxBatchActionBar("))
        XCTAssertTrue(inboxViewSource.contains("private struct CollectedInboxBatchActionBar"))
        XCTAssertTrue(inboxViewSource.contains("CollectedInboxBatchTagEditor("))
        XCTAssertTrue(inboxViewSource.contains("viewModel.applyTagsToBatchSelection(tags)"))
        XCTAssertTrue(inboxViewSource.contains("CollectedInboxPasteQueuePanel("))
        XCTAssertTrue(inboxViewSource.contains("viewModel.pasteQueueItems.count"))
        XCTAssertTrue(inboxViewSource.contains("onShowAllPins: clipboardPinActions.showAll"))
        XCTAssertTrue(inboxViewSource.contains("onHideAllPins: clipboardPinActions.hideAll"))
        XCTAssertTrue(inboxViewSource.contains("onCloseAllPins: clipboardPinActions.closeAll"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.reorderPasteQueue"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.removePasteQueueItem"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.clearPasteQueue"))
        XCTAssertTrue(inboxViewSource.contains("await viewModel.pasteNextInQueue()"))
        XCTAssertFalse(inboxViewSource.contains("batchButton(\"添加标签\", icon: \"tag\", isEnabled: false)"))
        XCTAssertTrue(inboxViewSource.contains("@State private var showBatchDeleteConfirmation = false"))
        XCTAssertTrue(inboxViewSource.contains(".alert(\"确认删除批量选择？\""))
        XCTAssertTrue(inboxViewSource.contains("Button(\"删除 \\(viewModel.selectedItemIDs.count) 项\", role: .destructive)"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.archiveBatchSelection()"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.deleteBatchSelection()"))
        XCTAssertTrue(inboxViewSource.contains("viewModel.enqueueBatchSelectionForPaste()"))
        XCTAssertTrue(inboxViewSource.contains("CollectedInboxBatchResultBanner("))
        XCTAssertTrue(inboxViewSource.contains("private struct CollectedInboxBatchResultBanner"))
        XCTAssertTrue(inboxViewSource.contains("result.failureCount"))
        XCTAssertTrue(inboxViewSource.contains("失败项已保留选择"))
        XCTAssertTrue(inboxViewSource.contains(".onKeyPress(.upArrow)"))
        XCTAssertTrue(inboxViewSource.contains(".onKeyPress(.downArrow)"))
        XCTAssertTrue(inboxViewSource.contains(".onKeyPress(.space)"))
        XCTAssertTrue(inboxViewSource.contains(".onKeyPress(.return)"))
        XCTAssertTrue(inboxViewSource.contains(".onKeyPress(.delete)"))
        XCTAssertTrue(inboxViewSource.contains(".onKeyPress(.escape)"))
        XCTAssertTrue(inboxViewSource.contains("CollectedInboxQuickPreview("))
        XCTAssertTrue(inboxViewSource.contains(".alert(\"确认删除当前内容？\""))
        XCTAssertTrue(inboxViewSource.contains("usesResponsiveInspector: true"))
        XCTAssertTrue(inboxViewSource.contains("compactInspectorTitle: \"收集详情\""))
        XCTAssertTrue(shellSource.contains("AcWorkResponsiveLayout.inspectorPresentation("))
        XCTAssertTrue(shellSource.contains("usesCompactInspector"))
        XCTAssertTrue(shellSource.contains(".sheet(isPresented: $showsCompactInspector)"))
        XCTAssertTrue(shellSource.contains("Label(compactInspectorTitle, systemImage: \"sidebar.right\")"))
        XCTAssertTrue(inboxViewSource.contains("private final class CollectedItemThumbnailCache"))
        XCTAssertTrue(inboxViewSource.contains("NSCache<NSString, NSImage>"))
        XCTAssertTrue(inboxViewSource.contains("private struct CollectedItemThumbnailView"))
        XCTAssertTrue(inboxViewSource.contains("QLThumbnailGenerator.shared.generateBestRepresentation"))
        XCTAssertTrue(inboxViewSource.contains("store.loadImage(asset: asset, maxPixelSize: maxPixelSize)"))
        XCTAssertTrue(inboxViewSource.contains("CollectedItemThumbnailView(item: item, height: 56"))
        XCTAssertTrue(inboxViewSource.contains("CollectedItemThumbnailView(item: item, height: 180"))
        XCTAssertTrue(inboxViewSource.contains("CollectedItemThumbnailView(item: item, height: 260"))
        XCTAssertTrue(inboxViewSource.contains("var thumbnailCacheKey: String?"))
        XCTAssertTrue(inboxViewSource.contains("private final class CollectedLinkIconCache"))
        XCTAssertTrue(inboxViewSource.contains("private struct CollectedLinkSiteIconView"))
        XCTAssertTrue(inboxViewSource.contains("components.path = \"/favicon.ico\""))
        XCTAssertTrue(inboxViewSource.contains("request.timeoutInterval = 4"))
        XCTAssertTrue(inboxViewSource.contains("data.count <= 1_000_000"))
        XCTAssertTrue(inboxViewSource.contains("private struct CollectedItemFileSizeView"))
        XCTAssertTrue(inboxViewSource.contains("item.metadata[\"fileSize\"]"))
        XCTAssertTrue(inboxViewSource.contains("resourceValues(forKeys: [.fileSizeKey])"))
        XCTAssertTrue(inboxViewSource.contains("asset.fileSize"))
        XCTAssertTrue(inboxViewSource.contains("await viewModel.pin(item.id)"))
        XCTAssertTrue(inboxViewSource.contains("await viewModel.setFavorite(item.id"))
        XCTAssertTrue(inboxViewSource.contains("await viewModel.archive(item.id)"))
        XCTAssertTrue(inboxViewSource.contains("await viewModel.delete(item.id)"))
        XCTAssertTrue(inboxViewSource.contains("await viewModel.saveClipboardItemToInbox(item.id)"))
        XCTAssertTrue(viewModelSource.contains("public func pin(_ id: CollectedItemID) async"))
        XCTAssertTrue(viewModelSource.contains("public func setFavorite(_ id: CollectedItemID, isFavorite: Bool) async"))
        XCTAssertTrue(viewModelSource.contains("public func archive(_ id: CollectedItemID) async"))
        XCTAssertTrue(viewModelSource.contains("public func saveClipboardItemToInbox(_ id: CollectedItemID) async"))
        XCTAssertTrue(viewModelSource.contains("public func archiveBatchSelection() async"))
        XCTAssertTrue(viewModelSource.contains("public func enqueueBatchSelectionForPaste()"))
        XCTAssertTrue(viewModelSource.contains("public struct CollectedInboxBatchOperationResult"))
        XCTAssertTrue(viewModelSource.contains("@Published public private(set) var lastBatchOperationResult"))
        XCTAssertTrue(viewModelSource.contains("private func performBatchOperation"))
        XCTAssertTrue(viewModelSource.contains("public enum CollectedInboxSelectionMovement"))
        XCTAssertTrue(viewModelSource.contains("public func moveSelection(_ movement: CollectedInboxSelectionMovement)"))
        XCTAssertTrue(viewModelSource.contains("@Published public private(set) var clipboardMonitoringState"))
        XCTAssertTrue(viewModelSource.contains("public func toggleClipboardMonitoring() async"))
        XCTAssertTrue(viewModelSource.contains("private var refreshRevision: UInt = 0"))
        XCTAssertTrue(viewModelSource.contains("public func cancelPendingTasks()"))
    }

    func testNotchTopBarUsesUnifiedStatusPills() throws {
        let source = try readSource("Features/Companion/NotchV2TopBar.swift")
        XCTAssertTrue(source.contains("topNavPill(title:"))
        XCTAssertTrue(source.contains("statusPill(icon:"))
        XCTAssertTrue(source.contains("NotchV2StatusPill("))
        XCTAssertTrue(source.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(source.contains("compactRightStatus"))
        XCTAssertTrue(source.contains("Button(\"进入状态页\")"))
        XCTAssertTrue(source.contains("openSettingsWindow()"))
        XCTAssertFalse(source.contains("perform(Selector((\"showSettings\"))"))
        XCTAssertFalse(source.contains("collapseButton"))
        XCTAssertFalse(source.contains("private func topNavButton"))
    }

    func testAgentPreviewWindowCanSwitchTraceModes() throws {
        let source = try readSource("App/AppDelegate.swift")
        XCTAssertTrue(source.contains("previewSelection = \"quickAsk\""))
        XCTAssertTrue(source.contains("--agent-preview-tool-call"))
        XCTAssertTrue(source.contains("--agent-preview-automation"))
        XCTAssertTrue(source.contains("previewSidebarSelection"))
        XCTAssertTrue(source.contains("shouldLoadDashboardData: false"))
    }

    func testAgentViewModelLoadsTaskBoardWithDashboardData() throws {
        let source = try readSource("App/ViewModels/AgentViewModel.swift")
        XCTAssertTrue(source.contains("async let taskBoardTask = loadAgentTasks(filter: nil)"))
        XCTAssertTrue(source.contains("var taskBoardSummary"))
        XCTAssertTrue(source.contains("var currentWorkSummary"))
        XCTAssertTrue(source.contains("var recentTaskSummaries"))
        XCTAssertTrue(source.contains("provider: openai"))
        XCTAssertTrue(source.contains("- 已读取 2 条素材"))
    }

    func testVoiceEntryOnlyKeepsStatusEntry() throws {
        let source = try readSource("Features/Native/VoiceEntry/VoiceEntryView.swift")
        XCTAssertFalse(source.contains("权限状态"))
        XCTAssertTrue(source.contains("查看状态"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"关键摘要\""))
        XCTAssertTrue(source.contains("SectionHeader("))
        XCTAssertTrue(source.contains("MetricCard("))
    }

    func testSettingsViewsOnlyKeepStatusJump() throws {
        let suiteSource = try readSource("Features/Native/Settings/SettingsSuiteView.swift")
        let viewSource = try readSource("Features/Native/Settings/SettingsView.swift")

        XCTAssertFalse(suiteSource.contains("诊断信息"))
        XCTAssertTrue(suiteSource.contains("查看状态"))
        XCTAssertFalse(viewSource.contains("诊断信息"))
        XCTAssertTrue(viewSource.contains("查看状态"))
    }

    func testSettingsViewUsesSharedWorkspaceComponents() throws {
        let source = try readSource("Features/Native/Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("SectionHeader("))
        XCTAssertTrue(source.contains("MetricCard("))
        XCTAssertTrue(source.contains("StateContainer("))
        XCTAssertTrue(source.contains("StatusBadge(text:"))
        XCTAssertTrue(source.contains("scrollContentBackground(.hidden)"))
        XCTAssertTrue(source.contains("listRowBackground(Color.clear)"))
        XCTAssertFalse(source.contains("struct StatusBadge"))
    }

    func testSettingsViewSurfacesSearchResultsAndLivePreviewPanels() throws {
        let source = try readSource("Features/Native/Settings/SettingsView.swift")
        XCTAssertTrue(source.contains("settingsSearchResultsPanel"))
        XCTAssertTrue(source.contains("settingsLivePreviewPanel"))
        XCTAssertTrue(source.contains("onChange(of: settingsSearchQuery)"))
        XCTAssertTrue(source.contains("SettingsSearchCatalog"))
        XCTAssertTrue(source.contains("LivePreviewPanel"))
        XCTAssertTrue(source.contains("自动采集"))
        XCTAssertTrue(source.contains("截图权限"))
    }

    func testClipboardViewUsesSharedBackdropAndSidebarCards() throws {
        let source = try readSource("Features/Native/Clipboard/ClipboardView.swift")
        XCTAssertTrue(source.contains(".background(AppVisualBackdrop())"))
        XCTAssertTrue(source.contains("clipboardSummaryRail"))
        XCTAssertTrue(source.contains("pinQuickAction"))
        XCTAssertTrue(source.contains("PasteQueuePanel(viewModel: viewModel)"))
        XCTAssertFalse(source.contains(".background(AppSurfaceTokens.background)"))
    }

    func testWorkspaceSharedComponentsUseSharedBackdropAndCardSurfaces() throws {
        let source = try readSource("Features/Native/Shared/WorkspaceSharedComponents.swift")
        XCTAssertTrue(source.contains("AppVisualBackdrop()"))
        XCTAssertTrue(source.contains("StatusBadge(text:"))
        XCTAssertTrue(source.contains("StateContainer("))
        XCTAssertFalse(source.contains(".background(AppSurfaceTokens.background.ignoresSafeArea())"))
    }

    func testSettingsPreviewWindowSupportsDebugLaunchers() throws {
        let source = try readSource("App/AppDelegate.swift")
        XCTAssertTrue(source.contains("--settings-preview"))
        XCTAssertTrue(source.contains("--settings-preview-narrow"))
        XCTAssertTrue(source.contains("--settings-preview-export="))
        XCTAssertTrue(source.contains("showSettingsPreviewWindow()"))
        XCTAssertTrue(source.contains("SettingsView("))
        XCTAssertTrue(source.contains("initialSearchQuery: \"权限\""))
    }

    func testScheduleDashboardUsesSharedCardShells() throws {
        let source = try readSource("Features/Native/Schedule/ScheduleDashboardView.swift")
        XCTAssertTrue(source.contains("AppVisualBackdrop()"))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"今日日程\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"时间线\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"时间锚点\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"今日统计\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"周视图\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"本周事件\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"月视图\""))
        XCTAssertTrue(source.contains("AppSurfaceCard(title: \"本月事件\""))
        XCTAssertFalse(source.contains("background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))"))
    }

    func testMainWindowPrunesPlaceholderAcMindWindows() throws {
        let source = try readSource("App/AppDelegate.swift")
        XCTAssertTrue(source.contains("prunePlaceholderWindows()"))
        XCTAssertTrue(source.contains("schedulePlaceholderWindowPrune()"))
        XCTAssertTrue(source.contains("applicationDidBecomeActive"))
        XCTAssertTrue(source.contains("ensureVisibleOnScreenIfNeeded()"))
        XCTAssertTrue(source.contains("NSEvent.mouseLocation"))
        XCTAssertTrue(source.contains("NSScreen.screens.first(where:"))
        XCTAssertTrue(source.contains("title.isEmpty && isSmallLaunchShell"))
        XCTAssertTrue(source.contains("title == \"AcMind\" && isSmallLaunchShell"))
        XCTAssertTrue(source.contains("(title.isEmpty || title == \"AcMind\") && isThinPlaceholder"))
        XCTAssertTrue(source.contains("AXUIElementCreateApplication"))
        XCTAssertTrue(source.contains("kAXWindowsAttribute"))
        XCTAssertTrue(source.contains("kAXCloseButtonAttribute"))
        XCTAssertTrue(source.contains("kAXPressAction"))
        XCTAssertTrue(source.contains("window.frame.width <= 520 && window.frame.height <= 420"))
        XCTAssertTrue(source.contains("window.frame.width >= 800 && window.frame.height <= 120"))
    }

    func testAppEntryUsesRealSettingsScene() throws {
        let source = try readSource("App/AcMindApp.swift")
        XCTAssertTrue(source.contains("Settings {"))
        XCTAssertTrue(source.contains("SettingsView(initialCategory: .general)"))
        XCTAssertFalse(source.contains("WindowGroup {"))
    }

    func testCompanionVoicePanelSupportsEditableDraftAndStageFlow() throws {
        let source = try readSource("Features/Companion/CompanionVoicePanel.swift")
        XCTAssertTrue(source.contains("stageStrip"))
        XCTAssertTrue(source.contains("TextEditor(text:"))
        XCTAssertTrue(source.contains("editableText"))
        XCTAssertTrue(source.contains("准备就绪"))
        XCTAssertTrue(source.contains("开始说话"))
        XCTAssertTrue(source.contains("复制修正版"))
        XCTAssertTrue(source.contains("恢复原文"))
        XCTAssertTrue(source.contains("SayInputPresentationLabelFormatter.processingText"))
    }

    func testNotchSummaryRailIsLightweight() throws {
        let source = try readSource("Features/Companion/NotchV2SystemStatusRail.swift")
        XCTAssertTrue(source.contains("NotchV2StatusPill"))
        XCTAssertTrue(source.contains("NotchV2InfoRow"))
        XCTAssertTrue(source.contains("查看状态"))
        XCTAssertFalse(source.contains("BatteryService"))
        XCTAssertFalse(source.contains("PermissionManager"))
    }

    func testNotchOverviewUsesAdaptiveActionTiles() throws {
        let source = try readSource("Features/Companion/NotchV2OverviewPage.swift")
        let cardSource = try readSource("Features/Companion/NotchV2Card.swift")
        let viewModelSource = try readSource("Features/Companion/NotchV2ViewModel.swift")

        XCTAssertTrue(source.contains("GridItem(.adaptive(minimum: 92, maximum: 132)"))
        XCTAssertTrue(cardSource.contains("struct NotchV2ActionButton"))
        XCTAssertTrue(cardSource.contains("let accent: Color"))
        XCTAssertTrue(cardSource.contains("RoundedRectangle(cornerRadius: 13"))
        XCTAssertTrue(viewModelSource.contains("NotchV2StatusPill("))
        XCTAssertTrue(viewModelSource.contains("openStatusAction"))
        XCTAssertFalse(viewModelSource.contains("Button(\"查看状态\")"))
    }

    func testNotchPagesUseSharedInfoRows() throws {
        let overviewSource = try readSource("Features/Companion/NotchV2OverviewPage.swift")
        let musicSource = try readSource("Features/Companion/NotchV2MusicPage.swift")
        let dynamicSource = try readSource("Features/Companion/DynamicContinent/DynamicContinentPages.swift")

        XCTAssertTrue(overviewSource.contains("NotchV2InfoRow("))
        XCTAssertTrue(musicSource.contains("NotchV2InfoRow("))
        XCTAssertTrue(dynamicSource.contains("NotchV2InfoRow("))
        XCTAssertFalse(overviewSource.contains("compactRow(label:"))
        XCTAssertFalse(musicSource.contains("compactRow(label:"))
    }

    func testShowSystemStatusRoutesToSystemStatusSelection() throws {
        let source = try readSource("App/AppDelegate.swift")
        XCTAssertTrue(source.contains("case .systemStatus:"))
        XCTAssertTrue(source.contains("appState.navigate(to: .systemStatus)"))
        XCTAssertTrue(source.contains("@objc func showSystemStatus()"))
    }

    func testNotchSystemStatusPageIsAlwaysSelectable() throws {
        let source = try readSource("Features/Companion/NotchV2ViewModel.swift")
        XCTAssertTrue(source.contains("func openSystemStatusPage()"))
        XCTAssertTrue(source.contains("case .systemStatus:"))
        XCTAssertTrue(source.contains("return true"))
    }

    func testNotchAttentionHintOpensCompanionStatusPageDirectly() throws {
        let source = try readSource("Features/Companion/NotchV2ViewModel.swift")
        XCTAssertTrue(source.contains("openSystemStatusPage()"))
    }

    func testAppSurfaceCardSupportsVerticalStretching() throws {
        let source = try readSource("Features/Native/Shared/AppSurfaceStyle.swift")
        XCTAssertTrue(source.contains("let fillHeight: Bool"))
        XCTAssertTrue(source.contains("frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil"))
    }

    func testSharedWorkspaceComponentsExposeFoundationContracts() throws {
        let source = try readSource("Features/Native/Shared/WorkspaceSharedComponents.swift")
        XCTAssertTrue(source.contains("struct SectionHeaderAction"))
        XCTAssertTrue(source.contains("struct SectionHeader"))
        XCTAssertTrue(source.contains("enum StatusBadgeTone"))
        XCTAssertTrue(source.contains("struct StatusBadge"))
        XCTAssertTrue(source.contains("struct MetricCard"))
        XCTAssertTrue(source.contains("struct StateContainer"))
        XCTAssertTrue(source.contains("#Preview(\"Shared Components / Wide\")"))
        XCTAssertTrue(source.contains("#Preview(\"Shared Components / Narrow\")"))
    }

    func testProductPanelFoundationIsolatedFromLegacyTokens() throws {
        let source = try readSource("Design/AcMindDesignTokens.swift")
        let productPanelRangeStart = try XCTUnwrap(source.range(of: "// MARK: - Product Panel Tokens"))
        let productPanelSource = String(source[productPanelRangeStart.lowerBound...])

        XCTAssertTrue(productPanelSource.contains("enum ProductPanelTokens"))
        XCTAssertTrue(productPanelSource.contains("enum ProductPanelCardVariant"))
        XCTAssertTrue(productPanelSource.contains("enum ProductPanelStatusTone"))
        XCTAssertTrue(productPanelSource.contains("struct ProductPanelCard"))
        XCTAssertTrue(productPanelSource.contains("static let defaultWidth: CGFloat = 1160"))
        XCTAssertTrue(productPanelSource.contains("static let narrowWidth: CGFloat = 760"))
        XCTAssertTrue(productPanelSource.contains("#Preview(\"Product Panel / Wide\")"))
        XCTAssertTrue(productPanelSource.contains("#Preview(\"Product Panel / Narrow\")"))
        XCTAssertFalse(productPanelSource.contains("ProductPanelTokens.background ="))
        XCTAssertFalse(productPanelSource.contains("AppSurfaceTokens"))
    }

    func testSystemStatusViewUsesSharedBackgroundAndSnapshotDriven() throws {
        let source = try readSource("Features/Native/SystemStatus/SystemStatusView.swift")
        XCTAssertTrue(source.contains(".background(Color.clear)"))
        XCTAssertFalse(source.contains("BatteryService.shared"))
        XCTAssertTrue(source.contains("private let permissionManager: PermissionManager"))
        XCTAssertTrue(source.contains("PermissionStatusCard(permission: permission)"))
        XCTAssertTrue(source.contains("permissionManager.openSettingsFor(kind)"))
        XCTAssertTrue(source.contains("permissionManager.openPrivacySettings()"))
        XCTAssertTrue(source.contains("SectionHeader("))
        XCTAssertTrue(source.contains("MetricCard("))
        XCTAssertTrue(source.contains("StateContainer("))
        XCTAssertTrue(source.contains("StatusBadge("))
        XCTAssertTrue(source.contains("unavailableReasons"))
        XCTAssertTrue(source.contains("健康摘要"))
        XCTAssertTrue(source.contains("诊断区"))
        XCTAssertTrue(source.contains("权限与能力"))
    }

    func testMainContentRoutesHomeToTheWorkspaceDashboard() throws {
        let source = try readSource("App/ContentView.swift")
        XCTAssertTrue(source.contains("case .home:"))
        XCTAssertTrue(source.contains("WorkspaceHomeView("))
        XCTAssertTrue(source.contains("systemStatusService: serviceContainer.systemStatusService"))
        XCTAssertTrue(source.contains("permissionManager: serviceContainer.permissionManager"))
        XCTAssertTrue(source.contains("case .systemStatus:"))
        XCTAssertTrue(source.contains("SystemStatusView("))
        XCTAssertTrue(source.contains("case .inbox:"))
        XCTAssertTrue(source.contains("InboxView(clipboardPinActions: clipboardPinActions)"))
        XCTAssertTrue(source.contains("case .clipboard:"))
        XCTAssertFalse(source.contains("CaptureWorkspaceView(mode:"))
    }

    func testContentViewUsesSharedSidebarView() throws {
        let source = try readSource("App/ContentView.swift")
        XCTAssertTrue(source.contains("SidebarView()"))
        XCTAssertFalse(source.contains("MainSidebar("))
        XCTAssertFalse(source.contains("struct MainSidebar"))
        XCTAssertFalse(source.contains("struct SidebarItemView"))
    }

    func testMainNavigationShortcutsLiveInNavigationCommandMenu() throws {
        let appSource = try readSource("App/AcMindApp.swift")
        let itemSource = try readSource("AcMindKit/Models/SidebarItem.swift")

        XCTAssertTrue(appSource.contains("CommandMenu(\"导航\")"))
        XCTAssertTrue(appSource.contains("ForEach(SidebarItem.shortcutItems)"))
        XCTAssertTrue(appSource.contains("Button(item.commandTitle) { navigate(to: item) }"))
        XCTAssertTrue(appSource.contains(".keyboardShortcut("))
        XCTAssertTrue(appSource.contains("private func navigate(to item: SidebarItem)"))
        XCTAssertTrue(itemSource.contains("public var commandTitle: String"))
        XCTAssertTrue(itemSource.contains("case .home: return \"前往工作台\""))
        XCTAssertTrue(itemSource.contains("case .settings: return \"前往设置\""))
    }

    func testAppStateKeepsInboxSelectionCanonical() throws {
        let source = try readSource("App/AppState.swift")
        XCTAssertTrue(source.contains("public func canonicalSidebarItem(for item: SidebarItem) -> SidebarItem"))
        XCTAssertTrue(source.contains("item == .clipboard ? .inbox : item"))
        XCTAssertTrue(source.contains("public func navigate(to item: SidebarItem)"))
        XCTAssertTrue(source.contains("public func navigateToInbox(workspace selection: String? = \"all\")"))
        XCTAssertTrue(source.contains("selectInboxWorkspace(selection)"))
        XCTAssertTrue(source.contains("sidebarSelection = canonicalSidebarItem(for: item)"))
        XCTAssertTrue(source.contains("public func selectInboxWorkspace(_ selection: String?)"))
    }

    func testMainWindowUsesAcWorkDefaultAndMinimumSizes() throws {
        let appDelegate = try readSource("App/AppDelegate.swift")
        let contentView = try readSource("App/ContentView.swift")
        XCTAssertTrue(appDelegate.contains("width: 1500, height: 920"))
        XCTAssertTrue(appDelegate.contains("NSSize(width: 1180, height: 720)"))
        XCTAssertTrue(appDelegate.contains("window.contentMinSize = AppWindowGeometry.minimumContentSize"))
        XCTAssertTrue(appDelegate.contains("AppWindowGeometry.clampedContentSize(for: currentSize)"))
        XCTAssertTrue(appDelegate.contains("max(contentSize.width, minimumContentSize.width)"))
        XCTAssertTrue(appDelegate.contains("max(contentSize.height, minimumContentSize.height)"))
        XCTAssertTrue(contentView.contains("AppWindowGeometry.minimumContentSize.width"))
        XCTAssertTrue(contentView.contains("AppWindowGeometry.minimumContentSize.height"))
        XCTAssertFalse(contentView.contains("minWidth: 880"))
    }

    func testAppSurfaceTokensMatchAcWorkPhaseOneLayout() throws {
        let source = try readSource("Features/Native/Shared/AppSurfaceStyle.swift")
        XCTAssertTrue(source.contains("enum Radius"))
        XCTAssertTrue(source.contains("enum Spacing"))
        XCTAssertTrue(source.contains("enum Typography"))
        XCTAssertTrue(source.contains("static let main: CGFloat = 16"))
        XCTAssertTrue(source.contains("static let card: CGFloat = 12"))
        XCTAssertTrue(source.contains("static let section: CGFloat = 10"))
        XCTAssertTrue(source.contains("static let control: CGFloat = 9"))
        XCTAssertTrue(source.contains("static let sidebar: CGFloat = 18"))
        XCTAssertTrue(source.contains("static let page: CGFloat = lg"))
        XCTAssertTrue(source.contains("static let section: CGFloat = md"))
        XCTAssertTrue(source.contains("static let card: CGFloat = sm"))
        XCTAssertTrue(source.contains("static let display: CGFloat = 28"))
        XCTAssertTrue(source.contains("sidebarWidth: CGFloat = 250"))
        XCTAssertTrue(source.contains("toolbarHeight: CGFloat = 60"))
        XCTAssertTrue(source.contains("leadingRailWidth: CGFloat = 220"))
        XCTAssertTrue(source.contains("trailingRailWidth: CGFloat = 304"))
        XCTAssertTrue(source.contains("pagePadding: CGFloat = Spacing.page"))
        XCTAssertTrue(source.contains("sectionSpacing: CGFloat = Spacing.section"))
        XCTAssertTrue(source.contains("cardSpacing: CGFloat = Spacing.card"))
        XCTAssertTrue(source.contains("compactInspectorThreshold: CGFloat = 1320"))
        XCTAssertTrue(source.contains("minimumWindowWidth: CGFloat = 1180"))
        XCTAssertTrue(source.contains("minimumWindowHeight: CGFloat = 720"))
    }

    func testCaptureWorkspaceViewIsOnlyACompatibilityProxy() throws {
        let source = try readSource("Features/Native/Shared/CaptureWorkspaceView.swift")
        XCTAssertFalse(source.contains("enum Mode"))
        XCTAssertFalse(source.contains("workspaceToggle("))
        XCTAssertFalse(source.contains("ClipboardView("))
        XCTAssertTrue(source.contains("InboxView("))
        XCTAssertTrue(source.contains("previewScenario: previewScenario"))
    }

    func testWorkspaceHomeViewDoesNotUseSystemStatusSingleton() throws {
        let source = try readSource("Features/Native/Home/WorkspaceHomeView.swift")
        XCTAssertFalse(source.contains("SystemStatusViewModel(service: .shared)"))
        XCTAssertTrue(source.contains("systemStatusService"))
        XCTAssertTrue(source.contains("SystemStatusLabelFormatter"))
        XCTAssertTrue(source.contains("availabilityState"))
        XCTAssertTrue(source.contains("healthState"))
    }

    func testWorkspaceHomeViewUsesWorkspaceLanguageInsteadOfStatusLanguage() throws {
        let source = try readSource("Features/Native/Home/WorkspaceHomeView.swift")
        XCTAssertTrue(source.contains("工作台总览"))
        XCTAssertTrue(source.contains("homePrimaryDeck"))
        XCTAssertTrue(source.contains("navigationActions"))
        XCTAssertTrue(source.contains("ProductPanelCard"))
        XCTAssertTrue(source.contains("当前重点"))
        XCTAssertTrue(source.contains("下一步"))
        XCTAssertTrue(source.contains("运行概览"))
        XCTAssertTrue(source.contains("运行提醒"))
        XCTAssertTrue(source.contains("工作台摘要"))
        XCTAssertTrue(source.contains("资源"))
        XCTAssertTrue(source.contains("连接与权限"))
        XCTAssertTrue(source.contains("温度状态"))
        XCTAssertFalse(source.contains("本机状态总览"))
        XCTAssertFalse(source.contains("系统状态总览"))
        XCTAssertFalse(source.contains("状态指示"))
        XCTAssertTrue(source.contains("dashboardViewModel.refresh()"))
        XCTAssertTrue(source.contains(".onDisappear { viewModel.stopMonitoring() }"))
    }

    func testWorkspaceHomeViewUsesDashboardRepositoryStateLayer() throws {
        let source = try readSource("Features/Native/Home/WorkspaceHomeView.swift")
        XCTAssertTrue(source.contains("struct WorkspaceDashboardSnapshot"))
        XCTAssertTrue(source.contains("protocol WorkspaceDashboardRepositoryProtocol"))
        XCTAssertTrue(source.contains("struct LiveWorkspaceDashboardRepository"))
        XCTAssertTrue(source.contains("struct PreviewWorkspaceDashboardRepository"))
        XCTAssertTrue(source.contains("final class WorkspaceDashboardViewModel"))
        XCTAssertTrue(source.contains("dashboardViewModel.refresh()"))
        XCTAssertTrue(source.contains("dashboardViewModel.snapshot.currentFocus"))
        XCTAssertTrue(source.contains("dashboardViewModel.snapshot.permissionSummary"))
        XCTAssertTrue(source.contains("currentPage: appState.sidebarSelection.displayName"))
        XCTAssertTrue(source.contains("permissionSummary: SystemStatusLabelFormatter.permissionOverviewSummary"))
    }

    func testWorkspacePageShellUsesUnifiedBackdropLayer() throws {
        let source = try readSource("Features/Native/Shared/AppSurfaceStyle.swift")
        XCTAssertTrue(source.contains("background(AppSurfaceBackdrop())"))
        XCTAssertTrue(source.contains("struct AppSurfaceBackdrop: View"))
        XCTAssertTrue(source.contains("secondarySidebarBackground = Color(nsColor: .underPageBackgroundColor)"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"\\(title)工具栏\")"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"\\(title)内容区\")"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"\\(title)详情栏\")"))
        XCTAssertTrue(source.contains(".accessibilitySortPriority(90)"))
        XCTAssertTrue(source.contains(".accessibilitySortPriority(70)"))
        XCTAssertTrue(source.contains(".accessibilitySortPriority(60)"))
    }

    func testSystemStatusViewDoesNotUseSystemStatusSingleton() throws {
        let source = try readSource("Features/Native/SystemStatus/SystemStatusView.swift")
        XCTAssertFalse(source.contains("SystemStatusViewModel(service: .shared)"))
        XCTAssertTrue(source.contains("SystemStatusViewModel(service:"))
        XCTAssertTrue(source.contains(".onAppear { viewModel.startMonitoring() }"))
        XCTAssertTrue(source.contains(".onDisappear { viewModel.stopMonitoring() }"))
    }

    func testServiceContainerOwnsSystemStatusServiceLifecycle() throws {
        let source = try readSource("App/ServiceContainer.swift")
        XCTAssertTrue(source.contains("public let systemStatusService"))
        XCTAssertTrue(source.contains("SystemStatusService(permissionManager: permissionManager)"))
        XCTAssertTrue(source.contains("systemStatusService.stop()"))
    }

    func testSharedPermissionStateExplainsFailuresAndOpensSystemSettings() throws {
        let sharedSource = try readSource("Features/Native/Shared/WorkspaceSharedComponents.swift")
        let homeSource = try readSource("Features/Native/Home/WorkspaceHomeView.swift")
        let inboxSource = try readSource("Features/Native/Inbox/InboxView.swift")
        let readerSource = try readSource("AcMindKit/Services/SystemStatus/SystemStatusReaders.swift")

        XCTAssertTrue(sharedSource.contains("struct PermissionStatusCard: View"))
        XCTAssertTrue(sharedSource.contains("@Environment(\\.colorSchemeContrast) private var colorSchemeContrast"))
        XCTAssertTrue(sharedSource.contains("Text(permission.unavailableReason"))
        XCTAssertTrue(sharedSource.contains("Button(\"打开系统设置\""))
        XCTAssertTrue(sharedSource.contains("colorSchemeContrast == .increased"))
        XCTAssertTrue(sharedSource.contains(".accessibilityHint(\"打开与\\(permission.name)对应的 macOS 权限设置\")"))
        XCTAssertTrue(homeSource.contains("PermissionStatusCard("))
        XCTAssertTrue(homeSource.contains("openPermissionSettings(for: item)"))
        XCTAssertTrue(readerSource.contains("isAvailable: status.isAuthorized"))
        XCTAssertTrue(readerSource.contains("partial.unavailableReasons = partial.permissions.compactMap"))
        XCTAssertTrue(inboxSource.contains("disabledReason: \"已有内容操作正在处理中\""))
        XCTAssertTrue(inboxSource.contains(".accessibilityHint(isEnabled ? title : disabledReason)"))
        XCTAssertTrue(inboxSource.contains("disabledReason: String = \"当前操作暂不可用\""))
        XCTAssertTrue(inboxSource.contains("请至少输入一个标签后再应用"))
        XCTAssertTrue(inboxSource.contains("队列为空，无需清空"))
        XCTAssertTrue(inboxSource.contains("ScrollView(.horizontal, showsIndicators: false)"))
        XCTAssertTrue(inboxSource.contains(".minimumScaleFactor(0.82)"))
    }

    func testSystemStatusServiceHasNoSharedSingleton() throws {
        let source = try readSource("AcMindKit/Services/SystemStatus/SystemStatusService.swift")
        XCTAssertFalse(source.contains("static let shared"))
    }

    func testNotchCompanionViewsUseInjectedSystemEventCenter() throws {
        let rootSource = try readSource("Features/Companion/NotchV2RootView.swift")
        let hudSource = try readSource("Features/Companion/SystemEventHUD.swift")
        let musicSource = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(rootSource.contains("SystemEventHUDView(center: viewModel.systemEventCenter)"))
        XCTAssertFalse(hudSource.contains("SystemEventCenter.shared"))
        XCTAssertFalse(musicSource.contains("SystemEventCenter.shared"))
    }

    func testNotchCompanionViewModelUsesInjectedMediaServices() throws {
        let source = try readSource("Features/Companion/NotchV2ViewModel.swift")
        XCTAssertFalse(source.contains("BatteryService.shared"))
        XCTAssertFalse(source.contains("MusicService.shared"))
        XCTAssertFalse(source.contains("SystemEventCenter.shared"))
        XCTAssertTrue(source.contains("batteryService: BatteryService"))
        XCTAssertTrue(source.contains("systemStatusService: SystemStatusService"))
        XCTAssertTrue(source.contains("systemEventCenter: SystemEventCenter"))
        XCTAssertTrue(source.contains("musicService: MusicService"))
    }

    func testCompanionDemoViewsAreInjected() throws {
        let batterySource = try readSource("Features/Companion/BatteryService.swift")
        let musicSource = try readSource("Features/Companion/MusicService.swift")

        XCTAssertFalse(batterySource.contains("BatteryService.shared"))
        XCTAssertFalse(musicSource.contains("MusicService.shared"))
        XCTAssertTrue(batterySource.contains("batteryService: BatteryService"))
        XCTAssertTrue(musicSource.contains("musicService: MusicService"))
    }

    func testMusicServiceDoesNotAutoPromptAccessibilityPermission() throws {
        let source = try readSource("Features/Companion/MusicService.swift")

        XCTAssertFalse(source.contains("\"AXTrustedCheckOptionPrompt\": true"))
        XCTAssertTrue(source.contains("AXIsProcessTrusted()"))
        XCTAssertTrue(source.contains("didLogMissingAccessibilityThisLaunch"))
        XCTAssertTrue(source.contains("falling back to OCR"))
    }

    func testDynamicContinentTemplateScrollsItsContentArea() throws {
        let source = try readSource("Features/Companion/DynamicContinent/DynamicContinentTemplateV2.swift")
        XCTAssertTrue(source.contains("ScrollView(.vertical, showsIndicators: false)"))
        XCTAssertTrue(source.contains("GeometryReader"))
        XCTAssertTrue(source.contains("height: safeContentHeight"))
        XCTAssertTrue(source.contains("safeContentHeight"))
        XCTAssertTrue(source.contains("NotchV2LightStatusStrip"))
    }

    func testDynamicContinentFooterHasEnoughReservedHeight() throws {
        let tokenSource = try readSource("Features/Companion/NotchV2DesignTokens.swift")
        let templateSource = try readSource("Features/Companion/DynamicContinent/DynamicContinentTemplateV2.swift")

        XCTAssertTrue(tokenSource.contains("static let dashboardFooterHeight: CGFloat = 28"))
        XCTAssertFalse(templateSource.contains(".padding(.vertical, 6)\n                .frame(height: NotchV2DesignTokens.dashboardFooterHeight)"))
    }

    func testExpandedHeightMatchesDesignLayoutBudget() throws {
        let designSource = try readSource("Design/AcMindDesignTokens.swift")
        let layoutSource = try readSource("AcMindKit/Services/UI/CompanionLayout.swift")

        XCTAssertTrue(designSource.contains("secondaryCardRadius: CGFloat = AppSurfaceTokens.Radius.section"))
        XCTAssertTrue(designSource.contains("smallSpacing: CGFloat = AppSurfaceTokens.Spacing.xs"))
        XCTAssertTrue(designSource.contains("mediumSpacing: CGFloat = AppSurfaceTokens.Spacing.md"))
        XCTAssertTrue(designSource.contains("largeSpacing: CGFloat = AppSurfaceTokens.Spacing.xl"))
        XCTAssertTrue(designSource.contains("cardSpacing: CGFloat = AppSurfaceTokens.Layout.cardSpacing"))
        XCTAssertTrue(designSource.contains("sectionDesc: CGFloat = AppSurfaceTokens.Typography.sectionDesc"))
        XCTAssertTrue(designSource.contains("static let expandedOverviewHeight: CGFloat = 300"))
        XCTAssertTrue(designSource.contains("static let dashboardFooterHeight: CGFloat = 28"))
        XCTAssertTrue(layoutSource.contains("public static let expandedHeight: CGFloat = 300"))
    }

    func testNotchPanelPositionsExpandedFrameUsingCurrentPageHeight() throws {
        let source = try readSource("Features/Companion/NotchPanel.swift")
        XCTAssertTrue(source.contains("CompanionScreenPositioning.expandedFrame(on: screenFrame, height: viewModel.expandedHeight)"))
    }

    func testAgentPageRightColumnIsMoreCompact() throws {
        let source = try readSource("Features/Companion/NotchV2AgentPage.swift")
        XCTAssertTrue(source.contains("leftColumnWidth: 136"))
        XCTAssertTrue(source.contains("fillHeight: true"))
        XCTAssertTrue(source.contains("suffix(3)"))
        XCTAssertFalse(source.contains("LazyVGrid"))
    }

    func testAgentPageCenterCardUsesRemainingHeight() throws {
        let source = try readSource("Features/Companion/NotchV2AgentPage.swift")
        XCTAssertTrue(source.contains("fillHeight: true"))
        XCTAssertTrue(source.contains("Spacer(minLength: 0)"))
        XCTAssertTrue(source.contains("suffix(3)"))
    }

    func testOverviewPageMovesStatusActionIntoSystemQuickView() throws {
        let source = try readSource("Features/Companion/NotchV2OverviewPage.swift")
        XCTAssertFalse(source.contains("title: \"状态入口\""))
        XCTAssertTrue(source.contains("进入状态页"))
        XCTAssertTrue(source.contains("title: \"系统快览\""))
        XCTAssertFalse(source.contains("音乐常驻"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "fillHeight: true").count - 1, 3)
        XCTAssertFalse(source.contains("fillHeight: false"))
    }

    func testMusicPageRightControlCardUsesFillHeight() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")
        XCTAssertTrue(source.contains("controlCard"))
        XCTAssertTrue(source.contains("fillHeight: true"))
        XCTAssertTrue(source.contains("viewModel.musicService.openMusicApp()"))
        XCTAssertTrue(source.contains("播放控制"))
    }

    func testSystemStatusViewUsesFillHeightCardsForDenseSections() throws {
        let source = try readSource("Features/Native/SystemStatus/SystemStatusView.swift")
        XCTAssertTrue(source.contains("fillHeight: true"))
        XCTAssertTrue(source.contains(".frame(maxHeight: .infinity, alignment: .topLeading)"))
    }

    func testDashboardLayoutLetsColumnsStretchVertically() throws {
        let source = try readSource("Features/Companion/NotchV2DashboardLayout.swift")
        XCTAssertTrue(source.contains("frame(maxHeight: .infinity, alignment: .topLeading)"))
    }

    func testSystemStatusPageUsesSixCoreTilesAndNarrowRails() throws {
        let source = try readSource("Features/Companion/DynamicContinent/DynamicContinentPages.swift")
        XCTAssertTrue(source.contains("leftColumnWidth: 176"))
        XCTAssertTrue(source.contains("rightColumnWidth: 176"))
        XCTAssertTrue(source.contains("电池电量"))
        XCTAssertTrue(source.contains("网速（上传下载量）"))
        XCTAssertTrue(source.contains("当前设备温度"))
        XCTAssertTrue(source.contains("当前设备风扇转速"))
        XCTAssertTrue(source.contains("CPU 负载率"))
        XCTAssertTrue(source.contains("内存负载率"))
        XCTAssertTrue(source.contains("NotchV2SegmentedPill"))
    }

    func testTopBarStatusButtonPrefersSystemStatusPage() throws {
        let source = try readSource("Features/Companion/NotchV2TopBar.swift")
        XCTAssertTrue(source.contains("viewModel.openSystemStatusPage()"))
        XCTAssertTrue(source.contains("isSelected: viewModel.effectiveSelectedPage == .systemStatus"))
        XCTAssertTrue(source.contains("panelBackground.opacity(0.82)"))
    }

    func testStatusPillSupportsSelectedFeedback() throws {
        let source = try readSource("Features/Companion/NotchV2Card.swift")
        XCTAssertTrue(source.contains("let isSelected: Bool"))
        XCTAssertTrue(source.contains("isSelected ? accent.opacity(1.0)"))
        XCTAssertTrue(source.contains("scaleEffect(isSelected ? 1.02 : 1.0)"))
    }

    func testNotchCardsUseSofterPanelShadowAndFill() throws {
        let source = try readSource("Features/Companion/NotchV2Card.swift")
        XCTAssertTrue(source.contains("innerCardBackground.opacity(0.92)"))
        XCTAssertTrue(source.contains("innerCardBackground.opacity(0.88)"))
        XCTAssertTrue(source.contains("shadow(color: cardAccent?.opacity(0.06) ?? .black.opacity(0.12), radius: 10, x: 0, y: 5)"))
        XCTAssertTrue(source.contains("panelBackground.opacity(0.82)"))
    }

    func testCollapsedMusicLayoutUsesWidthBasedFallbacks() throws {
        let source = try readSource("Features/Companion/NotchV2CollapsedView.swift")
        XCTAssertTrue(source.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(source.contains("musicCollapsedRichLayout"))
        XCTAssertTrue(source.contains("musicCollapsedCompactLayout"))
        XCTAssertTrue(source.contains("musicCollapsedTinyLayout"))
    }

    func testNotchOverviewAndMusicUseSharedCTAButtons() throws {
        let overviewSource = try readSource("Features/Companion/NotchV2OverviewPage.swift")
        let musicSource = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(overviewSource.contains("NotchV2StatusPill("))
        XCTAssertTrue(overviewSource.contains("进入状态页"))
        XCTAssertTrue(musicSource.contains("NotchV2StatusPill("))
        XCTAssertTrue(musicSource.contains("打开来源播放器"))
    }

    func testLightStatusStripUsesStrongerHighlightedFeedback() throws {
        let source = try readSource("Features/Companion/NotchV2StatusStrip.swift")
        XCTAssertTrue(source.contains("scaleEffect(item.highlighted ? 1.02 : 1.0)"))
        XCTAssertTrue(source.contains("cornerRadius: 11"))
        XCTAssertTrue(source.contains(".padding(.vertical, 2)"))
        XCTAssertTrue(source.contains("font(.system(size: 8, weight: .medium, design: .rounded))"))
        XCTAssertTrue(source.contains("highlighted: playbackState.isPlaying || playbackState.title.isEmpty == false"))
        XCTAssertTrue(source.contains("panelBackground.opacity(0.82)"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
