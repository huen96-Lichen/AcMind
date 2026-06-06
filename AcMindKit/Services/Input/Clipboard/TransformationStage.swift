import Foundation

public enum ClipboardCleaningDecision: Sendable {
    case ignore
    case clean(String)
    case pass
}

public struct TransformationStage: PipelineStage {
    private static let phonePattern = try? NSRegularExpression(pattern: "1[3-9]\\d{9}")
    private static let idCardPattern = try? NSRegularExpression(pattern: "\\d{17}[\\dXx]")
    private static let emailPattern = try? NSRegularExpression(pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")

    private let cleaningRulesEvaluator: (@Sendable (String, String?) -> ClipboardCleaningDecision)?

    public init(cleaningRulesEvaluator: (@Sendable (String, String?) -> ClipboardCleaningDecision)? = nil) {
        self.cleaningRulesEvaluator = cleaningRulesEvaluator
    }

    public func process(_ context: inout PipelineContext) async throws {
        guard var item = context.item else { return }

        if let cleaningRulesEvaluator {
            let text = item.textContent ?? item.content ?? ""
            let result = cleaningRulesEvaluator(text, item.sourceApp)

            switch result {
            case .ignore:
                context.shouldIgnore = true
                return
            case .clean(let cleanedText):
                item.textContent = cleanedText
                if item.type == .text || item.type == .url {
                    item.content = cleanedText
                }
            case .pass:
                break
            }
        }

        let text = item.textContent ?? item.content ?? ""

        let isSensitive = Self.containsSensitiveInfo(text)
        item.isSensitive = isSensitive

        if item.type == .image, let content = item.content {
            item.visualHash = "img_\(content.prefix(32))"
        }

        if let html = item.htmlContent {
            let combined = (text + html)
            item.visualHash = "rt_\(combined.hashValue)"
        }

        context.item = item
    }

    private static func containsSensitiveInfo(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)

        if let phonePattern, phonePattern.firstMatch(in: text, range: range) != nil { return true }
        if let idCardPattern, idCardPattern.firstMatch(in: text, range: range) != nil { return true }
        if let emailPattern, emailPattern.firstMatch(in: text, range: range) != nil { return true }

        return false
    }
}
