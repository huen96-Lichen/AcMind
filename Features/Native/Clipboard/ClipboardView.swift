import SwiftUI
import AppKit
import AcMindKit

struct ClipboardView: View {
    @StateObject private var viewModel = ClipboardViewModel()
    let clipboardPinActions: ClipboardPinActions
    @State private var selectedSidebarItem: String? = "all"
    @State private var viewMode: ViewMode = .grid
    @State private var selectedItem: ClipboardItem?
    @State private var pinWindowCount: Int = 0
    private let contentTypeFilters: [ClipboardContentType?] = [nil, .text, .image, .file, .url]

    init(clipboardPinActions: ClipboardPinActions) {
        self.clipboardPinActions = clipboardPinActions
    }

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
        }
        .background(AppSurfaceTokens.background)
        .onAppear {
            refreshPinWindowCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .acmindClipboardPinWindowsChanged)) { _ in
            refreshPinWindowCount()
        }
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
                pinWindowManagementCluster
                pinWindowCountBadge

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

    private var pinWindowManagementCluster: some View {
        HStack(spacing: 6) {
            managementButton(title: "全部显示", icon: "rectangle.stack.badge.play") {
                clipboardPinActions.showAll()
            }
            managementButton(title: "全部隐藏", icon: "rectangle.stack.badge.minus") {
                clipboardPinActions.hideAll()
            }
            managementButton(title: "全部关闭", icon: "xmark.circle") {
                clipboardPinActions.closeAll()
            }
            managementButton(title: "复制诊断", icon: "doc.text.magnifyingglass") {
                clipboardPinActions.copyDiagnostics()
            }
        }
    }

    private func managementButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var pinWindowCountBadge: some View {
        return HStack(spacing: 6) {
            Image(systemName: "pin")
                .font(.system(size: 11, weight: .medium))
            Text("Pin \(pinWindowCount)")
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(pinWindowCount > 0 ? Color.orange.opacity(0.12) : AppSurfaceTokens.cardBackgroundSoft)
        )
        .foregroundStyle(pinWindowCount > 0 ? Color.orange : .secondary)
    }

    private func refreshPinWindowCount() {
        pinWindowCount = (NSApp.delegate as? AppDelegate)?.clipboardPinWindowCount() ?? 0
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
        GeometryReader { proxy in
            ScrollView {
                LazyVGrid(columns: clipboardColumns(availableWidth: proxy.size.width, minimumWidth: 240), spacing: ContentCardPresentation.cardSpacing) {
                    ForEach(viewModel.filteredItems) { item in
                        ClipboardItemCard(
                            item: item,
                            isSelected: selectedItem?.id == item.id,
                            onSelect: { selectedItem = item },
                            onCopy: { Task { await viewModel.copyItem(id: item.id) } },
                            onPin: { pinItemToDesktop(item) },
                            onUnpin: { Task { await viewModel.unpinItem(id: item.id) } },
                            onDelete: { deleteClipboardItem(item) }
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    private var clipboardGrid: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVGrid(columns: clipboardColumns(availableWidth: proxy.size.width, minimumWidth: 220), spacing: ContentCardPresentation.cardSpacing) {
                    ForEach(viewModel.filteredItems) { item in
                        ClipboardItemCard(
                            item: item,
                            isSelected: selectedItem?.id == item.id,
                            onSelect: { selectedItem = item },
                            onCopy: {
                                Task { await viewModel.copyItem(id: item.id) }
                            },
                            onPin: {
                                pinItemToDesktop(item)
                            },
                            onUnpin: { Task { await viewModel.unpinItem(id: item.id) } },
                            onDelete: { deleteClipboardItem(item) }
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    private func clipboardColumns(availableWidth: CGFloat, minimumWidth: CGFloat) -> [GridItem] {
        MaterialCardGridLayout.columns(availableWidth: availableWidth, minimumColumnWidth: minimumWidth)
    }

    private func pinItemToDesktop(_ item: ClipboardItem) {
        clipboardPinActions.showItem(item)
        Task {
            await viewModel.pinItem(id: item.id)
        }
    }

    private func deleteClipboardItem(_ item: ClipboardItem) {
        if selectedItem?.id == item.id {
            selectedItem = nil
        }
        Task {
            await viewModel.deleteItem(id: item.id)
        }
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

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onPin: () -> Void
    let onUnpin: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    private var metadata: MaterialCardMetadata {
        MaterialCardMetadataFactory.clipboard(item: item)
    }
    private var previewHeight: CGFloat {
        ContentCardPresentation.previewHeight(for: item.type, text: ClipboardCardPresentation.previewText(for: item))
    }
    private var cardHeightValue: CGFloat {
        ContentCardPresentation.cardHeight(
            for: item.type,
            text: ClipboardCardPresentation.previewText(for: item)
        )
    }

    var body: some View {
        MaterialCardShell(
            isSelected: isSelected,
            isHovered: isHovered,
            cardHeight: cardHeightValue,
            onSelect: onSelect,
            header: { headerBar },
            preview: { previewBody },
            footer: { cardMetadata },
            actions: { actionBar }
        )
        .onHover { isHovered = $0 }
        .contextMenu { contextMenuItems }
    }

    private var cardMetadata: some View {
        HStack(spacing: 6) {
            Text(metadata.subtitle)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)

            Text("·")
                .font(.caption)
                .foregroundStyle(Color(NSColor.tertiaryLabelColor))

            Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: ContentCardPresentation.materialMetadataMinHeight, alignment: .topLeading)
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: item.type.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(item.type.color)

            Text(item.type.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            if item.isPinned {
                Text("Pinned")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.10)))
            }

            Spacer(minLength: 0)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button(action: onPin) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppSurfaceTokens.cardBackground.opacity(0.92)))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.orange)
            .contentShape(Circle())
            .help("Pin 到桌面")
            .accessibilityLabel(Text("Pin 悬浮窗"))
            .accessibilityHint(Text("将这条剪贴板内容固定为最前端的小窗口"))

            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppSurfaceTokens.cardBackground.opacity(0.92)))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(AppSurfaceTokens.secondaryText)
            .contentShape(Circle())
            .help("复制")
            .accessibilityLabel(Text("复制内容"))
            .accessibilityHint(Text("将当前内容复制回系统剪贴板"))
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Pin 到桌面", action: onPin)
        Button("复制内容", action: onCopy)

        if item.isPinned {
            Button("取消列表固定", action: onUnpin)
        }

        Divider()

        Button("删除", role: .destructive, action: onDelete)
    }

    @ViewBuilder
    private var previewBody: some View {
        if item.type == .image {
            ClipboardItemThumbnailView(
                item: item,
                size: CGSize(width: 0, height: previewHeight),
                cornerRadius: ContentCardPresentation.previewRadius,
                expandToWidth: true
            )
            .frame(maxWidth: .infinity)
            .frame(height: previewHeight)
        } else {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                    .fill(item.type.color.opacity(0.10))

                VStack(alignment: .leading, spacing: 12) {
                    Text(ClipboardCardPresentation.previewText(for: item))
                        .font(.system(size: 14))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.92)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                }
                .padding(14)
            }
            .frame(height: previewHeight)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                    .stroke(item.type.color.opacity(0.18), lineWidth: 1)
            )
            .clipped()
        }
    }

}

struct ClipboardItemThumbnailView: View {
    let item: ClipboardItem
    let size: CGSize
    let cornerRadius: CGFloat
    var expandToWidth: Bool = false

    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if item.type == .image, let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(item.type.color.opacity(0.12))

                    Image(systemName: item.type.icon)
                        .font(.system(size: expandToWidth ? 26 : 16, weight: .medium))
                        .foregroundStyle(item.type.color)
                }
            }
        }
        .frame(
            width: expandToWidth ? nil : size.width,
            height: size.height > 0 ? size.height : (expandToWidth ? 160 : size.height)
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator, lineWidth: 1)
        )
        .task(id: item.id) {
            await loadThumbnailIfNeeded()
        }
    }

    private func loadThumbnailIfNeeded() async {
        guard item.type == .image, let assetId = item.content, ServiceContainer.isInitialized() else { return }
        guard let asset = try? await ServiceContainer.shared.assetStore.getAsset(id: assetId) else { return }
        let maxPixelSize = max(ContentCardPresentation.thumbnailHeight * 2.4, 480)
        guard let image = await ServiceContainer.shared.assetStore.loadImage(asset: asset, maxPixelSize: maxPixelSize) else { return }
        await MainActor.run {
            thumbnail = image
        }
    }
}
