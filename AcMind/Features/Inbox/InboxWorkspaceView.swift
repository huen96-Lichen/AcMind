import AppKit
import SwiftUI
import UniformTypeIdentifiers
import AcMindKit

struct InboxWorkspaceView: View {
    @StateObject private var viewModel: InboxViewModel
    @EnvironmentObject private var toastManager: ToastManager
    @State private var selectedCategory: InboxFilterCategory = .all
    @State private var selectedItemID: String?
    @State private var showNewTextSheet = false
    @State private var showURLSheet = false
    @State private var showImportPicker = false
    @State private var showDeleteConfirm = false
    @State private var draftText = ""
    @State private var draftURL = ""

    init(container: ServiceContainer, toastManager: ToastManager) {
        self._viewModel = StateObject(wrappedValue: InboxViewModel(container: container, toastManager: toastManager))
    }

    var body: some View {
        ACWorkspaceShell(
            title: "收集箱",
            subtitle: "收拢文本、文件、网页和手动记录，再整理归档或送往 Agent。",
            trailing: {
                HStack(spacing: 12) {
                    ACSearchField("搜索收集内容", text: $viewModel.searchQuery, width: 220, height: ACLayout.controlHeight)

                    ACButton("新建文本", kind: .secondary, minWidth: 82) {
                        draftText = ""
                        showNewTextSheet = true
                    }

                    ACButton("导入文件", kind: .secondary, minWidth: 82) {
                        showImportPicker = true
                    }

                    ACButton("抓取网页", kind: .primary, minWidth: 82) {
                        draftURL = ""
                        showURLSheet = true
                    }
                }
            },
            left: { leftSidebar },
            center: { centerList },
            right: { rightDetail }
        )
        .task {
            await reload()
        }
        .onChange(of: selectedCategory) { _, newValue in
            viewModel.statusFilter = newValue.statusFilter
            Task { await reload() }
        }
        .sheet(isPresented: $showNewTextSheet) {
            inboxTextComposer
        }
        .sheet(isPresented: $showURLSheet) {
            inboxURLComposer
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.plainText, .text, .item],
            allowsMultipleSelection: false
        ) { result in
            Task {
                switch result {
                case .success(let urls):
                    guard let url = urls.first else {
                        toastManager.show(.warning, "没有选择文件")
                        return
                    }
                    await viewModel.importFile(url: url)
                    selectedItemID = viewModel.items.first?.id
                case .failure(let error):
                    toastManager.show(.error, "文件导入失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private var leftSidebar: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("状态筛选")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                VStack(spacing: 8) {
                    ForEach(InboxFilterCategory.allCases) { category in
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
                                    Text("\(category.count(from: viewModel.items)) 条")
                                        .font(ACTypography.caption)
                                        .foregroundStyle(ACColors.secondaryText)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .background(selectedCategory == category ? ACColors.selectedFill : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selectedCategory == category ? ACColors.accentBlue.opacity(0.3) : ACColors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().overlay(ACColors.divider)

                VStack(alignment: .leading, spacing: 10) {
                    Text("摘要")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)

                    InboxMetricRow(label: "全部", value: "\(viewModel.items.count)")
                    InboxMetricRow(label: "待处理", value: "\(viewModel.items.filter { $0.status == .pending || $0.status == .captured }.count)")
                    InboxMetricRow(label: "已蒸馏", value: "\(viewModel.items.filter { $0.status == .distilled }.count)")
                    InboxMetricRow(label: "已归档", value: "\(viewModel.items.filter { $0.status == .archived }.count)")
                }
            }
        }
    }

    private var centerList: some View {
        ACCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("收集内容")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("\(filteredItems.count) 条结果")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    Spacer(minLength: 0)

                    ACBadge(selectedCategory.title, kind: .blue)
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
                        subtitle: "试试切换筛选条件，或者新建一条文本收集。"
                    )
                    .frame(maxWidth: .infinity, minHeight: 420)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(groupedItems) { section in
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
                                                InboxSourceRow(item: item, isSelected: selectedItemID == item.id)
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

    private var rightDetail: some View {
        ACDetailPanel(width: ACLayout.inspectorWidth, padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                if let selectedItem {
                    InboxDetailHeader(item: selectedItem)

                    InboxContentCard(item: selectedItem)

                    InboxActionSection(
                        copyAction: {
                            copyCurrent(selectedItem)
                        },
                        distillAction: {
                            Task { await viewModel.distillItem(selectedItem) }
                        },
                        archiveAction: {
                            Task { await viewModel.updateStatus(selectedItem, status: .archived) }
                        },
                        pendingAction: {
                            Task { await viewModel.updateStatus(selectedItem, status: .pending) }
                        },
                        deleteAction: {
                            showDeleteConfirm = true
                        }
                    )

                    ACInfoTable([
                        .init("来源", value: selectedItem.source.displayName),
                        .init("类型", value: selectedItem.type.displayName),
                        .init("状态", value: selectedItem.status.displayName),
                        .init("创建时间", value: Self.dateFormatter.string(from: selectedItem.createdAt)),
                        .init("更新时间", value: Self.dateFormatter.string(from: selectedItem.updatedAt ?? selectedItem.createdAt)),
                        .init("URL", value: selectedItem.originalUrl ?? "无")
                    ])

                    InboxTagSection(tags: selectedItem.tags)
                } else {
                    ACEmptyState(
                        icon: "tray",
                        title: "没有选中的内容",
                        subtitle: "从左侧选择一条收集内容查看详情。"
                    )
                    .frame(maxWidth: .infinity, minHeight: 420)
                }
            }
        }
        .confirmationDialog("删除这条收集内容？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                guard let selectedItem else { return }
                Task {
                    await viewModel.delete(item: selectedItem)
                    selectedItemID = filteredItems.first?.id
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后会从本地收集箱中移除。")
        }
    }

    private var inboxTextComposer: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { showNewTextSheet = false }
                Spacer()
                Text("新建文本收集")
                    .font(.headline)
                Spacer()
                Button("保存") {
                    let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else {
                        toastManager.show(.warning, "输入不能为空")
                        return
                    }
                    Task {
                        await viewModel.createTextItem(text)
                        selectedItemID = viewModel.items.first?.id
                        showNewTextSheet = false
                    }
                }
            }
            .padding()

            Divider()

            TextEditor(text: $draftText)
                .font(.system(size: 14))
                .padding()
        }
        .frame(width: 540, height: 360)
    }

