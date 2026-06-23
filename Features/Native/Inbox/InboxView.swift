import SwiftUI
import AcMindKit
import QuickLookThumbnailing

struct InboxView: View {
    private enum FocusTarget: Hashable {
        case search
        case content
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: CollectedInboxViewModel
    @StateObject private var workflowCoordinator: CollectedItemWorkflowCoordinator
    private let clipboardPinActions: ClipboardPinActions
    @State private var showBatchDeleteConfirmation = false
    @State private var showBatchTagEditor = false
    @State private var showPasteQueue = false
    @State private var showKeyboardPreview = false
    @State private var showKeyboardDeleteConfirmation = false
    @State private var refreshTask: Task<Void, Never>?
    @FocusState private var focusTarget: FocusTarget?

    init(clipboardPinActions: ClipboardPinActions, previewScenario: AcWorkPreviewScenario? = AcWorkPreviewScenario.fromProcessArguments()) {
        self.clipboardPinActions = clipboardPinActions
        _viewModel = StateObject(wrappedValue: CollectedInboxViewModel(repository: InboxCollectedItemRepository(previewScenario: previewScenario)))
        _workflowCoordinator = StateObject(wrappedValue: CollectedItemWorkflowCoordinator())
    }

    var body: some View {
        AcWorkShell(
            title: "收集箱",
            subtitle: "\(viewModel.items.count) 条内容",
            headerActions: AnyView(addContentMenu),
            leadingRailWidth: AppSurfaceTokens.Layout.leadingRailWidth,
            trailingRailWidth: AppSurfaceTokens.Layout.summaryWidth,
            usesResponsiveInspector: true,
            compactInspectorTitle: "收集详情",
            leadingRail: {
                CollectedInboxFilterRail(
                    items: viewModel.allItems,
                    filterState: viewModel.filterState,
                    onUpdateFilter: updateFilter,
                    onClearFilters: clearFilters
                )
            },
            content: {
                itemList
            },
            trailingRail: {
                CollectedInboxInspector(
                    items: viewModel.items,
                    selectedItem: viewModel.selectedItem,
                    selectedCount: viewModel.selectedItemIDs.count,
                    partialErrorCount: viewModel.partialErrors.count,
                    activeFilterSummary: activeFilterChips.isEmpty ? "全部内容" : activeFilterChips.joined(separator: "、"),
                    activeAIAction: workflowCoordinator.activeItemID == viewModel.selectedItem?.id ? workflowCoordinator.activeAIAction : nil,
                    isPerformingWorkflow: workflowCoordinator.isPerforming,
                    pasteQueueCount: viewModel.pasteQueueItems.count,
                    onShowAllPins: clipboardPinActions.showAll,
                    onHideAllPins: clipboardPinActions.hideAll,
                    onCloseAllPins: clipboardPinActions.closeAll,
                    onOpenPasteQueue: { showPasteQueue = true },
                    onPinToggle: { item in Task { item.isPinned ? await viewModel.unpin(item.id) : await viewModel.pin(item.id) } },
                    onFavoriteToggle: { item in Task { await viewModel.setFavorite(item.id, isFavorite: !item.isFavorite) } },
                    onArchive: { item in Task { await viewModel.archive(item.id) } },
                    onSaveClipboard: { item in Task { await viewModel.saveClipboardItemToInbox(item.id) } },
                    onEnqueuePaste: { item in viewModel.enqueueForPaste([item.id]) },
                    onAI: performAI,
                    onWorkflow: performWorkflow,
                    onDelete: { item in Task { await viewModel.delete(item.id) } }
                )
            }
        )
        .background(AppSurfaceBackdrop())
        .onAppear {
            focusTarget = .content
            appState.inboxWorkspaceSelection = "all"
            scheduleRefresh()
        }
        .onChange(of: appState.pendingInboxDetailSourceItemID) { _, _ in
            scheduleRefresh()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
            viewModel.cancelPendingTasks()
        }
        .onKeyPress(.upArrow) {
            viewModel.moveSelection(.previous)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.moveSelection(.next)
            return .handled
        }
        .onKeyPress(.space) {
            ensureKeyboardSelection()
            showKeyboardPreview = viewModel.selectedItem != nil
            return showKeyboardPreview ? .handled : .ignored
        }
        .onKeyPress(.return) {
            ensureKeyboardSelection()
            showKeyboardPreview = viewModel.selectedItem != nil
            return showKeyboardPreview ? .handled : .ignored
        }
        .onKeyPress(.delete) {
            guard viewModel.selectedItem != nil, viewModel.isBatchSelecting == false else { return .ignored }
            showKeyboardDeleteConfirmation = true
            return .handled
        }
        .onKeyPress(.escape) {
            if showKeyboardPreview {
                showKeyboardPreview = false
            } else if viewModel.isBatchSelecting {
                viewModel.clearSelection()
            } else {
                viewModel.clearSelection()
                focusTarget = .content
            }
            return .handled
        }
        .background(searchKeyboardShortcut)
        .sheet(isPresented: $showKeyboardPreview) {
            if let selectedItem = viewModel.selectedItem {
                CollectedInboxQuickPreview(
                    item: selectedItem,
                    onClose: { showKeyboardPreview = false }
                )
            }
        }
        .alert("确认删除当前内容？", isPresented: $showKeyboardDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task { await viewModel.deleteSelectedItem() }
            }
        } message: {
            Text("该操作会从内容原始来源删除当前收集项。")
        }
        .sheet(isPresented: $showBatchTagEditor) {
            CollectedInboxBatchTagEditor(
                selectedCount: viewModel.selectedItemIDs.count,
                onCancel: { showBatchTagEditor = false },
                onApply: { tags in
                    showBatchTagEditor = false
                    Task { await viewModel.applyTagsToBatchSelection(tags) }
                }
            )
        }
        .sheet(isPresented: $showPasteQueue) {
            CollectedInboxPasteQueuePanel(
                queueItems: viewModel.pasteQueueItems,
                collectedItems: viewModel.items,
                onPasteNext: { Task { await viewModel.pasteNextInQueue() } },
                onRemove: viewModel.removePasteQueueItem,
                onMove: viewModel.reorderPasteQueue,
                onClear: viewModel.clearPasteQueue,
                onClose: { showPasteQueue = false }
            )
        }
    }

