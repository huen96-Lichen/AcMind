import AppKit
import XCTest
@testable import AcMindKit

final class AgentToolRouterTests: XCTestCase {
    func testKnowledgeWriteAndReadUseStoredCards() async throws {
        let storage = AgentToolRouterStorageStub()
        let router = AgentToolRouter(storage: storage)

        let writeResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .knowledge,
                action: "write",
                parameters: [
                    "content": "这里是一段要写入知识库的内容",
                    "title": "知识卡片标题",
                    "sourceItemId": "source-1",
                    "category": "work"
                ]
            )
        )

        XCTAssertTrue(writeResult.success)
        XCTAssertEqual(storage.knowledgeCards.count, 1)

        let readResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .knowledge,
                action: "read"
            )
        )

        XCTAssertTrue(readResult.success)
        XCTAssertTrue(readResult.output?.contains("知识卡片标题") == true)
    }

    func testExportToObsidianWritesMarkdownFile() async throws {
        let storage = AgentToolRouterStorageStub()
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind-AgentToolRouterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: vaultURL)
        }

        storage.settings["vault.path"] = vaultURL.path
        storage.settings["vault.defaultFolder"] = "Inbox"
        storage.settings["vault.pathRule"] = "flat"
        storage.settings["vault.conflictStrategy"] = "rename"
        storage.settings["vault.autoFrontmatter"] = "true"
        storage.settings["vault.frontmatterTemplate"] = #"{"project":"AcMind"}"#

        let sourceItem = SourceItem(
            id: "source-1",
            type: .text,
            source: .manual,
            status: .distilled,
            title: "源内容"
        )
        storage.sourceItems[sourceItem.id] = sourceItem

        let note = DistilledNote(
            id: "note-1",
            sourceItemId: sourceItem.id,
            title: "导出标题",
            summary: "导出摘要",
            category: "work",
            tags: ["acmind"],
            documentType: "note",
            contentMarkdown: "# 导出标题\n\n内容",
            valueScore: 0.8
        )
        storage.distilledNotes[note.id] = note

        let router = AgentToolRouter(storage: storage)
        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .export,
                action: "toObsidian",
                parameters: [
                    "noteId": note.id,
                    "sourceItemId": sourceItem.id
                ]
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output?.contains(".md") == true)

        let exportedFiles = try FileManager.default.contentsOfDirectory(at: vaultURL.appendingPathComponent("Inbox"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "md" }
        XCTAssertFalse(exportedFiles.isEmpty)
    }

    func testUnsupportedAgentToolRoutesReturnFailure() async throws {
        let storage = AgentToolRouterStorageStub()
        let router = AgentToolRouter(storage: storage)

        let cases: [(AgentToolType, String, [String: String], String)] = [
            (.voice, "transcribe", [:], "请提供 audioURL"),
            (.schedule, "create", ["name": "晨间安排"], "请提供 skillName")
        ]

        for (toolType, action, parameters, expectedMessage) in cases {
            let result = try await router.routeTool(
                request: AgentToolRequest(
                    toolType: toolType,
                    action: action,
                    parameters: parameters
                )
            )

            XCTAssertFalse(result.success)
            XCTAssertEqual(result.toolType, toolType)
            XCTAssertEqual(result.action, action)
            XCTAssertTrue(result.errorMessage?.contains(expectedMessage) == true)
        }
    }

    func testFileDeleteReturnsStructuredFailureForMissingPath() async throws {
        let storage = AgentToolRouterStorageStub()
        let router = AgentToolRouter(storage: storage)
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind-AgentToolRouterTests-\(UUID().uuidString).txt")

        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .file,
                action: "delete",
                parameters: ["path": missingURL.path]
            )
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.errorMessage?.contains("文件不存在") == true)
    }

    func testAIChatUsesInjectedRuntimeWithPromptAndProvider() async throws {
        let storage = AgentToolRouterStorageStub()
        let aiRuntime = MockAIRuntime(
            providers: [
                ProviderConfig(
                    id: "provider-1",
                    name: "测试 Provider",
                    providerType: .ollama,
                    tier: .localLight,
                    baseURL: "http://localhost:11434",
                    modelId: "llama3.1",
                    enabled: true
                )
            ],
            response: ChatResponse(content: "AI 返回内容", model: "gpt-test", providerId: "provider-1")
        )
        let router = AgentToolRouter(storage: storage, aiRuntime: aiRuntime)

        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .ai,
                action: "chat",
                parameters: [
                    "prompt": "请总结这段内容",
                    "providerId": "provider-1",
                    "model": "gpt-test",
                    "systemPrompt": "你是一个摘要助手"
                ]
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output?.contains("AI 返回内容") == true)
        XCTAssertEqual(aiRuntime.lastProviderId, "provider-1")
        XCTAssertEqual(aiRuntime.lastModel, "gpt-test")
        XCTAssertEqual(aiRuntime.lastMessages?.count, 2)
        XCTAssertEqual(aiRuntime.lastMessages?.first?.role, .system)
        XCTAssertEqual(aiRuntime.lastMessages?.first?.content, "你是一个摘要助手")
        XCTAssertEqual(aiRuntime.lastMessages?.last?.role, .user)
        XCTAssertEqual(aiRuntime.lastMessages?.last?.content, "请总结这段内容")
    }

    func testAIQuickAskUsesQuickAskPathAndContext() async throws {
        let storage = AgentToolRouterStorageStub()
        let aiRuntime = MockAIRuntime(
            providers: [
                ProviderConfig(
                    id: "provider-1",
                    name: "测试 Provider",
                    providerType: .ollama,
                    tier: .localLight,
                    baseURL: "http://localhost:11434",
                    modelId: "llama3.1",
                    enabled: true
                )
            ],
            response: ChatResponse(content: "你可以先拆成三步。", model: "gpt-test", providerId: "provider-1")
        )
        let router = AgentToolRouter(storage: storage, aiRuntime: aiRuntime)

        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .ai,
                action: "quickAsk",
                parameters: [
                    "question": "我该怎么开始？",
                    "providerId": "provider-1",
                    "model": "gpt-test",
                    "context": "项目目标是尽快验证方向"
                ]
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output?.contains("你可以先拆成三步。") == true)
        XCTAssertEqual(aiRuntime.lastProviderId, "provider-1")
        XCTAssertEqual(aiRuntime.lastModel, "gpt-test")
        XCTAssertTrue(aiRuntime.lastMessages?.last?.content.contains("我该怎么开始？") == true)
        XCTAssertTrue(aiRuntime.lastMessages?.last?.content.contains("项目目标是尽快验证方向") == true)
    }

    func testAIAutomationDraftUsesDedicatedRoute() async throws {
        let storage = AgentToolRouterStorageStub()
        let aiRuntime = MockAIRuntime(
            providers: [
                ProviderConfig(
                    id: "provider-1",
                    name: "测试 Provider",
                    providerType: .ollama,
                    tier: .localLight,
                    baseURL: "http://localhost:11434",
                    modelId: "llama3.1",
                    enabled: true
                )
            ],
            response: ChatResponse(content: "1. 收集需求\n2. 拆解步骤")
        )
        let router = AgentToolRouter(storage: storage, aiRuntime: aiRuntime)

        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .ai,
                action: "automationDraft",
                parameters: [
                    "goal": "整理今天的待办并发给团队",
                    "providerId": "provider-1",
                    "model": "gpt-test",
                    "context": "自动化草案"
                ]
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output?.contains("1. 收集需求") == true)
        XCTAssertEqual(aiRuntime.lastProviderId, "provider-1")
        XCTAssertEqual(aiRuntime.lastModel, "gpt-test")
        XCTAssertTrue(aiRuntime.lastMessages?.last?.content.contains("自动化草案") == true)
        XCTAssertTrue(aiRuntime.lastMessages?.last?.content.contains("整理今天的待办并发给团队") == true)
    }

    func testAIChatParsesMessagesPayload() async throws {
        let storage = AgentToolRouterStorageStub()
        let aiRuntime = MockAIRuntime(response: ChatResponse(content: "多轮对话响应"))
        let router = AgentToolRouter(storage: storage, aiRuntime: aiRuntime)

        let messages = #"[{"role":"system","content":"你是助手"},{"role":"user","content":"你好"}]"#
        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .ai,
                action: "prompt",
                parameters: [
                    "messages": messages
                ]
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output?.contains("多轮对话响应") == true)
        XCTAssertEqual(aiRuntime.lastMessages?.count, 2)
        XCTAssertEqual(aiRuntime.lastMessages?.first?.role, .system)
        XCTAssertEqual(aiRuntime.lastMessages?.last?.role, .user)
    }

    func testAIProvidersAndModelsRoutesExposeRuntimeData() async throws {
        let storage = AgentToolRouterStorageStub()
        let aiRuntime = MockAIRuntime(
            providers: [
                ProviderConfig(
                    id: "provider-1",
                    name: "本地模型",
                    providerType: .ollama,
                    tier: .localLight,
                    baseURL: "http://localhost:11434",
                    modelId: "llama3.1",
                    enabled: true
                )
            ],
            models: ["llama3.1", "qwen2.5"]
        )
        let router = AgentToolRouter(storage: storage, aiRuntime: aiRuntime)

        let providersResult = try await router.routeTool(
            request: AgentToolRequest(toolType: .ai, action: "providers")
        )
        XCTAssertTrue(providersResult.success)
        XCTAssertTrue(providersResult.output?.contains("本地模型") == true)

        let modelsResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .ai,
                action: "models",
                parameters: ["providerId": "provider-1"]
            )
        )
        XCTAssertTrue(modelsResult.success)
        XCTAssertTrue(modelsResult.output?.contains("llama3.1") == true)
        XCTAssertTrue(modelsResult.output?.contains("qwen2.5") == true)
    }

    func testToolsJSONFormatterAndBase64CodecAreReal() async throws {
        let storage = AgentToolRouterStorageStub()
        let router = AgentToolRouter(storage: storage)

        let jsonResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .tools,
                action: "jsonFormatter",
                parameters: [
                    "name": "jsonFormatter",
                    "text": #"{"b":2,"a":1}"#,
                    "pretty": "true"
                ]
            )
        )

        XCTAssertTrue(jsonResult.success)
        XCTAssertTrue(jsonResult.output?.contains("\"a\"") == true)
        XCTAssertTrue(jsonResult.output?.contains("\n") == true)

        let base64Result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .tools,
                action: "base64Codec",
                parameters: [
                    "name": "base64Codec",
                    "text": "AcMind",
                    "mode": "encode"
                ]
            )
        )

        XCTAssertTrue(base64Result.success)
        XCTAssertEqual(base64Result.output, "QWNNaW5k")
    }

    func testToolsSRTAndImageProcessAreReal() async throws {
        let storage = AgentToolRouterStorageStub()
        let router = AgentToolRouter(storage: storage)

        let srtResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .tools,
                action: "srtToFcpxml",
                parameters: [
                    "name": "srtToFcpxml",
                    "srt": """
                    1
                    00:00:01,000 --> 00:00:03,000
                    第一行

                    2
                    00:00:04,000 --> 00:00:06,000
                    第二行
                    """
                ]
            )
        )

        XCTAssertTrue(srtResult.success)
        XCTAssertTrue(srtResult.output?.contains("<fcpxml") == true)
        XCTAssertTrue(srtResult.output?.contains("第一行") == true)

        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 16, height: 16)).fill()
        image.unlockFocus()

        let imageURL = FileManager.default.temporaryDirectory.appendingPathComponent("agent-router-image-\(UUID().uuidString).tiff")
        try XCTUnwrap(image.tiffRepresentation).write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let imageResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .tools,
                action: "imageProcess",
                parameters: [
                    "name": "imageProcess",
                    "path": imageURL.path,
                    "format": "png",
                    "maxDimension": "8",
                    "quality": "0.8"
                ]
            )
        )

        XCTAssertTrue(imageResult.success)
        XCTAssertTrue(imageResult.output?.contains("format: png") == true)
    }

    func testToolsBatchDownloadPreviewAndVideoDownloadAreReal() async throws {
        let storage = AgentToolRouterStorageStub()
        let processRunner = MockProcessRunner(result: ProcessCommandResult(stdout: "yt-dlp done", stderr: "", exitCode: 0))
        let router = AgentToolRouter(storage: storage, processRunner: processRunner)

        let batchResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .tools,
                action: "batchDownload",
                parameters: [
                    "name": "batchDownload",
                    "url": "https://example.com/article",
                    "html": #"<html><body><img src="https://example.com/image.png"><a href="https://example.com/file.pdf">file</a></body></html>"#,
                    "previewOnly": "true"
                ]
            )
        )

        XCTAssertTrue(batchResult.success)
        XCTAssertTrue(batchResult.output?.contains("https://example.com/image.png") == true)
        XCTAssertTrue(batchResult.output?.contains("https://example.com/file.pdf") == true)

        let videoFolder = FileManager.default.temporaryDirectory.appendingPathComponent("AcMind-Video-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: videoFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: videoFolder) }

        let videoResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .tools,
                action: "videoDownload",
                parameters: [
                    "name": "videoDownload",
                    "url": "https://example.com/watch?v=123",
                    "binaryPath": "/bin/echo",
                    "outputFolder": videoFolder.path,
                    "format": "best"
                ]
            )
        )

        XCTAssertTrue(videoResult.success)
        XCTAssertEqual(processRunner.lastExecutablePath, "/bin/echo")
        XCTAssertTrue(processRunner.lastArguments.contains("https://example.com/watch?v=123"))
    }

    func testToolsDocumentConvertAndFileRoutesAreReal() async throws {
        let storage = AgentToolRouterStorageStub()
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("AcMind-AgentToolRouterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = tempRoot.appendingPathComponent("source.txt")
        try "第一行\n第二行".write(to: sourceURL, atomically: true, encoding: .utf8)

        let router = AgentToolRouter(storage: storage, processRunner: MockProcessRunner(result: ProcessCommandResult(stdout: "", stderr: "", exitCode: 1)))

        let documentResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .tools,
                action: "documentConvert",
                parameters: [
                    "name": "documentConvert",
                    "sourceURL": sourceURL.path
                ]
            )
        )

        XCTAssertTrue(documentResult.success)
        XCTAssertTrue(documentResult.output?.contains("# source") == true)

        let folderURL = tempRoot.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let renameSource = folderURL.appendingPathComponent("old.txt")
        try "hello".write(to: renameSource, atomically: true, encoding: .utf8)

        let fileInfoResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .file,
                action: "info",
                parameters: ["path": renameSource.path]
            )
        )
        XCTAssertTrue(fileInfoResult.success)
        XCTAssertTrue(fileInfoResult.output?.contains("old.txt") == true)

        let renameResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .file,
                action: "rename",
                parameters: [
                    "path": renameSource.path,
                    "newName": "new.txt"
                ]
            )
        )
        XCTAssertTrue(renameResult.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folderURL.appendingPathComponent("new.txt").path))
    }

    func testToolsModelManagementAndAPITestRoutesExposeProviderState() async throws {
        let storage = AgentToolRouterStorageStub()
        let aiRuntime = MockAIRuntime(
            providers: [
                ProviderConfig(
                    id: "provider-1",
                    name: "本地模型",
                    providerType: .ollama,
                    tier: .localLight,
                    baseURL: "http://localhost:11434",
                    modelId: "llama3.1",
                    enabled: true
                ),
                ProviderConfig(
                    id: "provider-2",
                    name: "停用提供商",
                    providerType: .openAICompatible,
                    tier: .cloudLight,
                    baseURL: "https://example.com",
                    modelId: "gpt-test",
                    enabled: false
                )
            ],
            models: ["llama3.1", "qwen2.5"]
        )
        let router = AgentToolRouter(storage: storage, aiRuntime: aiRuntime)

        let managementResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .tools,
                action: "modelManagement",
                parameters: [
                    "name": "modelManagement",
                    "providerId": "provider-1"
                ]
            )
        )

        XCTAssertTrue(managementResult.success)
        XCTAssertTrue(managementResult.output?.contains("provider-1") == true)
        XCTAssertTrue(managementResult.output?.contains("llama3.1") == true)

        let apiTestResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .tools,
                action: "apiTest",
                parameters: [
                    "name": "apiTest",
                    "providerId": "provider-1"
                ]
            )
        )

        XCTAssertTrue(apiTestResult.success)
        XCTAssertTrue(apiTestResult.output?.contains("provider-1: 可用") == true)
        XCTAssertTrue(apiTestResult.output?.contains("llama3.1") == true)
    }

    func testAvailableToolsIncludesAI() async {
        let storage = AgentToolRouterStorageStub()
        let router = AgentToolRouter(storage: storage)

        let tools = await router.getAvailableTools()
        XCTAssertTrue(tools.contains(where: { $0.type == .ai }))
        XCTAssertTrue(tools.contains(where: { $0.type == .file }))
    }

    func testClipboardSummarizeUsesStoredItems() async throws {
        let storage = AgentToolRouterStorageStub()
        storage.clipboardItems = [
            ClipboardItem(type: .text, content: "第一条剪贴板内容", textContent: "第一条剪贴板内容"),
            ClipboardItem(type: .url, content: "https://example.com", textContent: "https://example.com"),
            ClipboardItem(type: .file, content: "/tmp/demo.txt", textContent: "demo.txt")
        ]

        let router = AgentToolRouter(storage: storage)
        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .clipboard,
                action: "summarize"
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output?.contains("剪贴板历史 (3)") == true)
        XCTAssertTrue(result.output?.contains("第一条剪贴板内容") == true)
    }

    func testMarkdownFormatNormalizesSpacing() async throws {
        let storage = AgentToolRouterStorageStub()
        let router = AgentToolRouter(storage: storage)

        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .markdown,
                action: "format",
                parameters: [
                    "text": "#标题\n\nParagraph  \n\n##子标题"
                ]
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "# 标题\n\nParagraph\n\n## 子标题")
    }

    func testWebDigestFetchUsesProcessRunner() async throws {
        let storage = AgentToolRouterStorageStub()
        let processRunner = MockProcessRunner(result: ProcessCommandResult(stdout: "# 标题\n正文", stderr: "", exitCode: 0))
        let router = AgentToolRouter(storage: storage, processRunner: processRunner)

        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .webDigest,
                action: "fetch",
                parameters: ["url": "https://example.com/article"]
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "# 标题\n正文")
        XCTAssertEqual(processRunner.lastExecutablePath, "/usr/bin/env")
        XCTAssertEqual(processRunner.lastArguments, ["defuddle", "parse", "https://example.com/article", "--md"])
    }

    func testScheduleCreateListUpdateAndDeleteUsePersistence() async throws {
        let storage = AgentToolRouterStorageStub()
        let router = AgentToolRouter(storage: storage)

        let createResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .schedule,
                action: "create",
                parameters: [
                    "name": "晨间整理",
                    "cronExpression": "0 8 * * *",
                    "skillName": "quick_note",
                    "inputParams": #"{"priority":"high"}"#
                ]
            )
        )

        XCTAssertTrue(createResult.success)
        XCTAssertEqual(storage.scheduledTasks.count, 1)
        let createdTask = try XCTUnwrap(storage.scheduledTasks.values.first)
        XCTAssertEqual(createdTask.name, "晨间整理")

        let listResult = try await router.routeTool(
            request: AgentToolRequest(toolType: .schedule, action: "list")
        )
        XCTAssertTrue(listResult.success)
        XCTAssertTrue(listResult.output?.contains("晨间整理") == true)

        let updateResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .schedule,
                action: "update",
                parameters: [
                    "taskId": createdTask.id,
                    "enabled": "false",
                    "name": "晨间整理（更新）"
                ]
            )
        )
        XCTAssertTrue(updateResult.success)
        XCTAssertEqual(storage.scheduledTasks[createdTask.id]?.enabled, false)
        XCTAssertEqual(storage.scheduledTasks[createdTask.id]?.name, "晨间整理（更新）")

        let deleteResult = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .schedule,
                action: "delete",
                parameters: ["taskId": createdTask.id]
            )
        )
        XCTAssertTrue(deleteResult.success)
        XCTAssertNil(storage.scheduledTasks[createdTask.id])
    }

    func testVoiceTranscribeUsesInjectedVoiceService() async throws {
        let storage = AgentToolRouterStorageStub()
        let voiceService = MockVoiceService(transcript: "这是转写结果")
        let router = AgentToolRouter(storage: storage, voiceService: voiceService)

        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("agent-router-test.m4a")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data(), attributes: nil)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .voice,
                action: "transcribe",
                parameters: [
                    "audioURL": audioURL.path,
                    "language": "zh"
                ]
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "这是转写结果")
        XCTAssertEqual(voiceService.lastAudioPath, audioURL.path)
    }

    func testInboxDistillUsesDistillService() async throws {
        let storage = AgentToolRouterStorageStub()
        let sourceItem = SourceItem(
            id: "source-1",
            type: .text,
            source: .manual,
            status: .captured,
            title: "待蒸馏条目",
            previewText: "原始内容"
        )
        storage.sourceItems[sourceItem.id] = sourceItem

        let distillService = MockDistillService(storage: storage)
        let router = AgentToolRouter(storage: storage, distillService: distillService)

        let result = try await router.routeTool(
            request: AgentToolRequest(
                toolType: .inbox,
                action: "distill",
                parameters: ["itemId": sourceItem.id]
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output?.contains("待蒸馏条目") == true)
        XCTAssertEqual(storage.distilledNotes.count, 1)
    }

    func testKnowledgeReadHidesDeletedCardsFromDefaultListing() async throws {
        let storage = AgentToolRouterStorageStub()
        storage.knowledgeCards["active-card"] = KnowledgeCard(
            id: "active-card",
            sourceItemId: "source-active",
            canonicalTitle: "活跃卡片",
            status: .active
        )
        storage.knowledgeCards["deleted-card"] = KnowledgeCard(
            id: "deleted-card",
            sourceItemId: "source-deleted",
            canonicalTitle: "已删除卡片",
            status: .deleted
        )

        let router = AgentToolRouter(storage: storage)
        let result = try await router.routeTool(
            request: AgentToolRequest(toolType: .knowledge, action: "read")
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output?.contains("活跃卡片") == true)
        XCTAssertFalse(result.output?.contains("已删除卡片") == true)
        XCTAssertTrue(result.output?.contains("知识卡片 (1)") == true)
    }
}

