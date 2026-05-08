import Foundation

public enum AIPromptStyle: String, Codable, CaseIterable, Sendable {
    case technical
    case creative
    case business
    case general
    
    public var displayName: String {
        switch self {
        case .technical: return "技术文档"
        case .creative: return "创意写作"
        case .business: return "商务沟通"
        case .general: return "通用"
        }
    }
}

public actor AIPromptService {
    
    public static let shared = AIPromptService()
    
    private let systemPrompt: String = """
    # 角色
    你是一个专业的 AI Prompt 整理专家。用户的语音输入是需要被整理成结构化 prompt 的原材料。
    
    # 核心原则
    1. 保留用户的原始意图，即使表达不完整也要推断正确意图
    2. 技术术语、品牌名、人名、产品名原样保留
    3. 自动识别口语中的约束条件和要求
    4. 整理成可直接使用的 AI prompt 格式
    
    # 输出格式
    整理后的 prompt 应该包含：
    - 明确的任务目标
    - 具体的约束条件
    - 期望的输出格式
    - 必要的上下文信息
    
    # 禁止事项
    - 不要添加用户没有提到的内容
    - 不要替用户做决定
    - 不要使用模糊的描述
    - 不要在输出中添加解释性文字
    """
    
    public func polishToPrompt(
        text: String,
        style: AIPromptStyle = .general,
        aiRuntime: AIRuntimeProtocol
    ) async throws -> String {
        let stylePrompt = styleSystemPrompt(for: style)
        let fullPrompt = "\(systemPrompt)\n\n\(stylePrompt)"
        
        let userContent = """
        请将以下语音输入整理为结构化的 AI prompt：
        
        <原始输入>
        \(text)
        </原始输入>
        
        要求：
        1. 提取明确的任务目标
        2. 识别并列出约束条件
        3. 指定输出格式（如需要）
        4. 补充必要的上下文信息
        5. 只输出整理后的 prompt，不添加任何解释
        """
        
        let messages = [
            ChatMessage(role: "system", content: fullPrompt),
            ChatMessage(role: "user", content: userContent)
        ]
        
        let response = try await aiRuntime.chat(messages: messages)
        
        return cleanOutput(response.content)
    }
    
    public func polishToPromptStream(
        text: String,
        style: AIPromptStyle = .general,
        aiRuntime: AIRuntimeProtocol,
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let stylePrompt = styleSystemPrompt(for: style)
        let fullPrompt = "\(systemPrompt)\n\n\(stylePrompt)"
        
        let userContent = """
        请将以下语音输入整理为结构化的 AI prompt：
        
        <原始输入>
        \(text)
        </原始输入>
        
        只输出整理后的 prompt，不添加任何解释。
        """
        
        let messages = [
            ChatMessage(role: "system", content: fullPrompt),
            ChatMessage(role: "user", content: userContent)
        ]
        
        var fullContent = ""
        
        for try await response in aiRuntime.chatStream(messages: messages) {
            let chunk = response.content
            fullContent += chunk
            await onChunk(chunk)
        }
        
        return cleanOutput(fullContent)
    }
    
    public func extractStructuredPrompt(from text: String) -> StructuredPrompt {
        var prompt = StructuredPrompt()
        
        let lines = text.components(separatedBy: .newlines)
        
        var inConstraints = false
        var inOutputFormat = false
        var inContext = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.contains("任务") || trimmed.contains("目标") || trimmed.contains("要求") {
                prompt.task = extractContent(from: trimmed)
                continue
            }
            
            if trimmed.contains("约束") || trimmed.contains("条件") || trimmed.contains("限制") {
                inConstraints = true
                inOutputFormat = false
                inContext = false
                continue
            }
            
            if trimmed.contains("输出") || trimmed.contains("格式") || trimmed.contains("结果") {
                inConstraints = false
                inOutputFormat = true
                inContext = false
                continue
            }
            
            if trimmed.contains("上下文") || trimmed.contains("背景") || trimmed.contains("信息") {
                inConstraints = false
                inOutputFormat = false
                inContext = true
                continue
            }
            
            if trimmed.isEmpty {
                inConstraints = false
                inOutputFormat = false
                inContext = false
                continue
            }
            
            if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") {
                let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if inConstraints {
                    prompt.constraints.append(content)
                } else if inOutputFormat {
                    prompt.outputFormat.append(content)
                } else if inContext {
                    prompt.context.append(content)
                } else {
                    prompt.constraints.append(content)
                }
            } else if !inConstraints && !inOutputFormat && !inContext && !prompt.task.isEmpty && prompt.constraints.isEmpty {
                prompt.constraints.append(trimmed)
            }
        }
        
        return prompt
    }
    
    private func styleSystemPrompt(for style: AIPromptStyle) -> String {
        switch style {
        case .technical:
            return """
            # 风格：技术文档
            - 使用精确的技术术语
            - 明确指定技术栈和版本要求
            - 包含代码相关的约束
            - 输出格式优先 Markdown 代码块
            """
            
        case .creative:
            return """
            # 风格：创意写作
            - 允许开放性的任务描述
            - 关注创意方向和风格要求
            - 可以指定参考作品或风格
            - 输出格式可以是创意文本
            """
            
        case .business:
            return """
            # 风格：商务沟通
            - 使用正式的专业用语
            - 明确受众和目的
            - 包含数据和指标要求
            - 输出格式优先清晰的列表或段落
            """
            
        case .general:
            return """
            # 风格：通用
            - 根据任务内容自适应
            - 保持描述清晰准确
            - 不做过度技术化或文学化
            - 输出格式根据任务类型决定
            """
        }
    }
    
    private func extractContent(from line: String) -> String {
        let separators = [":", "：", "-", "—", "–"]
        for sep in separators {
            if let range = line.range(of: sep) {
                return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return line
    }
    
    private func cleanOutput(_ content: String) -> String {
        var output = content
        
        output = stripMarkdownFence(output)
        output = stripBoilerplate(output)
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func stripMarkdownFence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.hasPrefix("```") && trimmed.hasSuffix("```") else {
            return text
        }
        
        var lines = trimmed.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return text }
        
        lines.removeFirst()
        lines.removeLast()
        
        return lines.joined(separator: "\n")
    }
    
    private func stripBoilerplate(_ text: String) -> String {
        let prefixes = [
            "以下是整理后的 prompt",
            "整理后的 prompt",
            "Prompt：",
            "prompt：",
            "Prompt:",
            "prompt:"
        ]
        
        var result = text
        
        for prefix in prefixes {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                break
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct StructuredPrompt: Sendable {
    public var task: String = ""
    public var constraints: [String] = []
    public var outputFormat: [String] = []
    public var context: [String] = []
    
    public init() {}
    
    public func toMarkdown() -> String {
        var parts: [String] = []
        
        if !task.isEmpty {
            parts.append("## 任务\n\(task)")
        }
        
        if !constraints.isEmpty {
            let constraintItems = constraints.map { "- \($0)" }.joined(separator: "\n")
            parts.append("## 约束条件\n\(constraintItems)")
        }
        
        if !outputFormat.isEmpty {
            let formatItems = outputFormat.map { "- \($0)" }.joined(separator: "\n")
            parts.append("## 输出格式\n\(formatItems)")
        }
        
        if !context.isEmpty {
            let contextItems = context.map { "- \($0)" }.joined(separator: "\n")
            parts.append("## 上下文\n\(contextItems)")
        }
        
        return parts.joined(separator: "\n\n")
    }
    
    public func toPlainText() -> String {
        var parts: [String] = []
        
        if !task.isEmpty {
            parts.append(task)
        }
        
        if !constraints.isEmpty {
            parts.append(constraints.joined(separator: "；"))
        }
        
        if !outputFormat.isEmpty {
            parts.append(outputFormat.joined(separator: "；"))
        }
        
        if !context.isEmpty {
            parts.append(context.joined(separator: "；"))
        }
        
        return parts.joined(separator: "\n\n")
    }
}

public enum AIPromptError: Error, LocalizedError {
    case polishingFailed(String)
    case invalidInput
    case runtimeUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .polishingFailed(let message):
            return "Prompt 整理失败: \(message)"
        case .invalidInput:
            return "无效的输入"
        case .runtimeUnavailable:
            return "AI Runtime 不可用"
        }
    }
}