    private var itemList: some View {
        VStack(spacing: 0) {
            inboxOverviewCard

            Divider()

            inboxControlBar

            if let batchResult = viewModel.lastBatchOperationResult {
                CollectedInboxBatchResultBanner(
                    result: batchResult,
                    onDismiss: { viewModel.clearBatchOperationResult() }
                )

                Divider()
            }

            if let feedback = workflowCoordinator.feedback {
                CollectedInboxWorkflowFeedbackBanner(
                    feedback: feedback,
                    onDismiss: workflowCoordinator.clearFeedback
                )

                Divider()
            }

            if viewModel.isBatchSelecting {
                CollectedInboxBatchActionBar(
                    selectedCount: viewModel.selectedItemIDs.count,
                    isPerformingWorkflow: workflowCoordinator.isPerforming,
                    onClearSelection: { viewModel.clearSelection() },
                    onAddTags: { showBatchTagEditor = true },
                    onSendToAgent: { performBatchWorkflow(.sendToAgent) },
                    onCreateTask: { performBatchWorkflow(.createTask) },
                    onCreateSchedule: { performBatchWorkflow(.createSchedule) },
                    onArchive: { Task { await viewModel.archiveBatchSelection() } },
                    onEnqueuePaste: { viewModel.enqueueBatchSelectionForPaste() },
                    onExport: { performBatchWorkflow(.exportMarkdown) },
                    onDelete: { showBatchDeleteConfirmation = true }
                )

                Divider()
            }

            Divider()

            if viewModel.phase == .loading {
                loadingState
            } else if case .failed(let errorMessage) = viewModel.phase {
                errorState(message: errorMessage)
            } else if viewModel.items.isEmpty {
                emptyState
            } else {
                GeometryReader { proxy in
                    ScrollView {
                        if viewModel.viewMode == .list {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.items) { item in
                                    CollectedInboxItemCard(
                                        item: item,
                                        presentation: .list,
                                        density: viewModel.density,
                                        isSelected: viewModel.selectedItemID == item.id,
                                        isBatchSelected: viewModel.selectedItemIDs.contains(item.id),
                                        onSelect: { viewModel.select(item.id) },
                                        onToggleBatch: { viewModel.toggleBatchSelection(item.id) },
                                        onPinToggle: { Task { item.isPinned ? await viewModel.unpin(item.id) : await viewModel.pin(item.id) } },
                                        onFavoriteToggle: { Task { await viewModel.setFavorite(item.id, isFavorite: !item.isFavorite) } },
                                        onArchive: { Task { await viewModel.archive(item.id) } },
                                        onSaveClipboard: { Task { await viewModel.saveClipboardItemToInbox(item.id) } },
                                        onEnqueuePaste: { viewModel.enqueueForPaste([item.id]) },
                                        onDelete: { Task { await viewModel.delete(item.id) } }
                                    )
                                }
                            }
                            .padding(16)
                        } else {
                            LazyVGrid(columns: inboxColumns(availableWidth: proxy.size.width), spacing: 12) {
                                ForEach(viewModel.items) { item in
                                    CollectedInboxItemCard(
                                        item: item,
                                        presentation: .grid,
                                        density: viewModel.density,
                                        isSelected: viewModel.selectedItemID == item.id,
                                        isBatchSelected: viewModel.selectedItemIDs.contains(item.id),
                                        onSelect: { viewModel.select(item.id) },
                                        onToggleBatch: { viewModel.toggleBatchSelection(item.id) },
                                        onPinToggle: { Task { item.isPinned ? await viewModel.unpin(item.id) : await viewModel.pin(item.id) } },
                                        onFavoriteToggle: { Task { await viewModel.setFavorite(item.id, isFavorite: !item.isFavorite) } },
                                        onArchive: { Task { await viewModel.archive(item.id) } },
                                        onSaveClipboard: { Task { await viewModel.saveClipboardItemToInbox(item.id) } },
                                        onEnqueuePaste: { viewModel.enqueueForPaste([item.id]) },
                                        onDelete: { Task { await viewModel.delete(item.id) } }
                                    )
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .focusable(true)
        .focused($focusTarget, equals: .content)
        .alert("确认删除批量选择？", isPresented: $showBatchDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除 \(viewModel.selectedItemIDs.count) 项", role: .destructive) {
                Task { await viewModel.deleteBatchSelection() }
            }
        } message: {
            Text("删除后这些收集项会从当前来源移除。此操作不会影响未选择的内容。")
        }
    }

    private var inboxOverviewCard: some View {
        AppSurfaceCard(title: "收集概览", subtitle: "摘要卡 + 列表区", padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    inboxSummaryChip(title: "总量", value: "\(viewModel.allItems.count) 条", tint: AppSurfaceTokens.accentBlue)
                    inboxSummaryChip(title: "待处理", value: "\(viewModel.count(for: InboxQuickFilter.pending)) 条", tint: AppSurfaceTokens.accentOrange)
                    inboxSummaryChip(title: "Pin", value: "\(viewModel.count(for: .pinned)) 条", tint: AppSurfaceTokens.accentGreen)
                    inboxSummaryChip(title: "收藏", value: "\(viewModel.count(for: .favorites)) 条", tint: AppSurfaceTokens.secondaryText)
                }

                HStack(alignment: .center, spacing: 10) {
                    AppSurfaceSummaryChip(
                        title: "筛选",
                        value: activeFilterSummary,
                        tint: AppSurfaceTokens.primaryText
                    )
                    AppSurfaceSummaryChip(
                        title: "队列",
                        value: viewModel.pasteQueueItems.isEmpty ? "空" : "\(viewModel.pasteQueueItems.count) 项",
                        tint: AppSurfaceTokens.accentBlue
                    )
                    AppSurfaceSummaryChip(
                        title: "模式",
                        value: viewModel.viewMode == .list ? "列表" : "网格",
                        tint: AppSurfaceTokens.secondaryText
                    )
                }

                Text("列表主体保持高效浏览，顶部只负责概览与状态解释。")
                    .font(.system(size: AppSurfaceTokens.Typography.caption))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
        }
        .padding(.horizontal, AppSurfaceTokens.Spacing.lg)
        .padding(.top, AppSurfaceTokens.Spacing.lg)
    }

    private func inboxSummaryChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.system(size: AppSurfaceTokens.Typography.controlStrong, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSurfaceTokens.Spacing.sm)
        .padding(.vertical, AppSurfaceTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func inboxColumns(availableWidth: CGFloat) -> [GridItem] {
        let count = MaterialCardGridLayout.columnCount(
            availableWidth: availableWidth,
            minimumColumnWidth: 240,
            maximumColumns: 3
        )
        return Array(
            repeating: GridItem(.flexible(minimum: 240, maximum: 300), spacing: MaterialCardGridLayout.spacing),
            count: count
        )
    }

    private var addContentMenu: some View {
        Menu {
            Button {
                NotificationCenter.default.post(name: .companionShowQuickNote, object: nil)
            } label: {
                Label("快速记录", systemImage: "square.and.pencil")
            }
            Button {
                NotificationCenter.default.post(name: .companionShowCapturePanel, object: nil)
            } label: {
                Label("截图或文件", systemImage: "viewfinder")
            }
            Button {
                NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
            } label: {
                Label("语音记录", systemImage: "mic")
            }
        } label: {
            Label("添加内容", systemImage: "plus")
                .font(.system(size: 12, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("添加收集内容")
    }

    private var inboxControlBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                searchBar

                Spacer(minLength: 8)

                Menu {
                    Button("最新优先") { updateFilter { $0.sort = .newestFirst } }
                    Button("最早优先") { updateFilter { $0.sort = .oldestFirst } }
                    Button("Pin 优先") { updateFilter { $0.sort = .pinnedFirst } }
                    Button("最近更新") { updateFilter { $0.sort = .recentlyUpdated } }
                } label: {
                    Label(viewModel.filterState.sort.displayName, systemImage: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)

                HStack(spacing: 4) {
                    viewModeButton(.grid, icon: "square.grid.2x2")
                    viewModeButton(.list, icon: "list.bullet")
                    if viewModel.viewMode == .list {
                        densityButton
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackground.opacity(0.75))
                )

                if viewModel.pasteQueueItems.isEmpty == false {
                    Button {
                        showPasteQueue = true
                    } label: {
                        Label("队列 \(viewModel.pasteQueueItems.count)", systemImage: "list.number")
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityLabel("打开粘贴队列")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if viewModel.filterState.sources.contains(.clipboard) {
                        clipboardMonitoringControl
                    }

                    Label(activeFilterSummary, systemImage: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    ForEach(activeFilterChips, id: \.self) { chip in
                        Text(chip)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AppSurfaceTokens.cardBackground.opacity(0.82)))
                            .overlay(
                                Capsule()
                                    .stroke(AppSurfaceTokens.separator.opacity(0.45), lineWidth: 1)
                            )
                    }

                    if hasActiveInlineFilters {
                        Button("清除筛选") {
                            clearFilters()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var hasActiveInlineFilters: Bool {
        viewModel.filterState.quickFilter != .all ||
        viewModel.filterState.sources.isEmpty == false ||
        viewModel.filterState.contentTypes.isEmpty == false ||
        viewModel.filterState.statuses.isEmpty == false ||
        viewModel.filterState.searchQuery.isEmpty == false ||
        viewModel.filterState.sort != .newestFirst
    }

    private var activeFilterSummary: String {
        hasActiveInlineFilters ? "当前筛选" : "全部内容"
    }

    private var activeFilterChips: [String] {
        var chips: [String] = []
        if viewModel.filterState.quickFilter != .all {
            chips.append(viewModel.filterState.quickFilter.displayName)
        }
        chips.append(contentsOf: viewModel.filterState.sources.map(\.displayName).sorted())
        chips.append(contentsOf: viewModel.filterState.contentTypes.map(\.displayName).sorted())
        chips.append(contentsOf: viewModel.filterState.statuses.map(\.displayName).sorted())
        if viewModel.filterState.sort != .newestFirst {
            chips.append(viewModel.filterState.sort.displayName)
        }
        if viewModel.filterState.searchQuery.isEmpty == false {
            chips.append("搜索：\(viewModel.filterState.searchQuery)")
        }
        return chips
    }

    private func viewModeButton(_ mode: CollectedInboxViewMode, icon: String) -> some View {
        Button {
            viewModel.setViewMode(mode)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(viewModel.viewMode == mode ? Color.white : AppSurfaceTokens.secondaryText)
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(viewModel.viewMode == mode ? AppSurfaceTokens.accentBlue : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode == .grid ? "网格视图" : "列表视图")
    }

    private var densityButton: some View {
        Button {
            viewModel.setDensity(viewModel.density == .standard ? .compact : .standard)
        } label: {
            Image(systemName: viewModel.density == .standard ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.plain)
        .help(viewModel.density == .standard ? "切换为紧凑行高" : "切换为标准行高")
        .accessibilityLabel(viewModel.density == .standard ? "紧凑列表" : "标准列表")
    }

    private var clipboardMonitoringControl: some View {
        Button {
            Task { await viewModel.toggleClipboardMonitoring() }
        } label: {
            Label(
                viewModel.clipboardMonitoringState.displayName,
                systemImage: viewModel.clipboardMonitoringState.iconName
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(viewModel.clipboardMonitoringState.tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(viewModel.clipboardMonitoringState.tint.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.clipboardMonitoringState.canToggle == false)
        .help(viewModel.clipboardMonitoringState.helpText)
        .accessibilityLabel(viewModel.clipboardMonitoringState.helpText)
        .accessibilityHint(
            viewModel.clipboardMonitoringState.canToggle
                ? "暂停或恢复剪贴板监听"
                : "当前状态不可操作：\(viewModel.clipboardMonitoringState.helpText)"
        )
    }

    private func filterChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : AppSurfaceTokens.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.cardBackground.opacity(0.82))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppSurfaceTokens.separator.opacity(0.55), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func updateFilter(_ mutate: @escaping (inout InboxFilterState) -> Void) {
        var next = viewModel.filterState
        mutate(&next)
        Task { await viewModel.updateFilter(next) }
    }

    private func clearFilters() {
        Task { await viewModel.updateFilter(InboxFilterState()) }
    }

    private func ensureKeyboardSelection() {
        if viewModel.selectedItemID == nil {
            viewModel.moveSelection(.next)
        }
    }

    private func performWorkflow(_ action: CollectedItemWorkflowAction, item: CollectedItem) {
        Task {
            await workflowCoordinator.perform(action, item: item)
        }
    }

    private func performAI(_ action: CollectedItemAIAction, item: CollectedItem) {
        Task {
            await workflowCoordinator.performAI(action, item: item) { result, id in
                _ = try await viewModel.applyAIResult(result, to: id)
            }
        }
    }

    private func performBatchWorkflow(_ action: CollectedItemWorkflowAction) {
        let items = viewModel.items.filter { viewModel.selectedItemIDs.contains($0.id) }
        Task {
            await workflowCoordinator.performBatch(action, items: items)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .font(.caption)
                .accessibilityHidden(true)

            TextField(
                "搜索收集箱...",
                text: Binding(
                    get: { viewModel.filterState.searchQuery },
                    set: { viewModel.updateSearchQuery($0) }
                )
            )
                .textFieldStyle(.plain)
                .focused($focusTarget, equals: .search)
                .accessibilityLabel("搜索收集箱")

            if !viewModel.filterState.searchQuery.isEmpty {
                Button(action: { viewModel.updateSearchQuery("", debounceNanoseconds: 0) }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground.opacity(0.96))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("收集箱搜索")
    }

    private var searchKeyboardShortcut: some View {
        Button("搜索收集箱") {
            focusTarget = .search
        }
        .keyboardShortcut("f", modifiers: .command)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var emptyState: some View {
        StateContainer(
            phase: .empty(
                title: "暂无收集内容",
                message: "通过语音、截图、剪贴板或 Agent 生成内容后，会先进入这里等待整理。"
            )
        ) {
            AppSurfaceEmptyState(
                icon: "tray",
                title: "暂无收集内容",
                message: "通过语音、截图、剪贴板或 Agent 生成内容后，会先进入这里等待整理。",
                tint: AppSurfaceTokens.accentBlue
            )
        }
        .padding(AppSurfaceTokens.Spacing.lg)
    }

    private var loadingState: some View {
        StateContainer(
            phase: .loading(message: "正在加载收集箱：读取语音、截图、剪贴板和 Agent 生成内容。")
        ) {
            EmptyView()
        }
        .padding(AppSurfaceTokens.Spacing.lg)
    }

    private func errorState(message: String) -> some View {
        StateContainer(
            phase: .failed(title: "收集箱加载失败", message: message, actionTitle: "重试") {
                Task { await viewModel.refresh() }
            }
        ) {
            EmptyView()
        }
        .padding(AppSurfaceTokens.Spacing.lg)
    }

    @MainActor
    private func focusPendingCaptureDetailIfNeeded() async {
        guard let pendingItemID = appState.pendingInboxDetailSourceItemID else { return }

        if let item = viewModel.items.first(where: { $0.id.rawID == pendingItemID || $0.id.stableValue == pendingItemID }) {
            appState.inboxWorkspaceSelection = "all"
            viewModel.select(item.id)
            appState.pendingInboxDetailSourceItemID = nil
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            await viewModel.refresh()
            guard Task.isCancelled == false else { return }
            await focusPendingCaptureDetailIfNeeded()
        }
    }
}

private struct CollectedInboxFilterRail: View {
    let items: [CollectedItem]
    let filterState: InboxFilterState
    let onUpdateFilter: (@escaping (inout InboxFilterState) -> Void) -> Void
    let onClearFilters: () -> Void

    private let sourceFilters: [CollectionSource] = [.clipboard, .phoneSync, .voice, .screenshotOCR, .agent, .manual]
    private let contentTypeFilters: [CollectedContentType] = [.text, .link, .image, .file, .code, .richText, .video]
    private let statusFilters: [ProcessingStatus] = [.pending, .refined, .archived, .exported]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                railHeader

                railSection(title: "快捷视图") {
                    ForEach(InboxQuickFilter.allCases, id: \.self) { filter in
                        railButton(
                            title: filter.displayName,
                            icon: filter.iconName,
                            isSelected: filterState.quickFilter == filter,
                            badge: "\(count(for: filter))"
                        ) {
                            onUpdateFilter { $0.quickFilter = filter }
                        }
                    }
                }

                railSection(title: "来源") {
                    ForEach(sourceFilters, id: \.self) { source in
                        railButton(
                            title: source.displayName,
                            icon: source.iconName,
                            isSelected: filterState.sources.contains(source),
                            badge: "\(items.filter { $0.source == source }.count)"
                        ) {
                            onUpdateFilter { state in
                                state.sources.toggleMembership(source)
                            }
                        }
                    }
                }

                railSection(title: "类型") {
                    ForEach(contentTypeFilters, id: \.self) { type in
                        railButton(
                            title: type.displayName,
                            icon: type.iconName,
                            isSelected: filterState.contentTypes.contains(type),
                            badge: "\(items.filter { $0.contentType == type }.count)"
                        ) {
                            onUpdateFilter { state in
                                state.contentTypes.toggleMembership(type)
                            }
                        }
                    }
                }

                railSection(title: "状态") {
                    ForEach(statusFilters, id: \.self) { status in
                        railButton(
                            title: status.displayName,
                            icon: status.iconName,
                            isSelected: filterState.statuses.contains(status),
                            badge: "\(items.filter { $0.processingStatus == status }.count)"
                        ) {
                            onUpdateFilter { state in
                                state.statuses.toggleMembership(status)
                            }
                        }
                    }
                }

                if hasActiveFilters {
                    Button(action: onClearFilters) {
                        Label("清除全部筛选", systemImage: "xmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.accentBlue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding(AppSurfaceTokens.Spacing.lg)
        }
        .background(AppSurfaceBackdrop())
        .accessibilityLabel("收集箱筛选栏")
    }

    private var railHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Filter Rail")
                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .bold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)

            Text("收集箱")
                .font(.system(size: AppSurfaceTokens.Typography.pageTitle, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Text("\(items.count) 条内容 · 多条件筛选")
                .font(.system(size: AppSurfaceTokens.Typography.caption))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var hasActiveFilters: Bool {
        filterState.quickFilter != .all ||
        filterState.sources.isEmpty == false ||
        filterState.contentTypes.isEmpty == false ||
        filterState.statuses.isEmpty == false ||
        filterState.searchQuery.isEmpty == false ||
        filterState.sort != .newestFirst
    }

    private func count(for filter: InboxQuickFilter) -> Int {
        switch filter {
        case .all:
            return items.count
        case .pending:
            return items.filter { $0.processingStatus == .pending || $0.processingStatus == .captured }.count
        case .pinned:
            return items.filter(\.isPinned).count
        case .favorites:
            return items.filter(\.isFavorite).count
        case .recent:
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
            return items.filter { ($0.updatedAt ?? $0.createdAt) >= cutoff }.count
        }
    }

    private func railSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                content()
            }
        }
    }

    private func railButton(title: String, icon: String, isSelected: Bool, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.10) : AppSurfaceTokens.cardBackground.opacity(0.68))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.42) : AppSurfaceTokens.separator.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private enum CollectedInboxCardPresentation {
    case grid
    case list
}

@MainActor
private final class CollectedItemThumbnailCache {
    static let shared = CollectedItemThumbnailCache()

    private let images = NSCache<NSString, NSImage>()

    private init() {
        images.countLimit = 160
        images.totalCostLimit = 96 * 1024 * 1024
    }

    func image(for key: String) -> NSImage? {
        images.object(forKey: key as NSString)
    }

    func insert(_ image: NSImage, for key: String) {
        let pixelCost = max(1, Int(image.size.width * image.size.height * 4))
        images.setObject(image, forKey: key as NSString, cost: pixelCost)
    }
}

private struct CollectedItemThumbnailView: View {
    let item: CollectedItem
    let height: CGFloat
    var cornerRadius: CGFloat = 10

    private let assetStore: AssetStoreProtocol
    @State private var thumbnail: NSImage?
    @State private var isLoading = false

    init(
        item: CollectedItem,
        height: CGFloat,
        cornerRadius: CGFloat = 10,
        assetStore: AssetStoreProtocol = AssetStore()
    ) {
        self.item = item
        self.height = height
        self.cornerRadius = cornerRadius
        self.assetStore = assetStore
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(item.contentType.tint.opacity(0.08))

            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: item.contentType.iconName)
                    .font(.system(size: height >= 100 ? 26 : 16, weight: .medium))
                    .foregroundStyle(item.contentType.tint)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.28), lineWidth: 1)
        )
        .task(id: item.thumbnailCacheKey) {
            await loadThumbnailIfNeeded()
        }
        .accessibilityLabel("\(item.contentType.displayName)缩略图")
    }

    private func loadThumbnailIfNeeded() async {
        guard let cacheKey = item.thumbnailCacheKey else { return }
        var cached: NSImage?
        await MainActor.run {
            cached = CollectedItemThumbnailCache.shared.image(for: cacheKey)
        }
        if let cached {
            thumbnail = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        let maxPixelSize = max(height * 2.5, 360)
        let loaded: NSImage?
        if let assetID = item.thumbnailAssetID {
            let store = assetStore
            if let asset = try? await store.getAsset(id: assetID) {
                loaded = store.loadImage(asset: asset, maxPixelSize: maxPixelSize)
            } else {
                loaded = nil
            }
        } else if let fileURL = item.thumbnailFileURL {
            loaded = await Self.quickLookThumbnail(url: fileURL, maxPixelSize: maxPixelSize)
        } else {
            loaded = nil
        }

        guard let loaded else { return }
        await MainActor.run {
            CollectedItemThumbnailCache.shared.insert(loaded, for: cacheKey)
            thumbnail = loaded
        }
    }

    private static func quickLookThumbnail(url: URL, maxPixelSize: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: maxPixelSize, height: maxPixelSize),
            scale: 1,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
    }
}

@MainActor
private final class CollectedLinkIconCache {
    static let shared = CollectedLinkIconCache()

    private let images = NSCache<NSString, NSImage>()

    private init() {
        images.countLimit = 80
        images.totalCostLimit = 8 * 1024 * 1024
    }

    func image(for host: String) -> NSImage? {
        images.object(forKey: host as NSString)
    }

    func insert(_ image: NSImage, for host: String) {
        images.setObject(image, forKey: host as NSString)
    }
}

private struct CollectedLinkSiteIconView: View {
    let item: CollectedItem
    let size: CGFloat

    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "globe")
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .systemTeal))
            }
        }
        .frame(width: size, height: size)
        .padding(size * 0.16)
        .background(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color(nsColor: .systemTeal).opacity(0.10))
        )
        .task(id: item.linkHost) {
            await loadIconIfNeeded()
        }
        .accessibilityLabel(item.linkHost.map { "\($0) 站点图标" } ?? "链接图标")
    }

    private func loadIconIfNeeded() async {
        guard let host = item.linkHost, let faviconURL = item.faviconURL else { return }
        var cached: NSImage?
        await MainActor.run {
            cached = CollectedLinkIconCache.shared.image(for: host)
        }
        if let cached {
            icon = cached
            return
        }

        var request = URLRequest(url: faviconURL)
        request.timeoutInterval = 4
        request.cachePolicy = .returnCacheDataElseLoad
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode ?? 500 < 400,
            data.count <= 1_000_000,
            let loaded = NSImage(data: data)
        else {
            return
        }

        await MainActor.run {
            CollectedLinkIconCache.shared.insert(loaded, for: host)
            icon = loaded
        }
    }
}

private struct CollectedItemFileSizeView: View {
    let item: CollectedItem
    var prefix: String? = nil

    private let assetStore: AssetStoreProtocol
    @State private var formattedSize: String?

    init(item: CollectedItem, prefix: String? = nil, assetStore: AssetStoreProtocol = AssetStore()) {
        self.item = item
        self.prefix = prefix
        self.assetStore = assetStore
    }

    var body: some View {
        Group {
            if let formattedSize {
                Text(prefix.map { "\($0)\(formattedSize)" } ?? formattedSize)
            }
        }
        .task(id: item.thumbnailCacheKey) {
            formattedSize = await resolveFileSize()
        }
    }

    private func resolveFileSize() async -> String? {
        if let rawSize = item.metadata["fileSize"].flatMap(Int64.init), rawSize > 0 {
            return ByteCountFormatter.string(fromByteCount: rawSize, countStyle: .file)
        }
        if let fileURL = item.thumbnailFileURL,
           let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > 0 {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        if let assetID = item.thumbnailAssetID,
           let asset = try? await assetStore.getAsset(id: assetID),
           let size = asset.fileSize,
           size > 0 {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        return nil
    }
}

private struct CollectedInboxQuickPreview: View {
    let item: CollectedItem
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if item.contentType == .link {
                    CollectedLinkSiteIconView(item: item, size: 34)
                } else {
                    Image(systemName: item.contentType.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(item.contentType.tint)
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(item.contentType.tint.opacity(0.12))
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title ?? item.contentType.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(2)

                    Text("\(item.source.displayName) · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }

                Spacer(minLength: 12)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityLabel("关闭快速预览")
            }
            .padding(18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if item.supportsThumbnail {
                        CollectedItemThumbnailView(item: item, height: 260, cornerRadius: 14)
                    }

                    Text(item.inspectorPreviewText)
                        .font(item.contentType == .code ? .system(size: 13, design: .monospaced) : .system(size: 13))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 420, idealHeight: 520)
        .background(AppSurfaceBackdrop())
        .accessibilityLabel("收集箱快速预览")
    }
}

private struct CollectedInboxBatchResultBanner: View {
    let result: CollectedInboxBatchOperationResult
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: result.failureCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(result.failureCount == 0 ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(resultSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                if result.failureMessages.isEmpty == false {
                    Text(result.failureMessages.prefix(2).joined(separator: "\n"))
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭批量操作结果")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(result.failureCount == 0 ? Color(nsColor: .systemGreen).opacity(0.08) : Color(nsColor: .systemOrange).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(result.failureCount == 0 ? Color(nsColor: .systemGreen).opacity(0.22) : Color(nsColor: .systemOrange).opacity(0.28), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .accessibilityLabel("批量操作结果")
    }

    private var resultSummary: String {
        if result.failureCount == 0 {
            return "\(result.actionTitle)完成：成功 \(result.successCount) 项"
        }
        if result.successCount == 0 {
            return "\(result.actionTitle)失败：失败 \(result.failureCount) 项，失败项已保留选择"
        }
        return "\(result.actionTitle)部分完成：成功 \(result.successCount) 项，失败 \(result.failureCount) 项，失败项已保留选择"
    }
}

private struct CollectedInboxWorkflowFeedbackBanner: View {
    let feedback: CollectedItemWorkflowFeedback
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feedback.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(feedback.isError ? Color(nsColor: .systemOrange) : Color(nsColor: .systemGreen))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(feedback.actionTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(feedback.message)
                    .font(.system(size: 11))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭工作流结果")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill((feedback.isError ? Color(nsColor: .systemOrange) : Color(nsColor: .systemGreen)).opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((feedback.isError ? Color(nsColor: .systemOrange) : Color(nsColor: .systemGreen)).opacity(0.24), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .accessibilityLabel("工作流结果")
    }
}

private struct CollectedInboxBatchTagEditor: View {
    let selectedCount: Int
    let onCancel: () -> Void
    let onApply: ([String]) -> Void
    @State private var tagText = ""

    private var tags: [String] {
        tagText
            .components(separatedBy: CharacterSet(charactersIn: ",，\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("批量添加标签")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text("为已选择的 \(selectedCount) 项合并标签，不会覆盖原有标签。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            TextField("例如：项目 A，待跟进，设计", text: $tagText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            if tags.isEmpty == false {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AppSurfaceTokens.accentBlue.opacity(0.12)))
                    }
                }
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("应用标签") {
                    onApply(tags)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tags.isEmpty)
                .help(tags.isEmpty ? "请至少输入一个标签" : "将标签应用到所选内容")
                .accessibilityHint(tags.isEmpty ? "请至少输入一个标签后再应用" : "将标签应用到所选内容")
            }
        }
        .padding(22)
        .frame(width: 440)
        .background(AppSurfaceBackdrop())
    }
}

private struct CollectedInboxPasteQueuePanel: View {
    let queueItems: [PasteQueue.QueueItem]
    let collectedItems: [CollectedItem]
    let onPasteNext: () -> Void
    let onRemove: (String) -> Void
    let onMove: (Int, Int) -> Void
    let onClear: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("粘贴队列")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(queueItems.count) 条内容，按顺序连续粘贴")
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                Spacer()
                Button("清空", role: .destructive, action: onClear)
                    .disabled(queueItems.isEmpty)
                    .help(queueItems.isEmpty ? "队列为空，无需清空" : "清空全部粘贴队列")
                    .accessibilityHint(queueItems.isEmpty ? "队列为空，无需清空" : "清空全部粘贴队列")
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭粘贴队列")
            }
            .padding(18)

            Divider()

            if queueItems.isEmpty {
                ContentUnavailableView(
                    "队列为空",
                    systemImage: "list.number",
                    description: Text("从收集项操作或批量工具条加入内容。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(queueItems.enumerated()), id: \.element.id) { index, queueItem in
                            queueRow(queueItem, index: index)
                        }
                    }
                    .padding(16)
                }
            }

            Divider()

            Button(action: onPasteNext) {
                Label("粘贴下一条", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(.borderedProminent)
            .disabled(queueItems.isEmpty)
            .help(queueItems.isEmpty ? "请先将内容加入粘贴队列" : "粘贴队列中的下一条内容")
            .accessibilityHint(queueItems.isEmpty ? "请先将内容加入粘贴队列" : "粘贴队列中的下一条内容")
            .padding(16)
        }
        .frame(minWidth: 520, idealWidth: 620, minHeight: 420, idealHeight: 560)
        .background(AppSurfaceBackdrop())
    }

    private func queueRow(_ queueItem: PasteQueue.QueueItem, index: Int) -> some View {
        let item = collectedItems.first {
            $0.id.origin == .clipboardItem && $0.id.rawID == queueItem.clipboardItemId
        }

        return HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .frame(width: 24)

            Image(systemName: item?.contentType.iconName ?? "doc")
                .frame(width: 18)
                .foregroundStyle(AppSurfaceTokens.accentBlue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item?.workflowTitle ?? "剪贴板内容")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(item?.workflowBody ?? queueItem.clipboardItemId)
                    .font(.system(size: 11))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Button { onMove(index, index - 1) } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(index == 0)
            .accessibilityLabel("上移")
            .help(index == 0 ? "已经位于队列顶部" : "在粘贴队列中上移")
            .accessibilityHint(index == 0 ? "已经位于队列顶部" : "在粘贴队列中上移")

            Button { onMove(index, index + 1) } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(index == queueItems.count - 1)
            .accessibilityLabel("下移")
            .help(index == queueItems.count - 1 ? "已经位于队列底部" : "在粘贴队列中下移")
            .accessibilityHint(index == queueItems.count - 1 ? "已经位于队列底部" : "在粘贴队列中下移")

            Button(role: .destructive) {
                onRemove(queueItem.id)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("移出队列")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct CollectedInboxBatchActionBar: View {
    let selectedCount: Int
    let isPerformingWorkflow: Bool
    let onClearSelection: () -> Void
    let onAddTags: () -> Void
    let onSendToAgent: () -> Void
    let onCreateTask: () -> Void
    let onCreateSchedule: () -> Void
    let onArchive: () -> Void
    let onEnqueuePaste: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Label("已选择 \(selectedCount) 项", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.accentBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                batchButton("添加标签", icon: "tag", action: onAddTags)
                batchButton("发送给 Agent", icon: "paperplane", isEnabled: !isPerformingWorkflow, action: onSendToAgent)
                batchButton("转任务", icon: "checkmark.square", isEnabled: !isPerformingWorkflow, action: onCreateTask)
                batchButton("转日程", icon: "calendar", isEnabled: !isPerformingWorkflow, action: onCreateSchedule)
                batchButton("归档", icon: "archivebox", action: onArchive)
                batchButton("加入队列", icon: "text.insert", action: onEnqueuePaste)
                batchButton("导出", icon: "square.and.arrow.up", isEnabled: !isPerformingWorkflow, action: onExport)

                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .semibold))

                Button(action: onClearSelection) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("退出批量选择")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppSurfaceTokens.accentBlue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppSurfaceTokens.accentBlue.opacity(0.22), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .accessibilityLabel("批量操作条")
    }

    private func batchButton(
        _ title: String,
        icon: String,
        isEnabled: Bool = true,
        disabledReason: String = "当前操作暂不可用",
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .accessibilityHidden(true)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(isEnabled ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText.opacity(0.65))
        .disabled(isEnabled == false)
        .accessibilityLabel(title)
        .help(isEnabled ? title : disabledReason)
        .accessibilityHint(isEnabled ? title : disabledReason)
    }
}

private struct CollectedInboxInspector: View {
    let items: [CollectedItem]
    let selectedItem: CollectedItem?
    let selectedCount: Int
    let partialErrorCount: Int
    let activeFilterSummary: String
    let activeAIAction: CollectedItemAIAction?
    let isPerformingWorkflow: Bool
    let pasteQueueCount: Int
    let onShowAllPins: () -> Void
    let onHideAllPins: () -> Void
    let onCloseAllPins: () -> Void
    let onOpenPasteQueue: () -> Void
    let onPinToggle: (CollectedItem) -> Void
    let onFavoriteToggle: (CollectedItem) -> Void
    let onArchive: (CollectedItem) -> Void
    let onSaveClipboard: (CollectedItem) -> Void
    let onEnqueuePaste: (CollectedItem) -> Void
    let onAI: (CollectedItemAIAction, CollectedItem) -> Void
    let onWorkflow: (CollectedItemWorkflowAction, CollectedItem) -> Void
    let onDelete: (CollectedItem) -> Void

    var body: some View {
        AcInspector(
            title: selectedItem?.title ?? "Inspector",
            subtitle: selectedItem.map { "\($0.contentType.displayName) · \($0.processingStatus.displayName)" } ?? "选择一条内容查看细节",
            footerContent: selectedItem.map { AnyView(fixedActionFooter(for: $0)) }
        ) {
            if let selectedItem {
                selectedInspector(for: selectedItem)
            } else {
                summaryInspector
            }
        }
    }

    private var summaryInspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSurfaceCard(title: "收集概览", subtitle: activeFilterSummary, padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    metricRow(title: "总数量", value: "\(items.count)")
                    metricRow(title: "待整理", value: "\(items.filter { $0.processingStatus == .pending || $0.processingStatus == .captured }.count)")
                    metricRow(title: "Pin", value: "\(items.filter(\.isPinned).count)")
                    metricRow(title: "手机同步", value: "\(items.filter { $0.source == .phoneSync }.count)")
                    metricRow(title: "粘贴队列", value: "\(items.filter { $0.id.origin == .clipboardItem }.count)")
                    metricRow(title: "批量选择", value: selectedCount == 0 ? "无" : "\(selectedCount)")
                    metricRow(title: "部分错误", value: partialErrorCount == 0 ? "无" : "\(partialErrorCount)")
                }
            }

            AppSurfaceCard(title: "下一步", subtitle: "Inspector 将承接内容去向", padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    guidanceLine("选择内容后可查看完整预览、来源和标签。")
                    guidanceLine("剪贴板内容可保存到收集箱或加入粘贴队列。")
                    guidanceLine("任务、日程、知识库和 Markdown 去向已接通，可从内容详情直接执行。")
                }
            }

            AppSurfaceCard(title: "Pin 与队列", subtitle: "\(pasteQueueCount) 条待粘贴", padding: 14) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        inspectorAction("显示 Pin", icon: "eye", action: onShowAllPins)
                        inspectorAction("隐藏 Pin", icon: "eye.slash", action: onHideAllPins)
                    }
                    HStack(spacing: 8) {
                        inspectorAction("关闭 Pin", icon: "xmark.circle", action: onCloseAllPins)
                        inspectorAction("粘贴队列", icon: "list.number", isEnabled: pasteQueueCount > 0, action: onOpenPasteQueue)
                    }
                }
            }
        }
    }

