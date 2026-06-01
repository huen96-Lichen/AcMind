import AppKit
import AcMindKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - WebDigest Panel
// 网页精读 - 输入 URL，调用 defuddle 提取 Markdown

struct WebDigestPanel: View {
    @StateObject private var viewModel = WebDigestViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    inputCard
                    resultCard
                }
                .padding(20)
            }
        }
        .frame(width: 760, height: 640)
        .background(AppSurfaceTokens.background)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WebDigest｜网页精读")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("输入网页 URL，用 `defuddle parse <url> --md` 抽取正文并生成 Markdown。")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button {
                viewModel.clear()
            } label: {
                Label("清空", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "globe")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("轻量网页精读")
                        .font(.headline)
                    Text("适合把一篇网页文章快速转换为可编辑的 Markdown 草稿。")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            Text("如果本机还没装 `defuddle`，请先运行 `npm install -g defuddle`。")
                .font(.caption)
                .foregroundStyle(Color.secondary)

            HStack(spacing: 8) {
                Label("解析正文", systemImage: "doc.text.magnifyingglass")
                Label("输出 Markdown", systemImage: "square.and.pencil")
                Label("可复制保存", systemImage: "tray.and.arrow.down")
            }
            .font(.caption2)
            .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("URL 输入")
                .font(.headline)

            HStack(spacing: 10) {
                TextField("https://example.com/article", text: $viewModel.urlString)
                    .textFieldStyle(.roundedBorder)

                Button {
                    viewModel.generateMarkdown()
                } label: {
                    if viewModel.isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("生成")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGenerating)
            }

            HStack(spacing: 12) {
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)

                Spacer()

                Button {
                    viewModel.copyMarkdown()
                } label: {
                    Label("复制 Markdown", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.markdown.isEmpty)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Markdown 输出")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.saveMarkdown()
                } label: {
                    Label("保存为 .md", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.markdown.isEmpty)
            }

            TextEditor(text: $viewModel.markdown)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 260)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }
}

@MainActor
final class WebDigestViewModel: ObservableObject {
    @Published var urlString = ""
    @Published var markdown = ""
    @Published var statusText = "等待输入 URL"
    @Published var errorMessage: String?
    @Published var isGenerating = false

    private let runner: ProcessCommandRunning

    init(runner: ProcessCommandRunning = ProcessCommandRunner()) {
        self.runner = runner
    }

    func clear() {
        urlString = ""
        markdown = ""
        statusText = "等待输入 URL"
        errorMessage = nil
        isGenerating = false
    }

    func generateMarkdown() {
        guard let url = normalizeURL(urlString) else {
            errorMessage = "请输入有效的网址，例如 https://example.com"
            statusText = "URL 无效"
            ToastManager.shared.show(.warning, "请输入有效的网址")
            return
        }

        isGenerating = true
        errorMessage = nil
        statusText = "正在调用 defuddle..."
        markdown = ""

        Task {
            do {
                let result = try await runner.run(
                    executablePath: "/usr/bin/env",
                    arguments: ["defuddle", "parse", url.absoluteString, "--md"],
                    environment: nil,
                    currentDirectoryURL: nil
                )

                let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    self.isGenerating = false
                    if output.isEmpty {
                        self.statusText = "完成，但没有提取到正文"
                        self.errorMessage = "defuddle 没有返回可用的 Markdown 内容。"
                        ToastManager.shared.show(.warning, "没有提取到可用正文")
                    } else {
                        self.markdown = output
                        self.statusText = "已生成 Markdown"
                        self.errorMessage = nil
                        ToastManager.shared.show(.success, "网页已转换为 Markdown")
                    }
                }
            } catch {
                let message = friendlyMessage(for: error)
                await MainActor.run {
                    self.isGenerating = false
                    self.statusText = "生成失败"
                    self.errorMessage = message
                    ToastManager.shared.show(.error, message)
                }
            }
        }
    }

    func copyMarkdown() {
        guard markdown.isEmpty == false else {
            ToastManager.shared.show(.warning, "没有可复制的 Markdown")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        ToastManager.shared.show(.success, "Markdown 已复制")
    }

    func saveMarkdown() {
        guard markdown.isEmpty == false else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "content.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
                ToastManager.shared.show(.success, "已保存到 \(url.lastPathComponent)")
            } catch {
                ToastManager.shared.show(.error, "保存失败: \(error.localizedDescription)")
            }
        }
    }

    private func normalizeURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if let url = URL(string: "https://\(trimmed)") {
            return url
        }

        return nil
    }

    private func friendlyMessage(for error: Error) -> String {
        if let sttError = error as? STTError {
            switch sttError {
            case .transcriptionFailed(let message):
                if message.localizedCaseInsensitiveContains("defuddle") ||
                    message.localizedCaseInsensitiveContains("command not found") {
                    return "未找到 defuddle。请先运行 `npm install -g defuddle`。"
                }
                return message
            case .providerNotAvailable(let message):
                return message
            case .apiKeyMissing(let message):
                return message
            case .modelNotDownloaded(let message):
                return message
            }
        }

        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("defuddle") ||
            message.localizedCaseInsensitiveContains("command not found") {
            return "未找到 defuddle。请先运行 `npm install -g defuddle`。"
        }
        return message
    }
}
