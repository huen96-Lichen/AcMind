import SwiftUI

struct InboxDetailPanel: View {
    let item: InboxItem?
    let onDistill: () -> Void
    let onDelete: () -> Void

    @State private var note: String = ""

    init(
        item: InboxItem?,
        onDistill: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self.item = item
        self.onDistill = onDistill
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: 0) {
            if let item {
                header(item: item)
                Divider().background(InboxColors.border)
                previewSection(item: item)
                Divider().background(InboxColors.border)
                actionButtons(item: item)
                Divider().background(InboxColors.border)
                infoPanel(item: item)
                Divider().background(InboxColors.border)
                noteSection
                Divider().background(InboxColors.border)
                tagsSection(item: item)
                Spacer(minLength: 0)
            } else {
                emptyState
            }
        }
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func header(item: InboxItem) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(typeBackground(for: item.type))
                    .frame(width: 32, height: 32)

                Image(systemName: typeIconName(for: item.type))
                    .font(.system(size: 14))
                    .foregroundColor(typeForeground(for: item.type))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    Text(item.type.rawValue)
                        .font(.caption)
                        .foregroundColor(typeForeground(for: item.type))

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Color(NSColor.tertiaryLabelColor))

                    Text(item.time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: {}) {
                    Image(systemName: "star")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Menu {
                    Button("复制链接") {}
                    Button("分享") {}
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
    private func previewSection(item: InboxItem) -> some View {
        VStack(spacing: 8) {
            switch item.type {
            case .voice:
                audioPreview(item: item)
            case .image:
                imagePreview(item: item)
            case .task, .markdown, .document:
                textPreview(item: item)
            }
        }
        .padding(12)
    }

    private func audioPreview(item: InboxItem) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(InboxColors.accentOrange.opacity(0.1))
                            .frame(width: 40, height: 40)

                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundColor(InboxColors.accentOrange)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    InboxWaveformView(data: item.waveformData ?? [8, 12, 9, 14, 10, 8, 11, 16, 9, 13, 18, 12, 8, 10, 14, 11])

                    Text(item.duration ?? "00:00")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func imagePreview(item: InboxItem) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(InboxColors.softFill)
                .frame(height: 180)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary.opacity(0.35))
                        Text(item.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
        }
    }

    private func textPreview(item: InboxItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.recognitionText ?? item.summary)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func actionButtons(item: InboxItem) -> some View {
        HStack(spacing: 8) {
            if item.type == .voice {
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
                Button("移动到工作台") {}
                Button("发送到知识库") {}
                Button("添加到日程") {}
            } label: {
                Image(systemName: "ellipsis")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
        .padding(12)
    }

    private func infoPanel(item: InboxItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("信息")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(spacing: 4) {
                InfoRow(label: "类型", value: item.type.rawValue)
                InfoRow(label: "来源", value: item.source.isEmpty ? "手动输入" : item.source)
                InfoRow(label: "摘要", value: item.summary)

                if let duration = item.duration {
                    InfoRow(label: "时长", value: duration)
                }

                InfoRow(label: "时间", value: item.time)
                InfoRow(label: "状态", value: item.status.rawValue, valueColor: statusColor(for: item.status))
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

    private func tagsSection(item: InboxItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.subheadline)
                .fontWeight(.medium)

            InboxTagsSection(tags: item.tags)
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

    private func typeBackground(for type: InboxItemType) -> Color {
        switch type {
        case .voice: return InboxColors.voiceBackground
        case .task: return InboxColors.taskBackground
        case .markdown: return InboxColors.markdownBackground
        case .document: return InboxColors.documentBackground
        case .image: return InboxColors.imageBackground
        }
    }

    private func typeForeground(for type: InboxItemType) -> Color {
        switch type {
        case .voice: return InboxColors.voiceIconColor
        case .task: return InboxColors.taskIconColor
        case .markdown: return InboxColors.markdownIconColor
        case .document: return InboxColors.documentIconColor
        case .image: return InboxColors.imageIconColor
        }
    }

    private func typeIconName(for type: InboxItemType) -> String {
        switch type {
        case .voice: return "waveform"
        case .task: return "checkmark.circle"
        case .markdown: return "doc.plaintext"
        case .document: return "doc"
        case .image: return "photo"
        }
    }

    private func statusColor(for status: InboxItemStatus) -> Color {
        switch status {
        case .pending: return InboxColors.pendingText
        case .completed: return InboxColors.completedText
        case .archived: return InboxColors.archivedText
        case .collected: return InboxColors.completedText
        }
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
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundColor(valueColor ?? .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