    private func selectedInspector(for item: CollectedItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSurfaceCard(title: "内容预览", subtitle: item.source.displayName, padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    if item.supportsThumbnail {
                        CollectedItemThumbnailView(item: item, height: 180, cornerRadius: 12)
                    }

                    Text(item.inspectorPreviewText)
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                }
            }

            AppSurfaceCard(title: "元信息", subtitle: "来源、设备和标签", padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    metricRow(title: "来源", value: item.source.displayName)
                    metricRow(title: "应用", value: item.sourceApplication?.nilIfEmpty ?? "未知")
                    metricRow(title: "设备", value: item.sourceDevice?.nilIfEmpty ?? "本机")
                    metricRow(title: "创建", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    metricRow(title: "类型", value: item.contentType.displayName)
                    if item.contentType == .link {
                        metricRow(title: "站点", value: item.linkHost ?? "未知")
                    }
                    if item.supportsFileSize {
                        fileSizeMetricRow(item)
                    }
                    metricRow(title: "项目", value: item.projectID?.nilIfEmpty ?? "未归档")
                    tagWrap(tags: item.tags)
                }
            }

            AppSurfaceCard(title: "AI", subtitle: activeAIAction == nil ? "结构化处理当前内容" : "正在处理，请稍候", padding: 14) {
                VStack(spacing: 8) {
                    aiAction("自动标题", icon: "textformat.size", action: .generateTitle, item: item)
                    aiAction("摘要", icon: "sparkles", action: .summarize, item: item)
                    aiAction("提取待办", icon: "checklist", action: .extractTodos, item: item)
                    aiAction("提取日程", icon: "calendar.badge.plus", action: .extractSchedule, item: item)
                    aiAction("润色", icon: "wand.and.stars", action: .polish, item: item)
                    inspectorAction("发送给 Agent", icon: "paperplane", isEnabled: isPerformingWorkflow == false) {
                        onWorkflow(.sendToAgent, item)
                    }
                }
            }