    private var inboxURLComposer: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { showURLSheet = false }
                Spacer()
                Text("抓取网页到收集箱")
                    .font(.headline)
                Spacer()
                Button("保存") {
                    guard let url = URL(string: draftURL.trimmingCharacters(in: .whitespacesAndNewlines)),
                          url.scheme != nil else {
                        toastManager.show(.warning, "请输入有效网址")
                        return
                    }
                    Task {
                        await viewModel.captureWebpage(url: url)
                        selectedItemID = viewModel.items.first?.id
                        showURLSheet = false
                    }
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                TextField("https://example.com", text: $draftURL)
                    .textFieldStyle(.roundedBorder)
                Text("保存前会先尝试抓取网页标题和正文，失败时会给出明确反馈。")
                    .font(.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }
            .padding()
        }
        .frame(width: 540, height: 220)
    }

    private var selectedItem: SourceItem? {
        if let selectedItemID, let item = filteredItems.first(where: { $0.id == selectedItemID }) {
            return item
        }
        return filteredItems.first
    }

    private var filteredItems: [SourceItem] {
        let statusFiltered = viewModel.items.filter { item in
            selectedCategory.matches(item)
        }
        return statusFiltered.sorted { ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) }
    }

    private var groupedItems: [InboxSection] {
        let cal = Calendar.current
        let today = filteredItems.filter { cal.isDateInToday($0.createdAt) }
        let yesterday = filteredItems.filter { cal.isDateInYesterday($0.createdAt) }
        let earlier = filteredItems.filter { !cal.isDateInToday($0.createdAt) && !cal.isDateInYesterday($0.createdAt) }

        var sections: [InboxSection] = []
        if !today.isEmpty { sections.append(.init(title: "今天", items: today)) }
        if !yesterday.isEmpty { sections.append(.init(title: "昨天", items: yesterday)) }
        if !earlier.isEmpty { sections.append(.init(title: "更早", items: earlier)) }
        return sections
    }

    private func reload() async {
        await viewModel.loadItems()
        if selectedItemID == nil {
            selectedItemID = viewModel.items.first?.id
        } else if let currentSelectedItemID = selectedItemID, viewModel.items.contains(where: { $0.id == currentSelectedItemID }) == false {
            selectedItemID = viewModel.items.first?.id
        }
    }

    private func copyCurrent(_ item: SourceItem) {
        let text = item.polishedTranscript ?? item.transcript ?? item.previewText ?? item.ocrText ?? item.title ?? ""
        guard !text.isEmpty else {
            toastManager.show(.warning, "没有可复制的内容")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        toastManager.show(.success, "已复制到剪贴板")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private enum InboxFilterCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case inbox = "收集箱"
    case pending = "待处理"
    case captured = "已采集"
    case distilled = "已蒸馏"
    case exported = "已导出"
    case archived = "已归档"

    var id: String { rawValue }
    var title: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray"
        case .inbox: return "tray.full"
        case .pending: return "clock"
        case .captured: return "square.and.arrow.down"
        case .distilled: return "sparkles"
        case .exported: return "doc.badge.arrow.up"
        case .archived: return "archivebox"
        }
    }

    var statusFilter: SourceItemStatus? {
        switch self {
        case .all: return nil
        case .inbox: return .inbox
        case .pending: return .pending
        case .captured: return .captured
        case .distilled: return .distilled
        case .exported: return .exported
        case .archived: return .archived
        }
    }

    func count(from items: [SourceItem]) -> Int {
        switch self {
        case .all:
            return items.count
        default:
            return items.filter { $0.status == statusFilter }.count
        }
    }

    func matches(_ item: SourceItem) -> Bool {
        guard let statusFilter else { return true }
        return item.status == statusFilter
    }
}