private final class AgentToolRouterStorageStub: StorageServiceProtocol, @unchecked Sendable {
    var sourceItems: [String: SourceItem] = [:]
    var distilledNotes: [String: DistilledNote] = [:]
    var knowledgeCards: [String: KnowledgeCard] = [:]
    var exportRecords: [ExportRecord] = []
    var settings: [String: String] = [:]
    var scheduledTasks: [String: ScheduledAgentTask] = [:]
    var clipboardItems: [ClipboardItem] = []

    func insertSourceItem(_ item: SourceItem) async throws { sourceItems[item.id] = item }
    func getSourceItem(id: String) async throws -> SourceItem? { sourceItems[id] }
    func listSourceItems(filter: SourceItemFilter?) async throws -> [SourceItem] { Array(sourceItems.values) }
    func updateSourceItem(_ item: SourceItem) async throws { sourceItems[item.id] = item }
    func deleteSourceItem(id: String) async throws { sourceItems.removeValue(forKey: id) }

    func insertChatSession(_ session: ChatSession) async throws {}
    func getChatSession(id: String) async throws -> ChatSession? { nil }
    func listChatSessions(status: String?) async throws -> [ChatSession] { [] }
    func updateChatSession(_ session: ChatSession) async throws {}
    func deleteChatSession(id: String) async throws {}
    func insertChatMessage(_ message: ChatMessage) async throws {}
    func listChatMessages(sessionId: String) async throws -> [ChatMessage] { [] }

