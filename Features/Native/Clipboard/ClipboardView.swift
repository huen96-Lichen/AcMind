import SwiftUI
import AcMindKit

struct ClipboardView: View {
    @StateObject private var viewModel = ClipboardViewModel()
    @State private var selectedSidebarItem: String? = "all"
    @State private var viewMode: ViewMode = .list
    @State private var selectedItem: ClipboardItem?
    private let contentTypeFilters: [ClipboardContentType?] = [nil, .text, .image, .file, .url]

    private var sidebarSections: [SecondarySidebarSection] {
        [
            SecondarySidebarSection(
                id: "type",
                title: "类型",
                items: [
                    SecondarySidebarItem(id: "all", title: "全部", icon: "doc.on.doc", badge: "\(viewModel.items.count)"),
                    SecondarySidebarItem(id: "text", title: "文本", icon: "text.quote"),
                    SecondarySidebarItem(id: "link", title: "链接", icon: "link"),
                    SecondarySidebarItem(id: "image", title: "图片", icon: "photo"),
                    SecondarySidebarItem(id: "code", title: "代码", icon: "chevron.left.forwardslash.chevron.right")
                ]
            ),
            SecondarySidebarSection(
                id: "time",
                title: "时间",
                items: [
                    SecondarySidebarItem(id: "recent", title: "最近 24 小时", icon: "clock"),
                    SecondarySidebarItem(id: "favorite", title: "已收藏", icon: "star")
                ]
            ),
            SecondarySidebarSection(
                id: "experimental",
                title: "实验功能",
                items: [
                    SecondarySidebarItem(id: "phoneSync", title: "手机同步（实验）", icon: "iphone")
                ]
            )
        ]
    }

    var body: some View {
        HSplitView {
            SecondarySidebarWithHeader(
                title: "剪贴板 & 手机同步",
                subtitle: "\(viewModel.items.count) 条内容",
                sections: sidebarSections,
                selectedItem: $selectedSidebarItem
            )
            .frame(width: 220)

            contentArea

            if let item = selectedItem {
                detailPanel(item: item)
                    .frame(width: 280)
            }
        }
        .background(AppSurfaceTokens.background)
    }

    private var contentArea: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            filterBar

            if viewModel.filteredItems.isEmpty {
                emptyState
            } else {
                switch viewMode {
                case .list:
                    clipboardList
                case .grid:
                    clipboardGrid
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("剪贴板历史")
                        .font(.system(size: 17, weight: .semibold))

                    Text("\(viewModel.items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                Text("自动保存剪贴板内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                searchField

                viewModePicker

                Button {
                    Task { await viewModel.clearHistory() }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清空历史")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField("搜索...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .frame(width: 160)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            Button(action: { viewMode = .list }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12))
                    .padding(6)
                    .background(viewMode == .list ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundStyle(viewMode == .list ? Color.accentColor : Color.secondary)
                    .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .help("列表视图")

            Button(action: { viewMode = .grid }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12))
                    .padding(6)
                    .background(viewMode == .grid ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundStyle(viewMode == .grid ? Color.accentColor : Color.secondary)
                    .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .help("网格视图")
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(6)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(contentTypeFilters, id: \.self) { filter in
                    let isActive = viewModel.selectedType == filter
                    Button {
                        viewModel.selectedType = filter
                    } label: {
                        HStack(spacing: 4) {
                            if let icon = filter?.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 11))
                            }
                            Text(filter?.displayName ?? "全部")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isActive ? Color.accentColor : Color.secondary.opacity(0.1))
                        .foregroundStyle(isActive ? Color.white : Color.primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.3))

            Text("剪贴板为空")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("复制内容后将自动记录")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var clipboardList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.filteredItems) { item in
                    ClipboardItemRow(
                        item: item,
                        viewModel: viewModel,
                        isSelected: selectedItem?.id == item.id,
                        onSelect: { selectedItem = item }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var clipboardGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 280))], spacing: 12) {
                ForEach(viewModel.filteredItems) { item in
                    ClipboardItemCard(
                        item: item,
                        isSelected: selectedItem?.id == item.id,
                        onSelect: { selectedItem = item },
                        onCopy: {
                            Task { await viewModel.copyText(item.textContent ?? item.content ?? "") }
                        }
                    )
                }
            }
            .padding(16)
        }
    }

    private func detailPanel(item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("预览")
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
                    itemPreview(item: item)
                    itemMetadata(item: item)
                    itemActions(item: item)
                }
                .padding(16)
            }
        }
        .background(AppSurfaceTokens.cardBackground)
    }

    private func itemPreview(item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.type.icon)
                    .foregroundStyle(item.type.color)
                Text(item.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(item.textContent ?? item.content ?? "无内容")
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppSurfaceTokens.background))
        }
    }

    private func itemMetadata(item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("元数据")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                metadataRow(label: "来源", value: item.sourceApp ?? "未知")
                metadataRow(label: "时间", value: item.createdAt.formatted())
                metadataRow(label: "类型", value: item.type.displayName)
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(AppSurfaceTokens.background))
    }

    private func itemActions(item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("操作")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                actionButton(icon: "doc.on.doc", title: "复制到剪贴板") {
                    Task { await viewModel.copyItem(id: item.id) }
                }
                actionButton(icon: "pin", title: item.isPinned ? "取消固定" : "固定") {
                    Task {
                        if item.isPinned {
                            await viewModel.unpinItem(id: item.id)
                        } else {
                            await viewModel.pinItem(id: item.id)
                        }
                    }
                }
                actionButton(icon: "trash", title: "删除", role: .destructive) {
                    Task { await viewModel.deleteItem(id: item.id) }
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
            .background(RoundedRectangle(cornerRadius: 6).fill(AppSurfaceTokens.background))
        }
        .buttonStyle(.plain)
    }

    private func formatSize(_ length: Int) -> String {
        if length < 1024 {
            return "\(length) B"
        } else if length < 1024 * 1024 {
            return String(format: "%.1f KB", Double(length) / 1024)
        } else {
            return String(format: "%.1f MB", Double(length) / (1024 * 1024))
        }
    }
}

enum ViewMode {
    case list
    case grid
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    @ObservedObject var viewModel: ClipboardViewModel
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: item.type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(item.type.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.textContent ?? item.content ?? "无内容")
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

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
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

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    @State private var isHovered = false

    private var previewText: String {
        item.textContent ?? item.content ?? "无内容"
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(item.type.color.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: item.type.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(item.type.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.type.displayName)
                            .font(.system(size: 12, weight: .semibold))
                        Text(item.createdAt.formatted(.relative(presentation: .named)))
                            .font(.system(size: 11))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }

                    Spacer()

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }
                }

                Text(previewText)
                    .font(.system(size: 13))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    if let sourceApp = item.sourceApp, !sourceApp.isEmpty {
                        Text(sourceApp)
                            .font(.system(size: 11))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }

                    Spacer()

                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : (isHovered ? AppSurfaceTokens.cardBackgroundSoft : AppSurfaceTokens.cardBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : AppSurfaceTokens.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
