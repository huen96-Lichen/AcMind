import Foundation

// MARK: - AgentTool（Agent 工具协议与模型）

/// Agent 工具类型
public enum AgentToolType: String, Codable, Sendable, Hashable, CaseIterable {
    case inbox           // 收集箱
    case clipboard       // 剪贴板
    case schedule        // 日程
    case tools           // 工具集
    case voice           // 语音
    case knowledge      // 知识库
    case webDigest      // 网页精读
    case markdown       // Markdown 整理
    case ocr            // OCR
    case export         // 导出
    case file           // 文件操作
    case ai             // AI 调用

    public var displayName: String {
        switch self {
        case .inbox: return "收集箱"
        case .clipboard: return "剪贴板"
        case .schedule: return "日程"
        case .tools: return "工具"
        case .voice: return "语音"
        case .knowledge: return "知识库"
        case .webDigest: return "网页精读"
        case .markdown: return "Markdown 整理"
        case .ocr: return "OCR"
        case .export: return "导出"
        case .file: return "文件操作"
        case .ai: return "AI 调用"
        }
    }

    public var icon: String {
        switch self {
        case .inbox: return "tray.and.arrow.down"
        case .clipboard: return "doc.on.clipboard"
        case .schedule: return "calendar"
        case .tools: return "wrench.and.screwdriver"
        case .voice: return "waveform"
        case .knowledge: return "books.vertical"
        case .webDigest: return "globe"
        case .markdown: return "doc.text"
        case .ocr: return "text.viewfinder"
        case .export: return "square.and.arrow.up"
        case .file: return "folder"
        case .ai: return "sparkles"
        }
    }
}

/// Agent 工具调用请求
public struct AgentToolRequest: Codable, Sendable {
    public var toolType: AgentToolType
    public var action: String
    public var parameters: [String: String]
    public var context: [String: String]

    public init(
        toolType: AgentToolType,
        action: String,
        parameters: [String: String] = [:],
        context: [String: String] = [:]
    ) {
        self.toolType = toolType
        self.action = action
        self.parameters = parameters
        self.context = context
    }
}

/// Agent 工具调用结果
public struct AgentToolResult: Codable, Sendable, Identifiable {
    public let id: String
    public var toolType: AgentToolType
    public var action: String
    public var success: Bool
    public var output: String?
    public var errorMessage: String?
    public var durationMs: Int
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        toolType: AgentToolType,
        action: String,
        success: Bool,
        output: String? = nil,
        errorMessage: String? = nil,
        durationMs: Int = 0,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.toolType = toolType
        self.action = action
        self.success = success
        self.output = output
        self.errorMessage = errorMessage
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}

/// 可用工具信息
public struct AgentToolInfo: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public var type: AgentToolType
    public var name: String
    public var description: String
    public var enabled: Bool
    public var isAvailable: Bool
    public var availableActions: [String]

    public init(
        id: String = UUID().uuidString,
        type: AgentToolType,
        name: String,
        description: String,
        enabled: Bool = true,
        isAvailable: Bool = true,
        availableActions: [String] = []
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.enabled = enabled
        self.isAvailable = isAvailable
        self.availableActions = availableActions
    }

    public static let defaultTools: [AgentToolInfo] = [
        AgentToolInfo(
            type: .inbox,
            name: "收集箱",
            description: "管理收集箱内容，包括添加、查询、整理",
            availableActions: ["list", "add", "update", "delete", "distill"]
        ),
        AgentToolInfo(
            type: .clipboard,
            name: "剪贴板",
            description: "读取和管理剪贴板内容",
            availableActions: ["read", "history", "summarize"]
        ),
        AgentToolInfo(
            type: .schedule,
            name: "日程",
            description: "管理日程和提醒",
            availableActions: ["list", "create", "update", "delete", "suggest"]
        ),
        AgentToolInfo(
            type: .tools,
            name: "工具集",
            description: "调用 AcMind 工具",
            availableActions: ["webDigest", "ocr", "markdown", "export", "compare"]
        ),
        AgentToolInfo(
            type: .voice,
            name: "语音",
            description: "语音转写和处理",
            availableActions: ["transcribe", "tts"]
        ),
        AgentToolInfo(
            type: .knowledge,
            name: "知识库",
            description: "读写 Obsidian 知识库",
            availableActions: ["read", "write", "search", "link"]
        ),
        AgentToolInfo(
            type: .webDigest,
            name: "网页精读",
            description: "抓取和解析网页内容",
            availableActions: ["fetch", "parse", "summarize"]
        ),
        AgentToolInfo(
            type: .export,
            name: "导出",
            description: "导出内容到 Obsidian/Markdown",
            availableActions: ["toObsidian", "toMarkdown", "toJSON"]
        ),
        AgentToolInfo(
            type: .file,
            name: "文件操作",
            description: "查看、重命名、复制、移动、删除和打开文件",
            availableActions: ["info", "list", "rename", "move", "copy", "delete", "open", "reveal"]
        ),
        AgentToolInfo(
            type: .ai,
            name: "AI 调用",
            description: "直接调用 AI 运行时进行对话、查询 Provider 和模型",
            availableActions: ["chat", "ask", "quickAsk", "providers", "models", "health"]
        ),
    ]
}
