import Foundation
import SwiftUI

struct WorkbenchToolCardModel: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let state: String
    let badgeKind: ACBadge.Kind
    let destination: WorkbenchToolDestination
}

enum WorkbenchToolDestination: String, Identifiable {
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
    func makeView(toastManager: ToastManager) -> some View {
        switch self {
        case .json:
            JSONFormatterPanel(toastManager: toastManager)
        case .base64:
            Base64CodecPanel(toastManager: toastManager)
        case .markdown:
            MarkdownCleanerPanel(toastManager: toastManager)
        case .compare:
            TextComparePanel(toastManager: toastManager)
        case .document:
            DocumentConverterPanel(toastManager: toastManager)
        case .ocr:
            OCRPanel(toastManager: toastManager)
        case .srt:
            SRTWorkbenchFCPXMLPanel(toastManager: toastManager)
        case .webDigest:
            WebDigestPanel(toastManager: toastManager)
        }
    }
}

let workbenchToolCards: [WorkbenchToolCardModel] = [
    .init(title: "JSON 格式化", subtitle: "美化、压缩和校验 JSON", symbol: "curlybraces", tint: ACColors.accentBlue, state: "可用", badgeKind: .blue, destination: .json),
    .init(title: "Base64 编解码", subtitle: "文本和 Base64 互转", symbol: "arrow.left.arrow.right", tint: ACColors.accentGreen, state: "可用", badgeKind: .green, destination: .base64),
    .init(title: "Markdown 清理", subtitle: "整理标题、列表与空行", symbol: "text.alignleft", tint: ACColors.accentPurple, state: "可用", badgeKind: .purple, destination: .markdown),
    .init(title: "文本对比", subtitle: "快速比较两段文本", symbol: "square.2.layers.3d", tint: ACColors.accentOrange, state: "可用", badgeKind: .orange, destination: .compare),
    .init(title: "文档转换", subtitle: "把文档转成 Markdown", symbol: "doc", tint: ACColors.accentGreen, state: "可用", badgeKind: .green, destination: .document),
    .init(title: "OCR 图像识别", subtitle: "提取截图中的文本", symbol: "viewfinder", tint: ACColors.accentRed, state: "可用", badgeKind: .red, destination: .ocr),
    .init(title: "SRT → FCPXML", subtitle: "字幕转剪辑导出格式", symbol: "film", tint: ACColors.accentPurple, state: "可用", badgeKind: .purple, destination: .srt),
    .init(title: "网页正文提取", subtitle: "抓取网页标题和正文", symbol: "safari", tint: ACColors.accentBlue, state: "可用", badgeKind: .blue, destination: .webDigest)
]

struct WorkbenchDocument: Identifiable, Codable, Equatable {
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

extension WorkbenchDocument {
    static func makeSummary(_ content: String) -> String {
        let lines = content
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return String(lines.prefix(3).joined(separator: " ").prefix(160))
    }

    static func makeTags(_ content: String) -> [String] {
        let pattern = #"(?:^|\s)#([\p{L}0-9_\-]+)"#
        let matches = content.matches(pattern: pattern)
        return Array(Set(matches.map { String($0) })).sorted()
    }

    static func makeBacklinks(_ content: String) -> [String] {
        let pattern = #"\[\[([^\]]+)\]\]"#
        let matches = content.matches(pattern: pattern)
        return Array(Set(matches.map { String($0) })).sorted()
    }

    static func classifyDocument(title: String, content: String) -> WorkbenchSection {
        if !makeBacklinks(content).isEmpty || title.localizedCaseInsensitiveContains("知识") {
            return .knowledgeBase
        }
        if content.localizedCaseInsensitiveContains("TODO") || content.localizedCaseInsensitiveContains("项目") {
            return .projectNotes
        }
        return .archive
    }
}

enum WorkbenchSection: String, CaseIterable, Identifiable, Codable {
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

extension String {
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
