import SwiftUI
import AcMindKit

// MARK: - Tools View
// 工具 - 具体小工具集合

struct ToolsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ToolsViewModel
    @FocusState private var searchFieldFocused: Bool
    @AppStorage("ToolsView.sortMode") private var storedSortModeRawValue: String = ToolSortMode.recent.rawValue
    @AppStorage("ToolsView.selectedCategory") private var storedSelectedCategoryRawValue: String = ToolCategory.all.rawValue
    @AppStorage("ToolsView.searchQuery") private var storedSearchQuery: String = ""

    init(viewModel: ToolsViewModel = ToolsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        AcWorkShell(
            title: "工具台",
            subtitle: "先选工具，再配置参数，最后查看结果",
            headerActions: AnyView(headerActions),
            searchContent: AnyView(
                AcSearchField(
                    text: $viewModel.searchQuery,
                    placeholder: "搜索工具...",
                    width: 260,
                    focusBinding: $searchFieldFocused
                )
            ),
            leadingRailWidth: 0,
            trailingRailWidth: 0,
            leadingRail: { EmptyView() },
            content: { toolsCanvas },
            trailingRail: { EmptyView() }
        )
        .sheet(item: $viewModel.activeToolRoute, onDismiss: {
            viewModel.activeToolRoute = nil
        }) { route in
            toolSheet(for: route)
        }
        .onAppear {
            consumePendingWorkbenchToolRoute()
            restoreWorkspaceState()
        }
        .onChange(of: appState.pendingWorkbenchToolRoute) { _, _ in
            consumePendingWorkbenchToolRoute()
        }
        .onChange(of: viewModel.selectedCategory) { _, newValue in
            storedSelectedCategoryRawValue = newValue.rawValue
        }
        .onChange(of: viewModel.searchQuery) { _, newValue in
            storedSearchQuery = newValue
        }
        .background(AppVisualBackdrop())
        .background(searchKeyboardShortcut)
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Menu {
                Button("聚焦搜索") {
                    searchFieldFocused = true
                }

                Divider()

                Button("全部分类") {
                    viewModel.selectedCategory = .all
                }

                ForEach(ToolCategory.allCases.filter { $0 != .all }) { category in
                    Button(category.displayName) {
                        viewModel.selectedCategory = category
                    }
                }
            } label: {
                Label("选择工具", systemImage: "chevron.down")
            }
            .buttonStyle(.borderedProminent)

            Menu {
                ForEach(workflowStarterTools) { tool in
                    Button(tool.name) {
                        viewModel.openTool(tool)
                    }
                }
            } label: {
                Label("新建工作流", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            Button {
                appState.navigate(to: .workbench, workbenchToolRoute: .apiTest)
            } label: {
                Label("验证接口", systemImage: "checkmark.shield")
            }
            .buttonStyle(.bordered)

            Button {
                appState.navigate(to: .settings, settingsCategory: .aiModels)
            } label: {
                Label("模型设置", systemImage: "brain")
            }
            .buttonStyle(.bordered)

            Button {
                appState.navigate(to: .voiceEntry)
            } label: {
                Label("说入法", systemImage: "waveform")
            }
            .buttonStyle(.bordered)

            Button {
                appState.navigate(to: .settings)
            } label: {
                Label("设置首页", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
        }
    }

    private var workflowStarterTools: [Tool] {
        [
            .webDigest,
            .markdownCleaner,
            .jsonFormatter,
            .ocr
        ].compactMap { route in
            viewModel.tools.first { $0.route == route }
        }
    }

    private var toolsCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceSectionSpacing) {
                AppSurfaceCard(title: "分类筛选", subtitle: "按类别和最近使用收窄范围", padding: AppSurfaceTokens.Layout.workspaceCardPadding) {
                    VStack(alignment: .leading, spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                        HStack(spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                            Text("分类")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)

                            Spacer(minLength: 0)

                            sortModeMenu
                        }

                        categoryFilterBar
                    }
                }

                AppSurfaceCard(title: "工具库", subtitle: "\(displayedTools.count) 个工具", padding: AppSurfaceTokens.Layout.workspaceCardPadding) {
                    if displayedTools.isEmpty {
                        AppSurfaceEmptyState(
                            icon: "magnifyingglass",
                            title: "没有匹配的工具",
                            message: "换个关键词，或者切到其他分类继续查看。"
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: AppSurfaceTokens.Layout.workspaceGridSpacing)], spacing: AppSurfaceTokens.Layout.workspaceGridSpacing) {
                            ForEach(displayedTools) { tool in
                                ToolCard(tool: tool, isSelected: viewModel.activeToolRoute == tool.route) {
                                    viewModel.openTool(tool)
                                }
                            }
                        }
                    }
                }

                AppSurfaceCard(title: "最近使用", subtitle: "可恢复的工具历史", padding: AppSurfaceTokens.Layout.workspaceCardPadding) {
                    RecentToolsSection(
                        recentTools: viewModel.recentTools,
                        canRestoreRecentTools: viewModel.canRestoreRecentTools,
                        onToolTap: { recent in
                            viewModel.openRecentTool(recent)
                        },
                        onClear: {
                            viewModel.clearRecentTools()
                        },
                        onRestore: {
                            viewModel.restoreRecentTools()
                        }
                    )
                }
            }
            .padding(AppSurfaceTokens.Layout.workspacePagePadding)
            .frame(maxWidth: AppSurfaceTokens.Layout.workspaceMaxWidth, alignment: .leading)
        }
        .background(Color.clear)
    }

    private var displayedTools: [Tool] {
        sortTools(viewModel.filteredTools)
    }

    private var sortModeMenu: some View {
        Menu {
            ForEach(ToolSortMode.allCases) { mode in
                Button {
                    storedSortModeRawValue = mode.rawValue
                } label: {
                    if resolvedSortMode == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        } label: {
            Label(resolvedSortMode.title, systemImage: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.bordered)
    }

    private var categoryFilterBar: some View {
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

    private func sortTools(_ tools: [Tool]) -> [Tool] {
        switch resolvedSortMode {
        case .recent:
            let recentRoutes = Dictionary(uniqueKeysWithValues: viewModel.recentTools.enumerated().map { ($1.route, $0) })
            return tools.sorted {
                let leftRank = recentRoutes[$0.route] ?? Int.max
                let rightRank = recentRoutes[$1.route] ?? Int.max

                if leftRank != rightRank {
                    return leftRank < rightRank
                }

                return $0.name < $1.name
            }
        case .name:
            return tools.sorted { $0.name < $1.name }
        case .category:
            return tools.sorted {
                if $0.category.displayName != $1.category.displayName {
                    return $0.category.displayName < $1.category.displayName
                }
                return $0.name < $1.name
            }
        }
    }

    private var resolvedSortMode: ToolSortMode {
        ToolSortMode(rawValue: storedSortModeRawValue) ?? .recent
    }

    private func restoreWorkspaceState() {
        viewModel.selectedCategory = ToolCategory(rawValue: storedSelectedCategoryRawValue) ?? .all
        viewModel.searchQuery = storedSearchQuery
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

    private func consumePendingWorkbenchToolRoute() {
        guard let route = appState.pendingWorkbenchToolRoute else { return }
        viewModel.openTool(route)
        appState.pendingWorkbenchToolRoute = nil
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let tool: Tool
    let isSelected: Bool
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
                            Text("新")
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
                    .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.05) : AppSurfaceTokens.cardBackgroundSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                            .stroke(
                                isSelected ? AppSurfaceTokens.accentBlue.opacity(0.42) :
                                isPressed ? AppSurfaceTokens.separator.opacity(0.85) :
                                isHovered ? AppSurfaceTokens.separator.opacity(0.65) :
                                AppSurfaceTokens.separator,
                                lineWidth: 1
                            )
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                        .padding(10)
                }
            }
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
            HStack {
                if canRestoreRecentTools {
                    Button("恢复记录", action: onRestore)
                        .buttonStyle(.borderless)
                        .font(.caption)
                }

                Spacer()

                if !recentTools.isEmpty {
                    Button(action: onClear) {
                        Text("清空记录")
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

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
                        title: "最近尚未使用过工具",
                    message: "使用过的工具会保留在这里。",
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
    static let ai = ToolTag(id: "ai", displayName: "智能", color: .blue)
    static let dev = ToolTag(id: "dev", displayName: "开发", color: .gray)
    static let document = ToolTag(id: "document", displayName: "文档", color: .blue)
    static let local = ToolTag(id: "local", displayName: "本地", color: .gray)
        static let new = ToolTag(id: "new", displayName: "新", color: .blue)
    static let beta = ToolTag(id: "beta", displayName: "测试版", color: .gray)
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

enum ToolRoute: Identifiable, Sendable, Equatable {
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
        case .ai: return "智能工具"
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

enum ToolSortMode: String, CaseIterable, Identifiable {
    case recent
    case name
    case category

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "按最近使用"
        case .name: return "按名称"
        case .category: return "按分类"
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

    func openTool(_ route: ToolRoute) {
        activeToolRoute = route
        if let tool = tools.first(where: { $0.route == route }) {
            recordRecentTool(tool)
        }
    }

    func openRecentTool(_ recentTool: RecentTool) {
        if let tool = tools.first(where: { $0.id == recentTool.toolId || $0.route == recentTool.route }) {
            openTool(tool)
        } else {
            activeToolRoute = recentTool.route
        }
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
            Tool(name: "文稿整理", description: "自动整理和格式化文稿", icon: "text.quote", category: .text, tags: [.text, .local], route: .markdownCleaner),
            Tool(name: "文本对比", description: "对比两段文本的差异", icon: "arrow.left.arrow.right", category: .text, tags: [.text, .local], route: .textCompare),
            Tool(name: "JSON 格式化", description: "格式化和验证 JSON", icon: "curlybraces", category: .text, tags: [.dev, .local], route: .jsonFormatter),
            Tool(name: "Base64 编解码", description: "Base64 编码和解码", icon: "number", category: .text, tags: [.dev, .local], route: .base64Codec),
            
            // 内容转换
            Tool(name: "文档转换", description: "在 PDF、Word、文稿之间转换", icon: "doc.text", category: .conversion, tags: [.document, .new], route: .documentConvert),
            Tool(name: "图片处理", description: "压缩、裁剪、格式转换", icon: "photo", category: .conversion, tags: [.image, .local], route: .imageProcess),
            Tool(name: "文字识别", description: "从图片中提取文字", icon: "text.viewfinder", category: .conversion, tags: [.image, .ai, .new], route: .ocr),
            
            // 下载工具
            Tool(name: "网页精读", description: "输入网页地址，抓取正文并生成文稿", icon: "globe", category: .download, tags: [.download, .new], route: .webDigest),
            Tool(name: "批量下载", description: "批量下载网页中的图片或文件", icon: "arrow.down.circle", category: .download, tags: [.download], route: .batchDownload),
            Tool(name: "视频下载", description: "下载在线视频", icon: "video", category: .download, tags: [.download], route: .videoDownload),
            
            // 智能工具
            Tool(name: "接口测试", description: "测试智能提供商的接口", icon: "network", category: .ai, tags: [.ai, .dev], route: .apiTest),
            
            // 实用工具
            Tool(name: "批量重命名", description: "批量重命名文件和文件夹", icon: "character.cursor.ibeam", category: .utility, tags: [.document, .local], route: .batchRename),
            Tool(name: "SRT → FCPXML", description: "将 SRT 字幕转换为 Final Cut Pro 可用的 FCPXML 格式", icon: "captions.bubble", category: .conversion, tags: [.document, .new], route: .srtToFcpxml),
        ]
    }
}
