import AppKit
import SwiftUI
import AcMindKit

struct InboxItemCard: View {
    let item: SourceItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onMore: () -> Void
    
    @State private var isHovered = false
    
    private var previewText: String {
        if let text = item.previewText, !text.isEmpty {
            return text
        } else if let transcript = item.transcript, !transcript.isEmpty {
            return transcript
        } else if let ocr = item.ocrText, !ocr.isEmpty {
            return ocr
        }
        return ""
    }
    
    private var fileSize: String {
        if let sizeStr = item.metadata["fileSize"], let bytes = Int(sizeStr) {
            return formatFileSize(bytes)
        }
        return ""
    }
    
    private var dimensions: String {
        if let width = item.metadata["width"], let height = item.metadata["height"] {
            return "\(width) × \(height)"
        }
        return ""
    }
    
    private var duration: TimeInterval {
        if let durationStr = item.metadata["duration"], let duration = TimeInterval(durationStr) {
            return duration
        }
        return 60
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            typeIcon
            
            // 主内容区
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.title ?? "未命名")
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatTime(item.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    moreButton
                }
                
                // 元信息行
                HStack(spacing: 6) {
                    Text(item.type.displayName)
                        .font(.caption)
                        .foregroundColor(item.type.color)
                    
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                    
                    if !fileSize.isEmpty {
                        Text(fileSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                    }
                    
                    if !dimensions.isEmpty {
                        Text(dimensions)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                    }
                    
                    Text(formatTimeShort(item.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    InboxStatusTag(status: item.status)
                }
                
                // 预览内容
                previewContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(cardBackground)
        .cornerRadius(12)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    private var typeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(item.type.bgColor)
                .frame(width: 36, height: 36)
            
            Image(systemName: item.type.iconName)
                .font(.system(size: 16))
                .foregroundColor(item.type.color)
        }
        .frame(width: 36, height: 36)
    }
    
    private var moreButton: some View {
        Button(action: onMore) {
            Image(systemName: "ellipsis")
                .font(.caption)
                .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                .opacity(isHovered ? 1 : 0)
        }
        .buttonStyle(.plain)
        .frame(width: 20, height: 20)
    }
    
    @ViewBuilder
    private var previewContent: some View {
        switch item.type {
        case .audio:
            audioPreview
        case .screenshot, .image:
            imagePreview
        case .text:
            textPreview
        case .webpage:
            linkPreview
        case .pdf, .docx, .unknownFile:
            filePreview
        case .video:
            videoPreview
        }
    }
    
    private var audioPreview: some View {
        HStack(spacing: 8) {
            InboxWaveformPreview(duration: duration, color: item.type.color)
            
            Text(duration.formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
    }
    
    @ViewBuilder
    private var imagePreview: some View {
        HStack {
            Text(previewText.prefix(50).description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            if let path = item.contentPath {
                ImagePreview(url: URL(fileURLWithPath: path))
                    .frame(width: 60, height: 40)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.tertiaryLabelColor).opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
    
    private var textPreview: some View {
        Text(previewText.prefix(80).description)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
            .padding(.trailing, 20)
    }
    
    private var linkPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let url = item.originalUrl {
                Text(extractDomain(url))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(url)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
        }
    }
    
    private var filePreview: some View {
        Text(previewText.prefix(60).description)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
            .padding(.trailing, 20)
    }
    
    private var videoPreview: some View {
        HStack {
            Text(previewText.prefix(40).description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            Text(duration.formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var cardBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.08)
        } else if isHovered {
            return Color.secondary.opacity(0.04)
        }
        return Color.clear
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button("AI 整理") {
            copySummary()
            AppState.shared.selectSidebarItem(.agent)
        }
        
        Button("复制内容") {
            copySummary()
        }
        
        Divider()
        
        Button("移动到工作台") {
            AppState.shared.selectSidebarItem(.workbench)
        }
        
        Button("删除") {
            NotificationCenter.default.post(name: .acmindDeleteSourceItem, object: item.id)
        }
    }

    private func copySummary() {
        let text = item.previewText ?? item.transcript ?? item.ocrText ?? item.title ?? ""
        guard text.isEmpty == false else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatTimeShort(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
    
    private func extractDomain(_ urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return urlString
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

private struct ImagePreview: View {
    let url: URL
    
    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
                .foregroundColor(.secondary)
        }
    }
}
