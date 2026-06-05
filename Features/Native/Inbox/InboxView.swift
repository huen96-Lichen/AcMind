import SwiftUI
import AcMindKit

struct InboxView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = InboxViewModel()
    @State private var selectedSidebarItem: String? = "all"
    @State private var selectedItem: SourceItem?
    @State private var searchQuery = ""

    private var sidebarSections: [SecondarySidebarSection] {
        [
            SecondarySidebarSection(
                id: "source",
                title: "来源",
                items: [
                    SecondarySidebarItem(id: "all", title: "全部", icon: "tray", badge: "\(viewModel.items.count)"),
                    SecondarySidebarItem(id: "voice", title: "说入法", icon: "mic"),
                    SecondarySidebarItem(id: "screenshot", title: "截图 / OCR", icon: "camera.viewfinder"),
                    SecondarySidebarItem(id: "clipboard", title: "剪贴板", icon: "doc.on.clipboard"),
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
            switch selectedSidebarItem {
            case "voice": matchesSource = item.type == .audio
            case "screenshot": matchesSource = item.type == .screenshot
            case "clipboard": matchesSource = item.type == .text
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
        HSplitView {
            SecondarySidebarWithHeader(
                title: "收集箱",
                subtitle: "\(viewModel.items.count) 条内容",
                sections: sidebarSections,
                selectedItem: $selectedSidebarItem
            )
            .frame(width: 220)

            itemList
        }
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
        .frame(minWidth: 320)
    }

    private func inboxColumns(availableWidth: CGFloat) -> [GridItem] {
        MaterialCardGridLayout.columns(availableWidth: availableWidth, minimumColumnWidth: 240)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField("搜索收集箱...", text: $searchQuery)
                .textFieldStyle(.plain)

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
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

    @MainActor
    private func focusPendingCaptureDetailIfNeeded() async {
        guard let pendingItemID = appState.pendingInboxDetailSourceItemID else { return }

        if let item = viewModel.items.first(where: { $0.id == pendingItemID }) {
            selectedSidebarItem = "all"
            selectedItem = item
            appState.pendingInboxDetailSourceItemID = nil
        }
    }
}