            AppSurfaceCard(title: "去向", subtitle: "可执行操作优先接通", padding: 14) {
                VStack(spacing: 8) {
                    if item.id.origin == .clipboardItem {
                        inspectorAction("保存到收集箱", icon: "tray.and.arrow.down") { onSaveClipboard(item) }
                        inspectorAction("加入粘贴队列", icon: "text.insert") { onEnqueuePaste(item) }
                    }
                    inspectorAction("转任务", icon: "checkmark.square", isEnabled: isPerformingWorkflow == false) { onWorkflow(.createTask, item) }
                    inspectorAction("添加到日程", icon: "calendar", isEnabled: isPerformingWorkflow == false) { onWorkflow(.createSchedule, item) }
                    inspectorAction("保存到知识库", icon: "books.vertical", isEnabled: isPerformingWorkflow == false) { onWorkflow(.saveToKnowledge, item) }
                    inspectorAction("导出 Markdown", icon: "doc.plaintext", isEnabled: isPerformingWorkflow == false) { onWorkflow(.exportMarkdown, item) }
                }
            }
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func fileSizeMetricRow(_ item: CollectedItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("大小")
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer(minLength: 8)
            CollectedItemFileSizeView(item: item)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
    }

    private func guidanceLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle()
                .fill(AppSurfaceTokens.accentBlue.opacity(0.72))
                .frame(width: 5, height: 5)
                .padding(.top, 5)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tagWrap(tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            if tags.isEmpty {
                Text("无标签")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppSurfaceTokens.cardBackground.opacity(0.78)))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inspectorAction(
        _ title: String,
        icon: String,
        isEnabled: Bool = true,
        disabledReason: String = "当前操作暂不可用",
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isEnabled ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText.opacity(0.72))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground.opacity(isEnabled ? 0.82 : 0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
        .accessibilityLabel(title)
        .help(isEnabled ? title : disabledReason)
        .accessibilityHint(isEnabled ? title : disabledReason)
    }

