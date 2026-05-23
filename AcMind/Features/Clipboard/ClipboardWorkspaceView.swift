import AppKit
import SwiftUI
import AcMindKit

struct ClipboardWorkspaceView: View {
    @StateObject private var viewModel: ClipboardViewModel
    @EnvironmentObject private var toastManager: ToastManager
    @State private var selectedFilter: ClipboardFilterCategory = .all
    @State private var selectedItemID: String?
    @State private var searchText = ""
    @State private var showDeleteConfirm = false

    init(container: ServiceContainer, toastManager: ToastManager) {
        self._viewModel = StateObject(wrappedValue: ClipboardViewModel(container: container, toastManager: toastManager))
    }

    var body: some View {
        ACWorkspaceShell(
            title: "剪贴板",
            subtitle: "真实保存当前剪贴板、收藏、删除、搜索和回填复制。",
            trailing: {
                HStack(spacing: 12) {
                    ACSearchField("搜索剪贴板", text: $searchText, width: 220, height: ACLayout.controlHeight)
                    ACButton("保存当前剪贴板", kind: .primary, minWidth: 120) {
                        Task {
                            await viewModel.saveCurrentClipboard()
                            selectedItemID = viewModel.items.first?.id
                        }
                    }
                }
            },
            left: { sidebar },
            center: { centerColumn },
            right: { detailPanel }
        )
        .task {
            await reload()
        }
        .onChange(of: selectedFilter) { _, newValue in
            if newValue == .pinned {
                selectedItemID = filteredItems.first?.id
            } else {
                selectedItemID = filteredItems.first?.id
            }
        }
        .onChange(of: searchText) { _, _ in
            selectedItemID = filteredItems.first?.id
        }
        .confirmationDialog("清空全部剪贴板记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                Task {
                    await viewModel.clearAll()
                    selectedItemID = viewModel.items.first?.id
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会删除本地保存的剪贴板历史。")
        }
    }

    private var sidebar: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("智能分类")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                VStack(spacing: 8) {
                    ForEach(ClipboardFilterCategory.allCases) { category in
                        ClipboardFilterRow(
                            category: category,
                            selected: selectedFilter == category,
                            count: category.count(from: viewModel.items)
                        ) {
                            selectedFilter = category
                        }
                    }
                }

                Divider().overlay(ACColors.divider)

                VStack(alignment: .leading, spacing: 10) {
                    Text("批量操作")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)

                    ACButton("刷新记录", kind: .secondary) {
                        Task { await reload() }
                    }

