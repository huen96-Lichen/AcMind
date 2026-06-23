import SwiftUI
import AcMindKit

// MARK: - Tools View
// 工具 - 具体小工具集合

struct ToolsView: View {
    @StateObject private var viewModel: ToolsViewModel
    @FocusState private var searchFieldFocused: Bool

    init(viewModel: ToolsViewModel = ToolsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        AcWorkShell(
            title: "工具台",
            subtitle: "先选工具，再配置运行，最后查看结果",
            searchContent: AnyView(
                AcSearchField(
                    text: $viewModel.searchQuery,
                    placeholder: "搜索工具...",
                    width: 248,
                    focusBinding: $searchFieldFocused
                )
            ),
            leadingRailWidth: 208,
            trailingRailWidth: AppSurfaceTokens.Layout.summaryWidth,
            leadingRail: {
                toolsFilterRail
            },
            content: {
                toolsGrid
            },
            trailingRail: {
                toolDetailRail
            }
        )
        .sheet(item: $viewModel.activeToolRoute, onDismiss: {
            viewModel.activeToolRoute = nil
        }) { route in
            toolSheet(for: route)
        }
        .background(AppSurfaceBackdrop())
        .background(searchKeyboardShortcut)
    }

    private var toolsFilterRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ToolWorkspaceStageRail(
                    activeStage: ToolWorkspaceFlow.activeStage(activeToolRoute: viewModel.activeToolRoute),
                    selectionSummary: ToolWorkspaceFlow.selectionSummary(filteredCount: viewModel.filteredTools.count),
                    configurationSummary: ToolWorkspaceFlow.configurationSummary(activeToolRoute: viewModel.activeToolRoute),
                    reviewSummary: viewModel.recentTools.isEmpty ? "暂无结果" : ToolWorkspaceFlow.reviewSummary(recentCount: viewModel.recentTools.count)
                )

