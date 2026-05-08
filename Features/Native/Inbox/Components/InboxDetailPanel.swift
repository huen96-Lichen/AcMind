import SwiftUI
import AcMindKit

struct InboxDetailPanel: View {
    let item: SourceItem?
    let onDistill: () -> Void
    let onDelete: () -> Void
    
    @State private var note: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if let item = item {
                // 头部
                header(item: item)
                
                Divider()
                
                // 预览区域
                previewSection(item: item)
                
                Divider()
                
                // 操作按钮
                actionButtons(item: item)
                
                Divider()
                
                // 信息面板
                infoPanel(item: item)
                
                Divider()
                
                // 备注
                noteSection
                
                Divider()
                
                // 标签
                tagsSection(item: item)
                
                Spacer()
            } else {
                emptyState
            }
        }
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    @ViewBuilder
    private func header(item: SourceItem) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.type.bgColor)
                    .frame(width: 32, height: 32)
                
                Image(systemName: item.type.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(item.type.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? "未命名")
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 6) {
                    Text(item.type.displayName)
                        .font(.caption)
                        .foregroundColor(item.type.color)
                    
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                    
                    Text(formatDate(item.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Button {
                    // TODO: favorite action
                } label: {
                    Image(systemName: "star")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Menu {
                    Button("复制链接") { /* TODO */ }
                    Button("分享") { /* TODO */ }
                    Button("删除", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }
    
    @ViewBuilder
    private func previewSection(item: SourceItem) -> some View {
        VStack(spacing: 8) {
            switch item.type {
            case .audio:
                audioPreview(item: item)
            case .screenshot, .image:
                imagePreview(item: item)
            case .text:
                textPreview(item: item)
            case .webpage:
                linkPreview(item: item)
            case .pdf, .docx, .unknownFile:
                filePreview(item: item)
            case .video:
                videoPreview(item: item)
            }
        }
        .padding(12)
    }
    
    private func audioPreview(item: SourceItem) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    // TODO: play audio
                } label: {
                    ZStack {
                        Circle()
                            .fill(item.type.color.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundColor(item.type.color)
                    }
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    InboxWaveformPreview(duration: duration(for: item), color: item.type.color)
                    
                    Text(duration(for: item).formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func imagePreview(item: SourceItem) -> some View {
        VStack(spacing: 8) {
            if let path = item.contentPath {
                ImagePreview(url: URL(fileURLWithPath: path))
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.3))
                    .frame(height: 200)
            }
        }
    }
    
    private func textPreview(item: SourceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.previewText ?? item.transcript ?? "")
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
        }
    }
    
    private func linkPreview(item: SourceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = item.originalUrl {
                Text(url)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .underline()
                
                Button("打开链接") {
                    if let url = URL(string: url) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private func filePreview(item: SourceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.previewText ?? "")
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
            
            if let path = item.contentPath {
                Text("路径: \(path)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func videoPreview(item: SourceItem) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Image(systemName: "video")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.3))
                
                Button {
                    // TODO: play video
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 200)
            .background(Color.black.opacity(0.1))
            .cornerRadius(12)
            
            Text(duration(for: item).formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func actionButtons(item: SourceItem) -> some View {
        HStack(spacing: 8) {
            if item.type == .audio {
                Button {
                    // TODO: transcribe
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.cursor")
                        Text("转文字")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if item.type == .screenshot || item.type == .image {
                Button {
                    // TODO: OCR
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "character")
                        Text("OCR")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Button {
                onDistill()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("AI 整理")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            if item.type == .screenshot || item.type == .image {
                Button {
                    // TODO: copy
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "copy")
                        Text("复制")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Button {
                // TODO: share
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("分享")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Menu {
                Button("移动到工作台") { /* TODO */ }
                Button("发送到知识库") { /* TODO */ }
                Button("添加到日程") { /* TODO */ }
            } label: {
                Image(systemName: "ellipsis")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Spacer()
        }
        .padding(12)
    }
    
    private func infoPanel(item: SourceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("信息")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 4) {
                InfoRow(label: "类型", value: item.type.displayName)
                InfoRow(label: "来源", value: item.source.displayLabel)
                InfoRow(label: "大小", value: fileSize(for: item))
                
                if !dimensions(for: item).isEmpty {
                    InfoRow(label: "尺寸", value: dimensions(for: item))
                }
                
                if item.type == .audio || item.type == .video {
                    InfoRow(label: "时长", value: duration(for: item).formattedDuration)
                }
                
                InfoRow(label: "创建时间", value: formatDateTime(item.createdAt))
                InfoRow(label: "状态", value: item.status.displayLabel, valueColor: item.status.tagColor)
                InfoRow(label: "位置", value: "本地存储")
            }
        }
        .padding(12)
    }
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("添加备注...", text: $note)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                .font(.caption)
        }
        .padding(12)
    }
    
    private func tagsSection(item: SourceItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 4) {
                ForEach(item.tags, id: \.self) { tag in
                    InboxTagView(tag: tag)
                }
                
                Button {
                    // TODO: add tag
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        .padding(12)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            
            Text("选择内容查看详情")
                .font(.body)
                .foregroundColor(.secondary)
            
            Text("点击左侧列表中的内容")
                .font(.caption)
                .foregroundStyle(Color(NSColor.tertiaryLabelColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func duration(for item: SourceItem) -> TimeInterval {
        if let durationStr = item.metadata["duration"], let duration = TimeInterval(durationStr) {
            return duration
        }
        return 60
    }
    
    private func fileSize(for item: SourceItem) -> String {
        if let sizeStr = item.metadata["fileSize"], let bytes = Int(sizeStr) {
            if bytes < 1024 {
                return "\(bytes) B"
            } else if bytes < 1024 * 1024 {
                return String(format: "%.1f KB", Double(bytes) / 1024)
            } else {
                return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
            }
        }
        return "-"
    }
    
    private func dimensions(for item: SourceItem) -> String {
        if let width = item.metadata["width"], let height = item.metadata["height"] {
            return "\(width) × \(height)"
        }
        return ""
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    let valueColor: Color?
    
    init(label: String, value: String, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(valueColor ?? .primary)
        }
    }
}

private struct InboxTagView: View {
    let tag: String
    
    var body: some View {
        HStack(spacing: 2) {
            Text(tag)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Button {
                // TODO: remove tag
            } label: {
                Image(systemName: "x")
                    .font(.caption2)
                    .foregroundStyle(Color(NSColor.tertiaryLabelColor))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
}

private struct ImagePreview: View {
    let url: URL
    
    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "photo")
                .foregroundColor(.secondary)
        }
    }
}