    func insertDistilledNote(_ note: DistilledNote) async throws { distilledNotes[note.id] = note }
    func updateDistilledNote(_ note: DistilledNote) async throws { distilledNotes[note.id] = note }
    func deleteDistilledNote(id: String) async throws { distilledNotes.removeValue(forKey: id) }
    func listDistilledNotes() async throws -> [DistilledNote] { Array(distilledNotes.values) }

    func insertExportRecord(_ record: ExportRecord) async throws { exportRecords.append(record) }
    func listExportRecords() async throws -> [ExportRecord] { exportRecords }

    func insertKnowledgeCard(_ card: KnowledgeCard) async throws { knowledgeCards[card.id] = card }
    func updateKnowledgeCard(_ card: KnowledgeCard) async throws { knowledgeCards[card.id] = card }
    func listKnowledgeCards(status: KnowledgeCardStatus?) async throws -> [KnowledgeCard] {
        let cards = Array(knowledgeCards.values)
        if let status {
            return cards.filter { $0.status == status }
        }
        return cards
    }

    func insertKnowledgeEdge(_ edge: KnowledgeEdge) async throws {}
    func listKnowledgeEdges(fromCardId: String?, toCardId: String?) async throws -> [KnowledgeEdge] { [] }
    func deleteKnowledgeEdge(id: String) async throws {}

