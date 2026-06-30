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
                VStack(alignment: .leading, spacing: 12) {
                    AppSurfaceCard(title: "轻量网页精读", subtitle: "解析正文并生成文稿初稿", padding: 16) {
                        introCard
                    }
                    AppSurfaceCard(title: "URL 输入", subtitle: "输入网页地址后直接生成", padding: 16) {
                        inputCard
                    }
                    AppSurfaceCard(title: "Markdown 输出", subtitle: "可编辑、可复制、可保存", padding: 16) {
                        resultCard
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 760, height: 640)
        .background(AppVisualBackdrop())
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("网页精读")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("输入网页地址，用 `defuddle parse <url> --md` 抽取正文并生成文稿。")
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
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
            Text("本机未安装 `defuddle` 时，请先运行 `npm install -g defuddle`。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            HStack(spacing: 8) {
                Label("解析正文", systemImage: "doc.text.magnifyingglass")
                Label("输出文稿", systemImage: "square.and.pencil")
                Label("可复制保存", systemImage: "tray.and.arrow.down")
            }
            .font(.caption2)
            .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Spacer()

                Button {
                    viewModel.copyMarkdown()
                } label: {
                    Label("复制文稿", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.markdown.isEmpty)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()

                Button {
                    viewModel.openSavedMarkdown()
                } label: {
                    Label("打开文件", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.lastSavedURL == nil)

                Button {
                    viewModel.saveMarkdown()
                } label: {
                    Label("保存为文稿", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.markdown.isEmpty)
            }

            AppSurfaceTextEditorShell(text: $viewModel.markdown, minHeight: 260)
        }
    }
}

@MainActor
final class WebDigestViewModel: ObservableObject {
    @Published var urlString = ""
    @Published var markdown = ""
    @Published var statusText = ToolStatusLabelFormatter.waitingToInput("URL")
    @Published var errorMessage: String?
    @Published var isGenerating = false
    @Published var lastSavedURL: URL?

    private let runner: ProcessCommandRunning

    init(runner: ProcessCommandRunning = ProcessCommandRunner()) {
        self.runner = runner
    }

    func clear() {
        urlString = ""
        markdown = ""
        statusText = ToolStatusLabelFormatter.waitingToInput("URL")
        errorMessage = nil
        isGenerating = false
        lastSavedURL = nil
    }

    func generateMarkdown() {
        guard let url = normalizeURL(urlString) else {
            errorMessage = "请输入有效的网址，例如 https://example.com"
            statusText = ToolStatusLabelFormatter.failed("解析网页地址")
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.invalidInput("网址"))
            return
        }

        isGenerating = true
        errorMessage = nil
        statusText = ToolStatusLabelFormatter.running("调用 defuddle")
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
                        self.statusText = ToolStatusLabelFormatter.completed("提取正文")
                        self.errorMessage = "defuddle 没有返回可用的正文内容。"
                        ToastManager.shared.show(.warning, ToolStatusLabelFormatter.noContentAvailable("正文"))
                    } else {
                        self.markdown = output
                        self.statusText = ToolStatusLabelFormatter.completed("生成 Markdown")
                        self.errorMessage = nil
                        ToastManager.shared.show(.success, ToolStatusLabelFormatter.convertedToMarkdown("网页"))
                    }
                }
            } catch {
                let message = friendlyMessage(for: error)
                await MainActor.run {
                    self.isGenerating = false
                    self.statusText = ToolStatusLabelFormatter.failed("生成")
                    self.errorMessage = message
                    ToastManager.shared.show(.error, message)
                }
            }
        }
    }

    func copyMarkdown() {
        guard markdown.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.nothingToCopy("Markdown"))
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.copiedMarkdown())
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
                lastSavedURL = url
                ToastManager.shared.show(.success, ToolStatusLabelFormatter.savedTo(url.lastPathComponent))
            } catch {
                ToastManager.shared.show(.error, ToolStatusLabelFormatter.saveFailed(error.localizedDescription))
            }
        }
    }

    func openSavedMarkdown() {
        guard let lastSavedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastSavedURL])
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
                    return "未找到 defuddle，请先运行 `npm install -g defuddle`。"
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
            return "未找到 defuddle，请先运行 `npm install -g defuddle`。"
        }
        return message
    }
}
