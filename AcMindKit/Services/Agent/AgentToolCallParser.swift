import Foundation

// MARK: - AgentToolCallParser

/// 从自然语言中提取可直接执行的 Agent 工具调用。
public struct AgentToolCallRequest: Sendable, Equatable {
    public let toolType: AgentToolType
    public let action: String
    public let parameters: [String: String]

    public init(toolType: AgentToolType, action: String, parameters: [String: String] = [:]) {
        self.toolType = toolType
        self.action = action
        self.parameters = parameters
    }
}

public enum AgentToolCallParser {
    public static func parse(prompt: String) -> AgentToolCallRequest? {
        let lowercased = prompt.lowercased()
        let extractedURL = extractURL(from: prompt)
        let extractedPaths = extractFilePaths(from: prompt)
        let jsonPayload = payload(afterKeyword: "json", in: prompt)
        let base64EncodePayload = payload(afterKeyword: "base64 encode", in: prompt)
        let base64DecodePayload = payload(afterKeyword: "base64 decode", in: prompt)
        let webPayload = payload(afterKeyword: "web", in: prompt)
        let docPayload = payload(afterKeyword: "document", in: prompt) ?? payload(afterKeyword: "convert", in: prompt)
        let ocrPayload = payload(afterKeyword: "ocr", in: prompt)
        let providerPayload = extractProviderIdentifier(from: prompt)
        let identifierPayloads = extractIdentifiers(from: prompt)

        if lowercased.hasPrefix("json") || lowercased.contains("json ") || lowercased.contains("json:") {
            return AgentToolCallRequest(
                toolType: .tools,
                action: "jsonFormatter",
                parameters: ["text": jsonPayload ?? prompt, "pretty": "true"]
            )
        }

        if lowercased.contains("base64") {
            let mode = lowercased.contains("decode") ? "decode" : "encode"
            let payload = base64DecodePayload ?? base64EncodePayload ?? prompt
            return AgentToolCallRequest(
                toolType: .tools,
                action: "base64Codec",
                parameters: ["text": payload, "mode": mode]
            )
        }

        if lowercased.contains("modelmanagement") || lowercased.contains("model management") || lowercased.contains("模型管理") {
            var parameters: [String: String] = [:]
            if let providerPayload, providerPayload.isEmpty == false {
                parameters["providerId"] = providerPayload
            }
            return AgentToolCallRequest(toolType: .tools, action: "modelManagement", parameters: parameters)
        }

        if lowercased.contains("apitest") || lowercased.contains("api test") || lowercased.contains("接口测试") {
            var parameters: [String: String] = [:]
            if let providerPayload, providerPayload.isEmpty == false {
                parameters["providerId"] = providerPayload
            }
            guard parameters["providerId"]?.isEmpty == false else { return nil }
            return AgentToolCallRequest(toolType: .tools, action: "apiTest", parameters: parameters)
        }

        if lowercased.contains("ocr") || lowercased.contains("识别") || lowercased.contains("截图") || lowercased.contains("图片") {
            var parameters: [String: String] = [:]
            if let extractedPath = extractedPaths.first {
                parameters["path"] = extractedPath
            } else if let ocrPayload, ocrPayload.isEmpty == false {
                parameters["path"] = ocrPayload
            }
            if parameters.isEmpty == false {
                return AgentToolCallRequest(toolType: .tools, action: "ocr", parameters: parameters)
            }
        }

        if lowercased.contains("文档") || lowercased.contains("转换") || lowercased.contains("document") || lowercased.contains("convert") || lowercased.contains("pdf") || lowercased.contains("word") || lowercased.contains("md") {
            var parameters: [String: String] = [:]
            if let extractedPath = extractedPaths.first {
                parameters["path"] = extractedPath
            } else if let extractedURL {
                parameters["sourceURL"] = extractedURL
            } else if let docPayload, docPayload.isEmpty == false {
                parameters["sourceURL"] = docPayload
            }
            if parameters.isEmpty == false {
                return AgentToolCallRequest(toolType: .tools, action: "documentConvert", parameters: parameters)
            }
        }

        if lowercased.contains("export") || lowercased.contains("导出") {
            var parameters: [String: String] = [:]
            if let noteId = identifierPayloads.first(where: { $0.hasPrefix("note-") }) {
                parameters["noteId"] = noteId
            }
            if let sourceItemId = identifierPayloads.first(where: { $0.hasPrefix("source-") }) {
                parameters["sourceItemId"] = sourceItemId
            }
            if parameters.isEmpty == false {
                return AgentToolCallRequest(toolType: .export, action: "toObsidian", parameters: parameters)
            }
        }

        if lowercased.contains("batchdownload") || lowercased.contains("batch download") || lowercased.contains("批量下载") {
            guard let url = extractedURL ?? webPayload ?? (prompt.isEmpty ? nil : prompt) else { return nil }
            var parameters: [String: String] = ["url": url]
            if lowercased.contains("preview") || lowercased.contains("预览") {
                parameters["previewOnly"] = "true"
            }
            return AgentToolCallRequest(toolType: .tools, action: "batchDownload", parameters: parameters)
        }

        if lowercased.contains("videodownload") || lowercased.contains("video download") || lowercased.contains("视频下载") || lowercased.contains("下载视频") {
            guard let url = extractedURL ?? webPayload ?? (prompt.isEmpty ? nil : prompt) else { return nil }
            return AgentToolCallRequest(toolType: .tools, action: "videoDownload", parameters: ["url": url])
        }

        if let fileAction = fileOperationRequest(prompt: prompt, lowercased: lowercased, extractedPaths: extractedPaths) {
            return fileAction
        }

        if lowercased.contains("automation") || lowercased.contains("自动化") {
            return AgentToolCallRequest(
                toolType: .ai,
                action: "automationDraft",
                parameters: [
                    "goal": prompt
                ]
            )
        }

        if lowercased.contains("网页") || lowercased.contains("链接") || lowercased.contains("url") || lowercased.contains("http") || lowercased.hasPrefix("web") {
            let url = extractedURL ?? webPayload ?? prompt
            return AgentToolCallRequest(
                toolType: .tools,
                action: "webDigest",
                parameters: ["url": url]
            )
        }

        return nil
    }