    func insertClipboardItem(_ item: ClipboardItem) async throws {}
    func listClipboardItems(limit: Int?) async throws -> [ClipboardItem] {
        let items = clipboardItems
        guard let limit else { return items }
        return Array(items.prefix(limit))
    }
    func updateClipboardItem(_ item: ClipboardItem) async throws {}
    func deleteClipboardItem(id: String) async throws {}

    func insertScheduledAgentTask(_ task: ScheduledAgentTask) async throws { scheduledTasks[task.id] = task }
    func getScheduledAgentTask(id: String) async throws -> ScheduledAgentTask? { scheduledTasks[id] }
    func listScheduledAgentTasks() async throws -> [ScheduledAgentTask] { Array(scheduledTasks.values) }
    func deleteScheduledAgentTask(id: String) async throws { scheduledTasks.removeValue(forKey: id) }

    func listProviders() async -> [ProviderConfig] { [] }
    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}

    func getSetting(key: String) async throws -> String? { settings[key] }
    func insertScheduleEvent(_ event: ScheduleEvent) async throws {}
    func updateScheduleEvent(_ event: ScheduleEvent) async throws {}
    func deleteScheduleEvent(id: String) async throws {}
    func listScheduleEvents() async throws -> [ScheduleEvent] { [] }
    func getScheduleEvent(id: String) async throws -> ScheduleEvent? { nil }
    func setSetting(key: String, value: String) async throws { settings[key] = value }

    func importFromJSON(_ items: [SourceItem]) async throws -> Int { 0 }
    func checkLegacyDatabase() -> URL? { nil }
    func getDatabasePath() -> String { ":memory:" }
    func getDatabaseVersion() async throws -> Int { 1 }
}

