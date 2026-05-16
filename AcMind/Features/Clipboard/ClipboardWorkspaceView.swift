import SwiftUI

struct ClipboardWorkspaceView: View {
    @State private var selectedCategory: ClipboardCategory = .all
    @State private var searchText: String = ""
    @State private var selectedItemID: UUID = clipboardMockItems.first?.id ?? UUID()

    private var visibleItems: [ClipboardItem] {
        clipboardMockItems.filter { item in
            let categoryMatch = selectedCategory == .all || item.type.rawValue == selectedCategory.rawValue
            let searchMatch = searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText) || item.content.localizedCaseInsensitiveContains(searchText)
            return categoryMatch && searchMatch
        }
    }

    private var selectedItem: ClipboardItem? {
        visibleItems.first { $0.id == selectedItemID } ?? visibleItems.first
    }

    var body: some View {
        ACWorkspaceShell(
            title: "剪贴板",
            subtitle: "自动保存、智能分类、快速检索和内容复用。",
            trailing: {
                HStack(spacing: 12) {
                    ACSearchField("搜索剪贴板", text: $searchText, width: 220, height: ACLayout.controlHeight)
                    ACButton("新增", kind: .primary, minWidth: 78) {}
                }
            },
            left: { sidebar },
            center: {
                VStack(alignment: .leading, spacing: ACLayout.cardGap) {
                    statsBar
                    centerList
                }
            },
            right: { detailPanel }
        )
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            ClipboardStatCard(title: "全部", value: "126", subtitle: "条内容", symbol: "doc.on.doc")
            ClipboardStatCard(title: "最近 24 小时", value: "32", subtitle: "条内容", symbol: "clock")
            ClipboardStatCard(title: "文本", value: "68", subtitle: "条", symbol: "textformat")
            ClipboardStatCard(title: "图片", value: "24", subtitle: "条", symbol: "photo")
            ClipboardStatCard(title: "链接", value: "12", subtitle: "条", symbol: "link")
            ClipboardStatCard(title: "文件", value: "16", subtitle: "条", symbol: "doc")
            ClipboardStatCard(title: "代码", value: "6", subtitle: "条", symbol: "curlybraces")
        }
    }

    private var sidebar: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Text("智能分类")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                VStack(spacing: 8) {
                    ForEach(ClipboardCategory.allCases) { category in
                        ClipboardCategoryRow(
                            category: category,
                            selected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }

                Divider()
                    .overlay(ACColors.divider)

                VStack(alignment: .leading, spacing: 8) {
                    Text("收藏与清理")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)

                    ForEach(ClipboardManagementGroup.allCases) { group in
                        ClipboardUtilityRow(group: group)
                    }
                }
            }
        }
    }

    private var centerList: some View {
        ACCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("\(visibleItems.filter { $0.group == "今天" }.count) 条剪贴板内容")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(ACColors.cardBackground)
                .overlay(alignment: .bottom) {
                    Divider().overlay(ACColors.divider)
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(groupedVisibleItems, id: \.group) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.group)
                                    .font(ACTypography.captionMedium)
                                    .foregroundStyle(ACColors.secondaryText)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 8) {
                                    ForEach(group.items) { item in
                                        ACListRow(
                                            title: item.title,
                                            subtitle: item.subtitle,
                                            symbol: item.type.icon,
                                            selected: selectedItemID == item.id,
                                            tint: item.type.tint,
                                            meta: item.source,
                                            trailing: item.time
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedItemID = item.id
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 12)
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
                    ClipboardActionGroup(item: selectedItem)
                    ClipboardMetadataTable(item: selectedItem)
                } else {
                    ACEmptyState(
                        icon: "clipboard",
                        title: "选择一项查看详情",
                        subtitle: "右侧会展示内容预览、操作和元数据。"
                    )
                }
            }
        }
    }

    private var groupedVisibleItems: [ClipboardGroupSection] {
        let todayItems = visibleItems.filter { $0.group == "今天" }
        let yesterdayItems = visibleItems.filter { $0.group == "昨天" }
        var sections: [ClipboardGroupSection] = []

        if !todayItems.isEmpty {
            sections.append(.init(group: "今天", items: todayItems))
        }

        if !yesterdayItems.isEmpty {
            sections.append(.init(group: "昨天", items: yesterdayItems))
        }

        if sections.isEmpty, let first = visibleItems.first {
            sections.append(.init(group: "筛选结果", items: [first]))
        }

        return sections
    }
}

