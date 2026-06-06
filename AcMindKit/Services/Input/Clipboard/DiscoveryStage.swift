import Foundation
import AppKit

public struct DiscoveryStage: PipelineStage {
    private let assetStore: AssetStore

    public init(assetStore: AssetStore) {
        self.assetStore = assetStore
    }

    public func process(_ context: inout PipelineContext) async throws {
        let raw = context.rawContent

        if let urls = raw.fileURLs, !urls.isEmpty {
            let paths = urls
            let preview = paths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
            context.item = ClipboardItem(
                type: .file,
                content: paths.joined(separator: "\n"),
                textContent: "[文件] \(preview)",
                sourceApp: raw.sourceApp
            )
            return
        }

        if let imageData = raw.imageData {
            let image = NSImage(data: imageData)
            if let image {
                let assetFile = try await assetStore.saveImage(
                    image,
                    fileName: "clipboard_\(raw.timestamp.timeIntervalSince1970).png"
                )
                context.item = ClipboardItem(
                    type: .image,
                    content: assetFile.id,
                    textContent: "[图片] \(assetFile.fileName)",
                    sourceApp: raw.sourceApp
                )
            }
            return
        }

        if let html = raw.htmlContent, !html.isEmpty {
            let plainText = raw.textContent ?? stripHTML(html)
            context.item = ClipboardItem(
                type: .richText,
                content: html,
                textContent: plainText,
                sourceApp: raw.sourceApp,
                htmlContent: html
            )
            return
        }

        if let text = raw.textContent, !text.isEmpty {
            if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                context.item = ClipboardItem(
                    type: .url,
                    content: text,
                    textContent: text,
                    sourceApp: raw.sourceApp
                )
                return
            }

            if let language = detectCodeLanguage(text) {
                context.item = ClipboardItem(
                    type: .code,
                    content: text,
                    textContent: text,
                    sourceApp: raw.sourceApp,
                    codeLanguage: language
                )
                return
            }

            context.item = ClipboardItem(
                type: .text,
                content: text,
                textContent: text,
                sourceApp: raw.sourceApp
            )
            return
        }
    }

    private func stripHTML(_ html: String) -> String {
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
              ) else {
            return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        return attributed.string
    }

    private func detectCodeLanguage(_ text: String) -> String? {
        let lines = text.split(separator: "\n", maxSplits: 50)
        guard lines.count >= 2 else { return nil }

        var score = 0

        if text.contains("func ") || text.contains("import ") || text.contains("let ") || text.contains("var ") {
            if text.contains(": ") || text.contains("-> ") || text.contains("class ") { score += 3 }
        }
        if text.contains("NSPasteboard") || text.contains("SwiftUI") || text.contains("@MainActor") {
            return "swift"
        }

        if text.contains("def ") || text.contains("import ") || text.contains("print(") || text.contains("class ") && text.contains(":") {
            score += 2
        }
        if text.contains("self.") || text.contains("elif ") || text.contains("__init__") {
            return "python"
        }

        if text.contains("const ") || text.contains("let ") || text.contains("=>") || text.contains("function ") {
            score += 2
        }
        if text.contains("import {") || text.contains("export ") || text.contains("interface ") {
            return "javascript"
        }

        if text.contains("fn ") || text.contains("impl ") || text.contains("pub ") || text.contains("let mut ") {
            return "rust"
        }

        if text.hasPrefix("<") && text.contains(">") {
            return "html"
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if text.contains("\"") { return "json" }
        }

        let upper = text.uppercased()
        if upper.contains("SELECT ") || upper.contains("INSERT ") || upper.contains("CREATE TABLE") {
            return "sql"
        }

        if text.hasPrefix("#!/") || text.contains("echo ") || text.contains("export ") && text.contains("$") {
            return "bash"
        }

        let braceCount = text.filter { $0 == "{" || $0 == "}" }.count
        let semicolonCount = text.filter { $0 == ";" }.count
        if braceCount >= 4 || semicolonCount >= 3 {
            if score >= 2 { return "unknown" }
        }

        return nil
    }
}