private final class MockDistillService: DistillServiceProtocol, @unchecked Sendable {
    private let storage: AgentToolRouterStorageStub

    init(storage: AgentToolRouterStorageStub) {
        self.storage = storage
    }

    func distill(sourceItem: SourceItem) async throws -> DistilledNote {
        let note = DistilledNote(
            sourceItemId: sourceItem.id,
            title: sourceItem.title ?? "蒸馏结果",
            summary: sourceItem.previewText ?? sourceItem.title,
            category: "测试",
            tags: ["agent"],
            documentType: "note",
            contentMarkdown: sourceItem.previewText ?? sourceItem.title ?? "",
            valueScore: 0.8,
            confidence: 0.9
        )
        try await storage.insertDistilledNote(note)
        return note
    }

    func batchDistill(sourceItems: [SourceItem]) async throws -> [DistilledNote] {
        try await withThrowingTaskGroup(of: DistilledNote.self) { group in
            for item in sourceItems {
                group.addTask { try await self.distill(sourceItem: item) }
            }

            var notes: [DistilledNote] = []
            for try await note in group {
                notes.append(note)
            }
            return notes
        }
    }

    func review(noteId: String, action: ReviewAction) async throws -> DistilledNote? { nil }
}

private final class MockVoiceService: VoiceServiceProtocol, @unchecked Sendable {
    let transcript: String
    private(set) var lastAudioPath: String?

