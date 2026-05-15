import SwiftUI

enum ClipboardItemType: String, CaseIterable, Identifiable {
    case text
    case image
    case link
    case file
    case code
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .text: return "textformat"
        case .image: return "photo"
        case .link: return "link"
        case .file: return "doc"
        case .code: return "curlybraces"
        }
    }
    
    var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .link: return "链接"
        case .file: return "文件"
        case .code: return "代码"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .text: return ClipboardColors.textTypeFill
        case .image: return ClipboardColors.imageTypeFill
        case .link: return ClipboardColors.linkTypeFill
        case .file: return ClipboardColors.fileTypeFill
        case .code: return ClipboardColors.codeTypeFill
        }
    }
    
    var iconColor: Color {
        switch self {
        case .text: return ClipboardColors.accentBlue
        case .image: return ClipboardColors.accentPurple
        case .link: return ClipboardColors.accentGreen
        case .file: return ClipboardColors.accentPurple
        case .code: return ClipboardColors.accentOrange
        }
    }
    
    var badgeBackgroundColor: Color {
        switch self {
        case .text: return ClipboardColors.textTypeFill
        case .image: return ClipboardColors.imageTypeFill
        case .link: return ClipboardColors.linkTypeFill
        case .file: return ClipboardColors.fileTypeFill
        case .code: return ClipboardColors.codeTypeFill
        }
    }
    
    var badgeTextColor: Color {
        switch self {
        case .text: return ClipboardColors.accentBlue
        case .image: return ClipboardColors.accentPurple
        case .link: return ClipboardColors.accentGreen
        case .file: return ClipboardColors.accentPurple
        case .code: return ClipboardColors.accentOrange
        }
    }
}

struct ClipboardItem: Identifiable {
    let id = UUID()
    let type: ClipboardItemType
    let title: String
    let content: String
    let time: String
    let source: String
    let imageSize: String?
    let fileSize: String?
    let isFavorite: Bool
    let group: String
    
    var characterCount: Int {
        content.count
    }
}

let clipboardMockItems: [ClipboardItem] = [
    ClipboardItem(
        type: .text,
        title: "可以，下面这份就是基于刚才理想图反推的设计 + Codex 可落地任务单...",
        content: "可以，下面这份就是基于刚才理想图反推的设计 + Codex 可落地任务单。\n---\n# 补充任务：大陆开态预览支持板块切换与自定义\n当前「灵动胶囊 / 大陆 配置中心」已经有大陆展开态预览，但它现在更像静态展示。\n目标是把它升级为可配置的「大陆展示态块预览器」。\n## 一、核心目标",
        time: "10:23:45",
        source: "从 Agent 复制",
        imageSize: nil,
        fileSize: nil,
        isFavorite: false,
        group: "今天"
    ),
    ClipboardItem(
        type: .image,
        title: "产品需求 PRD 初稿.png",
        content: "",
        time: "10:21:30",
        source: "截图",
        imageSize: "1024 × 768",
        fileSize: "2.3 MB",
        isFavorite: false,
        group: "今天"
    ),
    ClipboardItem(
        type: .link,
        title: "https://www.acmind.com/docs/product/overview",
        content: "https://www.acmind.com/docs/product/overview",
        time: "10:15:22",
        source: "从 Chrome 复制",
        imageSize: nil,
        fileSize: nil,
        isFavorite: false,
        group: "今天"
    ),
    ClipboardItem(
        type: .file,
        title: "项目进度周报_2025-05-09.pdf",
        content: "",
        time: "09:48:11",
        source: "从 Finder 复制",
        imageSize: nil,
        fileSize: "1.2 MB",
        isFavorite: false,
        group: "今天"
    ),
    ClipboardItem(
        type: .code,
        title: "function debounce(fn, delay) { timer = null; return function(...args) {...",
        content: "function debounce(fn, delay) {\n    let timer = null;\n    return function(...args) {\n        if (timer) clearTimeout(timer);\n        timer = setTimeout(() => {\n            fn.apply(this, args);\n        }, delay);\n    };\n}",
        time: "09:32:05",
        source: "从 VS Code 复制",
        imageSize: nil,
        fileSize: nil,
        isFavorite: false,
        group: "今天"
    ),
    ClipboardItem(
        type: .text,
        title: "对，现在这版最大的问题可以明确下结论：",
        content: "对，现在这版最大的问题可以明确下结论：\n\n1. 信息密度太低，不适合高频检索\n2. 分类体系不清晰\n3. 缺少详情处理能力\n4. 视觉层级混乱",
        time: "18:36:20",
        source: "从 Agent 复制",
        imageSize: nil,
        fileSize: nil,
        isFavorite: false,
        group: "昨天"
    ),
    ClipboardItem(
        type: .image,
        title: "设计规范参考.png",
        content: "",
        time: "18:20:04",
        source: "截图",
        imageSize: "1200 × 800",
        fileSize: "1.6 MB",
        isFavorite: false,
        group: "昨天"
    )
]

enum ClipboardCategory: String, CaseIterable, Identifiable {
    case all = "全部剪贴板"
    case text = "文本"
    case image = "图片"
    case link = "链接"
    case file = "文件"
    case code = "代码"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "square.stack.3d.up"
        case .text: return "textformat"
        case .image: return "photo"
        case .link: return "link"
        case .file: return "doc"
        case .code: return "curlybraces"
        }
    }
    
    var count: Int {
        switch self {
        case .all: return clipboardMockItems.count
        case .text: return clipboardMockItems.filter { $0.type == .text }.count
        case .image: return clipboardMockItems.filter { $0.type == .image }.count
        case .link: return clipboardMockItems.filter { $0.type == .link }.count
        case .file: return clipboardMockItems.filter { $0.type == .file }.count
        case .code: return clipboardMockItems.filter { $0.type == .code }.count
        }
    }
}

enum ClipboardFavoriteCategory: String, CaseIterable, Identifiable {
    case favorites = "收藏内容"
    case frequentlyUsed = "常用内容"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .favorites: return "star.fill"
        case .frequentlyUsed: return "clock"
        }
    }
    
    var count: Int {
        switch self {
        case .favorites: return 8
        case .frequentlyUsed: return 15
        }
    }
}

enum ClipboardCleanupCategory: String, CaseIterable, Identifiable {
    case olderThan7Days = "超过 7 天"
    case olderThan30Days = "超过 30 天"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .olderThan7Days: return "clock.arrow.circlepath"
        case .olderThan30Days: return "calendar.badge.clock"
        }
    }
    
    var count: Int {
        switch self {
        case .olderThan7Days: return 23
        case .olderThan30Days: return 8
        }
    }
}

struct ClipboardStats {
    let totalItems: Int = 126
    let last24Hours: Int = 32
    let textCount: Int = 68
    let imageCount: Int = 24
    let linkCount: Int = 12
    let fileCount: Int = 16
    let codeCount: Int = 6
    let storageUsed: Double = 2.4
    let storageTotal: Double = 20.0
}

let clipboardStats = ClipboardStats()