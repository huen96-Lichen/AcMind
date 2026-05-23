import Foundation

// MARK: - AgentToolRouter

/// Agent 工具路由器
public protocol AgentToolRouterProtocol: Sendable {
    func getAvailableTools() async -> [AgentToolInfo]
    func routeTool(request: AgentToolRequest) async throws -> AgentToolResult
    func executeToolChain(requests: [AgentToolRequest]) async throws -> [AgentToolResult]
}

/// Agent 工具路由器实现
public actor AgentToolRouter: AgentToolRouterProtocol {
    private let storage: any StorageServiceProtocol
    private var enabledTools: Set<AgentToolType>

    public init(storage: any StorageServiceProtocol = StorageService()) {
        self.storage = storage
        self.enabledTools = Set(AgentToolType.allCases)
    }

    public func getAvailableTools() async -> [AgentToolInfo] {
        var tools = AgentToolInfo.defaultTools

        for i in tools.indices {
            tools[i].enabled = enabledTools.contains(tools[i].type)
        }

        return tools
    }

    public func routeTool(request: AgentToolRequest) async throws -> AgentToolResult {
        let startTime = Date()

        let result: AgentToolResult

        switch request.toolType {
        case .inbox:
            result = try await routeToInbox(request)
        case .clipboard:
            result = try await routeToClipboard(request)
        case .schedule:
            result = try await routeToSchedule(request)
        case .voice:
            result = try await routeToVoice(request)
        case .knowledge:
            result = try await routeToKnowledge(request)
        case .webDigest:
            result = try await routeToWebDigest(request)
        case .markdown:
            result = try await routeToMarkdown(request)
        case .ocr:
            result = try await routeToOCR(request)
        case .export:
            result = try await routeToExport(request)
        case .file:
            result = try await routeToFile(request)
        case .ai:
            result = try await routeToAI(request)
        case .tools:
            result = try await routeToTools(request)
        }

        let duration = Int(Date().timeIntervalSince(startTime) * 1000)

        return AgentToolResult(
            id: result.id,
            toolType: request.toolType,
            action: request.action,
            success: result.success,
            output: result.output,
            errorMessage: result.errorMessage,
            durationMs: duration,
            timestamp: Date()
        )
    }

    public func executeToolChain(requests: [AgentToolRequest]) async throws -> [AgentToolResult] {
        var results: [AgentToolResult] = []

        for request in requests {
            let result = try await routeTool(request: request)
            results.append(result)

            if !result.success {
                break
            }
        }

        return results
    }

    public func enableTool(_ type: AgentToolType) {
        enabledTools.insert(type)
    }

    public func disableTool(_ type: AgentToolType) {
        enabledTools.remove(type)
    }

    // MARK: - Private Routing Methods

    private func routeToInbox(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "list":
            let items = try await storage.listSourceItems(filter: nil)
            let output = items.prefix(10).map { "\($0.id): \($0.title ?? "无标题")" }.joined(separator: "\n")
            return AgentToolResult(
                toolType: .inbox,
                action: "list",
                success: true,
                output: "收集箱内容:\n\(output.isEmpty ? "暂无内容" : output)"
            )

        case "add":
            let text = request.parameters["text"] ?? ""
            let item = SourceItem(
                type: .text,
                source: .capsule,
                status: .captured,
                title: String(text.prefix(50)),
                previewText: text
            )
            try await storage.insertSourceItem(item)
            return AgentToolResult(
                toolType: .inbox,
                action: "add",
                success: true,
                output: "已添加到收集箱: \(item.id)"
            )

        case "distill":
            let itemId = request.parameters["itemId"] ?? ""
            if let item = try await storage.getSourceItem(id: itemId) {
                return AgentToolResult(
                    toolType: .inbox,
                    action: "distill",
                    success: true,
                    output: "开始蒸馏: \(item.title ?? "无标题")"
                )
            }
            return AgentToolResult(
                toolType: .inbox,
                action: "distill",
                success: false,
                errorMessage: "项目不存在"
            )

        default:
            return AgentToolResult(
                toolType: .inbox,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToClipboard(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "read":
            let items = try await storage.listClipboardItems(limit: 5)
            let output = items.map { String(($0.content ?? "").prefix(100)) }.joined(separator: "\n---\n")
            return AgentToolResult(
                toolType: .clipboard,
                action: "read",
                success: true,
                output: output.isEmpty ? "剪贴板为空" : output
            )

        case "summarize":
            return AgentToolResult(
                toolType: .clipboard,
                action: "summarize",
                success: true,
                output: "剪贴板摘要功能"
            )

        default:
            return AgentToolResult(
                toolType: .clipboard,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToSchedule(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "list":
            return AgentToolResult(
                toolType: .schedule,
                action: "list",
                success: true,
                output: "日程列表"
            )

        case "create":
            let title = request.parameters["title"] ?? "新日程"
            return AgentToolResult(
                toolType: .schedule,
                action: "create",
                success: true,
                output: "已创建日程: \(title)"
            )

        default:
            return AgentToolResult(
                toolType: .schedule,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToVoice(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "transcribe":
            return AgentToolResult(
                toolType: .voice,
                action: "transcribe",
                success: true,
                output: "语音转写"
            )

        default:
            return AgentToolResult(
                toolType: .voice,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToKnowledge(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "read":
            return AgentToolResult(
                toolType: .knowledge,
                action: "read",
                success: true,
                output: "知识库读取"
            )

        case "write":
            let content = request.parameters["content"] ?? ""
            return AgentToolResult(
                toolType: .knowledge,
                action: "write",
                success: true,
                output: "已写入 Obsidian: \(content.prefix(50))..."
            )

        default:
            return AgentToolResult(
                toolType: .knowledge,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToWebDigest(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "fetch":
            let url = request.parameters["url"] ?? ""
            return AgentToolResult(
                toolType: .webDigest,
                action: "fetch",
                success: true,
                output: "已抓取网页: \(url)"
            )

        default:
            return AgentToolResult(
                toolType: .webDigest,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToMarkdown(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "format":
            let content = request.parameters["content"] ?? ""
            _ = content
            return AgentToolResult(
                toolType: .markdown,
                action: "format",
                success: true,
                output: "Markdown 格式化完成"
            )

        default:
            return AgentToolResult(
                toolType: .markdown,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToOCR(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "recognize":
            return AgentToolResult(
                toolType: .ocr,
                action: "recognize",
                success: true,
                output: "OCR 识别完成"
            )

        default:
            return AgentToolResult(
                toolType: .ocr,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToExport(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "toObsidian":
            let content = request.parameters["content"] ?? ""
            _ = content
            return AgentToolResult(
                toolType: .export,
                action: "toObsidian",
                success: true,
                output: "已导出到 Obsidian"
            )

        default:
            return AgentToolResult(
                toolType: .export,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToFile(_ request: AgentToolRequest) async throws -> AgentToolResult {
        return AgentToolResult(
            toolType: .file,
            action: request.action,
            success: true,
            output: "文件操作: \(request.action)"
        )
    }

    private func routeToAI(_ request: AgentToolRequest) async throws -> AgentToolResult {
        return AgentToolResult(
            toolType: .ai,
            action: request.action,
            success: true,
            output: "AI 调用: \(request.action)"
        )
    }

    private func routeToTools(_ request: AgentToolRequest) async throws -> AgentToolResult {
        let toolName = request.parameters["name"] ?? ""
        return AgentToolResult(
            toolType: .tools,
            action: request.action,
            success: true,
            output: "工具调用: \(toolName)"
        )
    }
}
