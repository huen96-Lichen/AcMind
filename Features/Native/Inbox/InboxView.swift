import SwiftUI
import AcMindKit

struct InboxView: View {
    @StateObject private var viewModel = InboxViewModel()
    @State private var searchQuery = ""
    @State private var selectedType: SourceType?
    @State private var selectedItem: SourceItem?
    
    private var filteredItems: [SourceType: [SourceItem]] {
        let items = viewModel.items.filter { item in
            let matchesSearch = searchQuery.isEmpty ||
                (item.title?.lowercased().contains(searchQuery.lowercased()) ?? false) ||
                (item.previewText?.lowercased().contains(searchQuery.lowercased()) ?? false) ||
                (item.transcript?.lowercased().contains(searchQuery.lowercased()) ?? false)
            
            let matchesType = selectedType == nil || item.type == selectedType
            
            return matchesSearch && matchesType
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return Dictionary(grouping: items) { item in
            calendar.isDate(item.createdAt, inSameDayAs: today) ? SourceType.text : .audio
        }
    }
    
    private var allItems: [SourceItem] {
        viewModel.items.filter { item in
            let matchesSearch = searchQuery.isEmpty ||
                (item.title?.lowercased().contains(searchQuery.lowercased()) ?? false) ||
                (item.previewText?.lowercased().contains(searchQuery.lowercased()) ?? false) ||
                (item.transcript?.lowercased().contains(searchQuery.lowercased()) ?? false)
            
            let matchesType = selectedType == nil || item.type == selectedType
            
            return matchesSearch && matchesType
        }
    }
    
    private var typeCounts: [SourceType: Int] {
        Dictionary(grouping: viewModel.items, by: \.type)
            .mapValues { $0.count }
    }
    
    private var totalSize: String {
        let totalBytes = viewModel.items.reduce(0) { total, item in
            if let sizeStr = item.metadata["fileSize"], let bytes = Int(sizeStr) {
                return total + bytes
            }
            return total
        }
        
        if totalBytes < 1024 {
            return "\(totalBytes) B"
        } else if totalBytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(totalBytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(totalBytes) / (1024 * 1024))
        }
    }
    
    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                InboxHeader(
                    searchQuery: $searchQuery,
                    selectedType: $selectedType,
                    counts: typeCounts,
                    totalCount: viewModel.items.count,
                    totalSize: totalSize,
                    onNew: { /* TODO */ }
                )
                
                Divider()
                
                if allItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            let calendar = Calendar.current
                            let today = calendar.startOfDay(for: Date())
                            let todayItems = allItems.filter { calendar.isDate($0.createdAt, inSameDayAs: today) }
                            
                            if !todayItems.isEmpty {
                                SectionHeader(title: "今天", count: todayItems.count)
                                
                                ForEach(todayItems) { item in
                                    InboxItemCard(
                                        item: item,
                                        isSelected: selectedItem?.id == item.id,
                                        onSelect: { selectedItem = item },
                                        onMore: { /* TODO */ }
                                    )
                                }
                            }
                            
                            let otherItems = allItems.filter { !calendar.isDate($0.createdAt, inSameDayAs: today) }
                            
                            if !otherItems.isEmpty {
                                SectionHeader(title: "昨天", count: otherItems.count)
                                
                                ForEach(otherItems) { item in
                                    InboxItemCard(
                                        item: item,
                                        isSelected: selectedItem?.id == item.id,
                                        onSelect: { selectedItem = item },
                                        onMore: { /* TODO */ }
                                    )
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }
            
            InboxDetailPanel(
                item: selectedItem,
                onDistill: {
                    if let item = selectedItem {
                        Task { await viewModel.distillItem(item) }
                    }
                },
                onDelete: {
                    if let item = selectedItem {
                        Task { await viewModel.delete(item: item) }
                    }
                }
            )
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task { await viewModel.loadItems() }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            
            Text("暂无收集内容")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("你可以通过：")
                    .font(.body)
                    .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                
                HStack(spacing: 12) {
                    Text("- 随身语音")
                        .font(.caption)
                        .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                    
                    Text("- 截图")
                        .font(.caption)
                        .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                    
                    Text("- 快速记录")
                        .font(.caption)
                        .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                    
                    Text("- 剪贴板暂存")
                        .font(.caption)
                        .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                }
                
                Text("将内容放入收集箱")
                    .font(.body)
                    .foregroundStyle(Color(NSColor.tertiaryLabelColor))
            }
            
            Button("添加内容") {
                // TODO
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, -100)
    }
}

private struct SectionHeader: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(Color(NSColor.tertiaryLabelColor))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