private struct InboxSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [SourceItem]
}

private struct InboxMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.primaryText)
        }
        .padding(.vertical, 2)
    }
}

private struct InboxSourceRow: View {
    let item: SourceItem
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ACTypeIcon(item.type.iconName, tint: item.type.color, background: item.type.bgColor, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title ?? item.type.displayName)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(Self.dateFormatter.string(from: item.updatedAt ?? item.createdAt))
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }

                Text("\(item.type.displayName) · \(item.source.displayName)")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)

                Text(item.previewText ?? item.transcript ?? item.ocrText ?? "暂无预览")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            ACBadge(item.status.displayName, kind: badgeKind(for: item.status))
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

    private func badgeKind(for status: SourceItemStatus) -> ACBadge.Kind {
        switch status {
        case .inbox, .pending: return .orange
        case .capturing: return .blue
        case .captured, .parsed: return .blue
        case .distilling, .distilled: return .green
        case .exporting, .exported: return .purple
        case .archived: return .neutral
        case .deleted: return .red
        case .parsing: return .blue
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct InboxDetailHeader: View {
    let item: SourceItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ACTypeIcon(item.type.iconName, tint: item.type.color, background: item.type.bgColor, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "未命名")
                    .font(ACTypography.cardTitle)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(2)
                Text(item.source.displayName)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct InboxContentCard: View {
    let item: SourceItem

    var body: some View {
        ACCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("内容预览")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                Text(item.polishedTranscript ?? item.transcript ?? item.previewText ?? item.ocrText ?? "暂无内容")
                    .font(ACTypography.body)
                    .foregroundStyle(ACColors.primaryText)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct InboxActionSection: View {
    let copyAction: () -> Void
    let distillAction: () -> Void
    let archiveAction: () -> Void
    let pendingAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .font(ACTypography.panelTitle)
                .foregroundStyle(ACColors.primaryText)

            HStack(spacing: 8) {
                ACButton("复制内容", kind: .secondary, action: copyAction)
                ACButton("蒸馏", kind: .primary, action: distillAction)
                ACButton("待处理", kind: .secondary, action: pendingAction)
                ACButton("归档", kind: .secondary, action: archiveAction)
                ACButton("删除", kind: .ghost, action: deleteAction)
            }
        }
    }
}

private struct InboxTagSection: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("标签")
                .font(ACTypography.panelTitle)
                .foregroundStyle(ACColors.primaryText)

            if tags.isEmpty {
                Text("暂无标签")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        ACBadge(tag, kind: .neutral)
                    }
                }
            }
        }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: spacing) {
            content
        }
    }
}