                AcSection(title: "工具概览", subtitle: "固定外壳下的轻量摘要", padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        railSummaryRow(title: "工具总数", value: "\(viewModel.filteredTools.count)")
                        railSummaryRow(title: "最近使用", value: "\(viewModel.recentTools.count)")
                        railSummaryRow(title: "当前分类", value: viewModel.selectedCategory.displayName)
                    }
                }

                AcSection(title: "分类筛选", subtitle: "竖排快捷入口", padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(ToolCategory.allCases) { category in
                            Button {
                                viewModel.selectedCategory = category
                            } label: {
                                HStack(spacing: 8) {
                                    Text(category.displayName)
                                    Spacer()
                                    Text("\(viewModel.toolCount(for: category))")
                                        .font(.caption2)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(viewModel.selectedCategory == category ? AppSurfaceTokens.cardBackgroundSoft : AppSurfaceTokens.cardBackgroundSoft)
                                .foregroundStyle(viewModel.selectedCategory == category ? AppSurfaceTokens.primaryText : .primary)
                                .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(AppSurfaceTokens.Spacing.lg)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    private var toolDetailRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let selectedTool {
                    AppSurfaceCard(title: "工具详情", subtitle: "当前选中的具体工具", padding: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                        .fill(AppSurfaceTokens.accentBlue.opacity(0.12))
                                    Image(systemName: selectedTool.icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                                }
                                .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(selectedTool.name)
                                        .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                                        .foregroundStyle(AppSurfaceTokens.primaryText)
                                        .lineLimit(2)
                                    Text(selectedTool.description)
                                        .font(.system(size: AppSurfaceTokens.Typography.caption))
                                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                railSummaryRow(title: "分类", value: selectedTool.category.displayName)
                                railSummaryRow(title: "路由", value: selectedTool.route.displayName)
                                railSummaryRow(title: "标签", value: selectedTool.tags.map(\.displayName).joined(separator: " · "))
                            }

                            HStack(spacing: 8) {
                                Button("重新打开") {
                                    viewModel.openTool(selectedTool)
                                }
                                .buttonStyle(.borderedProminent)

                                Button("清空最近") {
                                    viewModel.clearRecentTools()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                } else {
                    AppSurfaceCard(title: "工具详情", subtitle: "选择一个工具后显示具体信息", padding: 14) {
                        AcEmptyState(
                            icon: "wrench.and.screwdriver",
                            title: "尚未选择工具",
                            message: "从中间列表里打开一个工具，右侧会只显示这个工具的具体信息。"
                        )
                    }
                }
            }
            .padding(AppSurfaceTokens.Spacing.lg)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    private var selectedTool: Tool? {
        guard let activeToolRoute = viewModel.activeToolRoute else { return nil }
        return viewModel.tools.first { $0.route == activeToolRoute }
    }

    private func railSummaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: AppSurfaceTokens.Typography.caption))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ToolCategory.allCases) { category in
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        HStack(spacing: 4) {
                            Text(category.displayName)
                            Text("\(viewModel.toolCount(for: category))")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.selectedCategory == category ? AppSurfaceTokens.accentBlue.opacity(0.10) : AppSurfaceTokens.cardBackgroundSoft)
                        .foregroundStyle(viewModel.selectedCategory == category ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(viewModel.selectedCategory == category ? AppSurfaceTokens.accentBlue.opacity(0.28) : AppSurfaceTokens.separator, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(AppSurfaceTokens.cardBackgroundSoft)
    }

    // MARK: - Tools Grid

    private var toolsGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                toolsOverviewCard

                AppSurfaceCard(title: "工具总览", subtitle: "搜索、筛选与快速入口都放在同一层", padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            overviewMetric(title: "当前分类", value: viewModel.selectedCategory.displayName)
                            overviewMetric(title: "命中工具", value: "\(viewModel.filteredTools.count)")
                            overviewMetric(title: "最近使用", value: "\(viewModel.recentTools.count)")
                        }

                        toolsCategoryStrip
                    }
                }

                if viewModel.filteredTools.isEmpty {
                    AppSurfaceEmptyState(
                        icon: "magnifyingglass",
                        title: "没有匹配的工具",
                        message: "换个关键词，或者切到其他分类继续查看。"
                    )
                    .padding(.top, 4)
                } else {
                    AppSurfaceCard(
                        title: "精选工具",
                        subtitle: viewModel.selectedCategory.displayName,
                        padding: 16
                    ) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                            ForEach(viewModel.filteredTools) { tool in
                                ToolCard(tool: tool) {
                                    viewModel.openTool(tool)
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppSurfaceTokens.Spacing.lg)
        }
        .background(Color.clear)
    }

    private var toolsOverviewCard: some View {
        AppSurfaceCard(title: "工具台概览", subtitle: "入口矩阵 + 结果区", padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                AppSurfaceSummaryStrip(chips: [
                    AppSurfaceSummaryChip(
                        title: "分类",
                        value: viewModel.selectedCategory.displayName,
                        tint: AppSurfaceTokens.accentBlue
                    ),
                    AppSurfaceSummaryChip(
                        title: "命中",
                        value: "\(viewModel.filteredTools.count) 个",
                        tint: AppSurfaceTokens.accentGreen
                    ),
                    AppSurfaceSummaryChip(
                        title: "最近",
                        value: "\(viewModel.recentTools.count) 个",
                        tint: viewModel.recentTools.isEmpty ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.accentOrange
                    )
                ])

                HStack(spacing: 10) {
                    overviewMetric(title: "工作阶段", value: ToolWorkspaceFlow.activeStage(activeToolRoute: viewModel.activeToolRoute).title, tint: AppSurfaceTokens.accentBlue)
                    overviewMetric(title: "筛选状态", value: viewModel.searchQuery.isEmpty ? "未搜索" : "已搜索", tint: viewModel.searchQuery.isEmpty ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.accentOrange)
                    overviewMetric(title: "详情面板", value: selectedTool == nil ? "未选中" : "已打开", tint: selectedTool == nil ? AppSurfaceTokens.secondaryText : AppSurfaceTokens.accentGreen)
                }

                Text("顶部先把当前分类、命中数和最近使用亮出来，下面仍然保持原来的工具网格与详情区。")
                    .font(.system(size: AppSurfaceTokens.Typography.caption))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(2)
            }
        }
    }

    private var toolsCategoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ToolCategory.allCases) { category in
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        HStack(spacing: 6) {
                            Text(category.displayName)
                            Text("\(viewModel.toolCount(for: category))")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(viewModel.selectedCategory == category ? AppSurfaceTokens.accentBlue.opacity(0.10) : AppSurfaceTokens.cardBackgroundSoft)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .stroke(viewModel.selectedCategory == category ? AppSurfaceTokens.accentBlue.opacity(0.28) : AppSurfaceTokens.separator, lineWidth: 1)
                        )
                        .foregroundStyle(viewModel.selectedCategory == category ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func overviewMetric(title: String, value: String, tint: Color = AppSurfaceTokens.primaryText) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    @ViewBuilder
    private func toolSheet(for route: ToolRoute) -> some View {
        switch route {
        case .webDigest:
            WebDigestPanel()
        case .jsonFormatter:
            JSONFormatterPanel()
        case .base64Codec:
            Base64CodecPanel()
        case .markdownCleaner:
            MarkdownCleanerPanel()
        case .textCompare:
            TextComparePanel()
        case .documentConvert:
            DocumentConverterPanel()
        case .ocr:
            OCRPanel()
        case .imageProcess:
            ImageProcessingPanel()
        case .batchRename:
            BatchRenamePanel()
        case .srtToFcpxml:
            SRTToFCPXMLPanel()
        case .batchDownload:
            BatchDownloadPanel()
        case .videoDownload:
            VideoDownloadPanel()
        case .apiTest:
            APITestPanel()
        }
    }

    private var searchKeyboardShortcut: some View {
        Button("搜索工具") {
            searchFieldFocused = true
        }
        .keyboardShortcut("f", modifiers: .command)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let tool: Tool
    let onTap: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                        .frame(width: 48, height: 48)

                    Image(systemName: tool.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                }

                // 内容
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(tool.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                        
                        if tool.tags.contains(where: { $0.id == "new" }) {
                            Text("NEW")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(AppSurfaceTokens.cardBackgroundSoft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(AppSurfaceTokens.accentGreen.opacity(0.28), lineWidth: 1)
                                )
                                .foregroundStyle(AppSurfaceTokens.accentGreen)
                                .cornerRadius(3)
                        }
                    }

                        Text(tool.description)
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 5) {
                        ForEach(tool.tags.prefix(2), id: \.id) { tag in
                            Text(tag.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(AppSurfaceTokens.cardBackgroundSoft)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(tag.color.opacity(0.22), lineWidth: 1)
                                )
                                .foregroundStyle(tag.color)
                                .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .opacity(isHovered ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .padding(14)
            .frame(height: 96)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                            .stroke(
                                isPressed ? AppSurfaceTokens.separator.opacity(0.85) :
                                isHovered ? AppSurfaceTokens.separator.opacity(0.65) :
                                AppSurfaceTokens.separator,
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.985 : 1)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .pressAction {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

// MARK: - Press Action Extension

private extension View {
    func pressAction(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressActionModifier(onPress: onPress, onRelease: onRelease))
    }
}

private struct PressActionModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

// MARK: - Recent Tools Section

struct RecentToolsSection: View {
    let recentTools: [RecentTool]
    let canRestoreRecentTools: Bool
    let onToolTap: (RecentTool) -> Void
    let onClear: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // 标题栏
            HStack {
                Text("最近使用")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if canRestoreRecentTools {
                    Button("恢复记录", action: onRestore)
                        .buttonStyle(.borderless)
                        .font(.caption)

                }

                if !recentTools.isEmpty {
                    Button(action: onClear) {
                        Text("清空记录")
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // 最近使用工具列表
            if !recentTools.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentTools) { tool in
                            RecentToolCard(tool: tool, onTap: {
                                onToolTap(tool)
                            })
                        }
                    }
                }
            } else {
                AppSurfaceEmptyState(
                    icon: "clock",
                    title: "暂无最近使用工具",
                    message: "开始使用任一工具后，这里会沉淀成你的快捷历史。",
                    actionTitle: canRestoreRecentTools ? "恢复记录" : nil,
                    tint: AppSurfaceTokens.accentBlue,
                    action: canRestoreRecentTools ? onRestore : nil
                )
            }
        }
    }
}

// MARK: - Recent Tool Card

struct RecentToolCard: View {
    let tool: RecentTool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                        .frame(width: 40, height: 40)

                    Image(systemName: tool.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                }

                // 名称
                Text(tool.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)

                // 时间
                Text(tool.relativeTime)
                    .font(.caption2)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                            .stroke(isHovered ? AppSurfaceTokens.accentBlue.opacity(0.22) : AppSurfaceTokens.separator, lineWidth: 1)
                    )
            )
            .frame(width: 92)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Tool Types

struct ToolTag: Hashable {
    let id: String
    let displayName: String
    let color: Color

    static let text = ToolTag(id: "text", displayName: "文本", color: .blue)
    static let image = ToolTag(id: "image", displayName: "图片", color: .gray)
    static let download = ToolTag(id: "download", displayName: "下载", color: .blue)
    static let ai = ToolTag(id: "ai", displayName: "AI", color: .blue)
    static let dev = ToolTag(id: "dev", displayName: "开发", color: .gray)
    static let document = ToolTag(id: "document", displayName: "文档", color: .blue)
    static let local = ToolTag(id: "local", displayName: "本地", color: .gray)
    static let new = ToolTag(id: "new", displayName: "NEW", color: .blue)
    static let beta = ToolTag(id: "beta", displayName: "Beta", color: .gray)
}

struct Tool: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let category: ToolCategory
    let tags: [ToolTag]
    let route: ToolRoute
}