private struct ClipboardStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let symbol: String

    var body: some View {
        ACCard(padding: 14) {
            HStack(spacing: 12) {
                ACTypeIcon(symbol, tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ACTypography.miniMedium)
                        .foregroundStyle(ACColors.secondaryText)
                    Text(value)
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text(subtitle)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.tertiaryText)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(height: 74)
    }
}

private struct ClipboardCategoryRow: View {
    let category: ClipboardCategory
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ACTypeIcon(category.icon, tint: selected ? ACColors.accentBlue : ACColors.secondaryText, background: selected ? ACColors.selectedFill : ACColors.softFill, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text("\(category.count) 条")
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

private struct ClipboardUtilityRow: View {
    let group: ClipboardManagementGroup

    var body: some View {
        HStack(spacing: 10) {
            ACTypeIcon(group.icon, tint: group.tint, background: group.tint.opacity(0.12), size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
                Text(group.subtitle)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }

            Spacer(minLength: 0)
            Text("\(group.count)")
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.tertiaryText)
        }
        .padding(10)
        .background(ACColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}

private struct ClipboardDetailHeader: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 12) {
            ACTypeIcon(item.type.icon, tint: item.type.tint, background: item.type.fill, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text("\(item.source) · \(item.time)")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }

            Spacer(minLength: 0)

            ACButton("收藏", kind: .ghost, action: {})
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

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                        .fill(ACColors.softFill)
                        .frame(height: 250)

                    previewContent
                        .frame(height: 250, alignment: .center)
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.type {
        case .text, .code:
            ScrollView {
                Text(item.content.isEmpty ? item.title : item.content)
                    .font(ACTypography.body)
                    .foregroundStyle(ACColors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(5)
                    .padding(16)
            }
        case .image:
            VStack(spacing: 10) {
                ACTypeIcon("photo", tint: ACColors.accentPurple, background: ACColors.selectedFill, size: 64)
                Text(item.title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                if let imageSize = item.imageSize {
                    Text(imageSize)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }
            }
        case .link:
            VStack(spacing: 10) {
                ACTypeIcon("link", tint: ACColors.accentGreen, background: ACColors.selectedFill, size: 64)
                Text(item.content)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.accentBlue)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.horizontal, 16)
            }
        case .file:
            VStack(spacing: 10) {
                ACTypeIcon("doc", tint: ACColors.accentOrange, background: ACColors.selectedFill, size: 64)
                Text(item.title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                if let fileSize = item.fileSize {
                    Text(fileSize)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }
            }
        }
    }
}

private struct ClipboardActionGroup: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .font(ACTypography.panelTitle)
                .foregroundStyle(ACColors.primaryText)

            HStack(spacing: 10) {
                ACButton("粘贴", kind: .primary, action: {})
                ACButton("复制", kind: .secondary, action: {})
                ACButton("分享", kind: .secondary, action: {})
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
                .init("来源", value: item.source),
                .init("时间", value: item.time),
                .init("分组", value: item.group),
                .init("字符数", value: "\(item.characterCount)"),
                .init("收藏状态", value: item.isFavorite ? "已收藏" : "未收藏")
            ])
        }
    }
}

private struct ClipboardGroupSection: Identifiable {
    let id = UUID()
    let group: String
    let items: [ClipboardItem]
}

private enum ClipboardItemType: String, CaseIterable, Identifiable {
    case text
    case image
    case link
    case file
    case code

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .text: return "textformat"
        case .image: return "photo"
        case .link: return "link"
        case .file: return "doc"
        case .code: return "curlybraces"
        }
    }

    var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .link: return "链接"
        case .file: return "文件"
        case .code: return "代码"
        }
    }

    var tint: Color {
        switch self {
        case .text: return ACColors.accentBlue
        case .image: return ACColors.accentPurple
        case .link: return ACColors.accentGreen
        case .file: return ACColors.accentOrange
        case .code: return ACColors.accentTeal
        }
    }

    var fill: Color {
        switch self {
        case .text: return ACColors.selectedFill
        case .image: return ACColors.accentPurple.opacity(0.12)
        case .link: return ACColors.accentGreen.opacity(0.12)
        case .file: return ACColors.accentOrange.opacity(0.12)
        case .code: return ACColors.accentTeal.opacity(0.12)
        }
    }
}

private struct ClipboardItem: Identifiable {
    let id = UUID()
    let type: ClipboardItemType
    let title: String
    let content: String
    let time: String
    let source: String
    let imageSize: String?
    let fileSize: String?
    let isFavorite: Bool
    let group: String

