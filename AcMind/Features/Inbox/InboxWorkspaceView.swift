import SwiftUI

struct InboxWorkspaceView: View {
    @State private var selectedCategory: InboxCategory = .all
    @State private var searchText: String = ""
    @State private var selectedItemID: InboxItem.ID = inboxMockItems.first?.id ?? UUID()

    var body: some View {
        ACWorkspaceShell(
            title: "收集箱",
            subtitle: "收拢语音、任务、文档和图片，再整理归档或送往 Agent。",
            trailing: {
                HStack(spacing: 12) {
                    ACSearchField("搜索收集内容", text: $searchText, width: 220, height: ACLayout.controlHeight)
                    ACButton("新建", kind: .secondary, minWidth: 72) {}
                }
            },
            left: { leftSidebar },
            center: { centerList },
            right: { rightColumn }
        )
    }

    private var leftSidebar: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("分类")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                VStack(spacing: 8) {
                    ForEach(InboxCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack(spacing: 10) {
                                ACTypeIcon(
                                    category.icon,
                                    tint: selectedCategory == category ? ACColors.accentBlue : ACColors.secondaryText,
                                    background: selectedCategory == category ? ACColors.selectedFill : ACColors.softFill,
                                    size: 32
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.title)
                                        .font(ACTypography.itemTitle)
                                        .foregroundStyle(ACColors.primaryText)
                                        .lineLimit(1)
                                    Text("\(category.count) 条")
                                        .font(ACTypography.caption)
                                        .foregroundStyle(ACColors.secondaryText)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .background(selectedCategory == category ? ACColors.selectedFill : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selectedCategory == category ? ACColors.accentBlue.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var centerList: some View {
        ACCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(todayFilteredItems.isEmpty ? "暂无内容" : "今日")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("\(filteredItems.count) 条收集内容")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }
                    Spacer(minLength: 0)
                    ACBadge("\(filteredItems.count) 条", kind: .blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(ACColors.cardBackground)
                .overlay(alignment: .bottom) {
                    Divider().overlay(ACColors.divider)
                }

                if filteredItems.isEmpty {
                    ACEmptyState(
                        icon: "tray",
                        title: "没有匹配的收集内容",
                        subtitle: "试试切换分类或清空搜索词。"
                    )
                    .frame(maxWidth: .infinity, minHeight: 420)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(groupedItems, id: \.id) { section in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(section.title)
                                        .font(ACTypography.captionMedium)
                                        .foregroundStyle(ACColors.secondaryText)
                                        .padding(.top, section.title == "今天" ? 0 : 6)

                                    VStack(spacing: 8) {
                                        ForEach(section.items) { item in
                                            Button {
                                                selectedItemID = item.id
                                            } label: {
                                                InboxListRow(item: item, isSelected: selectedItemID == item.id)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var rightColumn: some View {
        ACDetailPanel(width: ACLayout.inspectorWidth, padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                if let item = selectedItem {
                    InboxDetailHeader(item: item)

                    InboxAudioPreview(item: item)

                    InboxRecognitionSection(text: item.recognitionText)

                    InboxSuggestedActionsSection()

                    ACInfoTable([
                        .init("来源", value: item.source.isEmpty ? "手动整理" : item.source),
                        .init("创建时间", value: item.time),
                        .init("状态", value: item.status.rawValue),
                        .init("时长", value: item.duration ?? "无"),
                        .init("存储位置", value: "本地")
                    ])

                    InboxTagSection(tags: item.tags)
                } else {
                    ACEmptyState(
                        icon: "tray",
                        title: "没有选中的内容",
                        subtitle: "默认会选择第一条收集内容。"
                    )
                    .frame(maxWidth: .infinity, minHeight: 420)
                }
            }
        }
    }

    private var selectedItem: InboxItem? {
        filteredItems.first(where: { $0.id == selectedItemID }) ?? filteredItems.first ?? inboxMockItems.first
    }

    private var filteredItems: [InboxItem] {
        inboxMockItems.filter { item in
            categoryMatches(item) && searchMatches(item)
        }
    }

    private var todayFilteredItems: [InboxItem] {
        filteredItems.filter { $0.time.contains("10") || $0.time.contains("09") }
    }

    private var groupedItems: [InboxSection] {
        guard !filteredItems.isEmpty else { return [] }
        let today = filteredItems.filter { $0.time.contains("10") || $0.time.contains("09") }
        let earlier = filteredItems.filter { !($0.time.contains("10") || $0.time.contains("09")) }

        return [
            InboxSection(title: "今天", items: today.isEmpty ? filteredItems : today),
            InboxSection(title: "更早", items: today.isEmpty ? [] : earlier)
        ].filter { !$0.items.isEmpty }
    }

    private func categoryMatches(_ item: InboxItem) -> Bool {
        switch selectedCategory {
        case .all: return true
        case .pending: return item.status == .pending
        case .voice: return item.type == .voice
        case .task: return item.type == .task
        case .document: return item.type == .document
        case .markdown: return item.type == .markdown
        case .image: return item.type == .image
        }
    }

    private func searchMatches(_ item: InboxItem) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let haystack = [
            item.title,
            item.source,
            item.summary,
            item.recognitionText ?? "",
            item.status.rawValue
        ].joined(separator: " ")
        return haystack.localizedCaseInsensitiveContains(query)
    }
}

private enum InboxCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case pending = "待处理"
    case voice = "语音"
    case task = "任务"
    case document = "文档"
    case markdown = "Markdown"
    case image = "图片"

    var id: String { rawValue }
    var title: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray"
        case .pending: return "clock"
        case .voice: return "waveform"
        case .task: return "checklist"
        case .document: return "doc.text"
        case .markdown: return "doc.richtext"
        case .image: return "photo"
        }
    }

    var count: Int {
        switch self {
        case .all: return inboxMockItems.count
        case .pending: return inboxMockItems.filter { $0.status == .pending }.count
        case .voice: return inboxMockItems.filter { $0.type == .voice }.count
        case .task: return inboxMockItems.filter { $0.type == .task }.count
        case .document: return inboxMockItems.filter { $0.type == .document }.count
        case .markdown: return inboxMockItems.filter { $0.type == .markdown }.count
        case .image: return inboxMockItems.filter { $0.type == .image }.count
        }
    }
}

private struct InboxSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [InboxItem]
}

private struct InboxListRow: View {
    let item: InboxItem
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InboxListIcon(type: item.type)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    Text(item.time)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }

                Text("\(item.type.rawValue) · \(item.source.isEmpty ? "手动收集" : item.source)")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(item.summary)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                ACBadge(item.status.rawValue, kind: badgeKind(for: item.status))
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ACColors.tertiaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: ACLayout.listRowHeight, alignment: .topLeading)
        .background(isSelected ? ACColors.selectedFill : ACColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? ACColors.accentBlue.opacity(0.3) : ACColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func badgeKind(for status: InboxItemStatus) -> ACBadge.Kind {
        switch status {
        case .pending: return .orange
        case .completed: return .green
        case .archived: return .blue
        case .collected: return .purple
        }
    }
}

private struct InboxListIcon: View {
    let type: InboxItemType

    var body: some View {
        ACTypeIcon(iconName, tint: tint, background: background, size: 42)
    }

    private var iconName: String {
        switch type {
        case .voice: return "waveform"
        case .task: return "checklist"
        case .markdown: return "doc.richtext"
        case .document: return "doc.text"
        case .image: return "photo"
        }
    }

    private var tint: Color {
        switch type {
        case .voice: return ACColors.accentOrange
        case .task: return ACColors.accentPurple
        case .markdown: return ACColors.accentBlue
        case .document: return ACColors.accentBlue
        case .image: return ACColors.accentRed
        }
    }

    private var background: Color {
        tint.opacity(0.12)
    }
}

private struct InboxDetailHeader: View {
    let item: InboxItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InboxListIcon(type: item.type)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    ACBadge(item.status.rawValue, kind: .blue)
                }

                Text("\(item.type.rawValue) · \(item.source.isEmpty ? "手动收集" : item.source)")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }
        }
    }
}

