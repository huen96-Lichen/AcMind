import AppKit
import Foundation
import PDFKit

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
    private let distillService: any DistillServiceProtocol
    private let voiceService: any VoiceServiceProtocol
    private let aiRuntime: any AIRuntimeProtocol
    private let quickAskService: AgentQuickAskService
    private let processRunner: any ProcessCommandRunning
    private var enabledTools: Set<AgentToolType>

    public init(
        storage: any StorageServiceProtocol = StorageService(),
        distillService: (any DistillServiceProtocol)? = nil,
        voiceService: (any VoiceServiceProtocol)? = nil,
        aiRuntime: (any AIRuntimeProtocol)? = nil,
        processRunner: (any ProcessCommandRunning)? = nil
    ) {
        self.storage = storage
        self.distillService = distillService ?? DistillService(storage: storage)
        self.voiceService = voiceService ?? VoiceService(storage: storage)
        self.aiRuntime = aiRuntime ?? AIRuntimeService(storage: storage)
        self.quickAskService = AgentQuickAskService(aiRuntime: self.aiRuntime)
        self.processRunner = processRunner ?? ProcessCommandRunner()
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

    private func enableTool(_ type: AgentToolType) {
        enabledTools.insert(type)
    }

    private func disableTool(_ type: AgentToolType) {
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
                output: "收集箱内容:\n\(output.isEmpty ? "收集箱暂无内容" : output)"
            )

        case "add":
            let text = request.parameters["text"] ?? ""
            let item = SourceItem(
                type: .text,
                source: .agent,
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
            guard let item = try await storage.getSourceItem(id: itemId) else {
                return AgentToolResult(
                    toolType: .inbox,
                    action: "distill",
                    success: false,
                    errorMessage: "项目不存在"
                )
            }

            let note = try await distillService.distill(sourceItem: item)
            return AgentToolResult(
                toolType: .inbox,
                action: "distill",
                success: true,
                output: "已蒸馏: \(note.title ?? item.title ?? "无标题")"
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
            let output = summarizeClipboardItems(items, includeCount: false)
            return AgentToolResult(
                toolType: .clipboard,
                action: "read",
                success: true,
                output: output.isEmpty ? "剪贴板为空" : output
            )

        case "history":
            let items = try await storage.listClipboardItems(limit: 20)
            let output = summarizeClipboardItems(items, includeCount: true)
            return AgentToolResult(
                toolType: .clipboard,
                action: "history",
                success: true,
                output: output.isEmpty ? "剪贴板为空" : output
            )

        case "summarize":
            let items = try await storage.listClipboardItems(limit: 20)
            guard items.isEmpty == false else {
                return AgentToolResult(
                    toolType: .clipboard,
                    action: "summarize",
                    success: false,
                    errorMessage: "剪贴板为空"
                )
            }

            let summary = summarizeClipboardItems(items, includeCount: true)
            return AgentToolResult(
                toolType: .clipboard,
                action: "summarize",
                success: true,
                output: summary
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
            let tasks = try await storage.listScheduledAgentTasks()
            let lines = tasks.prefix(10).map { task in
                let state = task.enabled ? "启用" : "停用"
                return "\(task.name) | \(task.cronExpression) | \(task.skillName) | \(state)"
            }
            return AgentToolResult(
                toolType: .schedule,
                action: "list",
                success: true,
                output: "定时任务 (\(tasks.count)):\n\(lines.isEmpty ? "暂无任务" : lines.joined(separator: "\n"))"
            )

        case "create":
            let name = request.parameters["name"] ?? request.parameters["title"] ?? "新任务"
            let cronExpression = request.parameters["cronExpression"] ?? request.parameters["cron"] ?? "@daily"
            let skillName = request.parameters["skillName"] ?? request.parameters["skill"] ?? ""
            guard skillName.isEmpty == false else {
                return AgentToolResult(
                    toolType: .schedule,
                    action: "create",
                    success: false,
                    errorMessage: "请提供 skillName"
                )
            }

            let task = ScheduledAgentTask(
                name: name,
                cronExpression: cronExpression,
                skillName: skillName,
                inputParams: parseStringDictionary(request.parameters["inputParams"] ?? request.parameters["params"])
            )
            try await storage.insertScheduledAgentTask(task)
            return AgentToolResult(
                toolType: .schedule,
                action: "create",
                success: true,
                output: "已创建定时任务: \(task.name) (\(task.id))"
            )

        case "update":
            let taskID = request.parameters["taskId"] ?? request.parameters["id"] ?? ""
            guard taskID.isEmpty == false else {
                return AgentToolResult(
                    toolType: .schedule,
                    action: "update",
                    success: false,
                    errorMessage: "请提供 taskId"
                )
            }
            guard let existing = try await storage.getScheduledAgentTask(id: taskID) else {
                return AgentToolResult(
                    toolType: .schedule,
                    action: "update",
                    success: false,
                    errorMessage: "未找到任务: \(taskID)"
                )
            }

            var updated = existing
            if let name = request.parameters["name"], name.isEmpty == false { updated.name = name }
            if let cron = request.parameters["cronExpression"] ?? request.parameters["cron"], cron.isEmpty == false { updated.cronExpression = cron }
            if let skill = request.parameters["skillName"] ?? request.parameters["skill"], skill.isEmpty == false { updated.skillName = skill }
            if let enabled = request.parameters["enabled"].flatMap(Self.parseBool) { updated.enabled = enabled }
            if let params = request.parameters["inputParams"] ?? request.parameters["params"] {
                updated.inputParams = parseStringDictionary(params)
            }
            updated.updatedAt = Date()

            try await storage.insertScheduledAgentTask(updated)
            return AgentToolResult(
                toolType: .schedule,
                action: "update",
                success: true,
                output: "已更新定时任务: \(updated.name)"
            )

        case "delete":
            let taskID = request.parameters["taskId"] ?? request.parameters["id"] ?? ""
            guard taskID.isEmpty == false else {
                return AgentToolResult(
                    toolType: .schedule,
                    action: "delete",
                    success: false,
                    errorMessage: "请提供 taskId"
                )
            }
            try await storage.deleteScheduledAgentTask(id: taskID)
            return AgentToolResult(
                toolType: .schedule,
                action: "delete",
                success: true,
                output: "已删除定时任务: \(taskID)"
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
            let audioPath = request.parameters["audioURL"] ?? request.parameters["audioPath"] ?? ""
            guard audioPath.isEmpty == false else {
                return AgentToolResult(
                    toolType: .voice,
                    action: "transcribe",
                    success: false,
                    errorMessage: "请提供 audioURL"
                )
            }
            let audioURL = URL(fileURLWithPath: audioPath)
            let transcript = try await voiceService.transcribe(audioURL: audioURL)
            return AgentToolResult(
                toolType: .voice,
                action: "transcribe",
                success: true,
                output: transcript
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
        let knowledgeService = KnowledgeService(storage: storage)
        try await knowledgeService.setup()

        switch request.action {
        case "read":
            let cards = try await knowledgeService.listCards(filter: nil)
            let lines = cards.prefix(10).map { card in
                let title = card.canonicalTitle.isEmpty ? "未命名" : card.canonicalTitle
                let category = card.category ?? "未分类"
                return "\(title) [\(category)]"
            }
            return AgentToolResult(
                toolType: .knowledge,
                action: "read",
                success: true,
                output: "知识卡片 (\(cards.count)):\n\(lines.isEmpty ? "暂无知识卡片" : lines.joined(separator: "\n"))"
            )

        case "search":
            let query = request.parameters["query"] ?? ""
            guard query.isEmpty == false else {
                return AgentToolResult(
                    toolType: .knowledge,
                    action: "search",
                    success: false,
                    errorMessage: "请提供搜索词"
                )
            }

            let results = try await knowledgeService.searchCards(query: query)
            let lines = results.prefix(10).map { card in
                let title = card.canonicalTitle.isEmpty ? "未命名" : card.canonicalTitle
                return "\(title)"
            }
            return AgentToolResult(
                toolType: .knowledge,
                action: "search",
                success: true,
                output: "搜索结果 (\(results.count)):\n\(lines.isEmpty ? "无匹配结果" : lines.joined(separator: "\n"))"
            )

        case "write":
            let content = request.parameters["content"] ?? ""
            guard content.isEmpty == false else {
                return AgentToolResult(
                    toolType: .knowledge,
                    action: "write",
                    success: false,
                    errorMessage: "请提供要写入的内容"
                )
            }

            let sourceItemId = request.parameters["sourceItemId"] ?? "agent-\(UUID().uuidString)"
            let title = request.parameters["title"] ?? String(content.prefix(40))
            let category = request.parameters["category"].flatMap { $0.isEmpty ? nil : $0 }
            let tags = request.parameters["tags"]?
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false } ?? []
            let note = DistilledNote(
                sourceItemId: sourceItemId,
                title: title.isEmpty ? "未命名" : title,
                summary: request.parameters["summary"],
                category: category,
                tags: tags,
                documentType: request.parameters["documentType"],
                contentMarkdown: content,
                valueScore: nil,
                confidence: nil
            )
            let card = try await knowledgeService.createCard(from: note)
            return AgentToolResult(
                toolType: .knowledge,
                action: "write",
                success: true,
                output: "已写入知识库: \(card.canonicalTitle)"
            )

        case "delete":
            let cardId = request.parameters["cardId"] ?? ""
            guard cardId.isEmpty == false else {
                return AgentToolResult(
                    toolType: .knowledge,
                    action: "delete",
                    success: false,
                    errorMessage: "请提供 cardId"
                )
            }
            try await knowledgeService.deleteCard(id: cardId)
            return AgentToolResult(
                toolType: .knowledge,
                action: "delete",
                success: true,
                output: "已删除知识卡片: \(cardId)"
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
            guard url.isEmpty == false else {
                return AgentToolResult(
                    toolType: .webDigest,
                    action: "fetch",
                    success: false,
                    errorMessage: "请提供网页 URL"
                )
            }
            let result = try await processRunner.run(
                executablePath: "/usr/bin/env",
                arguments: ["defuddle", "parse", url, "--md"]
            )
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            guard output.isEmpty == false else {
                return AgentToolResult(
                    toolType: .webDigest,
                    action: "fetch",
                    success: false,
                    errorMessage: friendlyDefuddleError(from: result.stderr)
                )
            }
            return AgentToolResult(
                toolType: .webDigest,
                action: "fetch",
                success: true,
                output: output
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

    private func friendlyDefuddleError(from stderr: String) -> String {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "defuddle 没有返回可用内容"
        }
        if trimmed.localizedCaseInsensitiveContains("defuddle") ||
            trimmed.localizedCaseInsensitiveContains("command not found") ||
            trimmed.localizedCaseInsensitiveContains("no such file") {
            return "未找到 defuddle。请先运行 `npm install -g defuddle`，或安装后重试。"
        }
        return trimmed
    }

    private func routeToMarkdown(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "format":
            let rawText = request.parameters["text"] ?? request.parameters["content"] ?? ""
            guard rawText.isEmpty == false else {
                return AgentToolResult(
                    toolType: .markdown,
                    action: "format",
                    success: false,
                    errorMessage: "请提供要整理的 Markdown 文本"
                )
            }
            let formatted = formatMarkdown(rawText)
            return AgentToolResult(
                toolType: .markdown,
                action: "format",
                success: true,
                output: formatted
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
            let imagePath = request.parameters["imagePath"] ?? request.parameters["imageURL"] ?? ""
            guard imagePath.isEmpty == false else {
                return AgentToolResult(
                    toolType: .ocr,
                    action: "recognize",
                    success: false,
                    errorMessage: "请提供 imagePath"
                )
            }
            let result = try await VisionOCR.recognizeText(inFileAtPath: imagePath)
            return AgentToolResult(
                toolType: .ocr,
                action: "recognize",
                success: true,
                output: result.text
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
            let noteId = request.parameters["noteId"] ?? ""
            let sourceItemId = request.parameters["sourceItemId"] ?? ""
            guard noteId.isEmpty == false || sourceItemId.isEmpty == false else {
                return AgentToolResult(
                    toolType: .export,
                    action: "toObsidian",
                    success: false,
                    errorMessage: "请提供 noteId 或 sourceItemId"
                )
            }

            let exportService = ExportService(storage: storage)
            let config = try await makeExportConfig()

            if !noteId.isEmpty, let note = try await storage.listDistilledNotes().first(where: { $0.id == noteId }) {
                if !sourceItemId.isEmpty, let sourceItem = try await storage.getSourceItem(id: sourceItemId) {
                    let record = try await exportService.export(note: note, sourceItem: sourceItem, config: config)
                    return AgentToolResult(
                        toolType: .export,
                        action: "toObsidian",
                        success: true,
                        output: "已导出: \(record.relativeFilePath)"
                    )
                }

                let record = try await exportService.export(note: note, config: config)
                return AgentToolResult(
                    toolType: .export,
                    action: "toObsidian",
                    success: true,
                    output: "已导出: \(record.relativeFilePath)"
                )
            }

            if !sourceItemId.isEmpty,
               let sourceItem = try await storage.getSourceItem(id: sourceItemId),
               let note = try await storage.listDistilledNotes().first(where: { $0.sourceItemId == sourceItem.id }) {
                let record = try await exportService.export(note: note, sourceItem: sourceItem, config: config)
                return AgentToolResult(
                    toolType: .export,
                    action: "toObsidian",
                    success: true,
                    output: "已导出: \(record.relativeFilePath)"
                )
            }

            return AgentToolResult(
                toolType: .export,
                action: "toObsidian",
                success: false,
                errorMessage: "未找到可导出的笔记"
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
        switch request.action {
        case "info":
            guard let fileURL = resolveURL(from: request.parameters) else {
                return unsupportedToolResult(toolType: .file, action: request.action, message: "请提供 path 或 url")
            }
            return AgentToolResult(
                toolType: .file,
                action: "info",
                success: true,
                output: fileInfoDescription(at: fileURL)
            )

        case "list":
            guard let directoryURL = resolveURL(from: request.parameters) else {
                return unsupportedToolResult(toolType: .file, action: request.action, message: "请提供 path")
            }
            let entries = try listDirectory(at: directoryURL)
            return AgentToolResult(
                toolType: .file,
                action: "list",
                success: true,
                output: entries.isEmpty ? "目录为空" : entries.joined(separator: "\n")
            )

        case "rename":
            guard let sourceURL = resolveURL(from: request.parameters) else {
                return unsupportedToolResult(toolType: .file, action: request.action, message: "请提供 path")
            }
            guard let newName = request.parameters["newName"], newName.isEmpty == false else {
                return unsupportedToolResult(toolType: .file, action: request.action, message: "请提供 newName")
            }
            let renamedURL = try renameFile(at: sourceURL, newName: newName)
            return AgentToolResult(
                toolType: .file,
                action: "rename",
                success: true,
                output: renamedURL.path
            )

        case "move", "copy":
            guard let sourceURL = resolveURL(from: request.parameters) else {
                return unsupportedToolResult(toolType: .file, action: request.action, message: "请提供 path")
            }
            guard let destinationURL = resolveDestinationURL(from: request.parameters) else {
                return unsupportedToolResult(toolType: .file, action: request.action, message: "请提供 destinationPath 或 destinationDirectory")
            }
            if request.action == "move" {
                try moveFile(at: sourceURL, to: destinationURL)
            } else {
                try copyFile(at: sourceURL, to: destinationURL)
            }
            return AgentToolResult(
                toolType: .file,
                action: request.action,
                success: true,
                output: destinationURL.path
            )

        case "delete":
            guard let fileURL = resolveURL(from: request.parameters) else {
                return unsupportedToolResult(toolType: .file, action: request.action, message: "请提供 path")
            }
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return unsupportedToolResult(toolType: .file, action: request.action, message: "文件不存在: \(fileURL.path)")
            }
            try FileManager.default.removeItem(at: fileURL)
            return AgentToolResult(
                toolType: .file,
                action: "delete",
                success: true,
                output: "已删除 \(fileURL.lastPathComponent)"
            )

        case "open", "reveal":
            guard let fileURL = resolveURL(from: request.parameters) else {
                return unsupportedToolResult(toolType: .file, action: request.action, message: "请提供 path")
            }
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return unsupportedToolResult(toolType: .file, action: request.action, message: "文件不存在: \(fileURL.path)")
            }
            if request.action == "open" {
                NSWorkspace.shared.open(fileURL)
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }
            return AgentToolResult(
                toolType: .file,
                action: request.action,
                success: true,
                output: fileURL.path
            )

        default:
            return AgentToolResult(
                toolType: .file,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToAI(_ request: AgentToolRequest) async throws -> AgentToolResult {
        switch request.action {
        case "", "chat", "prompt", "complete":
            let messages = try buildAIMessages(from: request)
            guard messages.isEmpty == false else {
                return AgentToolResult(
                    toolType: .ai,
                    action: request.action.isEmpty ? "chat" : request.action,
                    success: false,
                    errorMessage: "请提供 prompt 或 messages"
                )
            }

            let providerId = request.parameters["providerId"].flatMap { $0.isEmpty ? nil : $0 }
            let model = request.parameters["model"].flatMap { $0.isEmpty ? nil : $0 }
            let response: ChatResponse

            if let providerId {
                response = try await aiRuntime.chat(messages: messages, providerId: providerId, model: model)
            } else {
                response = try await aiRuntime.chat(messages: messages)
            }

            var outputLines: [String] = []
            if let providerId = response.providerId ?? providerId {
                outputLines.append("provider: \(providerId)")
            }
            if let model = response.model {
                outputLines.append("model: \(model)")
            }
            outputLines.append(response.content)

            return AgentToolResult(
                toolType: .ai,
                action: request.action.isEmpty ? "chat" : request.action,
                success: true,
                output: outputLines.joined(separator: "\n")
            )

        case "ask", "quickAsk":
            let question = request.parameters["question"] ?? request.parameters["prompt"] ?? ""
            guard question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return AgentToolResult(
                    toolType: .ai,
                    action: request.action,
                    success: false,
                    errorMessage: "请提供 question 或 prompt"
                )
            }

            let providerId = request.parameters["providerId"].flatMap { $0.isEmpty ? nil : $0 }
            let model = request.parameters["model"].flatMap { $0.isEmpty ? nil : $0 }
            let context = request.parameters["context"].flatMap { $0.isEmpty ? nil : $0 }
            let response = try await quickAskService.ask(
                question: question,
                providerId: providerId,
                model: model,
                context: context
            )

            var outputLines: [String] = []
            if let providerId = response.providerId ?? providerId {
                outputLines.append("provider: \(providerId)")
            }
            if let model = response.model {
                outputLines.append("model: \(model)")
            }
            outputLines.append(response.content)

            return AgentToolResult(
                toolType: .ai,
                action: request.action,
                success: true,
                output: outputLines.joined(separator: "\n")
            )

        case "automation", "automationDraft", "draftAutomation":
            let goal = request.parameters["goal"]
                ?? request.parameters["question"]
                ?? request.parameters["prompt"]
                ?? request.parameters["input"]
                ?? ""
            guard goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return AgentToolResult(
                    toolType: .ai,
                    action: request.action,
                    success: false,
                    errorMessage: "请提供 goal、question 或 prompt"
                )
            }

            let providerId = request.parameters["providerId"].flatMap { $0.isEmpty ? nil : $0 }
            let model = request.parameters["model"].flatMap { $0.isEmpty ? nil : $0 }
            let context = request.parameters["context"].flatMap { $0.isEmpty ? nil : $0 }
            let instruction = """
            请把下面的目标拆解成可执行的自动化草案。
            要求：
            1. 输出 3 到 7 个步骤。
            2. 每一步尽量标注可以调用的工具类型或产物。
            3. 如果目标存在不确定点，请在最后单独列出待确认项。
            4. 使用简洁、可落地的中文。

            目标：
            \(goal)
            """
            let response = try await quickAskService.ask(
                question: instruction,
                providerId: providerId,
                model: model,
                context: context
            )

            var outputLines: [String] = []
            if let providerId = response.providerId ?? providerId {
                outputLines.append("provider: \(providerId)")
            }
            if let model = response.model {
                outputLines.append("model: \(model)")
            }
            outputLines.append(response.content)

            return AgentToolResult(
                toolType: .ai,
                action: request.action,
                success: true,
                output: outputLines.joined(separator: "\n")
            )

        case "providers", "listProviders":
            let providers = await aiRuntime.listProviders()
            let lines = providers.prefix(10).map { provider in
                let status = provider.enabled ? "启用" : "停用"
                return "\(provider.name) | \(provider.providerType.displayName) | \(provider.modelId) | \(status)"
            }
            return AgentToolResult(
                toolType: .ai,
                action: "providers",
                success: true,
                output: "智能提供商 (\(providers.count)):\n\(lines.isEmpty ? "暂无提供商" : lines.joined(separator: "\n"))"
            )

        case "models", "listModels":
            guard let providerId = request.parameters["providerId"], providerId.isEmpty == false else {
                return AgentToolResult(
                    toolType: .ai,
                    action: request.action,
                    success: false,
                    errorMessage: "请提供 providerId"
                )
            }
            let models = try await aiRuntime.listModels(providerId: providerId)
            return AgentToolResult(
                toolType: .ai,
                action: "models",
                success: true,
                output: "模型 (\(models.count)):\n\(models.isEmpty ? "暂无模型" : models.joined(separator: "\n"))"
            )

        case "health", "healthCheck":
            guard let providerId = request.parameters["providerId"], providerId.isEmpty == false else {
                return AgentToolResult(
                    toolType: .ai,
                    action: request.action,
                    success: false,
                    errorMessage: "请提供 providerId"
                )
            }
            let healthy = try await aiRuntime.healthCheck(providerId: providerId)
            return AgentToolResult(
                toolType: .ai,
                action: "health",
                success: true,
                output: "\(providerId): \(healthy ? "可用" : "不可用")"
            )

        default:
            return AgentToolResult(
                toolType: .ai,
                action: request.action,
                success: false,
                errorMessage: "未知操作: \(request.action)"
            )
        }
    }

    private func routeToTools(_ request: AgentToolRequest) async throws -> AgentToolResult {
        let toolName = (request.parameters["name"] ?? request.parameters["tool"] ?? request.action).lowercased()

        switch toolName {
        case "jsonformatter", "json", "jsonFormatter".lowercased():
            return try routeToJSONFormatter(request)

        case "base64codec", "base64":
            return routeToBase64(request)

        case "markdowncleaner", "markdown":
            return AgentToolResult(
                toolType: .tools,
                action: "markdownCleaner",
                success: true,
                output: formatMarkdown(request.parameters["text"] ?? request.parameters["content"] ?? "")
            )

        case "textcompare", "compare":
            return routeToTextCompare(request)

        case "documentconvert", "document", "convert":
            return try await routeToDocumentConvert(request)

        case "ocr":
            return try await routeToOCRTools(request)

        case "batchrename":
            return try routeToBatchRename(request)

        case "batchdownload":
            return try await routeToBatchDownload(request)

        case "videodownload":
            return try await routeToVideoDownload(request)

        case "srttofcpxml":
            return routeToSRTToFCPXML(request)

        case "imageprocess":
            return try routeToImageProcess(request)

        case "modelmanagement":
            return try await routeToModelManagement(request)

        case "apitest", "api":
            return try await routeToAPITest(request)

        case "webdigest":
            return try await routeToWebDigest(request)

        default:
            let toolName = request.parameters["name"] ?? ""
            return AgentToolResult(
                toolType: .tools,
                action: request.action,
                success: false,
                errorMessage: toolName.isEmpty ? "工具调用需要具体工具名称" : "暂不支持工具 '\(toolName)'"
            )
        }
    }

    private func summarizeClipboardItems(_ items: [ClipboardItem], includeCount: Bool) -> String {
        guard items.isEmpty == false else { return "" }

        let lines = items.prefix(5).enumerated().map { index, item in
            let title = item.textContent ?? item.content ?? "无内容"
            let type = item.type.displayName
            return "\(index + 1). [\(type)] \(String(title.prefix(80)))"
        }

        if includeCount {
            return "剪贴板历史 (\(items.count)):\n\(lines.joined(separator: "\n"))"
        }
        return lines.joined(separator: "\n---\n")
    }

    private func parseStringDictionary(_ raw: String?) -> [String: String] {
        guard let raw, raw.isEmpty == false else { return [:] }
        if let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            return decoded
        }
        return raw
            .split(separator: ",")
            .reduce(into: [:]) { dict, part in
                let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
                guard pieces.count == 2 else { return }
                dict[pieces[0].trimmingCharacters(in: .whitespacesAndNewlines)] = pieces[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
    }

    private func buildAIMessages(from request: AgentToolRequest) throws -> [ChatMessage] {
        if let rawMessages = request.parameters["messages"], rawMessages.isEmpty == false {
            let parsed = try parseChatMessages(rawMessages)
            if parsed.isEmpty == false {
                return parsed
            }
        }

        let prompt = request.parameters["prompt"]
            ?? request.parameters["text"]
            ?? request.parameters["input"]
            ?? request.parameters["content"]
            ?? ""
        let systemPrompt = request.parameters["systemPrompt"] ?? request.parameters["system"] ?? ""

        var messages: [ChatMessage] = []
        if systemPrompt.isEmpty == false {
            messages.append(ChatMessage(sessionId: UUID().uuidString, role: .system, content: systemPrompt))
        }
        if prompt.isEmpty == false {
            messages.append(ChatMessage(sessionId: UUID().uuidString, role: .user, content: prompt))
        }
        return messages
    }

    private func parseChatMessages(_ raw: String) throws -> [ChatMessage] {
        guard let data = raw.data(using: .utf8) else { return [] }

        if let decoded = try? JSONDecoder().decode([ChatMessagePayload].self, from: data) {
            return decoded.compactMap { payload in
                guard let role = ChatRole(rawValue: payload.role.lowercased()) else { return nil }
                return ChatMessage(
                    sessionId: UUID().uuidString,
                    role: role,
                    content: payload.content
                )
            }
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return json.compactMap { item in
                guard let roleRaw = item["role"] as? String,
                      let content = item["content"] as? String,
                      let role = ChatRole(rawValue: roleRaw.lowercased()) else { return nil }
                return ChatMessage(
                    sessionId: UUID().uuidString,
                    role: role,
                    content: content
                )
            }
        }

        return []
    }

    private func routeToJSONFormatter(_ request: AgentToolRequest) throws -> AgentToolResult {
        let raw = request.parameters["text"] ?? request.parameters["content"] ?? ""
        guard raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return unsupportedToolResult(toolType: .tools, action: "jsonFormatter", message: "请提供 text")
        }

        guard let data = raw.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return unsupportedToolResult(toolType: .tools, action: "jsonFormatter", message: "JSON 解析失败")
        }

        let pretty = Self.parseBool(request.parameters["pretty"] ?? "true") ?? true
        let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        let outputData = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
        let output = String(decoding: outputData, as: UTF8.self)
        return AgentToolResult(toolType: .tools, action: "jsonFormatter", success: true, output: output)
    }

    private func routeToBase64(_ request: AgentToolRequest) -> AgentToolResult {
        let raw = request.parameters["text"] ?? request.parameters["content"] ?? ""
        guard raw.isEmpty == false else {
            return unsupportedToolResult(toolType: .tools, action: "base64Codec", message: "请提供 text")
        }

        let mode = (request.parameters["mode"] ?? "encode").lowercased()
        switch mode {
        case "encode":
            let output = Data(raw.utf8).base64EncodedString()
            return AgentToolResult(toolType: .tools, action: "base64Codec", success: true, output: output)
        case "decode":
            guard let decodedData = Data(base64Encoded: raw),
                  let decoded = String(data: decodedData, encoding: .utf8) else {
                return unsupportedToolResult(toolType: .tools, action: "base64Codec", message: "Base64 解码失败")
            }
            return AgentToolResult(toolType: .tools, action: "base64Codec", success: true, output: decoded)
        default:
            return unsupportedToolResult(toolType: .tools, action: "base64Codec", message: "mode 仅支持 encode / decode")
        }
    }

    private func routeToTextCompare(_ request: AgentToolRequest) -> AgentToolResult {
        let left = request.parameters["leftText"] ?? request.parameters["left"] ?? ""
        let right = request.parameters["rightText"] ?? request.parameters["right"] ?? ""
        guard left.isEmpty == false || right.isEmpty == false else {
            return unsupportedToolResult(toolType: .tools, action: "textCompare", message: "请提供 leftText / rightText")
        }

        let result = compareText(left: left, right: right)
        return AgentToolResult(toolType: .tools, action: "textCompare", success: true, output: result)
    }

    private func routeToDocumentConvert(_ request: AgentToolRequest) async throws -> AgentToolResult {
        guard let sourceURL = resolveURL(from: request.parameters) else {
            return unsupportedToolResult(toolType: .tools, action: "documentConvert", message: "请提供 sourceURL 或 path")
        }

        let result = try await convertDocument(sourceURL: sourceURL)
        if let outputPath = request.parameters["outputPath"], outputPath.isEmpty == false {
            let destinationURL = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try result.markdown.write(to: destinationURL, atomically: true, encoding: .utf8)
            return AgentToolResult(toolType: .tools, action: "documentConvert", success: true, output: destinationURL.path)
        }

        return AgentToolResult(
            toolType: .tools,
            action: "documentConvert",
            success: true,
            output: "engine: \(result.engine)\n\(result.markdown)"
        )
    }

    private func routeToOCRTools(_ request: AgentToolRequest) async throws -> AgentToolResult {
        if let sourceURL = resolveURL(from: request.parameters) {
            let result = try await VisionOCR.recognizeText(inFileAtPath: sourceURL.path)
            return AgentToolResult(
                toolType: .tools,
                action: "ocr",
                success: true,
                output: result.text
            )
        }

        if let rawText = request.parameters["clipboard"] ?? request.parameters["imageDataBase64"], rawText.isEmpty == false,
           let data = Data(base64Encoded: rawText) {
            let result = try await VisionOCR.recognizeText(in: data)
            return AgentToolResult(toolType: .tools, action: "ocr", success: true, output: result.text)
        }

        return unsupportedToolResult(toolType: .tools, action: "ocr", message: "请提供 imagePath 或 clipboard/base64 图像数据")
    }

    private func routeToBatchRename(_ request: AgentToolRequest) throws -> AgentToolResult {
        guard let folderURL = resolveURL(from: request.parameters) else {
            return unsupportedToolResult(toolType: .tools, action: "batchRename", message: "请提供 folderPath")
        }

        let items = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let includeFolders = Self.parseBool(request.parameters["includeFolders"] ?? "true") ?? true
        let prefix = request.parameters["prefix"] ?? ""
        let suffix = request.parameters["suffix"] ?? ""
        let search = request.parameters["search"] ?? ""
        let replace = request.parameters["replace"] ?? ""

        var previews: [(original: URL, proposed: URL)] = []
        for url in items {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory && includeFolders == false { continue }
            let proposed = proposedRenameURL(for: url, prefix: prefix, suffix: suffix, search: search, replace: replace)
            previews.append((url, proposed))
        }

        guard previews.isEmpty == false else {
            return unsupportedToolResult(toolType: .tools, action: "batchRename", message: "文件夹为空或无可重命名项目")
        }

        let targetPaths = Set(previews.map { $0.proposed.path })
        guard targetPaths.count == previews.count else {
            return unsupportedToolResult(toolType: .tools, action: "batchRename", message: "结果中存在重复目标名称，请先调整规则")
        }

        for item in previews {
            if item.original.path == item.proposed.path {
                continue
            }
            if FileManager.default.fileExists(atPath: item.proposed.path) {
                return unsupportedToolResult(toolType: .tools, action: "batchRename", message: "目标已存在: \(item.proposed.lastPathComponent)")
            }
        }

        for item in previews {
            if item.original.path == item.proposed.path { continue }
            try FileManager.default.moveItem(at: item.original, to: item.proposed)
        }

        return AgentToolResult(
            toolType: .tools,
            action: "batchRename",
            success: true,
            output: "已重命名 \(previews.count) 项"
        )
    }

    private func routeToBatchDownload(_ request: AgentToolRequest) async throws -> AgentToolResult {
        guard let pageURL = normalizeWebURL(request.parameters["url"] ?? request.parameters["pageURL"] ?? request.parameters["pageUrl"]) else {
            return unsupportedToolResult(toolType: .tools, action: "batchDownload", message: "请提供 url")
        }

        let outputFolder = URL(fileURLWithPath: request.parameters["outputFolder"] ?? defaultDownloadDirectory(named: "BatchDownloads").path)
        let previewOnly = Self.parseBool(request.parameters["previewOnly"] ?? "false") ?? false
        let html = request.parameters["html"]
        let assets = try await collectBatchDownloadAssets(pageURL: pageURL, html: html)
        if previewOnly {
            return AgentToolResult(
                toolType: .tools,
                action: "batchDownload",
                success: true,
                output: assets.isEmpty ? "未发现资源" : assets.map(\.absoluteString).joined(separator: "\n")
            )
        }
        let results = try await downloadBatchAssets(assets, to: outputFolder)
        let successCount = results.filter(\.isDownloaded).count
        return AgentToolResult(
            toolType: .tools,
            action: "batchDownload",
            success: true,
            output: "完成，下载了 \(successCount) 个资源\n" + results.map { "\($0.sourceURL.absoluteString) -> \($0.destinationURL.path)" }.joined(separator: "\n")
        )
    }

    private func routeToVideoDownload(_ request: AgentToolRequest) async throws -> AgentToolResult {
        guard let videoURL = normalizeWebURL(request.parameters["url"] ?? request.parameters["videoURL"] ?? request.parameters["videoUrl"]) else {
            return unsupportedToolResult(toolType: .tools, action: "videoDownload", message: "请提供 url")
        }

        let format = AgentVideoDownloadFormat(rawValue: request.parameters["format"] ?? "best") ?? .best
        let outputFolder = URL(fileURLWithPath: request.parameters["outputFolder"] ?? defaultDownloadDirectory(named: "VideoDownloads").path)
        let binaryPath = request.parameters["binaryPath"].flatMap { $0.isEmpty ? nil : $0 } ?? executablePath(named: "yt-dlp")
        guard let binaryPath else {
            return unsupportedToolResult(toolType: .tools, action: "videoDownload", message: missingYTDLPMessage())
        }
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            return unsupportedToolResult(toolType: .tools, action: "videoDownload", message: missingYTDLPMessage(binaryPath: binaryPath))
        }
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        let result = try await processRunner.run(
            executablePath: binaryPath,
            arguments: buildVideoDownloadArguments(url: videoURL, outputFolder: outputFolder, format: format)
        )

        let files = recentFiles(in: outputFolder, since: Date().addingTimeInterval(-5 * 60))
        let output = files.isEmpty
            ? (result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "下载完成" : result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
            : files.map { $0.path }.joined(separator: "\n")
        return AgentToolResult(toolType: .tools, action: "videoDownload", success: true, output: output)
    }

    private func missingYTDLPMessage(binaryPath: String? = nil) -> String {
        if let binaryPath, binaryPath.isEmpty == false {
            return "未找到可执行的 yt-dlp: \(binaryPath)。请确认路径正确，或运行 `brew install yt-dlp` / `python3 -m pip install -U yt-dlp`。"
        }
        return "未找到 yt-dlp。请先运行 `brew install yt-dlp` 或 `python3 -m pip install -U yt-dlp`，也可以在参数 binaryPath 指定可执行文件路径。"
    }

    private func routeToSRTToFCPXML(_ request: AgentToolRequest) -> AgentToolResult {
        let srt = request.parameters["text"] ?? request.parameters["srt"] ?? request.parameters["content"] ?? ""
        guard srt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return unsupportedToolResult(toolType: .tools, action: "srtToFcpxml", message: "请提供 srt 内容")
        }
        let xml = convertSRTToFCPXML(srt)
        return AgentToolResult(toolType: .tools, action: "srtToFcpxml", success: true, output: xml)
    }

    private func routeToImageProcess(_ request: AgentToolRequest) throws -> AgentToolResult {
        let format = AgentImageOutputFormat(rawValue: (request.parameters["format"] ?? "jpeg").lowercased()) ?? .jpeg
        let maxDimension = Int(request.parameters["maxDimension"] ?? request.parameters["max"] ?? "")
        let quality = CGFloat(Double(request.parameters["quality"] ?? "0.82") ?? 0.82)

        let image: NSImage
        if let path = request.parameters["path"], path.isEmpty == false {
            guard let loaded = NSImage(contentsOfFile: path) else {
                return unsupportedToolResult(toolType: .tools, action: "imageProcess", message: "无法加载图片")
            }
            image = loaded
        } else if let base64 = request.parameters["imageDataBase64"], let data = Data(base64Encoded: base64), let loaded = NSImage(data: data) {
            image = loaded
        } else {
            return unsupportedToolResult(toolType: .tools, action: "imageProcess", message: "请提供 path 或 imageDataBase64")
        }

        let result = try processImage(image: image, outputFormat: format, maxDimension: maxDimension, quality: quality)
        if let outputPath = request.parameters["outputPath"], outputPath.isEmpty == false {
            try result.data.write(to: URL(fileURLWithPath: outputPath))
            return AgentToolResult(toolType: .tools, action: "imageProcess", success: true, output: outputPath)
        }
        return AgentToolResult(toolType: .tools, action: "imageProcess", success: true, output: "format: \(format.rawValue)\nsize: \(Int(result.outputSize.width))x\(Int(result.outputSize.height))")
    }

    private func routeToModelManagement(_ request: AgentToolRequest) async throws -> AgentToolResult {
        let providerId = request.parameters["providerId"]
        if let providerId, providerId.isEmpty == false {
            let models = try await aiRuntime.listModels(providerId: providerId)
            let text = models.isEmpty ? "暂无模型" : models.joined(separator: "\n")
            return AgentToolResult(toolType: .tools, action: "modelManagement", success: true, output: "provider: \(providerId)\n\(text)")
        }

        let providers = await aiRuntime.listProviders()
        let lines = providers.map { "\($0.id) | \($0.name) | \($0.modelId) | \($0.enabled ? "启用" : "停用")" }
        return AgentToolResult(toolType: .tools, action: "modelManagement", success: true, output: lines.isEmpty ? "暂无提供商" : lines.joined(separator: "\n"))
    }

    private func routeToAPITest(_ request: AgentToolRequest) async throws -> AgentToolResult {
        let providerId = request.parameters["providerId"]
        guard let providerId, providerId.isEmpty == false else {
            return unsupportedToolResult(toolType: .tools, action: "apiTest", message: "请提供 providerId")
        }

        let healthy = try await aiRuntime.healthCheck(providerId: providerId)
        let models = try await aiRuntime.listModels(providerId: providerId)
        return AgentToolResult(
            toolType: .tools,
            action: "apiTest",
            success: true,
            output: "\(providerId): \(healthy ? "可用" : "不可用")\n\(models.isEmpty ? "暂无模型" : models.joined(separator: "\n"))"
        )
    }

    private func formatMarkdown(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        var formatted: [String] = []
        var previousWasBlank = false

        for line in lines {
            let isBlank = line.isEmpty
            if isBlank {
                if previousWasBlank == false {
                    formatted.append("")
                }
                previousWasBlank = true
                continue
            }

            previousWasBlank = false

            if line.hasPrefix("#") {
                let hashes = line.prefix(while: { $0 == "#" })
                let title = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                formatted.append("\(hashes) \(title)")
            } else {
                formatted.append(line)
            }
        }

        return formatted.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseBool(_ raw: String) -> Bool? {
        switch raw.lowercased() {
        case "1", "true", "yes", "on": return true
        case "0", "false", "no", "off": return false
        default: return nil
        }
    }

    private func resolveURL(from parameters: [String: String]) -> URL? {
        if let path = parameters["path"], path.isEmpty == false {
            return URL(fileURLWithPath: path)
        }
        if let path = parameters["sourceURL"], path.isEmpty == false {
            if let url = URL(string: path), url.scheme != nil {
                return url
            }
            return URL(fileURLWithPath: path)
        }
        if let path = parameters["url"], path.isEmpty == false {
            if let url = URL(string: path), url.scheme != nil {
                return url
            }
            return URL(fileURLWithPath: path)
        }
        if let path = parameters["imagePath"], path.isEmpty == false {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func resolveDestinationURL(from parameters: [String: String]) -> URL? {
        if let path = parameters["destinationPath"], path.isEmpty == false {
            return URL(fileURLWithPath: path)
        }
        if let directory = parameters["destinationDirectory"], directory.isEmpty == false {
            guard let source = resolveURL(from: parameters) else { return nil }
            return URL(fileURLWithPath: directory).appendingPathComponent(source.lastPathComponent)
        }
        return nil
    }

    private func fileInfoDescription(at url: URL) -> String {
        let exists = FileManager.default.fileExists(atPath: url.path)
        guard exists else {
            return "不存在: \(url.path)"
        }

        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        let modified = (attrs[.modificationDate] as? Date).map { ISO8601DateFormatter().string(from: $0) } ?? "unknown"
        let type = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true ? "directory" : "file"
        return """
        path: \(url.path)
        type: \(type)
        size: \(size)
        modifiedAt: \(modified)
        """
    }

    private func listDirectory(at url: URL) throws -> [String] {
        let items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        return items.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { fileInfoDescription(at: $0) }
    }

    private func renameFile(at url: URL, newName: String) throws -> URL {
        let directory = url.deletingLastPathComponent()
        let target = directory.appendingPathComponent(newName)
        if FileManager.default.fileExists(atPath: target.path) {
            throw AgentToolRoutingError.invalidOperation("目标已存在: \(target.lastPathComponent)")
        }
        try FileManager.default.moveItem(at: url, to: target)
        return target
    }

    private func copyFile(at url: URL, to destination: URL) throws {
        let target = destination.hasDirectoryPath ? destination.appendingPathComponent(url.lastPathComponent) : destination
        if FileManager.default.fileExists(atPath: target.path) {
            throw AgentToolRoutingError.invalidOperation("目标已存在: \(target.lastPathComponent)")
        }
        try FileManager.default.copyItem(at: url, to: target)
    }

    private func moveFile(at url: URL, to destination: URL) throws {
        let target = destination.hasDirectoryPath ? destination.appendingPathComponent(url.lastPathComponent) : destination
        if FileManager.default.fileExists(atPath: target.path) {
            throw AgentToolRoutingError.invalidOperation("目标已存在: \(target.lastPathComponent)")
        }
        try FileManager.default.moveItem(at: url, to: target)
    }

    private func defaultDownloadDirectory(named name: String) -> URL {
        let base = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let folder = base.appendingPathComponent("AcMind", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func uniqueDestinationURL(in folder: URL, filename: String) -> URL {
        let fm = FileManager.default
        let base = folder.appendingPathComponent(filename, isDirectory: false)
        guard fm.fileExists(atPath: base.path) == false else {
            let ext = base.pathExtension
            let stem = base.deletingPathExtension().lastPathComponent
            var index = 2
            while true {
                let candidateName = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
                let candidate = folder.appendingPathComponent(candidateName)
                if fm.fileExists(atPath: candidate.path) == false {
                    return candidate
                }
                index += 1
            }
        }
        return base
    }

    private func sanitizeFilename(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "asset" : trimmed
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return fallback.components(separatedBy: invalid).joined(separator: "_")
    }

    private func executablePath(named name: String) -> String? {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        if let found = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) {
            return found
        }

        guard let pathValue = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for component in pathValue.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(component)).appendingPathComponent(name).path
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private func compareText(left: String, right: String) -> String {
        let leftLines = left
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        let rightLines = right
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        let sameCount = zip(leftLines, rightLines).filter { $0 == $1 }.count
        let deleteCount = max(0, leftLines.count - sameCount)
        let insertCount = max(0, rightLines.count - sameCount)
        return "左侧 \(leftLines.count) 行，右侧 \(rightLines.count) 行，相同 \(sameCount) 行，新增 \(insertCount) 行，删除 \(deleteCount) 行"
    }

    private func buildVideoDownloadArguments(url: URL, outputFolder: URL, format: AgentVideoDownloadFormat) -> [String] {
        var args = [
            "--no-playlist",
            "--restrict-filenames",
            "--newline",
            "-P", outputFolder.path,
            "-o", "%(title).80s.%(ext)s"
        ]
        args.append(contentsOf: format.ytDLPArguments)
        args.append(url.absoluteString)
        return args
    }

    private func recentFiles(in folder: URL, since date: Date) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return items.filter {
            guard let modified = try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                return false
            }
            return modified >= date
        }
        .sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhs > rhs
        }
    }

    private func normalizeWebURL(_ rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private func collectBatchDownloadAssets(pageURL: URL, html htmlContent: String? = nil) async throws -> [URL] {
        let html: String
        if let providedHTML = htmlContent {
            html = providedHTML
        } else {
            let (data, response) = try await URLSession.shared.data(from: pageURL)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw AgentToolRoutingError.invalidOperation("网页抓取失败")
            }
            html = String(decoding: data, as: UTF8.self)
        }

        let regex = try NSRegularExpression(
            pattern: #"(?i)<(img|source|a)[^>]*?(?:src|href|data-src|data-original)\s*=\s*["']([^"']+)["']"#
        )
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: range)

        var seen: Set<String> = []
        var assets: [URL] = []
        for match in matches {
            guard match.numberOfRanges >= 3,
                  let tagRange = Range(match.range(at: 1), in: html),
                  let urlRange = Range(match.range(at: 2), in: html) else {
                continue
            }
            let tag = String(html[tagRange]).lowercased()
            let rawURL = String(html[urlRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard rawURL.isEmpty == false else { continue }
            guard rawURL.hasPrefix("javascript:") == false,
                  rawURL.hasPrefix("mailto:") == false,
                  rawURL.hasPrefix("#") == false else {
                continue
            }
            guard let absoluteURL = URL(string: rawURL, relativeTo: pageURL)?.absoluteURL,
                  ["http", "https"].contains(absoluteURL.scheme?.lowercased() ?? "") else {
                continue
            }

            let isAssetCandidate: Bool
            if tag == "a" {
                let ext = absoluteURL.pathExtension.lowercased()
                isAssetCandidate = (!ext.isEmpty && !["html", "htm", "php", "asp", "aspx", "jsp"].contains(ext)) || absoluteURL.query?.contains("download") == true
            } else {
                isAssetCandidate = true
            }
            guard isAssetCandidate else { continue }

            let key = absoluteURL.absoluteString
            if seen.insert(key).inserted {
                assets.append(absoluteURL)
            }
        }
        return assets
    }

    private func downloadBatchAssets(_ assets: [URL], to folder: URL) async throws -> [BatchDownloadResult] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var results: [BatchDownloadResult] = []

        for (index, assetURL) in assets.enumerated() {
            do {
                let (tempURL, response) = try await URLSession.shared.download(from: assetURL)
                let filename = suggestedFilename(for: assetURL, response: response, index: index)
                let destination = uniqueDestinationURL(in: folder, filename: filename)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tempURL, to: destination)
                results.append(BatchDownloadResult(sourceURL: assetURL, destinationURL: destination, isDownloaded: true))
            } catch {
                let fallbackFilename = suggestedFilename(for: assetURL, response: nil, index: index)
                results.append(BatchDownloadResult(sourceURL: assetURL, destinationURL: folder.appendingPathComponent(fallbackFilename), isDownloaded: false))
            }
        }
        return results
    }

    private func suggestedFilename(for url: URL, response: URLResponse?, index: Int) -> String {
        if let filename = (response as? HTTPURLResponse)?.suggestedFilename, filename.isEmpty == false {
            return sanitizeFilename(filename)
        }
        if url.lastPathComponent.isEmpty == false {
            return sanitizeFilename(url.lastPathComponent)
        }
        if url.pathExtension.isEmpty == false {
            return "asset-\(index + 1).\(url.pathExtension)"
        }
        return "asset-\(index + 1)"
    }

    private func convertSRTToFCPXML(_ srtContent: String) -> String {
        let lines = srtContent.components(separatedBy: .newlines)
        var fcpxml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.10">
            <resources>
                <format id="r1" name="FFVideoFormat1080p30" frameDuration="1s/30s" width="1920" height="1080"/>
            </resources>
            <library>
                <event name="Imported from SRT">
                    <project name="Subtitles">
                        <sequence format="r1" duration="99/25s">
                            <spine>

        """

        var inSubtitle = false
        var subtitleNumber = ""
        var startTime = ""
        var endTime = ""
        var text = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if inSubtitle && subtitleNumber.isEmpty == false {
                    fcpxml += formatSubtitleFCPXML(start: startTime, end: endTime, text: text)
                }
                inSubtitle = false
                subtitleNumber = ""
                startTime = ""
                endTime = ""
                text = ""
                continue
            }

            if trimmed.contains("-->") {
                let times = trimmed.components(separatedBy: "-->")
                if times.count == 2 {
                    startTime = times[0].trimmingCharacters(in: .whitespaces)
                    endTime = times[1].trimmingCharacters(in: .whitespaces)
                }
                inSubtitle = true
            } else if subtitleNumber.isEmpty, trimmed.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
                subtitleNumber = trimmed
            } else if inSubtitle {
                if text.isEmpty == false { text += "\n" }
                text += trimmed
            }
        }

        if inSubtitle && subtitleNumber.isEmpty == false {
            fcpxml += formatSubtitleFCPXML(start: startTime, end: endTime, text: text)
        }

        fcpxml += """
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """
        return fcpxml
    }

    private func formatSubtitleFCPXML(start: String, end: String, text: String) -> String {
        let startSeconds = parseTimeToSeconds(start)
        let endSeconds = parseTimeToSeconds(end)
        let duration = max(0, endSeconds - startSeconds)
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        return """
                    <title name="\(escapedText)" start="\(formatSecondsToFCPTime(startSeconds))" duration="\(formatSecondsToFCPTime(duration))">
                        <text>\(escapedText)</text>
                    </title>

        """
    }

    private func parseTimeToSeconds(_ time: String) -> Double {
        let parts = time.replacingOccurrences(of: ",", with: ".").components(separatedBy: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else {
            return 0
        }
        return hours * 3600 + minutes * 60 + seconds
    }

    private func formatSecondsToFCPTime(_ seconds: Double) -> String {
        let value = max(0, seconds)
        return String(format: "%.2fs", value)
    }

    private func processImage(image: NSImage, outputFormat: AgentImageOutputFormat, maxDimension: Int?, quality: CGFloat) throws -> AgentImageProcessingResult {
        let baseSize = image.size
        let targetSize = scaledImageSize(for: baseSize, maxDimension: maxDimension)
        let rendered = render(image: image, size: targetSize)
        return try encodeImage(renderedImage: rendered, outputFormat: outputFormat, quality: quality)
    }

    private func scaledImageSize(for size: NSSize, maxDimension: Int?) -> NSSize {
        guard let maxDimension, maxDimension > 0 else { return size }
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let scale = min(CGFloat(maxDimension) / max(width, height), 1)
        return NSSize(width: width * scale, height: height * scale)
    }

    private func render(image: NSImage, size: NSSize) -> NSImage {
        if size == image.size { return image }
        let target = NSImage(size: size)
        target.lockFocus()
        defer { target.unlockFocus() }
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        return target
    }

    private func encodeImage(renderedImage: NSImage, outputFormat: AgentImageOutputFormat, quality: CGFloat) throws -> AgentImageProcessingResult {
        guard let tiff = renderedImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            throw AgentToolRoutingError.invalidOperation("无法转换图片数据")
        }

        let data: Data?
        switch outputFormat {
        case .png:
            data = rep.representation(using: .png, properties: [:])
        case .jpeg:
            data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .tiff:
            data = rep.representation(using: .tiff, properties: [:])
        }

        guard let data else {
            throw AgentToolRoutingError.invalidOperation("图片编码失败")
        }

        return AgentImageProcessingResult(data: data, outputSize: renderedImage.size, outputFormat: outputFormat)
    }

    private func convertDocument(sourceURL: URL) async throws -> (markdown: String, engine: String) {
        let ext = sourceURL.pathExtension.lowercased()

        if ext == "md" || ext == "markdown" || ext == "txt" {
            let content = try String(contentsOf: sourceURL, encoding: .utf8)
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                throw AgentToolRoutingError.invalidOperation("文件内容为空")
            }
            if ext == "md" || ext == "markdown" {
                return (content, "local-markdown")
            }
            return ("# \(sourceURL.deletingPathExtension().lastPathComponent)\n\n\(trimmed)", "local-text")
        }

        if let result = try? await processRunner.run(executablePath: "/usr/bin/env", arguments: ["markitdown", sourceURL.path]),
           result.exitCode == 0 {
            let text = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty == false {
                return (text, "markitdown")
            }
        }

        if ext == "pdf", let document = PDFDocument(url: sourceURL) {
            var pages: [String] = []
            for index in 0..<document.pageCount {
                if let page = document.page(at: index), let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false {
                    pages.append(text)
                }
            }
            guard pages.isEmpty == false else {
                throw AgentToolRoutingError.invalidOperation("PDF 中没有可提取的文本")
            }
            let rawTitle = (document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = (rawTitle?.isEmpty == false ? rawTitle : nil) ?? sourceURL.deletingPathExtension().lastPathComponent
            return ("# \(title)\n\n" + pages.joined(separator: "\n\n---\n\n"), "pdfkit")
        }

        if ["doc", "docx", "rtf", "html", "htm", "odt", "pptx"].contains(ext) {
            let result = try await processRunner.run(
                executablePath: "/usr/bin/textutil",
                arguments: ["-convert", "txt", "-stdout", sourceURL.path]
            )
            let text = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            guard result.exitCode == 0, text.isEmpty == false else {
                throw AgentToolRoutingError.invalidOperation(result.stderr.isEmpty ? "textutil 转换失败" : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return ("# \(sourceURL.deletingPathExtension().lastPathComponent)\n\n\(text)", "textutil")
        }

        throw AgentToolRoutingError.invalidOperation("不支持的文件格式: \(ext)")
    }

    private func proposedRenameURL(for url: URL, prefix: String, suffix: String, search: String, replace: String) -> URL {
        let directory = url.deletingLastPathComponent()
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let originalName = isDirectory ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
        let ext = isDirectory ? "" : url.pathExtension

        var name = originalName
        if search.isEmpty == false {
            name = name.replacingOccurrences(of: search, with: replace)
        }
        if prefix.isEmpty == false {
            name = prefix + name
        }
        if suffix.isEmpty == false {
            name = name + suffix
        }
        let finalName = isDirectory ? name : name + (ext.isEmpty ? "" : ".\(ext)")
        return directory.appendingPathComponent(finalName)
    }

    private func unsupportedToolResult(toolType: AgentToolType, action: String, message: String) -> AgentToolResult {
        AgentToolResult(
            toolType: toolType,
            action: action,
            success: false,
            errorMessage: message
        )
    }

    private func makeExportConfig() async throws -> ExportConfig {
        let vaultPath = (try? await storage.getSetting(key: "vault.path")).flatMap { $0.isEmpty ? nil : $0 }
        let defaultFolder = (try? await storage.getSetting(key: "vault.defaultFolder")).flatMap { $0.isEmpty ? nil : $0 } ?? "Inbox"
        let pathRule = ExportConfig.PathRule(rawValue: (try? await storage.getSetting(key: "vault.pathRule")) ?? "categoryDate") ?? .categoryDate
        let conflictStrategy = ConflictStrategy(rawValue: (try? await storage.getSetting(key: "vault.conflictStrategy")) ?? "rename") ?? .rename
        let autoFrontmatter = (try? await storage.getSetting(key: "vault.autoFrontmatter")) != "false"
        let frontmatterTemplateText = (try? await storage.getSetting(key: "vault.frontmatterTemplate")) ?? "{}"

        let frontmatterTemplate: [String: String]
        if let data = frontmatterTemplateText.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            frontmatterTemplate = decoded
        } else {
            frontmatterTemplate = [:]
        }

        return ExportConfig(
            vaultPath: vaultPath,
            defaultFolder: defaultFolder,
            pathRule: pathRule,
            conflictStrategy: conflictStrategy,
            autoFrontmatter: autoFrontmatter,
            frontmatterTemplate: frontmatterTemplate
        )
    }
}

private struct ChatMessagePayload: Codable {
    let role: String
    let content: String
}

private struct BatchDownloadResult {
    let sourceURL: URL
    let destinationURL: URL
    let isDownloaded: Bool
}

private enum AgentVideoDownloadFormat: String {
    case best
    case mp4
    case audio

    var ytDLPArguments: [String] {
        switch self {
        case .best:
            return ["-f", "bv*+ba/b", "--merge-output-format", "mp4"]
        case .mp4:
            return ["-f", "bestvideo[ext=mp4]+bestaudio/best", "--merge-output-format", "mp4"]
        case .audio:
            return ["-x", "--audio-format", "mp3"]
        }
    }
}

private enum AgentImageOutputFormat: String {
    case png
    case jpeg
    case tiff
}

private struct AgentImageProcessingResult {
    let data: Data
    let outputSize: NSSize
    let outputFormat: AgentImageOutputFormat
}

private enum AgentToolRoutingError: LocalizedError {
    case invalidOperation(String)

    var errorDescription: String? {
        switch self {
        case .invalidOperation(let message):
            return message
        }
    }
}
