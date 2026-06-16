import Foundation

public struct AgentTraceMetadataItem: Hashable, Sendable {
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

public enum AgentTraceSegment: Hashable, Sendable {
    case paragraph(String)
    case metadata([AgentTraceMetadataItem])
    case bulletList([String])
    case code(language: String?, code: String)
}

public enum AgentTraceRenderer {
    public static func parse(_ text: String) -> [AgentTraceSegment] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var blocks: [String] = []
        var buffer: [String] = []
        var isInsideCodeFence = false

        func flushBuffer() {
            guard buffer.isEmpty == false else { return }
            blocks.append(buffer.joined(separator: "\n"))
            buffer.removeAll(keepingCapacity: true)
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInsideCodeFence {
                    buffer.append(line)
                    flushBuffer()
                    isInsideCodeFence = false
                } else {
                    flushBuffer()
                    buffer.append(line)
                    isInsideCodeFence = true
                }
                continue
            }

            if isInsideCodeFence {
                buffer.append(line)
                continue
            }

            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flushBuffer()
            } else {
                buffer.append(line)
            }
        }

        flushBuffer()

        return blocks.compactMap(parseBlock(_:))
    }

    private static func parseBlock(_ block: String) -> AgentTraceSegment? {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let code = parseCodeBlock(trimmed) {
            return .code(language: code.language, code: code.body)
        }

        if let metadata = parseMetadataBlock(trimmed) {
            return .metadata(metadata)
        }

        if let bullets = parseBulletListBlock(trimmed) {
            return .bulletList(bullets)
        }

        return .paragraph(trimmed)
    }

    private static func parseCodeBlock(_ block: String) -> (language: String?, body: String)? {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2 else { return nil }

        let opening = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let closing = lines.last?.trimmingCharacters(in: .whitespaces) ?? ""
        guard opening.hasPrefix("```"), closing.hasPrefix("```") else { return nil }

        let languageHint = opening.dropFirst(3).trimmingCharacters(in: .whitespaces)
        let language = languageHint.isEmpty ? nil : languageHint
        let bodyLines = lines.dropFirst().dropLast()
        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.isEmpty == false else { return nil }
        return (language, body)
    }

    private static func parseMetadataBlock(_ block: String) -> [AgentTraceMetadataItem]? {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2 else { return nil }

        var items: [AgentTraceMetadataItem] = []
        items.reserveCapacity(lines.count)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.isEmpty == false else { return nil }
            guard let colonIndex = trimmed.firstIndex(of: ":") else { return nil }

            let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces)
            let valueStart = trimmed.index(after: colonIndex)
            let value = trimmed[valueStart...].trimmingCharacters(in: .whitespaces)
            guard key.isEmpty == false else { return nil }
            items.append(AgentTraceMetadataItem(key: key, value: value))
        }

        return items
    }

    private static func parseBulletListBlock(_ block: String) -> [String]? {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2 else { return nil }

        var items: [String] = []
        items.reserveCapacity(lines.count)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.isEmpty == false else { return nil }

            let content: String
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            } else if let dotIndex = trimmed.firstIndex(where: { $0 == "." }),
                      trimmed[..<dotIndex].allSatisfy({ $0.isNumber }) {
                let afterDotIndex = trimmed.index(after: dotIndex)
                guard afterDotIndex < trimmed.endIndex, trimmed[afterDotIndex] == " " else { return nil }
                content = String(trimmed[trimmed.index(after: afterDotIndex)...]).trimmingCharacters(in: .whitespaces)
            } else {
                return nil
            }

            guard content.isEmpty == false else { return nil }
            items.append(content)
        }

        return items
    }
}