private struct InboxAudioPreview: View {
    let item: InboxItem

    var body: some View {
        if let waveformData = item.waveformData {
            ACCard(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("音频播放")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Spacer(minLength: 0)
                        ACButton("播放", kind: .secondary) {}
                    }

                    HStack(spacing: 12) {
                        ACButton("▶︎", kind: .primary) {}
                        InboxWaveformMini(data: waveformData)
                        Text(item.duration ?? "00:00")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.primaryText)
                    }
                }
            }
        }
    }
}

private struct InboxWaveformMini: View {
    let data: [CGFloat]

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(Array(data.prefix(18).enumerated()), id: \.offset) { index, value in
                Capsule()
                    .fill(index % 3 == 0 ? ACColors.accentBlue : ACColors.accentPurple)
                    .frame(width: 4, height: max(8, value * 0.7))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .center)
        .padding(.horizontal, 10)
        .background(ACColors.softFill, in: RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
    }
}

private struct InboxRecognitionSection: View {
    let text: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("内容识别")
                    .font(ACTypography.cardTitle)
                    .foregroundStyle(ACColors.primaryText)
                Spacer(minLength: 0)
                ACButton("AI 识别", kind: .secondary) {}
            }

            if let text {
                Text(text)
                    .font(ACTypography.body)
                    .foregroundStyle(ACColors.primaryText)
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                    .background(ACColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                            .stroke(ACColors.border, lineWidth: 1)
                    )
            } else {
                ACEmptyState(icon: "sparkles", title: "暂无识别内容", subtitle: "这里会显示语音转写、OCR 或文本识别结果。")
                    .frame(maxWidth: .infinity, minHeight: 110)
            }
        }
    }
}

private struct InboxSuggestedActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建议操作")
                .font(ACTypography.cardTitle)
                .foregroundStyle(ACColors.primaryText)

            HStack(spacing: 8) {
                ACButton("新建任务", kind: .secondary) {}
                ACButton("生成文档", kind: .secondary) {}
                ACButton("生成图表", kind: .secondary) {}
                ACButton("发送到 Agent", kind: .secondary) {}
            }
        }
    }
}

private struct InboxTagSection: View {
    let tags: [(String, Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("标签")
                .font(ACTypography.cardTitle)
                .foregroundStyle(ACColors.primaryText)

            if tags.isEmpty {
                Text("暂无标签")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                        ACBadge(tag.0, kind: .neutral)
                            .foregroundStyle(tag.1)
                    }
                }
            }
        }
    }
}
