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

            if let item = selectedItem {
                detailPanel(item: item)
                    .frame(width: 300)
            }
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
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredItems) { item in
                            InboxItemRow(
                                item: item,
                                isSelected: selectedItem?.id == item.id,
                                onSelect: { selectedItem = item }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(minWidth: 300)
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

    private func detailPanel(item: SourceItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("详情")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { selectedItem = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    itemHeader(item: item)
                    itemContent(item: item)
                    itemActions(item: item)
                }
                .padding(16)
            }
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private func itemHeader(item: SourceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.type.iconName)
                    .foregroundStyle(item.type.color)
                Text(item.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let title = item.title {
                Text(title)
                    .font(.headline)
            }

            Text(item.createdAt.formatted())
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.7))
        )
    }

    private func itemContent(item: SourceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("内容预览")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(item.previewText ?? item.transcript ?? "无预览内容")
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppSurfaceTokens.cardBackground))
        }
    }

    private func itemActions(item: SourceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("操作")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                actionButton(icon: "sparkles", title: "AI 提炼") {
                    Task { await viewModel.distillItem(item) }
                }
                actionButton(icon: "archivebox", title: "归档") {
                    Task { await viewModel.archive(item: item) }
                }
                actionButton(icon: "rectangle.on.rectangle", title: "工作台") {
                    Task { await viewModel.moveToWorkbench(item: item) }
                }
                actionButton(icon: "brain", title: "知识库") {
                    Task { await viewModel.sendToKnowledgeBase(item: item) }
                }
                actionButton(icon: "trash", title: "删除", role: .destructive) {
                    Task { await viewModel.delete(item: item) }
                }
            }
        }
    }

    private func actionButton(icon: String, title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(AppSurfaceTokens.cardBackground))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
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

struct InboxItemRow: View {
    let item: SourceItem
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: item.type.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(item.type.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title ?? item.previewText ?? "未命名")
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? .white : .primary)

                    HStack(spacing: 4) {
                        Text(item.type.displayName)
                            .font(.system(size: 10))
                        Text("·")
                            .font(.system(size: 10))
                        Text(item.createdAt.formatted(.relative(presentation: .named)))
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : (isHovered ? AppSurfaceTokens.cardBackgroundSoft : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 8)
    }
}
