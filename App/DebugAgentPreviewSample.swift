import Foundation
import AcMindKit

#if DEBUG
enum DebugAgentPreviewSample {
    @MainActor
    static func makeViewModel() -> AgentViewModel {
        let viewModel = AgentViewModel()
        viewModel.availableModelOptions = [
            AgentViewModel.ModelOption(providerId: "openai", providerName: "OpenAI", modelName: "gpt-4.1"),
            AgentViewModel.ModelOption(providerId: "claude", providerName: "Anthropic", modelName: "claude-3.5-sonnet")
        ]
        viewModel.selectedModelOption = viewModel.availableModelOptions.first
        viewModel.selectedModelLabel = viewModel.availableModelOptions.first?.displayName ?? "未配置模型"
        viewModel.projectContextItems = [
            SecondarySidebarItem(id: "proj-1", title: "日报自动化", icon: "folder", badge: "3")
        ]
        viewModel.recentItems = [
            SourceItem(type: .text, source: .manual, status: .distilled, title: "日报素材", previewText: "整理完成的日报片段"),
            SourceItem(type: .text, source: .manual, status: .captured, title: "会议要点", previewText: "待整理的会议纪要")
        ]
        viewModel.quickAskQuestion = "帮我解释这段脚本在做什么？"
        viewModel.quickAskAnswer = "这段脚本会先读取配置，然后在失败时回退到默认值。"
        viewModel.quickAskMessages = [
            ChatMessage(sessionId: "preview", role: .user, content: "帮我解释这段脚本在做什么？"),
            ChatMessage(sessionId: "preview", role: .assistant, content: "它会先读取配置，然后在失败时回退到默认值。")
        ]
        viewModel.toolCallResult = """
        执行完成

        provider: openai
        model: gpt-4.1

        - 已读取 2 条素材
        - 已生成初稿

        ```swift
        let config = loadConfig()
        guard config.isEnabled else { return }
        ```

        输出已写入初稿。
        """
        viewModel.errorMessage = "权限确认：需要辅助功能权限后才能继续。"
        viewModel.currentTask = AgentTask(
            title: "整理日报素材",
            description: "将会议要点整理成日报初稿",
            status: .running,
            steps: [
                TaskStep(title: "读取输入", description: "", status: .completed, result: "已读取 2 条素材", order: 0),
                TaskStep(title: "生成内容", description: "正在生成结构化结果", status: .running, toolCall: ToolCall(toolName: "composeDraft", toolType: .aiCall), order: 1)
            ],
            currentStepIndex: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_060),
            startedAt: Date(timeIntervalSince1970: 1_700_000_020)
        )
        viewModel.agentTasks = [
            AgentTask(
                title: "整理日报素材",
                description: "将会议要点整理成日报初稿",
                status: .running,
                steps: [
                    TaskStep(title: "读取输入", description: "", status: .completed, order: 0),
                    TaskStep(title: "生成内容", description: "", status: .running, order: 1)
                ],
                currentStepIndex: 1
            ),
            AgentTask(
                title: "导出周报",
                description: "导出 markdown 周报",
                status: .waiting,
                steps: [
                    TaskStep(title: "等待确认", description: "需要用户确认导出路径", status: .running, order: 0)
                ],
                currentStepIndex: 0
            ),
            AgentTask(
                title: "同步知识卡片",
                description: "同步后归档为技能",
                status: .completed,
                products: [TaskProduct(name: "日报.md", type: .markdown)]
            )
        ]
        return viewModel
    }
}
#endif