    private static func extractURL(from text: String) -> String? {
        let pattern = #"https?://[^\s]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func extractFilePaths(from text: String) -> [String] {
        let pattern = #"(?:(?:[A-Za-z]:)?\/[^ \n\t]+|~\/[^ \n\t]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return String(text[swiftRange]).replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        }
    }

    private static func payload(afterKeyword keyword: String, in text: String) -> String? {
        let lowercased = text.lowercased()
        guard let range = lowercased.range(of: keyword) else { return nil }
        let remainder = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard remainder.isEmpty == false else { return nil }
        return remainder.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractProviderIdentifier(from text: String) -> String? {
        let explicitPattern = #"(?i)\bprovider(?:id)?\b(?:\s*[:=]\s*|\s+)([A-Za-z0-9._-]+)"#
        if let explicit = firstCapture(in: text, pattern: explicitPattern) {
            return explicit
        }

        let loosePattern = #"(?i)\bprovider[-_A-Za-z0-9.]*\b"#
        return firstMatch(in: text, pattern: loosePattern)
    }

    private static func extractIdentifiers(from text: String) -> [String] {
        let pattern = #"(?:note|source)-[A-Za-z0-9._-]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    private static func fileOperationRequest(prompt: String, lowercased: String, extractedPaths: [String]) -> AgentToolCallRequest? {
        let hasFileKeyword = lowercased.contains("文件") || lowercased.contains("file") || lowercased.contains("path") || lowercased.contains("目录")
        guard hasFileKeyword || extractedPaths.isEmpty == false else { return nil }

        if lowercased.contains("rename") || lowercased.contains("重命名") {
            guard let source = extractedPaths.first else { return nil }
            let targetName = payload(afterAnyKeyword: ["为", "to", "="], in: prompt)
            var parameters: [String: String] = ["path": source]
            if let targetName, targetName.isEmpty == false {
                parameters["newName"] = sanitizeRenameTarget(targetName)
            }
            guard parameters["newName"]?.isEmpty == false else { return nil }
            return AgentToolCallRequest(toolType: .file, action: "rename", parameters: parameters)
        }

        if lowercased.contains("copy") || lowercased.contains("复制") {
            guard let source = extractedPaths.first else { return nil }
            let destination = extractedPaths.dropFirst().first ?? payload(afterAnyKeyword: ["copy to", "to", "到"], in: prompt)
            guard let destination, destination.isEmpty == false else { return nil }
            return AgentToolCallRequest(toolType: .file, action: "copy", parameters: [
                "path": source,
                "destinationPath": destination
            ])
        }

        if lowercased.contains("move") || lowercased.contains("移动") {
            guard let source = extractedPaths.first else { return nil }
            let destination = extractedPaths.dropFirst().first ?? payload(afterAnyKeyword: ["move to", "to", "到"], in: prompt)
            guard let destination, destination.isEmpty == false else { return nil }
            return AgentToolCallRequest(toolType: .file, action: "move", parameters: [
                "path": source,
                "destinationPath": destination
            ])
        }

        if lowercased.contains("open") || lowercased.contains("打开") {
            guard let source = extractedPaths.first else { return nil }
            return AgentToolCallRequest(toolType: .file, action: "open", parameters: ["path": source])
        }

        if lowercased.contains("reveal") || lowercased.contains("显示") || lowercased.contains("在访达") || lowercased.contains("访达中显示") {
            guard let source = extractedPaths.first else { return nil }
            return AgentToolCallRequest(toolType: .file, action: "reveal", parameters: ["path": source])
        }

        if lowercased.contains("delete") || lowercased.contains("删除") {
            guard let source = extractedPaths.first else { return nil }
            return AgentToolCallRequest(toolType: .file, action: "delete", parameters: ["path": source])
        }

        if lowercased.contains("info") || lowercased.contains("详情") || lowercased.contains("检查") || lowercased.contains("查看") {
            guard let source = extractedPaths.first else { return nil }
            return AgentToolCallRequest(toolType: .file, action: "info", parameters: ["path": source])
        }

        if lowercased.contains("list") || lowercased.contains("列出") || lowercased.contains("目录") {
            guard let source = extractedPaths.first else { return nil }
            return AgentToolCallRequest(toolType: .file, action: "list", parameters: ["path": source])
        }

        return nil
    }

    private static func payload(afterAnyKeyword keywords: [String], in text: String) -> String? {
        for keyword in keywords {
            if let payload = payload(afterKeyword: keyword, in: text) {
                return payload
            }
        }
        return nil
    }

    private static func sanitizeRenameTarget(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":=，。"))
            .trimmingCharacters(in: CharacterSet(charactersIn: "为"))
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[swiftRange])
    }
}
