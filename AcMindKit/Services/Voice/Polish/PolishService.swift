import Foundation

// MARK: - Polish Service

/// 润色服务
/// 复用 AIRuntimeService，支持用户自由选择 Provider/Model
public actor PolishService {
    
    // MARK: - Properties
    
    private let aiRuntime: AIRuntimeProtocol
    
    // MARK: - Initialization
    
    public init(aiRuntime: AIRuntimeProtocol) {
        self.aiRuntime = aiRuntime
    }
    
    // MARK: - Polish
    
    /// 润色文本
    /// - Parameters:
    ///   - text: 原始文本
    ///   - mode: 润色模式
    ///   - providerId: 指定的 Provider ID（可选，使用默认）
    ///   - model: 指定的模型（可选）
    ///   - hotwords: 热词列表
    /// - Returns: 润色后的文本
    public func polish(
        text: String,
        mode: VoicePolishMode,
        providerId: String? = nil,
        model: String? = nil,
        hotwords: [String] = []
    ) async throws -> String {
        guard mode != .none else { return text }
        
        // 构建 prompt
        let systemPrompt: String
        if hotwords.isEmpty {
            systemPrompt = PolishPrompts.systemPrompt(for: mode)
        } else {
            systemPrompt = PolishPrompts.systemPrompt(for: mode, hotwords: hotwords)
        }
        
        let userPrompt = PolishPrompts.userPrompt(for: text)
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userPrompt)
        ]
        
        // 调用 AI Runtime
        let response: ChatResponse
        if let providerId = providerId {
            response = try await aiRuntime.chat(
                messages: messages,
                providerId: providerId,
                model: model
            )
        } else {
            response = try await aiRuntime.chat(messages: messages)
        }
        
        // 清理输出
        return cleanOutput(response.content)
    }
    
    /// 流式润色
    /// - Parameters:
    ///   - text: 原始文本
    ///   - mode: 润色模式
    ///   - providerId: 指定的 Provider ID
    ///   - model: 指定的模型
    ///   - hotwords: 热词列表
    ///   - onChunk: 流式输出回调
    /// - Returns: 完整润色文本
    public func polishStream(
        text: String,
        mode: VoicePolishMode,
        providerId: String? = nil,
        model: String? = nil,
        hotwords: [String] = [],
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        guard mode != .none else { return text }
        
        let systemPrompt = hotwords.isEmpty
            ? PolishPrompts.systemPrompt(for: mode)
            : PolishPrompts.systemPrompt(for: mode, hotwords: hotwords)
        
        let userPrompt = PolishPrompts.userPrompt(for: text)
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userPrompt)
        ]
        
        var fullContent = ""
        
        let stream = aiRuntime.chatStream(messages: messages)
        
        for try await response in stream {
            let chunk = response.content
            fullContent += chunk
            await onChunk(chunk)
        }
        
        return cleanOutput(fullContent)
    }
    
    // MARK: - Output Cleaning
    
    /// 清理 LLM 输出
    private func cleanOutput(_ content: String) -> String {
        var output = content
        
        // 移除 thinking 标签
        output = stripThinkingBlocks(output)
        
        // 移除 markdown 围栏
        output = stripMarkdownFence(output)
        
        // 移除开头套话
        output = stripLeadingBoilerplate(output)
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 移除 thinking 标签
    private func stripThinkingBlocks(_ text: String) -> String {
        var result = text
        
        // 匹配 <think...</think...>> 标签（忽略大小写）
        let pattern = "<think[^>]*>.*?</think\\s*>"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        
        return result
    }
    
    /// 移除 markdown 围栏
    private func stripMarkdownFence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.hasPrefix("```") && trimmed.hasSuffix("```") else {
            return text
        }
        
        var lines = trimmed.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return text }
        
        // 移除第一行和最后一行
        lines.removeFirst()
        lines.removeLast()
        
        return lines.joined(separator: "\n")
    }
    
    /// 移除开头套话
    private func stripLeadingBoilerplate(_ text: String) -> String {
        let prefixes = [
            "根据您给的内容",
            "根据您提供的内容",
            "根据你给的内容",
            "根据你提供的内容",
            "以下是整理后的内容",
            "以下是优化后的内容",
            "以下为整理后的内容",
            "以下是结构化整理后的内容",
            "我整理如下",
            "我已整理如下",
            "整理如下",
            "优化如下",
            "结构化整理如下"
        ]
        
        var result = text
        
        for prefix in prefixes {
            if result.hasPrefix(prefix) {
                // 找到第一个句号或换行后的位置
                if let range = "[。：:，,\n]".regularExpressionRange(in: result) {
                    result = String(result[range.upperBound...])
                } else {
                    result = String(result.dropFirst(prefix.count))
                }
                break
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - String Extension

extension String {
    func regularExpressionRange(in string: String) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: self) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range) else { return nil }
        return Range(match.range, in: string)
    }
}