enum ToolRoute: Identifiable, Sendable {
    case webDigest
    case jsonFormatter
    case base64Codec
    case markdownCleaner
    case textCompare
    case documentConvert
    case ocr
    case imageProcess
    case batchRename
    case srtToFcpxml
    case batchDownload
    case videoDownload
    case apiTest

    var id: String {
        switch self {
        case .webDigest:
            return "webDigest"
        case .jsonFormatter:
            return "jsonFormatter"
        case .base64Codec:
            return "base64Codec"
        case .markdownCleaner:
            return "markdownCleaner"
        case .textCompare:
            return "textCompare"
        case .documentConvert:
            return "documentConvert"
        case .ocr:
            return "ocr"
        case .imageProcess:
            return "imageProcess"
        case .batchRename:
            return "batchRename"
        case .srtToFcpxml:
            return "srtToFcpxml"
        case .batchDownload:
            return "batchDownload"
        case .videoDownload:
            return "videoDownload"
        case .apiTest:
            return "apiTest"
        }
    }

    var storageID: String { id }

    init?(storageID: String) {
        switch storageID {
        case "webDigest": self = .webDigest
        case "jsonFormatter": self = .jsonFormatter
        case "base64Codec": self = .base64Codec
        case "markdownCleaner": self = .markdownCleaner
        case "textCompare": self = .textCompare
        case "documentConvert": self = .documentConvert
        case "ocr": self = .ocr
        case "imageProcess": self = .imageProcess
        case "batchRename": self = .batchRename
        case "srtToFcpxml": self = .srtToFcpxml
        case "batchDownload": self = .batchDownload
        case "videoDownload": self = .videoDownload
        case "apiTest": self = .apiTest
        default: return nil
        }
    }
}

