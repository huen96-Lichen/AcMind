import Foundation

public final class ValidationStage: PipelineStage, @unchecked Sendable {
    private var recentHashes: [String] = []
    private let maxRecentHashes = 50
    private var lastPasteHash: String?
    private var lastPasteTimestamp: Date?
    private let pasteEchoWindow: TimeInterval = 10.0

    public init() {}

    public func process(_ context: inout PipelineContext) async throws {
        guard let item = context.item else { return }

        let hash = computeHash(for: item)

        if let lastHash = lastPasteHash,
           let lastTime = lastPasteTimestamp,
           hash == lastHash,
           Date().timeIntervalSince(lastTime) < pasteEchoWindow {
            context.shouldIgnore = true
            return
        }

        if recentHashes.contains(hash) {
            context.shouldIgnore = true
            return
        }

        recentHashes.insert(hash, at: 0)
        if recentHashes.count > maxRecentHashes {
            recentHashes = Array(recentHashes.prefix(maxRecentHashes))
        }
    }

    public func recordPasteHash(_ hash: String) {
        lastPasteHash = hash
        lastPasteTimestamp = Date()
    }

    public func computeHash(for item: ClipboardItem) -> String {
        switch item.type {
        case .image:
            return "img_\(item.content ?? "")"
        case .richText:
            let html = item.htmlContent ?? item.content ?? ""
            return "rt_\(html.prefix(200))"
        case .code:
            let text = item.content ?? ""
            return "code_\(item.codeLanguage ?? "")_\(text.prefix(200))"
        default:
            let content = item.content ?? item.textContent ?? ""
            return "\(item.type.rawValue)_\(content.prefix(100))"
        }
    }

    public func rebuildHashes(from items: [ClipboardItem]) {
        recentHashes = items.map { computeHash(for: $0) }
        if recentHashes.count > maxRecentHashes {
            recentHashes = Array(recentHashes.prefix(maxRecentHashes))
        }
    }

    public func clearHashes() {
        recentHashes.removeAll()
    }
}
