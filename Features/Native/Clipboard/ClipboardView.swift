import SwiftUI
import AcMindKit

// MARK: - Clipboard View
// 剪贴板 - 复制、截图、临时材料历史

enum ViewMode {
    case list
    case grid
}

struct ClipboardView: View {
    @StateObject private var viewModel = ClipboardViewModel()
    @State private var viewMode: ViewMode = .grid

    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏统计面板
            sidebar
                .frame(width: 180)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing),
                    alignment: .trailing
                )

            // 主内容区
            VStack(spacing: 0) {
                // 头部
                header

                Divider()

                // 筛选栏
                filterBar

                // 内容
                content
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("剪贴板")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(String(viewModel.items.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                Text("\(viewModel.items.count) 条内容 · 自动保存")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            // 搜索
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.secondary)
                    .font(.caption)

                TextField("搜索剪贴板内容...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .frame(width: 200)
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            // 视图切换
            HStack(spacing: 0) {
                Button(action: { viewMode = .list }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                        .padding(6)
                        .background(viewMode == .list ? Color.accentColor.opacity(0.1) : Color.clear)
                        .foregroundStyle(viewMode == .list ? Color.accentColor : Color.secondary)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .help("列表视图")

                Button(action: { viewMode = .grid }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14))
                        .padding(6)
                        .background(viewMode == .grid ? Color.accentColor.opacity(0.1) : Color.clear)
                        .foregroundStyle(viewMode == .grid ? Color.accentColor : Color.secondary)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .help("网格视图")
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)

            // 清空按钮
            Button(action: { viewModel.clearAll() }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            .help("清空历史")
            .foregroundStyle(Color.secondary)
        }
        .padding()
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ClipboardFilter.allCases, id: \.self) { filter in
                        Button(action: { viewModel.filter = filter }) {
                            HStack(spacing: 4) {
                                if let icon = filter.icon {
                                    Image(systemName: icon)
                                        .font(.system(size: 12))
                                }
                                Text(filter.displayName)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.filter == filter ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(viewModel.filter == filter ? Color.white : Color.primary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Menu {
                        Button("文档") { viewModel.filter = .document }
                        Button("代码") { viewModel.filter = .code }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12))
                            Text("更多")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundStyle(Color.primary)
                        .cornerRadius(6)
                    }
                }
            }

            Spacer()

            // 排序按钮
            Button(action: {}) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12))
                    Text("最新")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .foregroundStyle(Color.secondary)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom),
            alignment: .bottom
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 16) {
            // 剪贴板统计
            VStack(alignment: .leading, spacing: 12) {
                Text("剪贴板统计")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondary)
                    .padding(.top, 16)

                // 总条目
                StatRow(label: "总条目", value: "\(viewModel.items.count)", icon: "doc.on.doc")
                // 今日新增
                StatRow(label: "今日新增", value: "\(viewModel.todayCount)", icon: "calendar.badge.plus")

                Divider()

                // 各类型统计
                ForEach(ClipboardFilter.allCases.filter { $0 != .all }, id: \.self) { filter in
                    StatRow(
                        label: filter.displayName,
                        value: "\(viewModel.count(of: filter))",
                        icon: filter.icon
                    )
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // 存储使用
            VStack(alignment: .leading, spacing: 8) {
                Text("存储使用")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondary)

                StorageProgressView(used: viewModel.storageUsed, total: viewModel.storageTotal)

                Text("\(formatStorage(viewModel.storageUsed)) / \(formatStorage(viewModel.storageTotal))")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 12)

            Divider()

            // 用户信息
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AcMind")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Pro")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 64))
                .foregroundStyle(Color.secondary.opacity(0.3))

            Text("剪贴板为空")
                .font(.title3)
                .foregroundStyle(Color.secondary)

            Text("复制内容后将自动记录")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Clipboard List

    private var clipboardList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredItems) { item in
                    ClipboardItemRow(item: item, viewModel: viewModel)

                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
    }

    // MARK: - Clipboard Grid

    private var clipboardGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 320))], spacing: 16) {
                ForEach(viewModel.filteredItems) { item in
                    ClipboardItemCard(item: item, viewModel: viewModel)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Helper Functions

    private func formatStorage(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    let icon: String?

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            } else {
                Color.clear.frame(width: 14)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Storage Progress View

struct StorageProgressView: View {
    let used: Int64
    let total: Int64

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * min(percentage, 1), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Clipboard Item Card

struct ClipboardItemCard: View {
    let item: ClipboardItem
    @ObservedObject var viewModel: ClipboardViewModel
    @State private var isHovered = false
    @State private var isFavorite = false

    var body: some View {
        VStack(spacing: 8) {
            // 图片预览区域
            if item.type == .screenshot {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .aspectRatio(4/3, contentMode: .fit)

                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.secondary.opacity(0.3))

                    // 收藏按钮
                    Button(action: { isFavorite.toggle() }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundStyle(isFavorite ? .yellow : .white)
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(4)
                    .opacity(isHovered ? 1 : 0)
                }
            } else {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.type.color.opacity(0.1))
                        .aspectRatio(4/3, contentMode: .fit)

                    VStack(spacing: 4) {
                        Image(systemName: item.type.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(item.type.color)

                        Text(item.type.displayName)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }

                    // 收藏按钮
                    Button(action: { isFavorite.toggle() }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundStyle(isFavorite ? .yellow : .white)
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(4)
                    .opacity(isHovered ? 1 : 0)
                }
            }

            // 内容信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(Color.primary)

                HStack(spacing: 4) {
                    Text(item.type.displayName)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(formatTime(item.timestamp))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                // 标签
                HStack(spacing: 4) {
                    TagView(label: item.type.displayName, color: item.type.color)
                    
                    if item.type == .screenshot {
                        TagView(label: "剪贴板", color: .gray)
                    } else if item.type == .text {
                        TagView(label: "文本笔记", color: .blue)
                    } else if item.type == .link {
                        TagView(label: "项目地址", color: .orange)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("复制") {
                viewModel.copyToClipboard(item)
            }

            Button("发送到收集箱") {
                viewModel.sendToInbox(item)
            }

            Button("发送到工作台") {
                viewModel.sendToWorkspace(item)
            }

            Divider()

            Button("删除") {
                viewModel.deleteItem(item)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Tag View

struct TagView: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .cornerRadius(4)
    }
}

// MARK: - Clipboard Item Row

struct ClipboardItemRow: View {
    let item: ClipboardItem
    @ObservedObject var viewModel: ClipboardViewModel
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.type.color.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: item.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(item.type.color)
            }

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(item.type.displayName)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(formatTime(item.timestamp))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer()

            // 操作按钮
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: { viewModel.copyToClipboard(item) }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("复制")

                    Button(action: { viewModel.sendToInbox(item) }) {
                        Image(systemName: "tray.and.arrow.down")
                    }
                    .buttonStyle(.plain)
                    .help("发送到收集箱")

                    Button(action: { viewModel.sendToWorkspace(item) }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)
                    .help("发送到工作台")

                    Button(action: { viewModel.deleteItem(item) }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.red)
                    .help("删除")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Color.secondary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("复制") {
                viewModel.copyToClipboard(item)
            }

            Button("发送到收集箱") {
                viewModel.sendToInbox(item)
            }

            Button("发送到工作台") {
                viewModel.sendToWorkspace(item)
            }

            Divider()

            Button("删除") {
                viewModel.deleteItem(item)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Clipboard Item Types

enum ClipboardItemType: String, CaseIterable {
    case text
    case screenshot
    case link

    var icon: String {
        switch self {
        case .text: return "text.quote"
        case .screenshot: return "photo"
        case .link: return "link"
        }
    }

    var color: Color {
        switch self {
        case .text: return .blue
        case .screenshot: return .green
        case .link: return .orange
        }
    }

    var displayName: String {
        switch self {
        case .text: return "文本"
        case .screenshot: return "截图"
        case .link: return "链接"
        }
    }
}

enum ClipboardFilter: CaseIterable {
    case all
    case text
    case screenshot
    case link
    case document
    case code

    var displayName: String {
        switch self {
        case .all: return "全部"
        case .text: return "文本"
        case .screenshot: return "图片"
        case .link: return "链接"
        case .document: return "文档"
        case .code: return "代码"
        }
    }

    var icon: String? {
        switch self {
        case .all: return "square.stack.3d.up"
        case .text: return "text.quote"
        case .screenshot: return "photo"
        case .link: return "link"
        case .document: return "doc.text"
        case .code: return "curlybraces"
        }
    }
}

// MARK: - Clipboard Item

struct ClipboardItem: Identifiable {
    let id = UUID()
    let content: String
    let preview: String
    let type: ClipboardItemType
    let timestamp: Date
}

// MARK: - View Model

@MainActor
class ClipboardViewModel: ObservableObject {
    private let clipboardService: ClipboardServiceProtocol

    @Published var items: [ClipboardItem] = []
    @Published var searchQuery = ""
    @Published var filter: ClipboardFilter = .all

    // 统计属性
    var todayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return items.filter { calendar.startOfDay(for: $0.timestamp) >= today }.count
    }

    var storageUsed: Int64 {
        // Mock 数据
        return 2_400_000_000
    }

    var storageTotal: Int64 {
        // Mock 数据
        return 20_000_000_000
    }

    func count(of filter: ClipboardFilter) -> Int {
        switch filter {
        case .all: return items.count
        case .text: return items.filter { $0.type == .text }.count
        case .screenshot: return items.filter { $0.type == .screenshot }.count
        case .link: return items.filter { $0.type == .link }.count
        case .document: return 0
        case .code: return 0
        }
    }

    var filteredItems: [ClipboardItem] {
        items.filter { item in
            let matchesSearch = searchQuery.isEmpty ||
                item.content.localizedCaseInsensitiveContains(searchQuery) ||
                item.preview.localizedCaseInsensitiveContains(searchQuery)

            let matchesFilter: Bool = {
                switch filter {
                case .all: return true
                case .text: return item.type == .text
                case .screenshot: return item.type == .screenshot
                case .link: return item.type == .link
                case .document: return false
                case .code: return false
                }
            }()

            return matchesSearch && matchesFilter
        }
    }

    init(clipboardService: ClipboardServiceProtocol? = nil) {
        self.clipboardService = clipboardService ?? ServiceContainer.shared.clipboardService
        loadItems()
    }

    private func loadItems() {
        Task {
            do {
                let serviceItems = try await clipboardService.listItems(filter: nil)
                items = serviceItems.map { item in
                    ClipboardItem(
                        content: item.textContent ?? item.content ?? "",
                        preview: String(item.textContent?.prefix(100) ?? item.content?.prefix(100) ?? ""),
                        type: mapContentType(item.type),
                        timestamp: item.createdAt
                    )
                }
            } catch {
                print("加载剪贴板数据失败: \(error.localizedDescription)")
            }
        }
    }

    private func mapContentType(_ type: ClipboardContentType) -> ClipboardItemType {
        switch type {
        case .text: return .text
        case .image: return .screenshot
        case .url: return .link
        case .file: return .text
        }
    }

    func copyToClipboard(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
    }

    func sendToInbox(_ item: ClipboardItem) {
        Task {
            do {
                _ = try await clipboardService.saveToInbox(id: item.id.uuidString)
            } catch {
                print("发送到收集箱失败: \(error.localizedDescription)")
            }
        }
    }

    func sendToWorkspace(_ item: ClipboardItem) {
        // 发送到工作台 - 保留占位
    }

    func deleteItem(_ item: ClipboardItem) {
        Task {
            do {
                try await clipboardService.deleteItem(id: item.id.uuidString)
                loadItems()
            } catch {
                print("删除失败: \(error.localizedDescription)")
            }
        }
    }

    func clearAll() {
        Task {
            do {
                try await clipboardService.clearHistory()
                loadItems()
            } catch {
                print("清空历史失败: \(error.localizedDescription)")
            }
        }
    }
}
