import SwiftUI
import AcMindKit

// MARK: - Tools View
// 工具 - 具体小工具集合

struct ToolsView: View {
    @StateObject private var viewModel = ToolsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            header

            // 分类筛选栏
            categoryFilterBar

            Divider()

            // 工具网格
            toolsGrid
        }
        .sheet(item: $viewModel.activeToolRoute, onDismiss: {
            viewModel.activeToolRoute = nil
        }) { route in
            toolSheet(for: route)
        }
        .background(AppSurfaceTokens.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("工具台")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Markdown、OCR、文档转换和批量处理")
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()

            // 搜索
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .font(.caption)

                TextField("搜索工具...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 240)

                Text("⌘K")
                    .font(.caption2)
                    .foregroundStyle(Color(NSColor.tertiaryLabelColor))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppSurfaceTokens.cardBackgroundSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppSurfaceTokens.separator, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
                        .background(viewModel.selectedCategory == category ? category.color.opacity(0.12) : Color.clear)
                        .foregroundStyle(viewModel.selectedCategory == category ? category.color : Color.secondary)
                        .cornerRadius(999)
                        .overlay(
                            viewModel.selectedCategory == category ?
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(category.color.opacity(0.3), lineWidth: 1) :
                            nil
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    // MARK: - Tools Grid

    private var toolsGrid: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 精选工具区标题
                HStack {
                    Text("精选工具")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // 工具卡片网格
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: 12) {
                    ForEach(viewModel.filteredTools) { tool in
                        ToolCard(tool: tool) {
                            viewModel.openTool(tool)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // 最近使用区
                RecentToolsSection(
                    recentTools: viewModel.recentTools,
                    canRestoreRecentTools: viewModel.canRestoreRecentTools,
                    onToolTap: { tool in
                        viewModel.openTool(Tool(
                            name: tool.name,
                            description: tool.description,
                            icon: tool.icon,
                            category: tool.category,
                            tags: [],
                            route: tool.route
                        ))
                    },
                    onClear: {
                        viewModel.clearRecentTools()
                    },
                    onRestore: {
                        viewModel.restoreRecentTools()
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
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
        case .modelManagement:
            ModelManagementPanel()
        case .apiTest:
            APITestPanel()
        }
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tool.category.color.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: tool.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(tool.category.color)
                }

                // 内容
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(tool.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primary)
                        
                        if tool.tags.contains(where: { $0.id == "new" }) {
                            Text("NEW")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(Color.green)
                                .cornerRadius(3)
                        }
                    }

                    Text(tool.description)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 5) {
                        ForEach(tool.tags.prefix(2), id: \.id) { tag in
                            Text(tag.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(tag.color.opacity(0.12))
                                .foregroundStyle(tag.color)
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .opacity(isHovered ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .padding(14)
            .frame(height: 96)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isPressed ? Color.accentColor.opacity(0.4) :
                                isHovered ? tool.category.color.opacity(0.25) :
                                Color(NSColor.separatorColor),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: isHovered ? Color.black.opacity(0.06) : Color.clear,
                radius: isHovered ? 8 : 0,
                x: 0,
                y: isHovered ? 2 : 0
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
                            .foregroundStyle(Color.secondary)
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
                // 空状态
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(Color.secondary)
                        .font(.caption)
                    
                    Text("暂无最近使用工具")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)

                    Spacer()
                }
                .padding(20)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(12)
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tool.category.color.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: tool.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(tool.category.color)
                }

                // 名称
                Text(tool.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                // 时间
                Text(tool.relativeTime)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isHovered ? tool.category.color.opacity(0.25) : Color(NSColor.separatorColor), lineWidth: 1)
                    )
            )
            .shadow(
                color: isHovered ? Color.black.opacity(0.05) : Color.clear,
                radius: isHovered ? 6 : 0,
                x: 0,
                y: isHovered ? 2 : 0
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
    static let image = ToolTag(id: "image", displayName: "图片", color: .purple)
    static let download = ToolTag(id: "download", displayName: "下载", color: .green)
    static let ai = ToolTag(id: "ai", displayName: "AI", color: .pink)
    static let dev = ToolTag(id: "dev", displayName: "开发", color: .gray)
    static let document = ToolTag(id: "document", displayName: "文档", color: .orange)
    static let local = ToolTag(id: "local", displayName: "本地", color: .teal)
    static let new = ToolTag(id: "new", displayName: "NEW", color: .green)
    static let beta = ToolTag(id: "beta", displayName: "Beta", color: .orange)
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
    case modelManagement
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
        case .modelManagement:
            return "modelManagement"
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
        case "modelManagement": self = .modelManagement
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
        case .conversion: return .indigo
        case .download: return .green
        case .ai: return .pink
        case .developer: return .gray
        case .utility: return .orange
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

/// 工具注册表 — 集中管理所有可用工具
/// 当前使用内置清单，后续可切到 JSON/Plist 配置并支持插件发现
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
            Tool(name: "模型管理", description: "管理本地和远程 AI 模型", icon: "cpu", category: .ai, tags: [.ai], route: .modelManagement),
            Tool(name: "API 测试", description: "测试 AI 提供商的 API", icon: "network", category: .ai, tags: [.ai, .dev], route: .apiTest),
            
            // 实用工具
            Tool(name: "批量重命名", description: "批量重命名文件和文件夹", icon: "character.cursor.ibeam", category: .utility, tags: [.document, .local], route: .batchRename),
            Tool(name: "SRT → FCPXML", description: "将 SRT 字幕转换为 Final Cut Pro 可用的 FCPXML 格式", icon: "captions.bubble", category: .conversion, tags: [.document, .new], route: .srtToFcpxml),
        ]
    }
}
