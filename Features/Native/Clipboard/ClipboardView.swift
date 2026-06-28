import SwiftUI
import AppKit
import AcMindKit

struct ClipboardView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @StateObject private var viewModel: ClipboardViewModel
    let clipboardPinActions: ClipboardPinActions
    let returnToInboxAction: (() -> Void)?
    @State private var selectedSidebarItem: String? = "all"
    @State private var viewMode: ViewMode = .grid
    @State private var selectedItem: ClipboardItem?
    @State private var pinWindowCount: Int = 0
    private let contentTypeFilters: [ClipboardContentType?] = [nil, .text, .image, .file, .url, .richText, .code, .video]

    init(clipboardPinActions: ClipboardPinActions, returnToInboxAction: (() -> Void)? = nil) {
        self.clipboardPinActions = clipboardPinActions
        self.returnToInboxAction = returnToInboxAction
        _viewModel = StateObject(wrappedValue: ClipboardViewModel(
            clipboardService: ServiceContainer.shared.clipboardService
        ))
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
                    SecondarySidebarItem(id: "richText", title: "富文本", icon: "doc.richtext"),
                    SecondarySidebarItem(id: "code", title: "代码", icon: "chevron.left.forwardslash.chevron.right"),
                    SecondarySidebarItem(id: "video", title: "视频", icon: "video")
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
        AcWorkShell(
            title: "剪贴板 & 手机同步",
            subtitle: "\(viewModel.items.count) 条内容",
            headerActions: AnyView(headerActions),
            leadingRailWidth: 208,
            trailingRailWidth: 224,
            leadingRail: {
                SecondarySidebar(
                    sections: sidebarSections,
                    selectedItem: $selectedSidebarItem,
                    footerAction: returnToInboxAction,
                    footerTitle: returnToInboxAction == nil ? nil : "返回收集箱",
                    footerIcon: returnToInboxAction == nil ? nil : "tray"
                )
                .padding(.top, 10)
            },
            content: {
                contentArea
            },
            trailingRail: {
                clipboardSummaryRail
            }
        )
        .background(AppVisualBackdrop())
        .onAppear {
            refreshPinWindowCount()
        }
        .task {
            await viewModel.loadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .acmindClipboardPinWindowsChanged)) { _ in
            refreshPinWindowCount()
        }
        .onKeyPress(.escape) {
            selectedItem = nil
            return .handled
        }
        .onKeyPress(.delete) {
            if let item = selectedItem {
                deleteClipboardItem(item)
                return .handled
            }
            return .ignored
        }
    }

    private var contentArea: some View {
        VStack(spacing: 0) {
            filterBar

            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredItems.isEmpty {
                    emptyState
                } else {
                    clipboardContent
                }
            }
            .animation(.easeOut(duration: 0.15), value: viewModel.isLoading)
        }
    }

    private var headerActions: some View {
        HStack {
            Spacer()

            HStack(spacing: 8) {
                pinWindowCountBadge
                searchField
                viewModePicker

                Button {
                    Task { await viewModel.clearHistory() }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: AppSurfaceTokens.Typography.controlStrong))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .buttonStyle(.plain)
                .help("清空历史")
            }
        }
    }

    private var clipboardSummaryRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("概览")
                            .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        statBadge(
                            count: viewModel.items.count,
                            label: "总计",
                            color: AppSurfaceTokens.accentBlue
                        )
                        statBadge(
                            count: viewModel.filteredItems.count,
                            label: "显示",
                            color: AppSurfaceTokens.accentGreen
                        )
                        statBadge(
                            count: pinWindowCount,
                            label: "Pin",
                            color: AppSurfaceTokens.accentOrange
                        )
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pin 管理")
                        .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    HStack(spacing: 6) {
                        pinQuickAction(icon: "eye", title: "显示") {
                            clipboardPinActions.showAll()
                        }
                        pinQuickAction(icon: "eye.slash", title: "隐藏") {
                            clipboardPinActions.hideAll()
                        }
                        pinQuickAction(icon: "xmark.circle", title: "关闭") {
                            clipboardPinActions.closeAll()
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                )

                PasteQueuePanel(viewModel: viewModel)
            }
            .padding(12)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    private func statBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: AppSurfaceTokens.Typography.metricValue, weight: .bold, design: .rounded))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text(label)
                .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(color.opacity(0.14), lineWidth: 1)
        )
    }

    private func pinQuickAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: AppSurfaceTokens.Typography.control))
                Text(title)
                    .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(AppSurfaceTokens.cardBackgroundSoft)
            .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppSurfaceTokens.secondaryText)
    }

    private var pinWindowCountBadge: some View {
        return HStack(spacing: 6) {
            Image(systemName: "pin")
                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
            Text("Pin \(pinWindowCount)")
                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(pinWindowCount > 0 ? AppSurfaceTokens.accentOrange.opacity(0.22) : AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
        )
        .foregroundStyle(pinWindowCount > 0 ? AppSurfaceTokens.accentOrange : AppSurfaceTokens.secondaryText)
    }

    private func refreshPinWindowCount() {
        pinWindowCount = (NSApp.delegate as? AppDelegate)?.clipboardPinWindowCount() ?? 0
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .font(.system(size: AppSurfaceTokens.Typography.control))

            TextField("搜索...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .frame(width: 160)
                .font(.system(size: AppSurfaceTokens.Typography.control))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
    }

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            Button(action: { viewMode = .list }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12))
                    .padding(6)
                    .background(viewMode == .list ? AppSurfaceTokens.cardBackgroundSoft : Color.clear)
                    .foregroundStyle(viewMode == .list ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                    .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut("l", modifiers: .command)
            .help("列表视图")

            Button(action: { viewMode = .grid }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12))
                    .padding(6)
                    .background(viewMode == .grid ? AppSurfaceTokens.cardBackgroundSoft : Color.clear)
                    .foregroundStyle(viewMode == .grid ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                    .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut("g", modifiers: .command)
            .help("网格视图")
        }
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
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
                                    .font(.system(size: AppSurfaceTokens.Typography.badge))
                            }
                            Text(filter?.displayName ?? "全部")
                                .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                .fill(isActive ? AppSurfaceTokens.cardBackgroundSoft : Color.clear)
                        )
                        .foregroundStyle(isActive ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                .stroke(isActive ? AppSurfaceTokens.separator.opacity(0.85) : AppSurfaceTokens.secondaryText.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if !viewModel.availableTags.isEmpty {
                    Divider()
                        .frame(height: 16)
                    
                    ForEach(viewModel.availableTags) { tag in
                        let isActive = viewModel.selectedTag == tag.name
                        Button {
                            viewModel.selectedTag = isActive ? nil : tag.name
                        } label: {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(tag.swiftColor)
                                    .frame(width: 6, height: 6)
                                Text(tag.name)
                                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                            )
                            .foregroundStyle(isActive ? AppSurfaceTokens.primaryText : AppSurfaceTokens.primaryText)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                    .stroke(isActive ? AppSurfaceTokens.separator.opacity(0.85) : AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppSurfaceTokens.secondaryText.opacity(0.06))
                    .frame(width: 80, height: 80)

                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(AppSurfaceTokens.secondaryText.opacity(0.5))
            }

            VStack(spacing: 6) {
                Text(viewModel.searchQuery.isEmpty ? "剪贴板为空" : "未找到匹配内容")
                    .font(.system(size: AppSurfaceTokens.Typography.bodyLarge, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Text(viewModel.searchQuery.isEmpty ? "复制内容后将自动记录在此处" : "尝试修改搜索关键词或筛选条件")
                    .font(.system(size: AppSurfaceTokens.Typography.body))
                    .foregroundStyle(AppSurfaceTokens.tertiaryText)
            }

            if !viewModel.searchQuery.isEmpty {
                Button("清除搜索") {
                    viewModel.searchQuery = ""
                    viewModel.selectedType = nil
                    viewModel.selectedTag = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppSurfaceTokens.cardBackgroundSoft))
                .overlay(
                    Capsule().stroke(AppSurfaceTokens.separator.opacity(0.85), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    private var clipboardContent: some View {
        GeometryReader { proxy in
            ScrollView {
                let columns = clipboardColumns(
                    availableWidth: proxy.size.width,
                    minimumWidth: viewMode == .list ? 240 : 220
                )
                LazyVGrid(columns: columns, spacing: ContentCardPresentation.cardSpacing) {
                    ForEach(viewModel.filteredItems) { item in
                        ClipboardItemCard(
                            item: item,
                            isSelected: selectedItem?.id == item.id,
                            onSelect: { selectedItem = item },
                            onCopy: { Task { await viewModel.copyItem(id: item.id) } },
                            onPin: { pinItemToDesktop(item) },
                            onUnpin: { Task { await viewModel.unpinItem(id: item.id) } },
                            onDelete: { deleteClipboardItem(item) },
                            onInbox: { Task { await viewModel.saveToInbox(id: item.id) } },
                            onAddToQueue: { viewModel.enqueueForSequentialPaste(ids: [item.id]) }
                        )
                        .id(item.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    }
                }
                .padding(16)
                .animation(.easeOut(duration: 0.2), value: viewModel.filteredItems.map(\.id))
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
    var onInbox: () -> Void = {}
    let onAddToQueue: () -> Void
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
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)

            if item.useCount > 0 {
                Text("·")
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                HStack(spacing: 2) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9))
                    Text("\(item.useCount)")
                        .font(.system(size: 10))
                }
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
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
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppSurfaceTokens.cardBackgroundSoft))
                    .overlay(
                        Capsule().stroke(AppSurfaceTokens.accentOrange.opacity(0.22), lineWidth: 1)
                    )
            }

            if !item.tags.isEmpty {
                ForEach(item.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(AppSurfaceTokens.cardBackgroundSoft))
                        .overlay(
                            Capsule().stroke(AppSurfaceTokens.accentBlue.opacity(0.22), lineWidth: 1)
                        )
                }
            }

            if item.isSensitive {
                Image(systemName: "lock.shield")
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
            }

            if item.type == .code, let lang = item.codeLanguage {
                Text(lang)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.accentCyan)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(AppSurfaceTokens.cardBackgroundSoft))
                    .overlay(
                        Capsule().stroke(AppSurfaceTokens.accentCyan.opacity(0.22), lineWidth: 1)
                    )
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
                        .background(Circle().fill(AppSurfaceTokens.cardBackgroundSoft))
                }
            .buttonStyle(.borderless)
            .foregroundStyle(AppSurfaceTokens.accentOrange)
            .contentShape(Circle())
            .help("Pin 到桌面")
            .accessibilityLabel(Text("Pin 悬浮窗"))
            .accessibilityHint(Text("将这条剪贴板内容固定为最前端的小窗口"))

            Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(AppSurfaceTokens.cardBackgroundSoft))
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

        Button("添加到粘贴队列", action: onAddToQueue)

        Button("保存到 Inbox") {
            onInbox()
        }

        if item.isSensitive {
            Text("⚠️ 包含敏感信息")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.accentOrange)
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
        } else if item.type == .code {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)

                VStack(alignment: .leading, spacing: 6) {
                    if let lang = item.codeLanguage {
                        Text(lang.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppSurfaceTokens.accentCyan)
                    }

                    Text(item.textContent ?? item.content ?? "")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(ClipboardCardPresentation.previewLineLimit(for: item))
                        .truncationMode(.tail)
                }
                .padding(10)
            }
            .frame(height: previewHeight)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                    .stroke(AppSurfaceTokens.accentCyan.opacity(0.18), lineWidth: 1)
            )
            .clipped()
        } else if item.type == .richText {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 10))
                            .foregroundStyle(AppSurfaceTokens.accentOrange)
                        Text("富文本")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppSurfaceTokens.accentOrange)
                    }

                    Text(item.textContent ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(ClipboardCardPresentation.previewLineLimit(for: item))
                        .truncationMode(.tail)
                }
                .padding(10)
            }
            .frame(height: previewHeight)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                    .stroke(AppSurfaceTokens.accentOrange.opacity(0.18), lineWidth: 1)
            )
            .clipped()
        } else {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: ContentCardPresentation.previewRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)

                VStack(alignment: .leading, spacing: 10) {
                    Text(ClipboardCardPresentation.previewText(for: item))
                        .font(.system(size: 14))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.92)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                }
                .padding(12)
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

    private let assetStore: AssetStoreProtocol

    @State private var thumbnail: NSImage?

    init(
        item: ClipboardItem,
        size: CGSize,
        cornerRadius: CGFloat,
        expandToWidth: Bool = false,
        assetStore: AssetStoreProtocol = AssetStore()
    ) {
        self.item = item
        self.size = size
        self.cornerRadius = cornerRadius
        self.expandToWidth = expandToWidth
        self.assetStore = assetStore
    }

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
                        .fill(AppSurfaceTokens.cardBackgroundSoft)

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
        guard item.type == .image, let assetId = item.content else { return }
        let store = assetStore
        guard let asset = try? await store.getAsset(id: assetId) else { return }
        let maxPixelSize = max(ContentCardPresentation.thumbnailHeight * 2.4, 480)
        guard let image = store.loadImage(asset: asset, maxPixelSize: maxPixelSize) else { return }
        await MainActor.run {
            thumbnail = image
        }
    }
}