    init(transcript: String) {
        self.transcript = transcript
    }

    func startRecording() async throws {}
    func stopRecording() async throws -> String { "" }
    func setStatusHandler(_ handler: @escaping @Sendable (RecordingStatus) -> Void) async {}
    func transcribe(audioURL: URL) async throws -> String {
        lastAudioPath = audioURL.path
        return transcript
    }
    func polishTranscript(_ text: String, mode: VoicePolishMode) async throws -> String { text }
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?) async throws -> String { text }
    func polishTranscript(_ text: String, mode: VoicePolishMode, hotwords: [String], customSystemPrompt: String?, contextInfo: String?, language: String) async throws -> String { text }
    func translateTranscript(_ text: String, targetLanguage: String, contextInfo: String?) async throws -> String { text }
    func translateTranscriptStream(_ text: String, targetLanguage: String, contextInfo: String?, onChunk: @escaping @Sendable (String) async -> Void) async throws -> String {
        await onChunk(text)
        return text
    }
    func getRecordingStatus() async -> RecordingStatus { .idle }
    func startRealtimeTranscription(onUpdate: @escaping @Sendable (TranscriptionSnapshot) -> Void) async throws {}
    func stopRealtimeTranscription() async throws -> String { "" }
    var isRealtimeActive: Bool { get async { false } }
}

