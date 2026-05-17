import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkbenchView: View {
    @State private var documents: [WorkbenchDocument] = []
    @State private var selectedSection: WorkbenchSection = .all
    @State private var searchText = ""
    @State private var selectedDocumentID: String?
    @State private var activeTool: WorkbenchToolDestination?
    @State private var showImporter = false
    @State private var showComposer = false
    @State private var draftTitle = ""
    @State private var draftContent = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        ACWorkspaceShell(
            title: "工作台",
            subtitle: "导入 Markdown / txt，自动生成摘要、标签、双链关联和本地索引；常用工具已并入此页。",
            trailing: {
                HStack(spacing: 12) {
                    ACSearchField("搜索文档", text: $searchText, width: 220, height: ACLayout.controlHeight)
                    ACButton("导入文件", kind: .primary, minWidth: 84) { showImporter = true }
                    ACButton("新建笔记", kind: .secondary, minWidth: 84) {
                        draftTitle = ""
                        draftContent = ""
                        showComposer = true
                    }
                }
            },
            left: { sidebar },
            center: { centerPanel },
            right: { detailPanel }
        )
        .task {
            loadDocuments()
        }
        .sheet(isPresented: $showComposer) {
            composerSheet
        }
        .sheet(item: $activeTool) { tool in
            tool.makeView()
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.plainText, .text, .item],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .confirmationDialog("删除这份文档？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                guard let selectedDocument else { return }
                documents.removeAll { $0.id == selectedDocument.id }
                persistDocuments()
                selectedDocumentID = filteredDocuments.first?.id
                ToastManager.shared.show(.success, "文档已删除")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后仅移除本地索引，不会删除原始文件。")
        }
    }

    private var sidebar: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("知识入口")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                VStack(spacing: 8) {
                    ForEach(WorkbenchSection.allCases) { section in
                        WorkbenchSidebarRow(
                            section: section,
                            count: section.count(from: documents),
                            selected: selectedSection == section
                        ) {
                            selectedSection = section
                            selectedDocumentID = filteredDocuments.first?.id
                        }
                    }
                }

                Divider().overlay(ACColors.divider)

                VStack(alignment: .leading, spacing: 10) {
                    Text("本地操作")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)

                    ACButton("导入文件", kind: .secondary) { showImporter = true }
                    ACButton("新建文本", kind: .ghost) {
                        draftTitle = ""
                        draftContent = ""
                        showComposer = true
                    }
                    ACButton("删除当前", kind: .ghost) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
    }

    private var centerPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            toolLibraryCard

            ACCard(padding: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedSection.title)
                            .font(ACTypography.sectionTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text(selectedSection.subtitle)
                            .font(ACTypography.body)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        ACBadge("\(filteredDocuments.count) 份", kind: .blue)
                        ACBadge("\(documents.filter { !$0.backlinks.isEmpty }.count) 双链", kind: .green)
                    }
                }
            }

            if filteredDocuments.isEmpty {
                ACCard {
                    ACEmptyState(
                        icon: "text.book.closed",
                        title: "当前没有可显示的文档",
                        subtitle: "点击导入文件，或者新建一条本地笔记。"
                    )
                }
            } else {
                ACCard(padding: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredDocuments) { document in
                            WorkbenchDocumentRow(
                                document: document,
                                selected: selectedDocumentID == document.id
                            ) {
                                selectedDocumentID = document.id
                            }
                        }
                    }
                }
            }
        }
    }

    private var toolLibraryCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("工具")
                        .font(ACTypography.sectionTitle)
                        .foregroundStyle(ACColors.primaryText)

                    Spacer(minLength: 0)

                    ACButton("打开 JSON 工具", kind: .primary, minWidth: 104) {
                        activeTool = .json
                    }
                }

                Text("后续我们加入的新功能都会按这种卡片格式继续罗列在这里。")
                    .font(ACTypography.body)
                    .foregroundStyle(ACColors.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    ForEach(workbenchToolCards) { card in
                        Button {
                            activeTool = card.destination
                        } label: {
                            WorkbenchToolCard(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var detailPanel: some View {
        ACDetailPanel(width: ACLayout.inspectorWidth, padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                if let selectedDocument {
                    WorkbenchDetailHeader(document: selectedDocument)
                    WorkbenchSummaryCard(document: selectedDocument)
                    WorkbenchLinkCard(document: selectedDocument)
                    WorkbenchMetadataCard(document: selectedDocument)
                    WorkbenchActionCard(
                        document: selectedDocument,
                        copyAction: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(selectedDocument.content, forType: .string)
                            ToastManager.shared.show(.success, "已复制文档内容")
                        },
                        revealAction: {
                            if let path = selectedDocument.path {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                                ToastManager.shared.show(.info, "已在 Finder 中打开")
                            } else {
                                ToastManager.shared.show(.warning, "该文档没有本地路径")
                            }
                        },
                        deleteAction: {
                            showDeleteConfirm = true
                        }
                    )
                } else {
                    ACEmptyState(
                        icon: "square.stack",
                        title: "选择一条文档查看详情",
                        subtitle: "这里会展示摘要、标签、双链和元数据。"
                    )
                }
            }
        }
    }

    private var filteredDocuments: [WorkbenchDocument] {
        documents
            .filter { document in
                let sectionMatch = selectedSection.matches(document)
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                let searchMatch: Bool
                if query.isEmpty {
                    searchMatch = true
                } else {
                    let haystack = [document.title, document.content, document.summary ?? "", document.tags.joined(separator: " ")]
                        .joined(separator: " ")
                    searchMatch = haystack.localizedCaseInsensitiveContains(query)
                }
                return sectionMatch && searchMatch
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var selectedDocument: WorkbenchDocument? {
        if let selectedDocumentID, let document = filteredDocuments.first(where: { $0.id == selectedDocumentID }) {
            return document
        }
        return filteredDocuments.first
    }

    private var composerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { showComposer = false }
                Spacer()
                Text("新建本地笔记")
                    .font(.headline)
                Spacer()
                Button("保存") {
                    let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let content = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !content.isEmpty else {
                        ToastManager.shared.show(.warning, "内容不能为空")
                        return
                    }
                    let newDocument = WorkbenchDocument(
                        title: title.isEmpty ? "未命名笔记" : title,
                        path: nil,
                        content: content,
                        summary: makeSummary(content),
                        tags: makeTags(content),
                        backlinks: makeBacklinks(content),
                        section: classifyDocument(title: title, content: content),
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    documents.insert(newDocument, at: 0)
                    persistDocuments()
                    selectedDocumentID = newDocument.id
                    showComposer = false
                    ToastManager.shared.show(.success, "已创建本地笔记")
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                TextField("标题", text: $draftTitle)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $draftContent)
                    .font(.system(size: 14))
                    .frame(minHeight: 260)
            }
            .padding()
        }
        .frame(width: 700, height: 460)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                ToastManager.shared.show(.warning, "没有选择文件")
                return
            }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let document = WorkbenchDocument(
                    title: url.deletingPathExtension().lastPathComponent,
                    path: url.path,
                    content: content,
                    summary: makeSummary(content),
                    tags: makeTags(content),
                    backlinks: makeBacklinks(content),
                    section: classifyDocument(title: url.lastPathComponent, content: content),
                    createdAt: Date(),
                    updatedAt: Date()
                )
                documents.insert(document, at: 0)
                persistDocuments()
                selectedDocumentID = document.id
                ToastManager.shared.show(.success, "已导入 \(url.lastPathComponent)")
            } catch {
                ToastManager.shared.show(.error, "文件读取失败: \(error.localizedDescription)")
            }
        case .failure(let error):
            ToastManager.shared.show(.error, "文件导入失败: \(error.localizedDescription)")
        }
    }

    private func loadDocuments() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([WorkbenchDocument].self, from: data) else {
            documents = Self.seedDocuments
            persistDocuments()
            selectedDocumentID = documents.first?.id
            return
        }

        documents = decoded
        if documents.isEmpty {
            documents = Self.seedDocuments
            persistDocuments()
        }
        selectedDocumentID = documents.first?.id
    }

    private func persistDocuments() {
        if let encoded = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }

    private func makeSummary(_ content: String) -> String {
        let lines = content
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return String(lines.prefix(3).joined(separator: " ").prefix(160))
    }

    private func makeTags(_ content: String) -> [String] {
        let pattern = #"(?:^|\s)#([\p{L}0-9_\-]+)"#
        let matches = content.matches(pattern: pattern)
        return Array(Set(matches.map { String($0) })).sorted()
    }

    private func makeBacklinks(_ content: String) -> [String] {
        let pattern = #"\[\[([^\]]+)\]\]"#
        let matches = content.matches(pattern: pattern)
        return Array(Set(matches.map { String($0) })).sorted()
    }

    private func classifyDocument(title: String, content: String) -> WorkbenchSection {
        if !makeBacklinks(content).isEmpty || title.localizedCaseInsensitiveContains("知识") {
            return .knowledgeBase
        }
        if content.localizedCaseInsensitiveContains("TODO") || content.localizedCaseInsensitiveContains("项目") {
            return .projectNotes
        }
        return .archive
    }

    private static let storageKey = "acmind.workbench.documents"

    private static let seedDocuments: [WorkbenchDocument] = [
        .init(
            title: "AcMind 本地工作台说明",
            path: nil,
            content: "这是一个初始说明文档，用于演示本地工作台的真实导入、预览和标签提取能力。#AcMind [[收集箱]]",
            summary: "工作台支持导入 Markdown / txt 文档，自动生成摘要、标签和双链关联。",
            tags: ["AcMind"],
            backlinks: ["收集箱"],
            section: .knowledgeBase,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}

private struct WorkbenchSidebarRow: View {
    let section: WorkbenchSection
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ACTypeIcon(section.icon, tint: selected ? ACColors.accentBlue : ACColors.secondaryText, background: selected ? ACColors.selectedFill : ACColors.softFill, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text("\(count) 份")
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(selected ? ACColors.selectedFill : ACColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? ACColors.accentBlue.opacity(0.3) : ACColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WorkbenchDocumentRow: View {
    let document: WorkbenchDocument
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ACTypeIcon("doc.text", tint: selected ? ACColors.accentBlue : ACColors.accentGreen, background: ACColors.selectedFill, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(document.title)
                            .font(ACTypography.itemTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Spacer(minLength: 0)
                        Text(document.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(ACTypography.mini)
                            .foregroundStyle(ACColors.tertiaryText)
                    }
                    Text(document.summary ?? makeSummaryFallback(document.content))
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    ACBadge(document.section.title, kind: badgeKind(for: document.section))
                    Text("\(document.wordCount) 字")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: ACLayout.listRowHeight, alignment: .topLeading)
            .background(selected ? ACColors.selectedFill : ACColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? ACColors.accentBlue.opacity(0.3) : ACColors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func badgeKind(for section: WorkbenchSection) -> ACBadge.Kind {
        switch section {
        case .all: return .blue
        case .knowledgeBase: return .green
        case .projectNotes: return .purple
        case .archive: return .neutral
        }
    }

    private func makeSummaryFallback(_ content: String) -> String {
        content.split(whereSeparator: \.isNewline).prefix(2).joined(separator: " ")
    }
}

private struct WorkbenchDetailHeader: View {
    let document: WorkbenchDocument

    var body: some View {
        HStack(spacing: 12) {
            ACTypeIcon("doc.text", tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(2)
                Text(document.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct WorkbenchSummaryCard: View {
    let document: WorkbenchDocument

    var body: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("摘要")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)
                Text(document.summary ?? "未生成摘要")
                    .font(ACTypography.body)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct WorkbenchLinkCard: View {
    let document: WorkbenchDocument

    var body: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("双链与关联")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)
                if document.backlinks.isEmpty {
                    Text("未发现双链")
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(document.backlinks, id: \.self) { link in
                            HStack(spacing: 10) {
                                ACTypeIcon("arrow.triangle.branch", tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 32)
                                Text(link)
                                    .font(ACTypography.captionMedium)
                                    .foregroundStyle(ACColors.primaryText)
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(ACColors.softFill)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
        }
    }
}

private struct WorkbenchMetadataCard: View {
    let document: WorkbenchDocument

    var body: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("元数据")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                ACInfoTable([
                    .init("分类", value: document.section.title),
                    .init("标签", value: document.tags.isEmpty ? "无" : document.tags.joined(separator: " · ")),
                    .init("字数", value: "\(document.wordCount)")
                ])
            }
        }
    }
}

private struct WorkbenchActionCard: View {
    let document: WorkbenchDocument
    let copyAction: () -> Void
    let revealAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .font(ACTypography.panelTitle)
                .foregroundStyle(ACColors.primaryText)

            HStack(spacing: 8) {
                ACButton("复制内容", kind: .primary, action: copyAction)
                ACButton("在 Finder 中显示", kind: .secondary, action: revealAction)
                ACButton("删除", kind: .ghost, action: deleteAction)
            }
        }
    }
}

private struct WorkbenchToolCard: View {
    let card: WorkbenchToolCardModel

    var body: some View {
        ACCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ACTypeIcon(card.symbol, tint: card.tint, background: card.tint.opacity(0.12), size: 32)
                    Spacer(minLength: 0)
                    ACBadge(card.state, kind: card.badgeKind)
                }

                Text(card.title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)

                Text(card.subtitle)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .frame(height: 120)
    }
}

private struct WorkbenchToolCardModel: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let state: String
    let badgeKind: ACBadge.Kind
    let destination: WorkbenchToolDestination
}

private enum WorkbenchToolDestination: String, Identifiable {
    case json
    case base64
    case markdown
    case compare
    case document
    case ocr
    case srt
    case webDigest

    var id: String { rawValue }

    @MainActor
    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .json:
            JSONFormatterPanel()
        case .base64:
            Base64CodecPanel()
        case .markdown:
            MarkdownCleanerPanel()
        case .compare:
            TextComparePanel()
        case .document:
            DocumentConverterPanel()
        case .ocr:
            OCRPanel()
        case .srt:
            SRTWorkbenchFCPXMLPanel()
        case .webDigest:
            WebDigestPanel()
        }
    }
}

private let workbenchToolCards: [WorkbenchToolCardModel] = [
    .init(title: "JSON 格式化", subtitle: "美化、压缩和校验 JSON", symbol: "curlybraces", tint: ACColors.accentBlue, state: "可用", badgeKind: .blue, destination: .json),
    .init(title: "Base64 编解码", subtitle: "文本和 Base64 互转", symbol: "arrow.left.arrow.right", tint: ACColors.accentGreen, state: "可用", badgeKind: .green, destination: .base64),
    .init(title: "Markdown 清理", subtitle: "整理标题、列表与空行", symbol: "text.alignleft", tint: ACColors.accentPurple, state: "可用", badgeKind: .purple, destination: .markdown),
    .init(title: "文本对比", subtitle: "快速比较两段文本", symbol: "square.2.layers.3d", tint: ACColors.accentOrange, state: "可用", badgeKind: .orange, destination: .compare),
    .init(title: "文档转换", subtitle: "把文档转成 Markdown", symbol: "doc", tint: ACColors.accentGreen, state: "可用", badgeKind: .green, destination: .document),
    .init(title: "OCR 图像识别", subtitle: "提取截图中的文本", symbol: "viewfinder", tint: ACColors.accentRed, state: "可用", badgeKind: .red, destination: .ocr),
    .init(title: "SRT → FCPXML", subtitle: "字幕转剪辑导出格式", symbol: "film", tint: ACColors.accentPurple, state: "可用", badgeKind: .purple, destination: .srt),
    .init(title: "网页正文提取", subtitle: "抓取网页标题和正文", symbol: "safari", tint: ACColors.accentBlue, state: "可用", badgeKind: .blue, destination: .webDigest)
]

private struct WorkbenchDocument: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var path: String?
    var content: String
    var summary: String?
    var tags: [String]
    var backlinks: [String]
    var section: WorkbenchSection
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        path: String?,
        content: String,
        summary: String?,
        tags: [String],
        backlinks: [String],
        section: WorkbenchSection,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.path = path
        self.content = content
        self.summary = summary
        self.tags = tags
        self.backlinks = backlinks
        self.section = section
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }
}

private enum WorkbenchSection: String, CaseIterable, Identifiable, Codable {
    case all
    case knowledgeBase
    case projectNotes
    case archive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .knowledgeBase: return "知识库"
        case .projectNotes: return "项目笔记"
        case .archive: return "待归档"
        }
    }

    var subtitle: String {
        switch self {
        case .all: return "所有本地导入与手动创建的文档"
        case .knowledgeBase: return "长期沉淀与结构化知识"
        case .projectNotes: return "项目推进与临时整理"
        case .archive: return "待清理和待整理内容"
        }
    }

    var icon: String {
        switch self {
        case .all: return "books.vertical"
        case .knowledgeBase: return "book.closed"
        case .projectNotes: return "note.text"
        case .archive: return "archivebox"
        }
    }

    func matches(_ document: WorkbenchDocument) -> Bool {
        switch self {
        case .all: return true
        default: return document.section == self
        }
    }

    func count(from documents: [WorkbenchDocument]) -> Int {
        documents.filter { matches($0) }.count
    }
}

private extension String {
    func matches(pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsRange = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, options: [], range: nsRange).compactMap { match in
            guard match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: self) else { return nil }
            return String(self[range])
        }
    }
}
