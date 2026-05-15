import SwiftUI

struct ClipboardDetailPanel: View {
    let item: ClipboardItem?
    @State private var isFavorite = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let item = item {
                DetailHeader(item: item, isFavorite: $isFavorite)
                
                DetailPreviewCard(item: item)
                
                DetailActions(item: item)
                
                DetailInfoTable(item: item)
            } else {
                emptyState
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(ClipboardLayout.detailPadding)
        .background(ClipboardColors.cardBackground)
        .cornerRadius(ClipboardLayout.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ClipboardLayout.cardRadius)
                .stroke(ClipboardColors.border, lineWidth: 1)
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundColor(ClipboardColors.tertiaryText)
            
            Text("选择一项查看详情")
                .font(ClipboardTypography.body)
                .foregroundColor(ClipboardColors.secondaryText)
        }
        .frame(maxHeight: .infinity)
    }
}

struct DetailHeader: View {
    let item: ClipboardItem
    @Binding var isFavorite: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TypeIcon(type: item.type, imageSize: nil)
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.type.displayName + "内容")
                    .font(ClipboardTypography.itemTitle)
                    .foregroundColor(ClipboardColors.primaryText)
                
                Text("\(item.source) · 今天 \(item.time)")
                    .font(ClipboardTypography.caption)
                    .foregroundColor(ClipboardColors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 4) {
                Button(action: { isFavorite.toggle() }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 15))
                        .foregroundColor(isFavorite ? ClipboardColors.accentYellow : ClipboardColors.secondaryText)
                }
                .frame(width: 28, height: 28)
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundColor(ClipboardColors.secondaryText)
                }
                .frame(width: 28, height: 28)
                
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15))
                        .foregroundColor(ClipboardColors.secondaryText)
                }
                .frame(width: 28, height: 28)
            }
        }
    }
}

struct DetailPreviewCard: View {
    let item: ClipboardItem
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ClipboardLayout.smallRadius)
                .fill(ClipboardColors.cardBackground)
                .frame(height: ClipboardLayout.detailPreviewHeight)
            
            VStack {
                ScrollView(.vertical) {
                    if item.type == .text || item.type == .code {
                        Text(item.content.isEmpty ? item.title : item.content)
                            .font(ClipboardTypography.body)
                            .foregroundColor(ClipboardColors.primaryText)
                            .lineSpacing(5)
                            .padding(16)
                    } else if item.type == .image {
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(ClipboardColors.accentPurple)
                            
                            Text(item.title)
                                .font(ClipboardTypography.body)
                                .foregroundColor(ClipboardColors.primaryText)
                            
                            if let imageSize = item.imageSize, let fileSize = item.fileSize {
                                Text("\(imageSize) · \(fileSize)")
                                    .font(ClipboardTypography.caption)
                                    .foregroundColor(ClipboardColors.secondaryText)
                            }
                        }
                        .padding(16)
                    } else if item.type == .link {
                        Text(item.title)
                            .font(ClipboardTypography.body)
                            .foregroundColor(ClipboardColors.accentBlue)
                            .padding(16)
                    } else if item.type == .file {
                        VStack(spacing: 8) {
                            Image(systemName: item.type.icon)
                                .font(.system(size: 32))
                                .foregroundColor(item.type.iconColor)
                            
                            Text(item.title)
                                .font(ClipboardTypography.itemTitle)
                                .foregroundColor(ClipboardColors.primaryText)
                            
                            if let fileSize = item.fileSize {
                                Text(fileSize)
                                    .font(ClipboardTypography.caption)
                                    .foregroundColor(ClipboardColors.secondaryText)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: ClipboardLayout.smallRadius)
                .stroke(ClipboardColors.border, lineWidth: 1)
        )
    }
}

struct DetailActions: View {
    let item: ClipboardItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .font(ClipboardTypography.sectionTitle)
                .foregroundColor(ClipboardColors.primaryText)
            
            HStack(spacing: 10) {
                ActionButton(
                    title: "粘贴到输入框",
                    icon: "arrow.right.to.line",
                    style: .primary
                )
                
                ActionButton(
                    title: "复制内容",
                    icon: "doc.on.doc",
                    style: .secondary
                )
                
                ActionButton(
                    title: "分享",
                    icon: "square.and.arrow.up",
                    style: .secondary
                )
            }
        }
    }
}

struct ActionButton: View {
    enum Style {
        case primary
        case secondary
    }
    
    let title: String
    let icon: String
    let style: Style
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(ClipboardTypography.bodyMedium)
            }
            .frame(height: 38)
            .padding(.horizontal, style == .primary ? 0 : 0)
            .frame(width: style == .primary ? 132 : 104)
            .background(style == .primary ? ClipboardColors.accentBlue : ClipboardColors.cardBackground)
            .foregroundColor(style == .primary ? .white : ClipboardColors.primaryText)
            .cornerRadius(ClipboardLayout.tinyRadius)
            .overlay(
                style == .secondary ? RoundedRectangle(cornerRadius: ClipboardLayout.tinyRadius)
                    .stroke(ClipboardColors.border, lineWidth: 1) : nil
            )
        }
    }
}

struct DetailInfoTable: View {
    let item: ClipboardItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("信息")
                .font(ClipboardTypography.sectionTitle)
                .foregroundColor(ClipboardColors.primaryText)
            
            VStack(spacing: 0) {
                InfoRow(label: "类型", value: item.type.displayName)
                
                if item.type == .text || item.type == .code {
                    InfoRow(label: "字符数", value: "\(item.characterCount)")
                } else if item.type == .image {
                    if let imageSize = item.imageSize {
                        InfoRow(label: "尺寸", value: imageSize)
                    }
                    if let fileSize = item.fileSize {
                        InfoRow(label: "大小", value: fileSize)
                    }
                } else if item.type == .file {
                    if let fileSize = item.fileSize {
                        InfoRow(label: "大小", value: fileSize)
                    }
                }
                
                InfoRow(label: "来源", value: item.source.replacingOccurrences(of: "从 ", with: "").replacingOccurrences(of: "复制", with: ""))
                
                InfoRow(label: "创建时间", value: "2025-05-09 \(item.time)")
                
                InfoRow(label: "存储位置", value: "本地剪贴板")
                
                InfoRow(label: "有效期", value: "永久保存（可在设置中修改）", isLast: true)
            }
            .background(ClipboardColors.cardBackground)
            .cornerRadius(ClipboardLayout.smallRadius)
            .overlay(
                RoundedRectangle(cornerRadius: ClipboardLayout.smallRadius)
                    .stroke(ClipboardColors.border, lineWidth: 1)
            )
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let isLast: Bool
    
    init(label: String, value: String, isLast: Bool = false) {
        self.label = label
        self.value = value
        self.isLast = isLast
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(ClipboardTypography.caption)
                .foregroundColor(ClipboardColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(ClipboardTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(ClipboardColors.primaryText)
        }
        .frame(height: 36)
        .padding(.horizontal, 14)
        .background(Color.clear)
        
        if !isLast {
            Divider()
                .background(ClipboardColors.softBorder)
                .padding(.horizontal, 14)
        }
    }
}