    private func aiAction(
        _ title: String,
        icon: String,
        action: CollectedItemAIAction,
        item: CollectedItem
    ) -> some View {
        inspectorAction(
            activeAIAction == action ? "\(title)处理中…" : title,
            icon: activeAIAction == action ? "hourglass" : icon,
            isEnabled: isPerformingWorkflow == false,
            disabledReason: "已有内容操作正在处理中"
        ) {
            onAI(action, item)
        }
    }

    private func fixedActionFooter(for item: CollectedItem) -> some View {
        VStack(spacing: 10) {
            Divider()

            HStack(spacing: 8) {
                Button {
                    onPinToggle(item)
                } label: {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(item.isPinned ? "取消 Pin" : "Pin")

                Button {
                    onFavoriteToggle(item)
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(item.isFavorite ? "取消收藏" : "收藏")

                Button("归档") {
                    onArchive(item)
                }
                .buttonStyle(.borderless)

                Spacer(minLength: 0)

                Button("删除", role: .destructive) {
                    onDelete(item)
                }
                .buttonStyle(.borderless)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }
}

private struct CollectedInboxItemCard: View {
    let item: CollectedItem
    let presentation: CollectedInboxCardPresentation
    let density: CollectedInboxDensity
    let isSelected: Bool
    let isBatchSelected: Bool
    let onSelect: () -> Void
    let onToggleBatch: () -> Void
    let onPinToggle: () -> Void
    let onFavoriteToggle: () -> Void
    let onArchive: () -> Void
    let onSaveClipboard: () -> Void
    let onEnqueuePaste: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var previewText: String {
        if let previewText = item.previewText, previewText.isEmpty == false {
            return previewText
        }

        switch item.content {
        case .text(let text), .audio(let text):
            return text ?? ""
        case .link(let urlString, let title):
            return [title, urlString].compactMap { $0 }.joined(separator: "\n")
        case .image(_, let caption), .video(_, let caption):
            return caption ?? ""
        case .file(let path, let name), .document(let path, let name):
            return name ?? path ?? ""
        case .code(let language, let text):
            return [language, text].compactMap { $0 }.joined(separator: "\n")
        case .richText(_, let plainText), .unknown(let plainText):
            return plainText ?? ""
        }
    }

    var body: some View {
        Button(action: onSelect) {
            if presentation == .list {
                listBody
            } else {
                gridBody
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu { menuItems }
        .accessibilityLabel(accessibilityTitle)
        .accessibilityHint("按 Return 或 Space 打开预览，按 Delete 删除。")
    }

    private var gridBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            previewPanel
                .frame(height: 72)
            footer
        }
        .padding(12)
        .frame(maxWidth: 300, minHeight: 188, maxHeight: 188, alignment: .topLeading)
        .background(cardBackground)
        .overlay(selectionOverlay)
    }

    private var listBody: some View {
        HStack(alignment: .top, spacing: 12) {
            if item.contentType == .link {
                CollectedLinkSiteIconView(item: item, size: 34)
            } else if item.supportsThumbnail {
                CollectedItemThumbnailView(item: item, height: 56, cornerRadius: 10)
                    .frame(width: 72)
            } else {
                contentIcon
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(item.contentType.tint.opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: density == .compact ? 3 : 6) {
                HStack(spacing: 8) {
                    Text(item.title ?? item.contentType.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)

                    statusPill

                    Spacer(minLength: 0)

                    actionButtons
                }

                Text(previewText.isEmpty ? "无预览内容" : previewText)
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if density == .standard {
                    metadataLine
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, density == .compact ? 7 : 10)
        .frame(maxWidth: .infinity, minHeight: density.rowHeight, maxHeight: density.rowHeight, alignment: .topLeading)
        .background(cardBackground)
        .overlay(selectionOverlay)
    }

    private var header: some View {
        HStack(spacing: 8) {
            contentIcon

            Text(item.contentType.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            statusPill

            Spacer(minLength: 0)

            actionButtons
        }
    }

    @ViewBuilder
    private var previewPanel: some View {
        if item.contentType == .link {
            HStack(alignment: .top, spacing: 10) {
                CollectedLinkSiteIconView(item: item, size: 36)

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title ?? item.linkHost ?? "链接")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)

                    Text(item.linkHost ?? item.originalURL ?? "未知站点")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(nsColor: .systemTeal))
                        .lineLimit(1)

                    Text(previewText.isEmpty ? "无链接摘要" : previewText)
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(Color(nsColor: .systemTeal).opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.18), lineWidth: 1)
            )
        } else if item.supportsThumbnail {
            CollectedItemThumbnailView(
                item: item,
                height: 72,
                cornerRadius: AppSurfaceTokens.inlineBlockRadius
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title ?? item.contentType.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(previewText.isEmpty ? "无预览内容" : previewText)
                    .font(item.contentType == .code ? .system(size: 12, design: .monospaced) : .system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(item.contentType == .text ? 5 : 3)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(item.contentType.tint.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataLine

            if item.tags.isEmpty == false {
                HStack(spacing: 6) {
                    ForEach(item.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppSurfaceTokens.cardBackground.opacity(0.75)))
                    }
                }
            }
        }
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            Label(item.source.displayName, systemImage: item.source.iconName)
            Text("·")
            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
            if let sourceApplication = item.sourceApplication, sourceApplication.isEmpty == false {
                Text("·")
                Text(sourceApplication)
            }
            if item.supportsFileSize {
                Text("·")
                CollectedItemFileSizeView(item: item)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(AppSurfaceTokens.secondaryText)
        .lineLimit(1)
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            Button(action: onToggleBatch) {
                Image(systemName: isBatchSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isBatchSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isBatchSelected ? "取消批量选择" : "加入批量选择")

            Button(action: onPinToggle) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(item.isPinned ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isPinned ? "取消 Pin" : "Pin")

            Button(action: onFavoriteToggle) {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(item.isFavorite ? Color(nsColor: .systemYellow) : AppSurfaceTokens.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isFavorite ? "取消收藏" : "收藏")
        }
        .font(.system(size: 12, weight: .semibold))
        .opacity(isHovered || isSelected || isBatchSelected || item.isPinned || item.isFavorite ? 1 : 0.74)
    }

    private var contentIcon: some View {
        Image(systemName: item.contentType.iconName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(item.contentType.tint)
            .accessibilityHidden(true)
    }

    private var statusPill: some View {
        Label(item.processingStatus.displayName, systemImage: item.processingStatus.accessibilityIconName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(item.processingStatus.tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(item.processingStatus.tint.opacity(0.10)))
            .accessibilityLabel("状态：\(item.processingStatus.displayName)")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.09) : AppSurfaceTokens.cardBackgroundSoft)
            .shadow(color: AppSurfaceTokens.separator.opacity(isHovered ? 0.16 : 0.07), radius: isHovered ? 7 : 3, x: 0, y: 2)
    }

    private var selectionOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.separator.opacity(isHovered ? 0.72 : 0.42), lineWidth: isSelected ? 1.5 : 1)
    }

    @ViewBuilder
    private var menuItems: some View {
        Button(item.isPinned ? "取消 Pin" : "Pin", action: onPinToggle)
        Button(item.isFavorite ? "取消收藏" : "收藏", action: onFavoriteToggle)
        Button("归档", action: onArchive)
        if item.id.origin == .clipboardItem {
            Button("保存到收集箱", action: onSaveClipboard)
            Button("加入粘贴队列", action: onEnqueuePaste)
        }
        Divider()
        Button("删除", role: .destructive, action: onDelete)
    }

    private var accessibilityTitle: String {
        var parts = [
            item.title ?? item.contentType.displayName,
            item.contentType.displayName,
            item.source.displayName,
            "状态 \(item.processingStatus.displayName)",
            item.createdAt.formatted(date: .abbreviated, time: .shortened)
        ]
        if item.isPinned {
            parts.append("已 Pin")
        }
        if item.isFavorite {
            parts.append("已收藏")
        }
        if isBatchSelected {
            parts.append("已加入批量选择")
        }
        if previewText.isEmpty == false {
            parts.append("预览 \(previewText.prefix(80))")
        }
        return parts.joined(separator: "，")
    }
}

private extension ProcessingStatus {
    var accessibilityIconName: String {
        switch self {
        case .pending, .captured:
            return "clock"
        case .processing:
            return "hourglass"
        case .refined, .exported:
            return "checkmark.circle.fill"
        case .archived:
            return "archivebox.fill"
        case .deleted:
            return "trash.fill"
        }
    }
}

private extension InboxQuickFilter {
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .pending: return "待整理"
        case .pinned: return "Pin"
        case .favorites: return "收藏"
        case .recent: return "最近更新"
        }
    }

    var iconName: String {
        switch self {
        case .all: return "tray"
        case .pending: return "clock"
        case .pinned: return "pin"
        case .favorites: return "star"
        case .recent: return "clock.arrow.circlepath"
        }
    }
}

private extension CollectedItemSort {
    var displayName: String {
        switch self {
        case .newestFirst: return "最新优先"
        case .oldestFirst: return "最早优先"
        case .pinnedFirst: return "Pin 优先"
        case .recentlyUpdated: return "最近更新"
        }
    }
}

private extension CollectedContentType {
    var displayName: String {
        switch self {
        case .text: return "文本"
        case .link: return "链接"
        case .image: return "图片"
        case .file: return "文件"
        case .code: return "代码"
        case .richText: return "富文本"
        case .video: return "视频"
        case .audio: return "音频"
        case .document: return "文档"
        case .unknown: return "未知"
        }
    }

    var iconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .richText: return "doc.richtext"
        case .video: return "video"
        case .audio: return "waveform"
        case .document: return "doc.text"
        case .unknown: return "questionmark.square"
        }
    }

    var tint: Color {
        switch self {
        case .text, .richText, .document:
            return AppSurfaceTokens.accentBlue
        case .link:
            return Color(nsColor: .systemTeal)
        case .image, .video:
            return Color(nsColor: .systemPurple)
        case .file:
            return Color(nsColor: .systemIndigo)
        case .code:
            return Color(nsColor: .systemGreen)
        case .audio:
            return Color(nsColor: .systemOrange)
        case .unknown:
            return AppSurfaceTokens.secondaryText
        }
    }
}

private extension CollectionSource {
    var displayName: String {
        switch self {
        case .clipboard: return "剪贴板"
        case .phoneSync: return "手机同步"
        case .voice: return "说入法"
        case .screenshotOCR: return "截图 OCR"
        case .agent: return "Agent"
        case .manual: return "手动添加"
        case .webpage: return "网页"
        case .file: return "文件"
        case .capsule: return "灵动大陆"
        case .imported: return "导入"
        }
    }