                    ACButton("清空历史", kind: .ghost) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
    }

    private var centerColumn: some View {
        ACCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("剪贴板记录")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("\(filteredItems.count) 条结果")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    Spacer(minLength: 0)

                    ACBadge(selectedFilter.title, kind: .blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(ACColors.cardBackground)
                .overlay(alignment: .bottom) {
                    Divider().overlay(ACColors.divider)
                }

                if filteredItems.isEmpty {
                    ACEmptyState(
                        icon: "clipboard",
                        title: "没有可显示的剪贴板内容",
                        subtitle: "先点击右上角「保存当前剪贴板」，或者切换筛选条件。"
                    )
                    .frame(maxWidth: .infinity, minHeight: 420)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(groupedItems) { section in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(section.title)
                                        .font(ACTypography.captionMedium)
                                        .foregroundStyle(ACColors.secondaryText)
                                        .padding(.top, section.title == "今天" ? 0 : 6)

                                    VStack(spacing: 8) {
                                        ForEach(section.items) { item in
                                            Button {
                                                selectedItemID = item.id
                                            } label: {
                                                ClipboardRow(item: item, isSelected: selectedItemID == item.id)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var detailPanel: some View {
        ACDetailPanel(width: ACLayout.inspectorWidth, padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                if let selectedItem {
                    ClipboardDetailHeader(item: selectedItem)
                    ClipboardPreviewCard(item: selectedItem)
                    ClipboardActionGroup(
                        item: selectedItem,
                        copyAction: {
                            Task { await viewModel.copyItem(selectedItem) }
                        },
                        pinAction: {
                            Task { await viewModel.togglePinned(selectedItem) }
                        },
                        deleteAction: {
                            Task {
                                await viewModel.delete(selectedItem)
                                selectedItemID = filteredItems.first?.id
                            }
                        }
                    )
                    ClipboardMetadataTable(item: selectedItem)
                } else {
                    ACEmptyState(
                        icon: "clipboard",
                        title: "选择一条记录查看详情",
                        subtitle: "右侧会显示内容预览、复制、收藏和删除操作。"
                    )
                }
            }
        }
    }

    private var filteredItems: [ClipboardItem] {
        let items = viewModel.items.filter { item in
            let matchesCategory: Bool
            switch selectedFilter {
            case .all:
                matchesCategory = true
            case .pinned:
                matchesCategory = item.isPinned
            default:
                matchesCategory = item.type == selectedFilter.contentType
            }

            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let haystack = [item.content, item.textContent, item.sourceApp]
                    .compactMap { $0 }
                    .joined(separator: " ")
                matchesSearch = haystack.localizedCaseInsensitiveContains(searchText)
            }
            return matchesCategory && matchesSearch
        }

        return items.sorted { $0.createdAt > $1.createdAt }
    }

    private var groupedItems: [ClipboardSection] {
        let cal = Calendar.current
        let today = filteredItems.filter { cal.isDateInToday($0.createdAt) }
        let yesterday = filteredItems.filter { cal.isDateInYesterday($0.createdAt) }
        let earlier = filteredItems.filter { !cal.isDateInToday($0.createdAt) && !cal.isDateInYesterday($0.createdAt) }

        var sections: [ClipboardSection] = []
        if !today.isEmpty { sections.append(.init(title: "今天", items: today)) }
        if !yesterday.isEmpty { sections.append(.init(title: "昨天", items: yesterday)) }
        if !earlier.isEmpty { sections.append(.init(title: "更早", items: earlier)) }
        return sections
    }

    private var selectedItem: ClipboardItem? {
        if let selectedItemID, let item = filteredItems.first(where: { $0.id == selectedItemID }) {
            return item
        }
        return filteredItems.first
    }

    private func reload() async {
        await viewModel.load()
        if selectedItemID == nil {
            selectedItemID = filteredItems.first?.id
        } else if let currentSelectedItemID = selectedItemID, filteredItems.contains(where: { $0.id == currentSelectedItemID }) == false {
            selectedItemID = filteredItems.first?.id
        }
    }
}

private extension ClipboardItem {
    var title: String {
        if let textContent, !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(textContent.prefix(48))
        }
        if let content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(content.prefix(48))
        }
        return "未命名剪贴板"
    }

    var subtitle: String {
        if let textContent, !textContent.isEmpty {
            return textContent
        }
        if let content, !content.isEmpty {
            return content
        }
        return sourceApp ?? "系统剪贴板"
    }
}

private extension ClipboardContentType {
    var iconName: String {
        switch self {
        case .text: return "textformat"
        case .image: return "photo"
        case .file: return "doc"
        case .url: return "link"
        }
    }

    var tint: Color {
        switch self {
        case .text: return ACColors.accentBlue
        case .image: return ACColors.accentPurple
        case .file: return ACColors.accentOrange
        case .url: return ACColors.accentGreen
        }
    }

    var fill: Color {
        tint.opacity(0.12)
    }
}

private enum ClipboardFilterCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case text = "文本"
    case url = "链接"
    case file = "文件"
    case image = "图片"
    case pinned = "收藏"

    var id: String { rawValue }
    var title: String { rawValue }

    var contentType: ClipboardContentType? {
        switch self {
        case .text: return .text
        case .url: return .url
        case .file: return .file
        case .image: return .image
        case .all, .pinned: return nil
        }
    }

    var icon: String {
        switch self {
        case .all: return "doc.on.doc"
        case .text: return "textformat"
        case .url: return "link"
        case .file: return "doc"
        case .image: return "photo"
        case .pinned: return "star"
        }
    }

    func count(from items: [ClipboardItem]) -> Int {
        switch self {
        case .all:
            return items.count
        case .pinned:
            return items.filter(\.isPinned).count
        case .text, .url, .file, .image:
            return items.filter { $0.type == contentType }.count
        }
    }
}

private struct ClipboardSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [ClipboardItem]
}