    var subtitle: String {
        if !content.isEmpty {
            return content
        }

        if let imageSize {
            return imageSize
        }

        if let fileSize {
            return fileSize
        }

        return source
    }

    var characterCount: Int {
        content.count
    }
}

private let clipboardMockItems: [ClipboardItem] = [
    .init(
        type: .text,
        title: "可以，下面这份就是基于刚才理想图反推的设计 + Codex 可落地任务单...",
        content: "可以，下面这份就是基于刚才理想图反推的设计 + Codex 可落地任务单。",
        time: "10:23:45",
        source: "从 Agent 复制",
        imageSize: nil,
        fileSize: nil,
        isFavorite: false,
        group: "今天"
    ),
    .init(
        type: .image,
        title: "产品需求 PRD 初稿.png",
        content: "",
        time: "10:21:30",
        source: "截图",
        imageSize: "1024 × 768",
        fileSize: "2.3 MB",
        isFavorite: false,
        group: "今天"
    ),
    .init(
        type: .link,
        title: "https://www.acmind.com/docs/product/overview",
        content: "https://www.acmind.com/docs/product/overview",
        time: "10:15:22",
        source: "从 Chrome 复制",
        imageSize: nil,
        fileSize: nil,
        isFavorite: false,
        group: "今天"
    ),
    .init(
        type: .file,
        title: "项目进度周报_2025-05-09.pdf",
        content: "",
        time: "09:48:11",
        source: "从 Finder 复制",
        imageSize: nil,
        fileSize: "1.2 MB",
        isFavorite: false,
        group: "今天"
    ),
    .init(
        type: .code,
        title: "function debounce(fn, delay) { timer = null; return function(...args) {...",
        content: "function debounce(fn, delay) {\n    let timer = null;\n    return function(...args) {\n        if (timer) clearTimeout(timer);\n        timer = setTimeout(() => {\n            fn.apply(this, args);\n        }, delay);\n    };\n}",
        time: "09:32:05",
        source: "从 VS Code 复制",
        imageSize: nil,
        fileSize: nil,
        isFavorite: false,
        group: "今天"
    ),
    .init(
        type: .text,
        title: "对，现在这版最大的问题可以明确下结论：",
        content: "对，现在这版最大的问题可以明确下结论：\n\n1. 信息密度太低，不适合高频检索\n2. 分类体系不清晰\n3. 缺少详情处理能力\n4. 视觉层级混乱",
        time: "18:36:20",
        source: "从 Agent 复制",
        imageSize: nil,
        fileSize: nil,
        isFavorite: false,
        group: "昨天"
    ),
    .init(
        type: .image,
        title: "设计规范参考.png",
        content: "",
        time: "18:20:04",
        source: "截图",
        imageSize: "1200 × 800",
        fileSize: "1.6 MB",
        isFavorite: false,
        group: "昨天"
    )
]

private enum ClipboardCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case text = "文本"
    case image = "图片"
    case link = "链接"
    case file = "文件"
    case code = "代码"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.stack.3d.up"
        case .text: return "textformat"
        case .image: return "photo"
        case .link: return "link"
        case .file: return "doc"
        case .code: return "curlybraces"
        }
    }

    var count: Int {
        switch self {
        case .all: return clipboardMockItems.count
        case .text: return clipboardMockItems.filter { $0.type == .text }.count
        case .image: return clipboardMockItems.filter { $0.type == .image }.count
        case .link: return clipboardMockItems.filter { $0.type == .link }.count
        case .file: return clipboardMockItems.filter { $0.type == .file }.count
        case .code: return clipboardMockItems.filter { $0.type == .code }.count
        }
    }
}

private enum ClipboardManagementGroup: String, CaseIterable, Identifiable {
    case favorites
    case cleanup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites: return "收藏"
        case .cleanup: return "清理"
        }
    }

    var subtitle: String {
        switch self {
        case .favorites: return "固定重要内容"
        case .cleanup: return "整理过期内容"
        }
    }

    var icon: String {
        switch self {
        case .favorites: return "star.fill"
        case .cleanup: return "trash"
        }
    }

    var tint: Color {
        switch self {
        case .favorites: return ACColors.accentYellow
        case .cleanup: return ACColors.accentRed
        }
    }

    var count: Int {
        switch self {
        case .favorites: return 8
        case .cleanup: return 23
        }
    }
}