enum ToolCategory: String, CaseIterable, Identifiable {
    case all = "all"
    case text = "text"
    case conversion = "conversion"
    case download = "download"
    case ai = "ai"
    case developer = "developer"
    case utility = "utility"
    
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "全部"
        case .text: return "文本处理"
        case .conversion: return "内容转换"
        case .download: return "下载工具"
        case .ai: return "AI 工具"
        case .developer: return "开发工具"
        case .utility: return "实用工具"
        }
    }

    var color: Color {
        switch self {
        case .all: return .gray
        case .text: return .blue
        case .conversion: return .gray
        case .download: return .blue
        case .ai: return .blue
        case .developer: return .gray
        case .utility: return .gray
        }
    }
}

// MARK: - View Model

struct RecentTool: Identifiable {
    let id: UUID
    let toolId: UUID
    let name: String
    let description: String
    let icon: String
    let category: ToolCategory
    let route: ToolRoute
    let lastUsedDate: Date

    var relativeTime: String {
        let now = Date()
        let diff = now.timeIntervalSince(lastUsedDate)
        
        if diff < 60 {
            return "刚刚"
        } else if diff < 3600 {
            return "\(Int(diff / 60))分钟前"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))小时前"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "昨天 HH:mm"
            return dateFormatter.string(from: lastUsedDate)
        }
    }
}

private extension RecentTool {
    init?(record: RecentToolRecord) {
        guard let category = ToolCategory(rawValue: record.category),
              let route = ToolRoute(storageID: record.route) else {
            return nil
        }

        self.init(
            id: record.id,
            toolId: record.toolId,
            name: record.name,
            description: record.description,
            icon: record.icon,
            category: category,
            route: route,
            lastUsedDate: record.lastUsedDate
        )
    }

    var record: RecentToolRecord {
        RecentToolRecord(
            id: id,
            toolId: toolId,
            name: name,
            description: description,
            icon: icon,
            category: category.rawValue,
            route: route.storageID,
            lastUsedDate: lastUsedDate
        )
    }
}

@MainActor
class ToolsViewModel: ObservableObject {
    @Published var tools: [Tool] = []
    @Published var searchQuery = ""
    @Published var selectedCategory: ToolCategory = .all
    @Published var activeToolRoute: ToolRoute?
    @Published var recentTools: [RecentTool] = []
    private var recentToolsRestoreBackup: [RecentTool] = []

    var canRestoreRecentTools: Bool {
        !recentToolsRestoreBackup.isEmpty
    }