private struct ClipboardFilterRow: View {
    let category: ClipboardFilterCategory
    let selected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ACTypeIcon(category.icon, tint: selected ? ACColors.accentBlue : ACColors.secondaryText, background: selected ? ACColors.selectedFill : ACColors.softFill, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text("\(count) 条")
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(selected ? ACColors.selectedFill : ACColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? ACColors.accentBlue.opacity(0.35) : ACColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ACTypeIcon(item.type.iconName, tint: item.type.tint, background: item.type.fill, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(Self.timeFormatter.string(from: item.createdAt))
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }

                Text(item.subtitle)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                ACBadge(item.type.displayName, kind: badgeKind(for: item.type))
                if item.isPinned {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ACColors.accentBlue)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: ACLayout.listRowHeight, alignment: .topLeading)
        .background(isSelected ? ACColors.selectedFill : ACColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? ACColors.accentBlue.opacity(0.3) : ACColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func badgeKind(for type: ClipboardContentType) -> ACBadge.Kind {
        switch type {
        case .text: return .blue
        case .url: return .green
        case .file: return .orange
        case .image: return .purple
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct ClipboardDetailHeader: View {
    let item: ClipboardItem
    @EnvironmentObject private var toastManager: ToastManager

    var body: some View {
        HStack(spacing: 12) {
            ACTypeIcon(item.type.iconName, tint: item.type.tint, background: item.type.fill, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(2)
                Text(item.sourceApp ?? "系统剪贴板")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }

            Spacer(minLength: 0)

            ACButton(item.isPinned ? "已收藏" : "收藏", kind: .ghost) {
                toastManager.show(.info, item.isPinned ? "收藏状态已开启" : "收藏状态可在列表中切换")
            }
        }
    }
}

private struct ClipboardPreviewCard: View {
    let item: ClipboardItem

    var body: some View {
        ACCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("预览")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                ScrollView {
                    Text(item.textContent ?? item.content ?? "暂无内容")
                        .font(ACTypography.body)
                        .foregroundStyle(ACColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(5)
                        .padding(16)
                        .textSelection(.enabled)
                }
                .frame(height: 250)
            }
        }
    }
}

private struct ClipboardActionGroup: View {
    let item: ClipboardItem
    let copyAction: () -> Void
    let pinAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .font(ACTypography.panelTitle)
                .foregroundStyle(ACColors.primaryText)

            HStack(spacing: 10) {
                ACButton("复制", kind: .primary, action: copyAction)
                ACButton(item.isPinned ? "取消收藏" : "收藏", kind: .secondary, action: pinAction)
                ACButton("删除", kind: .ghost, action: deleteAction)
            }
        }
    }
}

private struct ClipboardMetadataTable: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("信息表")
                .font(ACTypography.panelTitle)
                .foregroundStyle(ACColors.primaryText)

            ACInfoTable([
                .init("类型", value: item.type.displayName),
                .init("来源", value: item.sourceApp ?? "未知"),
                .init("创建时间", value: Self.dateFormatter.string(from: item.createdAt)),
                .init("字符数", value: "\(item.textContent?.count ?? item.content?.count ?? 0)"),
                .init("收藏状态", value: item.isPinned ? "已收藏" : "未收藏")
            ])
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
