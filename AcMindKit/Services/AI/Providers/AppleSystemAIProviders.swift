import Foundation

public struct AppleVisionOCRProvider: AIModelProvider {
    public let id = "apple.vision.ocr"
    public let displayName = "Apple Vision OCR"
    public let capabilities: [AICapability] = [.imageOCR, .local]

    public init() {}

    public func run(_ request: AIRequest) async throws -> AIResponse {
        guard request.taskType == .imageOCR else {
            throw AIError.invalidInput("Apple Vision OCR 只能处理 imageOCR 任务")
        }

        let result: OCRResult
        if let fileURL = request.fileURL {
            result = try await VisionOCR.recognizeText(in: fileURL)
        } else {
            throw AIError.invalidInput("imageOCR 任务缺少图片 fileURL")
        }

        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AIError.invalidResponse
        }

        return AIResponse(
            requestId: request.id,
            providerId: id,
            taskType: request.taskType,
            outputType: .rawOCR,
            text: text,
            confidence: averageConfidence(result.blocks),
            metadata: request.metadata
        )
    }

    private func averageConfidence(_ blocks: [OCRTextBlock]) -> Double? {
        guard !blocks.isEmpty else { return nil }
        let total = blocks.reduce(Float(0)) { $0 + $1.confidence }
        return Double(total / Float(blocks.count))
    }
}

public struct AppleSpeechProvider: AIModelProvider {
    public let id = "apple.speech"
    public let displayName = "Apple Speech"
    public let capabilities: [AICapability] = [.speechToText, .local]

    private let locale: Locale

    public init(locale: Locale = Locale(identifier: "zh-CN")) {
        self.locale = locale
    }

    public func run(_ request: AIRequest) async throws -> AIResponse {
        guard request.taskType == .speechToText else {
            throw AIError.invalidInput("Apple Speech 只能处理 speechToText 任务")
        }

        guard let fileURL = request.fileURL else {
            throw AIError.invalidInput("speechToText 任务缺少音频 fileURL")
        }

        let transcriber = AppleSpeechTranscriber(locale: locale)
        let transcript = try await transcriber.transcribe(audioFile: AudioFile(url: fileURL))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !transcript.isEmpty else {
            throw AIError.invalidResponse
        }

        return AIResponse(
            requestId: request.id,
            providerId: id,
            taskType: request.taskType,
            outputType: .rawTranscript,
            text: transcript,
            confidence: nil,
            metadata: request.metadata
        )
    }
}

public struct RuleBasedCleanupProvider: AIModelProvider {
    public let id = "local.rule.cleanup"
    public let displayName = "本地规则清洗"
    public let capabilities: [AICapability] = [
        .textCleanup,
        .summarization,
        .classification,
        .titleGeneration,
        .tagGeneration,
        .todoExtraction,
        .dailyReview,
        .local
    ]

    public init() {}

    public func run(_ request: AIRequest) async throws -> AIResponse {
        let text = (request.inputText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AIError.invalidInput("本地清洗任务缺少文本")
        }

        let category = classify(text: text, metadata: request.metadata)
        let title = generateTitle(from: text, category: category)
        let summary = summarize(text)
        let tags = generateTags(text: text, category: category)
        let markdown = buildMarkdown(
            title: title,
            summary: summary,
            category: category,
            tags: tags,
            originalText: text,
            taskType: request.taskType
        )

        let outputType = AcMindOutputType(rawValue: request.metadata[AIMetadataKey.outputType] ?? "")
            ?? (category == .task ? .todo : .markdownNote)

        return AIResponse(
            requestId: request.id,
            providerId: id,
            taskType: request.taskType,
            outputType: outputType,
            text: summary,
            markdown: markdown,
            title: title,
            summary: summary,
            category: category,
            tags: tags,
            confidence: 0.65,
            metadata: request.metadata
        )
    }

    public func classify(text: String, metadata: [String: String] = [:]) -> InboxCategory {
        if let value = metadata[AIMetadataKey.inboxCategory],
           let category = InboxCategory(rawValue: value) {
            return category
        }

        let lowercased = text.lowercased()
        if lowercased.contains("http://") || lowercased.contains("https://") {
            return .link
        }

        let taskKeywords = ["todo", "待办", "提醒", "记得", "需要", "明天", "deadline", "完成"]
        if taskKeywords.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .task
        }

        let diaryKeywords = ["今天", "心情", "复盘", "感受", "日记"]
        if diaryKeywords.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .diary
        }

        let referenceKeywords = ["资料", "论文", "文档", "截图", "摘录", "概念", "定义"]
        if referenceKeywords.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .reference
        }

        if text.count < 12 {
            return .needsConfirmation
        }

        return .idea
    }

    private func generateTitle(from text: String, category: InboxCategory) -> String {
        let firstLine = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? category.displayName

        let trimmed = firstLine.replacingOccurrences(of: "#", with: "")
        if trimmed.count <= 36 {
            return trimmed
        }
        return String(trimmed.prefix(36)) + "..."
    }

    private func summarize(_ text: String) -> String {
        let normalized = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if normalized.count <= 140 {
            return normalized
        }
        return String(normalized.prefix(140)) + "..."
    }

    private func generateTags(text: String, category: InboxCategory) -> [String] {
        var tags = ["AcMind", category.displayName]
        let keywordPairs: [(String, String)] = [
            ("swift", "Swift"),
            ("macos", "macOS"),
            ("ai", "AI"),
            ("模型", "模型"),
            ("日报", "日报"),
            ("会议", "会议"),
            ("Obsidian", "Obsidian")
        ]

        for (needle, tag) in keywordPairs where text.localizedCaseInsensitiveContains(needle) {
            tags.append(tag)
        }

        let uniqueTags = Array(NSOrderedSet(array: tags).compactMap { $0 as? String })
        return Array(uniqueTags.prefix(5))
    }

    private func buildMarkdown(
        title: String,
        summary: String,
        category: InboxCategory,
        tags: [String],
        originalText: String,
        taskType: AITaskType
    ) -> String {
        var parts: [String] = []
        parts.append("## 摘要\n\n\(summary)")
        parts.append("## 分类\n\n\(category.displayName)")

        if category == .task {
            parts.append("## 待办\n\n- [ ] \(summary)")
        }

        parts.append("## 标签\n\n\(tags.map { "#\($0)" }.joined(separator: " "))")
        parts.append("## 原文\n\n\(originalText)")
        parts.append("> 本条内容由 \(displayName) 处理，任务类型：\(taskType.rawValue)。")

        return "# \(title)\n\n" + parts.joined(separator: "\n\n")
    }
}
