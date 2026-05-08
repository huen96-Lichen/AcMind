import SwiftUI

// MARK: - SourceType UI 扩展

extension SourceType {
    public var iconName: String {
        switch self {
        case .text: return "text.quote"
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .pdf: return "doc.text.fill"
        case .docx: return "doc"
        case .screenshot: return "camera.viewfinder"
        case .webpage: return "globe"
        case .unknownFile: return "paperclip"
        }
    }

    public var color: Color {
        switch self {
        case .text: return .blue
        case .image: return .green
        case .audio: return .purple
        case .video: return .orange
        case .pdf: return .indigo
        case .docx: return .gray
        case .screenshot: return .mint
        case .webpage: return .cyan
        case .unknownFile: return .gray
        }
    }

    public var bgColor: Color {
        color.opacity(0.08)
    }
}

// MARK: - SourceItemStatus UI 扩展

extension SourceItemStatus {
    public var displayLabel: String {
        switch self {
        case .inbox: return "未处理"
        case .pending: return "待处理"
        case .capturing: return "采集中"
        case .captured: return "已采集"
        case .parsing: return "解析中"
        case .parsed: return "已解析"
        case .distilling: return "整理中"
        case .distilled: return "已整理"
        case .exporting: return "导出中"
        case .exported: return "已导出"
        case .archived: return "已归档"
        case .deleted: return "已删除"
        }
    }

    public var tagColor: Color {
        switch self {
        case .inbox: return .secondary
        case .pending: return .orange
        case .capturing, .parsing, .exporting: return .blue
        case .captured, .parsed: return .cyan
        case .distilling: return .blue
        case .distilled: return .green
        case .exported: return .green
        case .archived: return .mint
        case .deleted: return .red
        }
    }

    public var tagBgColor: Color {
        switch self {
        case .inbox: return .secondary.opacity(0.15)
        case .pending: return .orange.opacity(0.15)
        case .capturing, .parsing, .exporting: return .blue.opacity(0.15)
        case .captured, .parsed: return .cyan.opacity(0.15)
        case .distilling: return .blue.opacity(0.15)
        case .distilled: return .green.opacity(0.15)
        case .exported: return .green.opacity(0.15)
        case .archived: return .mint.opacity(0.15)
        case .deleted: return .red.opacity(0.15)
        }
    }
}

// MARK: - SourceOrigin UI 扩展

extension SourceOrigin {
    public var displayLabel: String {
        switch self {
        case .manual: return "手动输入"
        case .clipboard: return "剪贴板"
        case .screenshot: return "截图"
        case .webpage: return "网页"
        case .file: return "文件"
        case .voice: return "语音"
        case .capsule: return "胶囊"
        case .imported: return "导入"
        }
    }
}
