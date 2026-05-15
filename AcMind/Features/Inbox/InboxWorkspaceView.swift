import SwiftUI

struct InboxWorkspaceView: View {
    @State private var selectedCategory: InboxCategory = .all
    @State private var searchText: String = ""
    @State private var selectedItemID: InboxItem.ID = inboxMockItems.first?.id ?? UUID()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                inboxHeader

                HStack(alignment: .top, spacing: ACLayout.gapL) {
                    leftColumn
                    rightColumn
                }
            }
            .padding(.horizontal, ACLayout.pagePaddingX)
            .padding(.top, ACLayout.pagePaddingY)
            .padding(.bottom, ACLayout.pagePaddingBottom)
            .frame(maxWidth: 1512, alignment: .center)
        }
        .background(ACColors.pageBackground.ignoresSafeArea())
    }

    private var inboxHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("收集箱")
                        .font(ACTypography.pageTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text("把语音、任务、文档、Markdown 和图片收拢到这里，再整理归档或送往 Agent。")
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    ACSearchField("搜索收集内容", text: $searchText, width: 260, height: 36)
                    ACButton("新建", kind: .secondary, minWidth: 72) {}
                }
            }

            HStack(alignment: .center) {
                ACSegmentedControl(InboxCategory.allCases, selection: $selectedCategory) { category, isSelected in
                    Text(category.title)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: 620, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    ACButton("最新优先", kind: .secondary) {}
                    ACButton("筛选", kind: .secondary, minWidth: 72) {}
                }
            }
        }
        .frame(height: ACLayout.headerHeightMedium + 16)
    }

    private var leftColumn: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(todayFilteredItems.isEmpty ? "暂无内容" : "今日")
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Spacer()
                    ACBadge("\(todayFilteredItems.count) 条", kind: .blue)
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
                        VStack(spacing: 8) {
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
                    }
                    .frame(minHeight: 580)
                }
            }
        }
    }

    private var rightColumn: some View {
        ACDetailPanel(width: 486, padding: 16) {
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
        .frame(maxWidth: .infinity, minHeight: ACLayout.listRowMedium, alignment: .topLeading)
        .background(isSelected ? ACColors.selectedFill : ACColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(isSelected ? ACColors.accentBlue.opacity(0.35) : ACColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
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
