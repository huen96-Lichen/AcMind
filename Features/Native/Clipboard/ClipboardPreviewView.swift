import SwiftUI
import AppKit
import AcMindKit

struct ClipboardPreviewView: View {
    let item: ClipboardItem
    @State private var htmlContent: AttributedString?

    var body: some View {
        Group {
            switch item.type {
            case .richText:
                richTextPreview
            case .code:
                codePreview
            case .image:
                imagePreview
            default:
                textPreview
            }
        }
    }

    private var richTextPreview: some View {
        ScrollView {
            if let htmlContent {
                Text(htmlContent)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                Text(item.textContent ?? "")
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: item.id) {
            await loadHTMLContent()
        }
    }

    private var codePreview: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                if let lang = item.codeLanguage {
                    HStack {
                        Text(lang.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.08))
                }

                Text(item.textContent ?? item.content ?? "")
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .background(AppSurfaceTokens.primaryText.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var imagePreview: some View {
        ClipboardItemThumbnailView(
            item: item,
            size: CGSize(width: 400, height: 300),
            cornerRadius: 8,
            expandToWidth: true
        )
    }

    private var textPreview: some View {
        ScrollView {
            Text(item.textContent ?? item.content ?? "")
                .font(.system(size: 14))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func loadHTMLContent() async {
        guard item.type == .richText, let html = item.htmlContent ?? item.content else { return }
        let attributed = await Task.detached(priority: .userInitiated) {
            guard let data = html.data(using: .utf8) else { return nil }
            return try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
        }.value

        if let attributed {
            await MainActor.run {
                htmlContent = AttributedString(attributed)
            }
        }
    }
}