    var iconName: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .phoneSync: return "iphone"
        case .voice: return "mic"
        case .screenshotOCR: return "camera.viewfinder"
        case .agent: return "sparkles"
        case .manual: return "square.and.pencil"
        case .webpage: return "globe"
        case .file: return "folder"
        case .capsule: return "capsule"
        case .imported: return "tray.and.arrow.down"
        }
    }
}

private extension ProcessingStatus {
    var displayName: String {
        switch self {
        case .pending: return "待整理"
        case .captured: return "已采集"
        case .processing: return "处理中"
        case .refined: return "已提炼"
        case .archived: return "已归档"
        case .exported: return "已导出"
        case .deleted: return "已删除"
        }
    }

    var tint: Color {
        switch self {
        case .pending, .captured:
            return Color(nsColor: .systemOrange)
        case .processing:
            return AppSurfaceTokens.accentBlue
        case .refined:
            return Color(nsColor: .systemGreen)
        case .archived:
            return AppSurfaceTokens.secondaryText
        case .exported:
            return Color(nsColor: .systemTeal)
        case .deleted:
            return Color(nsColor: .systemRed)
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .captured: return "tray.and.arrow.down"
        case .processing: return "gearshape.2"
        case .refined: return "checkmark.circle"
        case .archived: return "archivebox"
        case .exported: return "square.and.arrow.up"
        case .deleted: return "trash"
        }
    }
}

