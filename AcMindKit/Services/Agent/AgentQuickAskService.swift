import Foundation

public actor AgentQuickAskService {
    private let aiRuntime: AIRuntimeProtocol
    private let storage: StorageServiceProtocol?

    public init(
        aiRuntime: AIRuntimeProtocol = AIRuntimeService(),
        storage: StorageServiceProtocol? = nil
    ) {
        self.aiRuntime = aiRuntime
        self.storage = storage
    }

    public func ask(
        question: String,
        providerId: String? = nil,
        model: String? = nil,
        context: String? = nil
    ) async throws -> ChatResponse {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuestion.isEmpty == false else {
            throw AIError.invalidInput("question 不能为空")
        }

        var messages: [ChatMessage] = [
            ChatMessage(
                sessionId: UUID().uuidString,
                role: .system,
                content: "你是一个简洁直接的 AI 助手。请优先给出可执行答案，避免长篇废话。"
            )
        ]

        if let context, context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            messages.append(
                ChatMessage(
                    sessionId: UUID().uuidString,
                    role: .user,
                    content: "上下文：\n\(context)\n\n问题：\n\(trimmedQuestion)"
                )
            )
        } else {
            messages.append(
                ChatMessage(
                    sessionId: UUID().uuidString,
                    role: .user,
                    content: trimmedQuestion
                )
            )
        }

        let response: ChatResponse
        if let providerId, providerId.isEmpty == false {
            response = try await aiRuntime.chat(messages: messages, providerId: providerId, model: model)
        } else {
            response = try await aiRuntime.chat(messages: messages)
        }

        if storage != nil {
            try? await persistHistory(
                question: trimmedQuestion,
                context: context,
                response: response,
                providerId: response.providerId ?? providerId,
                model: response.model ?? model
            )
        }

        return response
    }

    private func persistHistory(
        question: String,
        context: String?,
        response: ChatResponse,
        providerId: String?,
        model: String?
    ) async throws {
        let sessionId = UUID().uuidString
        let session = ChatSession(
            id: sessionId,
            title: String(question.prefix(40)),
            providerId: providerId,
            modelId: model,
            status: .active,
            metadata: [
                "kind": "quickAsk",
                "question": question,
                "context": context ?? ""
            ]
        )
        guard let storage else { return }
        try await storage.insertChatSession(session)

        let userMessage = ChatMessage(
            sessionId: sessionId,
            role: .user,
            content: context.map { contextText in
                contextText.isEmpty ? question : "上下文：\n\(contextText)\n\n问题：\n\(question)"
            } ?? question,
            status: .completed,
            modelId: model,
            providerId: providerId
        )
        try await storage.insertChatMessage(userMessage)

        let assistantMessage = ChatMessage(
            sessionId: sessionId,
            role: .assistant,
            content: response.content,
            status: .completed,
            modelId: response.model ?? model,
            providerId: response.providerId ?? providerId,
            promptTokens: response.promptTokens,
            completionTokens: response.completionTokens,
            latencyMs: response.latencyMs
        )
        try await storage.insertChatMessage(assistantMessage)

        var updatedSession = session
        updatedSession.status = .active
        updatedSession.updatedAt = Date()
        try await storage.updateChatSession(updatedSession)
    }
}
