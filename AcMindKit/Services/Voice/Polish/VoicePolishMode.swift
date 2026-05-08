import Foundation

public enum VoicePolishMode: String, Codable, Sendable, CaseIterable {
    case raw
    case light
    case structured
    case aiPrompt
    case formal
    case none

    public var displayName: String {
        switch self {
        case .raw: return "原文整理"
        case .light: return "轻度润色"
        case .structured: return "结构化整理"
        case .aiPrompt: return "AI Prompt"
        case .formal: return "正式表达"
        case .none: return "不润色"
        }
    }

    public var description: String {
        switch self {
        case .raw: return "仅补全标点、必要分句，保留原话顺序和用词"
        case .light: return "去掉口癖、重复、停顿，补充自然标点"
        case .structured: return "按语义归类成双层格式，适合任务清单"
        case .aiPrompt: return "整理为结构化 AI prompt，可直接用于 ChatGPT/Claude"
        case .formal: return "适合工作沟通和邮件的正式表达"
        case .none: return "不进行润色处理"
        }
    }
}