private extension ClipboardMonitoringState {
    var displayName: String {
        switch self {
        case .active: return "监听中"
        case .paused: return "已暂停"
        case .stopped: return "未启动"
        case .unavailable: return "监听不可用"
        }
    }

    var iconName: String {
        switch self {
        case .active: return "wave.3.right.circle.fill"
        case .paused: return "pause.circle.fill"
        case .stopped: return "stop.circle"
        case .unavailable: return "exclamationmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .active: return Color(nsColor: .systemGreen)
        case .paused: return Color(nsColor: .systemOrange)
        case .stopped, .unavailable: return AppSurfaceTokens.secondaryText
        }
    }

    var canToggle: Bool {
        self == .active || self == .paused
    }

    var helpText: String {
        switch self {
        case .active: return "剪贴板监听中，点击暂停"
        case .paused: return "剪贴板监听已暂停，点击恢复"
        case .stopped: return "剪贴板监听尚未启动"
        case .unavailable: return "当前环境不提供剪贴板监听"
        }
    }
}

private extension Set {
    mutating func toggleMembership(_ member: Element) {
        if contains(member) {
            remove(member)
        } else {
            insert(member)
        }
    }
}

private extension CollectedItem {
    var linkURL: URL? {
        let rawURL: String?
        switch content {
        case .link(let urlString, _):
            rawURL = urlString ?? originalURL
        default:
            rawURL = originalURL
        }

        guard let value = rawURL?.nilIfEmpty else { return nil }
        return URL(string: value)
    }

