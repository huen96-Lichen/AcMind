import SwiftUI
import AcMindKit

// MARK: - Clipboard View

/// 剪贴板历史视图
/// 功能：
/// 1. 显示剪贴板历史列表（文本/图片/文件/URL）
/// 2. 支持搜索和类型过滤
/// 3. 支持 pin/unpin/删除/复制/保存到 Inbox
/// 4. 显示统计信息
struct ClipboardView: View {
    @StateObject private var viewModel = ClipboardViewModel()
    @State private var showingClearConfirmation = false
    @State private var selectedItem: ClipboardItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar
            
            Divider()
            
            // 统计信息
            statsBar
            
            Divider()
            
            // 过滤栏
            filterBar
            
            // 列表
            listView
        }
        .frame(minWidth: 400, minHeight: 500)
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .alert("清空历史", isPresented: $showingClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                Task { await viewModel.clearHistory() }
            }
        } message: {
            Text("这将删除所有未固定的剪贴板历史。固定项目将被保留。")
        }
        .sheet(item: $selectedItem) { item in
            ClipboardItemDetailView(item: item, viewModel: viewModel)
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack {
            // 标题
            VStack(alignment: .leading, spacing: 2) {
                Text("剪贴板历史")
                    .font(.headline)
                
                Text(viewModel.isWatching ? "监听中" : "已暂停")
                    .font(.caption)
                    .foregroundStyle(viewModel.isWatching ? .green : .secondary)
            }
            
            Spacer()
            
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("搜索...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
            .frame(width: 200)
            
            // 暂停/恢复按钮
            Button(action: {
                Task {
                    if viewModel.isWatching {
                        await viewModel.pauseWatching()
                    } else {
                        await viewModel.resumeWatching()
                    }
                }
            }) {
                Image(systemName: viewModel.isWatching ? "pause.circle" : "play.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(viewModel.isWatching ? "暂停监听" : "恢复监听")
            
            // 清空按钮
            Button(action: { showingClearConfirmation = true }) {
                Image(systemName: "trash")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("清空历史")
        }
        .padding()
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack(spacing: 16) {
            StatBadge(
                icon: "doc.text",
                count: viewModel.stats.textCount,
                color: .blue,
                label: "文本"
            )
            
            StatBadge(
                icon: "photo",
                count: viewModel.stats.imageCount,
                color: .green,
                label: "图片"
            )
            
            StatBadge(
                icon: "doc",
                count: viewModel.stats.fileCount,
                color: .orange,
                label: "文件"
            )
            
            StatBadge(
                icon: "link",
                count: viewModel.stats.urlCount,
                color: .purple,
                label: "链接"
            )
            
            Divider()
                .frame(height: 20)
            
            HStack(spacing: 4) {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.yellow)
                Text("\(viewModel.stats.pinnedCount)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Text("共 \(viewModel.stats.totalCount) 项")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "全部",
                    isSelected: viewModel.selectedType == nil,
                    action: { viewModel.selectedType = nil }
                )
                
                ForEach(ClipboardContentType.allCases) { type in
                    FilterChip(
                        title: type.displayName,
                        icon: viewModel.typeIcon(for: type),
                        isSelected: viewModel.selectedType == type,
                        color: viewModel.typeColor(for: type),
                        action: { viewModel.selectedType = type }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - List View
    
    private var listView: some View {
        List {
            if viewModel.filteredItems.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "clipboard")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.5))
                        
                        Text(viewModel.searchQuery.isEmpty ? "暂无剪贴板历史" : "没有找到匹配项")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            } else {
                // Pinned Items Section
                let pinnedItems = viewModel.filteredItems.filter { $0.isPinned }
                if !pinnedItems.isEmpty {
                    Section {
                        ForEach(pinnedItems) { item in
                            ClipboardItemRow(
                                item: item,
                                viewModel: viewModel,
                                onSelect: { selectedItem = item }
                            )
                        }
                    } header: {
                        HStack {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.yellow)
                            Text("固定")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                // Unpinned Items Section
                let unpinnedItems = viewModel.filteredItems.filter { !$0.isPinned }
                if !unpinnedItems.isEmpty {
                    Section {
                        ForEach(unpinnedItems) { item in
                            ClipboardItemRow(
                                item: item,
                                viewModel: viewModel,
                                onSelect: { selectedItem = item }
                            )
                        }
                    } header: {
                        if !pinnedItems.isEmpty {
                            Text("历史")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Clipboard Item Row

struct ClipboardItemRow: View {
    let item: ClipboardItem
    @ObservedObject var viewModel: ClipboardViewModel
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(viewModel.typeColor(for: item.type).opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: viewModel.typeIcon(for: item.type))
                    .foregroundStyle(viewModel.typeColor(for: item.type))
                    .font(.system(size: 14, weight: .medium))
            }
            
            // 内容预览
            VStack(alignment: .leading, spacing: 4) {
                Text(previewText)
                    .lineLimit(2)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                    
                    if let sourceApp = item.sourceApp {
                        Text(sourceApp)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(viewModel.formatDate(item.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 操作按钮
            if isHovered {
                HStack(spacing: 8) {
                    // Pin/Unpin
                    Button(action: {
                        Task {
                            if item.isPinned {
                                await viewModel.unpinItem(id: item.id)
                            } else {
                                await viewModel.pinItem(id: item.id)
                            }
                        }
                    }) {
                        Image(systemName: item.isPinned ? "pin.slash" : "pin")
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "取消固定" : "固定")
                    
                    // Copy
                    Button(action: {
                        Task { await viewModel.copyItem(id: item.id) }
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("复制")
                    
                    // Save to Inbox
                    Button(action: {
                        Task { await viewModel.saveToInbox(id: item.id) }
                    }) {
                        Image(systemName: "tray.and.arrow.down")
                    }
                    .buttonStyle(.plain)
                    .help("保存到 Inbox")
                    
                    // Delete
                    Button(action: {
                        Task { await viewModel.deleteItem(id: item.id) }
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("删除")
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button {
                Task { await viewModel.copyItem(id: item.id) }
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            
            Button {
                Task { await viewModel.saveToInbox(id: item.id) }
            } label: {
                Label("保存到 Inbox", systemImage: "tray.and.arrow.down")
            }
            
            Divider()
            
            if item.isPinned {
                Button {
                    Task { await viewModel.unpinItem(id: item.id) }
                } label: {
                    Label("取消固定", systemImage: "pin.slash")
                }
            } else {
                Button {
                    Task { await viewModel.pinItem(id: item.id) }
                } label: {
                    Label("固定", systemImage: "pin")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                Task { await viewModel.deleteItem(id: item.id) }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private var previewText: String {
        let text = viewModel.previewText(for: item)
        return text.isEmpty ? "(空内容)" : text
    }
}

// MARK: - Clipboard Item Detail View

struct ClipboardItemDetailView: View {
    let item: ClipboardItem
    @ObservedObject var viewModel: ClipboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // 头部信息
                HStack {
                    ZStack {
                        Circle()
                            .fill(viewModel.typeColor(for: item.type).opacity(0.2))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: viewModel.typeIcon(for: item.type))
                            .foregroundStyle(viewModel.typeColor(for: item.type))
                            .font(.system(size: 20, weight: .medium))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.type.displayName)
                            .font(.headline)
                        
                        Text(viewModel.formatDate(item.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.yellow)
                            .font(.title2)
                    }
                }
                
                Divider()
                
                // 内容区域
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch item.type {
                        case .text, .url:
                            Text(item.textContent ?? item.content ?? "")
                                .font(.system(size: 14, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                        case .image:
                            if let assetId = item.content,
                               let asset = try? awaitAsset(id: assetId),
                               let image = loadImage(asset: asset) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit
                                    .frame(maxHeight: 300)
                            } else {
                                Text("无法加载图片")
                                    .foregroundStyle(.secondary)
                            }
                            
                        case .file:
                            if let paths = item.content?.split(separator: "\n") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(paths), id: \.self) { path in
                                        HStack {
                                            Image(systemName: "doc")
                                            Text(String(path))
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 12) {
                    Button("关闭") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Spacer()
                    
                    Button {
                        Task { await viewModel.copyItem(id: item.id) }
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        Task { await viewModel.saveToInbox(id: item.id) }
                    } label: {
                        Label("保存到 Inbox", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(minWidth: 400, minHeight: 300)
            .navigationTitle("剪贴板详情")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
    
    private func awaitAsset(id: String) -> AssetFile? {
        // 简化处理，实际应该使用 async/await
        nil
    }
    
    private func loadImage(asset: AssetFile) -> NSImage? {
        NSImage(contentsOfFile: asset.filePath)
    }
}

// MARK: - Helper Views

struct StatBadge: View {
    let icon: String
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    var color: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .medium : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? color : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extensions

extension ClipboardContentType: Identifiable {
    public var id: String { rawValue }
}

extension ClipboardItem: Identifiable {}