private final class MockProcessRunner: ProcessCommandRunning, @unchecked Sendable {
    let result: ProcessCommandResult
    private(set) var lastExecutablePath: String?
    private(set) var lastArguments: [String] = []

    init(result: ProcessCommandResult) {
        self.result = result
    }

    func run(
        executablePath: String,
        arguments: [String],
        environment: [String : String]?,
        currentDirectoryURL: URL?
    ) async throws -> ProcessCommandResult {
        lastExecutablePath = executablePath
        lastArguments = arguments
        return result
    }
}

private final class MockAIRuntime: AIRuntimeProtocol, @unchecked Sendable {
    var providers: [ProviderConfig]
    var models: [String]
    var response: ChatResponse
    private(set) var lastMessages: [ChatMessage]?
    private(set) var lastProviderId: String?
    private(set) var lastModel: String?

    init(
        providers: [ProviderConfig] = [],
        models: [String] = [],
        response: ChatResponse = ChatResponse(content: "mock-response")
    ) {
        self.providers = providers
        self.models = models
        self.response = response
    }

    func listProviders() async -> [ProviderConfig] {
        providers
    }

    func addProvider(_ config: ProviderConfig) async throws {}
    func updateProvider(_ config: ProviderConfig) async throws {}
    func removeProvider(id: String) async throws {}
    func setDefaultProvider(id: String) throws {}