    var linkHost: String? {
        linkURL?.host?.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }

    var faviconURL: URL? {
        guard let linkURL, let scheme = linkURL.scheme, let host = linkURL.host else { return nil }
        var components = URLComponents()
        components.scheme = scheme == "http" ? "http" : "https"
        components.host = host
        components.port = linkURL.port
        components.path = "/favicon.ico"
        return components.url
    }

    var supportsFileSize: Bool {
        contentType == .file || contentType == .document || contentType == .video || thumbnailAssetID != nil
    }

    var supportsThumbnail: Bool {
        thumbnailAssetID != nil || thumbnailFileURL != nil
    }

    var thumbnailAssetID: String? {
        switch content {
        case .image(let assetID, _):
            return assetID?.nilIfEmpty ?? assetFileIDs.first?.nilIfEmpty
        default:
            return contentType == .image ? assetFileIDs.first?.nilIfEmpty : nil
        }
    }

    var thumbnailFileURL: URL? {
        let path: String?
        switch content {
        case .file(let filePath, _), .document(let filePath, _), .video(let filePath, _):
            path = filePath
        default:
            path = nil
        }

        guard let resolvedPath = path?.nilIfEmpty else { return nil }
        return URL(fileURLWithPath: resolvedPath)
    }

    var thumbnailCacheKey: String? {
        if let assetID = thumbnailAssetID {
            return "asset:\(assetID)"
        }
        if let fileURL = thumbnailFileURL {
            return "file:\(fileURL.path)"
        }
        return nil
    }

    var inspectorPreviewText: String {
        if let previewText, previewText.isEmpty == false {
            return previewText
        }

        switch content {
        case .text(let text), .audio(let text):
            return text?.nilIfEmpty ?? "暂无文本内容"
        case .link(let urlString, let title):
            return [title, urlString].compactMap { $0?.nilIfEmpty }.joined(separator: "\n").nilIfEmpty ?? "暂无链接预览"
        case .image(_, let caption), .video(_, let caption):
            return caption?.nilIfEmpty ?? "暂无媒体说明"
        case .file(let path, let name), .document(let path, let name):
            return [name, path].compactMap { $0?.nilIfEmpty }.joined(separator: "\n").nilIfEmpty ?? "暂无文件预览"
        case .code(let language, let text):
            return [language, text].compactMap { $0?.nilIfEmpty }.joined(separator: "\n\n").nilIfEmpty ?? "暂无代码内容"
        case .richText(_, let plainText), .unknown(let plainText):
            return plainText?.nilIfEmpty ?? "暂无预览内容"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
