import SwiftUI
import AcMindKit

struct InboxHeader: View {
    @Binding var searchQuery: String
    @Binding var selectedType: SourceType?
    @Binding var selectedStatus: SourceItemStatus?
    let counts: [SourceType: Int]
    let totalCount: Int
    let totalSize: String
    let onNew: () -> Void
    
    private let types: [SourceType] = [.text, .audio, .screenshot, .webpage, .pdf, .docx, .unknownFile]
    
    var body: some View {
        VStack(spacing: 8) {
            // 第一行
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("收集箱")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(totalCount) 条内容 · \(totalSize) · 所有内容将保存至本地")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    TextField("搜索收集内容...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 200)
                }
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                // 视图切换按钮（暂时隐藏）
                HStack(spacing: 0) {
                    // List view
                    Button {
                        selectedStatus = nil
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    
                    // Compact view
                    Button {
                        selectedStatus = .pending
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    
                    // Card view
                    Button {
                        selectedStatus = .distilled
                    } label: {
                        Image(systemName: "square.grid.3x3")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .opacity(0)
                
                // 新建按钮
                Button(action: onNew) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("新建")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            // 第二行 - 类型筛选
            HStack(spacing: 6) {
                FilterButton(
                    title: "全部",
                    count: totalCount,
                    isSelected: selectedType == nil
                ) {
                    selectedType = nil
                }
                
                ForEach(types.filter { (counts[$0] ?? 0) > 0 }, id: \.self) { type in
                    FilterButton(
                        title: type.displayName,
                        count: counts[type] ?? 0,
                        isSelected: selectedType == type
                    ) {
                        selectedType = selectedType == type ? nil : type
                    }
                }
                
                Spacer()
                
                // 筛选器按钮
                Menu {
                    Button("全部") { selectedStatus = nil }
                    Button("未处理") { selectedStatus = .inbox }
                    Button("待 AI 整理") { selectedStatus = .pending }
                    Button("整理中") { selectedStatus = .distilling }
                    Button("已整理") { selectedStatus = .distilled }
                    Button("已归档") { selectedStatus = .archived }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "filter")
                            .font(.caption)
                        Text("筛选器")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
    }
}

private struct FilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.caption)
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