    var filteredTools: [Tool] {
        var result = tools
        
        if selectedCategory != .all {
            result = result.filter { $0.category == selectedCategory }
        }
        
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.tags.contains { $0.displayName.lowercased().contains(query) } ||
                $0.category.displayName.lowercased().contains(query)
            }
        }
        
        return result
    }

    init() {
        loadTools()
        loadRecentTools()
    }

    private func loadTools() {
        tools = ToolRegistry.defaultTools
    }

    private func loadRecentTools() {
        recentToolsRestoreBackup = []
        recentTools = RecentToolsStore.load(from: .standard).compactMap(RecentTool.init(record:))
    }

    func openTool(_ tool: Tool) {
        activeToolRoute = tool.route
        recordRecentTool(tool)
    }

    private func recordRecentTool(_ tool: Tool) {
        recentToolsRestoreBackup = []

        // 移除已存在的记录
        recentTools.removeAll { $0.toolId == tool.id }
        
        // 添加新记录
        let recent = RecentTool(
            id: UUID(),
            toolId: tool.id,
            name: tool.name,
            description: tool.description,
            icon: tool.icon,
            category: tool.category,
            route: tool.route,
            lastUsedDate: Date()
        )
        
        recentTools.insert(recent, at: 0)
        
        // 只保留最近10条记录
        if recentTools.count > 10 {
            recentTools = Array(recentTools.prefix(10))
        }

        saveRecentTools()
    }

    func clearRecentTools() {
        recentToolsRestoreBackup = recentTools
        recentTools.removeAll()
        saveRecentTools()
    }

    func restoreRecentTools() {
        guard !recentToolsRestoreBackup.isEmpty else { return }
        recentTools = recentToolsRestoreBackup
        recentToolsRestoreBackup = []
        saveRecentTools()
    }

    private func saveRecentTools() {
        RecentToolsStore.save(recentTools.map(\.record), to: .standard)
    }

    func toolCount(for category: ToolCategory) -> Int {
        if category == .all {
            return tools.count
        }
        return tools.filter { $0.category == category }.count
    }
}

// MARK: - Tool Registry

/// 工具注册表 - 集中管理当前可用的内置工具
enum ToolRegistry {
    static var defaultTools: [Tool] {
        [
            // 文本处理
            Tool(name: "Markdown 整理", description: "自动整理和格式化 Markdown 文档", icon: "text.quote", category: .text, tags: [.text, .local], route: .markdownCleaner),
            Tool(name: "文本对比", description: "对比两段文本的差异", icon: "arrow.left.arrow.right", category: .text, tags: [.text, .local], route: .textCompare),
            Tool(name: "JSON 格式化", description: "格式化和验证 JSON", icon: "curlybraces", category: .text, tags: [.dev, .local], route: .jsonFormatter),
            Tool(name: "Base64 编解码", description: "Base64 编码和解码", icon: "number", category: .text, tags: [.dev, .local], route: .base64Codec),
            
            // 内容转换
            Tool(name: "文档转换", description: "在 PDF、Word、Markdown 之间转换", icon: "doc.text", category: .conversion, tags: [.document, .new], route: .documentConvert),
            Tool(name: "图片处理", description: "压缩、裁剪、格式转换", icon: "photo", category: .conversion, tags: [.image, .local], route: .imageProcess),
            Tool(name: "OCR 识别", description: "从图片中提取文字", icon: "text.viewfinder", category: .conversion, tags: [.image, .ai, .new], route: .ocr),
            
            // 下载工具
            Tool(name: "WebDigest｜网页精读", description: "输入 URL，抓取网页正文并生成 Markdown", icon: "globe", category: .download, tags: [.download, .new], route: .webDigest),
            Tool(name: "批量下载", description: "批量下载网页中的图片或文件", icon: "arrow.down.circle", category: .download, tags: [.download], route: .batchDownload),
            Tool(name: "视频下载", description: "下载在线视频", icon: "video", category: .download, tags: [.download], route: .videoDownload),
            
            // AI 工具
            Tool(name: "API 测试", description: "测试 AI 提供商的 API", icon: "network", category: .ai, tags: [.ai, .dev], route: .apiTest),
            
            // 实用工具
            Tool(name: "批量重命名", description: "批量重命名文件和文件夹", icon: "character.cursor.ibeam", category: .utility, tags: [.document, .local], route: .batchRename),
            Tool(name: "SRT → FCPXML", description: "将 SRT 字幕转换为 Final Cut Pro 可用的 FCPXML 格式", icon: "captions.bubble", category: .conversion, tags: [.document, .new], route: .srtToFcpxml),
        ]
    }
}
