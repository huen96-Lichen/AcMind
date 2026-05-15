import SwiftUI

enum ViewMode {
    case list
    case grid
}

struct ClipboardHeaderBar: View {
    @State private var searchQuery = ""
    @State private var viewMode: ViewMode = .list
    @State private var showDeleteConfirm = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            titleBlock
            
            Spacer()
            
            searchBox
            
            addButton
            
            viewToggle
            
            deleteButton
        }
        .padding(.horizontal, ClipboardLayout.workspacePaddingX)
        .padding(.top, 22)
    }
    
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("剪贴板")
                .font(ClipboardTypography.pageTitle)
                .foregroundColor(ClipboardColors.primaryText)
            
            Text("自动保存、智能分类、快速粘贴")
                .font(ClipboardTypography.pageSubtitle)
                .foregroundColor(ClipboardColors.secondaryText)
        }
    }
    
    private var searchBox: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#777777"))
            
            TextField("搜索剪贴板内容...", text: $searchQuery)
                .font(ClipboardTypography.body)
                .foregroundColor(ClipboardColors.tertiaryText)
        }
        .frame(width: ClipboardLayout.searchWidth, height: ClipboardLayout.searchHeight)
        .background(ClipboardColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ClipboardLayout.searchHeight / 2)
                .stroke(ClipboardColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.025), radius: 8, y: 2)
    }
    
    private var addButton: some View {
        Button(action: {}) {
            Text("+ 新增")
                .font(ClipboardTypography.bodyMedium)
                .foregroundColor(ClipboardColors.primaryText)
        }
        .frame(width: ClipboardLayout.addButtonWidth, height: ClipboardLayout.addButtonHeight)
        .background(ClipboardColors.cardBackground)
        .cornerRadius(ClipboardLayout.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ClipboardLayout.smallRadius)
                .stroke(ClipboardColors.border, lineWidth: 1)
        )
    }
    
    private var viewToggle: some View {
        HStack(spacing: 0) {
            Button(action: { viewMode = .list }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 15))
            }
            .frame(width: 40, height: 34)
            .background(viewMode == .list ? ClipboardColors.softFill : Color.clear)
            .foregroundColor(viewMode == .list ? ClipboardColors.primaryText : ClipboardColors.secondaryText)
            .cornerRadius(ClipboardLayout.tinyRadius)
            
            Button(action: { viewMode = .grid }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15))
            }
            .frame(width: 40, height: 34)
            .background(viewMode == .grid ? ClipboardColors.softFill : Color.clear)
            .foregroundColor(viewMode == .grid ? ClipboardColors.primaryText : ClipboardColors.secondaryText)
            .cornerRadius(ClipboardLayout.tinyRadius)
        }
        .frame(height: ClipboardLayout.addButtonHeight)
        .background(ClipboardColors.cardBackground)
        .cornerRadius(ClipboardLayout.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ClipboardLayout.smallRadius)
                .stroke(ClipboardColors.border, lineWidth: 1)
        )
    }
    
    private var deleteButton: some View {
        Button(action: { showDeleteConfirm = true }) {
            Image(systemName: "trash")
                .font(.system(size: 16))
                .foregroundColor(ClipboardColors.secondaryText)
        }
        .frame(width: 40, height: ClipboardLayout.addButtonHeight)
        .background(ClipboardColors.cardBackground)
        .cornerRadius(ClipboardLayout.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ClipboardLayout.smallRadius)
                .stroke(ClipboardColors.border, lineWidth: 1)
        )
        .confirmationDialog("确认删除", isPresented: $showDeleteConfirm) {
            Button("清空全部", role: .destructive) {
            }
            Button("取消", role: .cancel) {
            }
        } message: {
            Text("确定要清空所有剪贴板内容吗？此操作无法撤销。")
        }
    }
}