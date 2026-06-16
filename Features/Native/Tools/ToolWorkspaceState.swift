import Foundation

enum ToolWorkspaceFlow {
    static func activeStage(activeToolRoute: ToolRoute?) -> ToolWorkspaceStage {
        activeToolRoute == nil ? .selection : .configuration
    }

    static func selectionSummary(filteredCount: Int) -> String {
        "\(filteredCount) 个命中"
    }

    static func configurationSummary(activeToolRoute: ToolRoute?) -> String {
        activeToolRoute?.displayName ?? "打开任意工具开始配置"
    }

    static func reviewSummary(recentCount: Int) -> String {
        recentCount == 0 ? "暂无最近结果" : "\(recentCount) 条最近动作"
    }
}

extension ToolRoute {
    var displayName: String {
        switch self {
        case .webDigest: return "WebDigest｜网页精读"
        case .jsonFormatter: return "JSON 格式化"
        case .base64Codec: return "Base64 编解码"
        case .markdownCleaner: return "Markdown 整理"
        case .textCompare: return "文本对比"
        case .documentConvert: return "文档转换"
        case .ocr: return "OCR 识别"
        case .imageProcess: return "图片处理"
        case .batchRename: return "批量重命名"
        case .srtToFcpxml: return "SRT → FCPXML"
        case .batchDownload: return "批量下载"
        case .videoDownload: return "视频下载"
        case .apiTest: return "API 测试"
        }
    }
}
