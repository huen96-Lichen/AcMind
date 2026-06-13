import SwiftUI
import AcMindKit

struct InboxView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = InboxViewModel()
    @State private var selectedItem: SourceItem?
    @State private var searchQuery = ""
    let clipboardPinActions: ClipboardPinActions

    init(clipboardPinActions: ClipboardPinActions) {
        self.clipboardPinActions = clipboardPinActions
    }

    private var selectedSidebarItem: Binding<String?> {
        Binding(
            get: { appState.inboxWorkspaceSelection },
            set: { appState.inboxWorkspaceSelection = $0 ?? "all" }
        )
    }

    private var sidebarSections: [SecondarySidebarSection] {
        [
            SecondarySidebarSection(
                id: "workspace",
                title: "工作区",
                items: [
                    SecondarySidebarItem(id: "all", title: "收集箱", icon: "tray", badge: "\(viewModel.items.count)"),
                    SecondarySidebarItem(id: "clipboardWorkspace", title: "剪贴板 & 手机同步", icon: "doc.on.clipboard")
                ]
            ),
            SecondarySidebarSection(
                id: "source",
                title: "来源",
                items: [
                    SecondarySidebarItem(id: "voice", title: "说入法", icon: "mic"),
                    SecondarySidebarItem(id: "screenshot", title: "截图 / OCR", icon: "camera.viewfinder"),
                    SecondarySidebarItem(id: "clipboard", title: "剪贴板入箱", icon: "tray.and.arrow.down"),
                    SecondarySidebarItem(id: "agent", title: "Agent 生成", icon: "sparkles")
                ]
            ),
            SecondarySidebarSection(
                id: "status",
                title: "状态",
                items: [
                    SecondarySidebarItem(id: "pending", title: "待整理", icon: "clock"),
                    SecondarySidebarItem(id: "refined", title: "已提炼", icon: "checkmark.circle"),
                    SecondarySidebarItem(id: "archived", title: "已归档", icon: "archivebox"),
                    SecondarySidebarItem(id: "exported", title: "已导出", icon: "square.and.arrow.up")
                ]
            )
        ]
    }

    private var filteredItems: [SourceItem] {
        viewModel.items.filter { item in
            let matchesSearch = searchQuery.isEmpty ||
                (item.title?.lowercased().contains(searchQuery.lowercased()) ?? false) ||
                (item.previewText?.lowercased().contains(searchQuery.lowercased()) ?? false)

            let matchesSource: Bool
            switch selectedSidebarItem.wrappedValue {
            case "voice": matchesSource = item.source == .voice || item.type == .audio
            case "screenshot": matchesSource = item.source == .screenshot || item.type == .screenshot
            case "clipboard": matchesSource = item.source == .clipboard
            case "agent": matchesSource = item.isAgentGenerated
            case "pending": matchesSource = item.status == .pending
            case "refined": matchesSource = item.status == .distilled
            case "archived": matchesSource = item.status == .archived
            default: matchesSource = true
            }

            return matchesSearch && matchesSource
        }
    }

    var body: some View {
        if appState.inboxWorkspaceSelection == "clipboardWorkspace" {
            ClipboardView(
                clipboardPinActions: clipboardPinActions,
                returnToInboxAction: { appState.selectInboxWorkspace("all") }
            )
        } else {
            WorkspacePageShell(
                title: "收集箱",
                subtitle: "\(viewModel.items.count) 条内容",
                leadingRailWidth: 208,
                trailingRailWidth: 224,
                leadingRail: {
                    SecondarySidebarWithHeader(
                        title: "收集箱",
                        subtitle: "\(viewModel.items.count) 条内容",
                        sections: sidebarSections,
                        selectedItem: selectedSidebarItem
                    )
                },
                content: {
                    itemList
                },
                trailingRail: {
                    inboxSummaryRail
                }
            )
            .background(AppVisualBackdrop())
            .onAppear {
                Task {
                    await viewModel.loadItems()
                    await focusPendingCaptureDetailIfNeeded()
                }
            }
            .onChange(of: appState.pendingInboxDetailSourceItemID) { _, _ in
                Task {
                    await viewModel.loadItems()
                    await focusPendingCaptureDetailIfNeeded()
                }
            }
        }
    }

    private var itemList: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            if filteredItems.isEmpty {
                emptyState
            } else {
                GeometryReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: inboxColumns(availableWidth: proxy.size.width), spacing: 12) {
                            ForEach(filteredItems) { item in
                                InboxItemCard(
                                    item: item,
                                    isSelected: selectedItem?.id == item.id,
                                    onSelect: { selectedItem = item },
                                    onMore: { selectedItem = item }
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func inboxColumns(availableWidth: CGFloat) -> [GridItem] {
        MaterialCardGridLayout.columns(availableWidth: availableWidth, minimumColumnWidth: 240)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .font(.caption)

            TextField("搜索收集箱...", text: $searchQuery)
                .textFieldStyle(.plain)

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var emptyState: some View {
        AppSurfaceEmptyState(
            icon: "tray",
            title: "暂无收集内容",
            message: "通过语音、截图、剪贴板或 Agent 生成内容后，会先进入这里等待整理。",
            tint: AppSurfaceTokens.accentBlue
        )
    }

    private var inboxSummaryRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppSurfaceCard(title: "状态摘要", subtitle: "固定外壳下的轻量信息", padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        summaryRow(title: "全部", value: "\(viewModel.items.count)")
                        summaryRow(title: "当前筛选", value: "\(filteredItems.count)")
                        summaryRow(title: "已选中", value: selectedItem == nil ? "无" : "1")
                    }
                }

                AppSurfaceCard(title: "整理提示", subtitle: "只展示真实状态", padding: 14) {
                    Text(selectedItem == nil ? "请选择一条内容查看细节。" : (selectedItem?.status.displayName ?? "未知"))
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
    }

    @MainActor
    private func focusPendingCaptureDetailIfNeeded() async {
        guard let pendingItemID = appState.pendingInboxDetailSourceItemID else { return }

        if let item = viewModel.items.first(where: { $0.id == pendingItemID }) {
            appState.inboxWorkspaceSelection = "all"
            selectedItem = item
            appState.pendingInboxDetailSourceItemID = nil
        }
    }
}