    func healthCheck(providerId: String) async throws -> Bool {
        providers.contains(where: { $0.id == providerId && $0.enabled })
    }

    func listModels(providerId: String) async throws -> [String] {
        models
    }

    func listJobs() async throws -> [ProcessJob] { [] }
    func cancelJob(id: String) async throws {}

    func runDistillation(sourceItem: SourceItem) async throws -> DistilledNote {
        DistilledNote(
            sourceItemId: sourceItem.id,
            title: sourceItem.title ?? "mock",
            summary: sourceItem.previewText ?? sourceItem.title,
            category: "测试",
            tags: [],
            documentType: "note",
            contentMarkdown: sourceItem.previewText ?? sourceItem.title ?? "",
            valueScore: 0.5
        )
    }

    func chat(messages: [ChatMessage]) async throws -> ChatResponse {
        lastMessages = messages
        lastProviderId = nil
        lastModel = nil
        return response
    }

    func chat(messages: [ChatMessage], providerId: String, model: String?) async throws -> ChatResponse {
        lastMessages = messages
        lastProviderId = providerId
        lastModel = model
        return ChatResponse(
            content: response.content,
            model: model ?? response.model,
            providerId: providerId,
            promptTokens: response.promptTokens,
            completionTokens: response.completionTokens,
            latencyMs: response.latencyMs,
            finishReason: response.finishReason,
            usage: response.usage,
            isStreaming: response.isStreaming
        )
    }

    func chatStream(messages: [ChatMessage]) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
