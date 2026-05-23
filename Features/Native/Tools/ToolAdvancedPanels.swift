import AppKit
import AcMindKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Generic Shell Runner

struct ShellCommandResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}


enum ToolShellError: LocalizedError {
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(message):
            return message
        }
    }
}

enum ToolShellRunner {
    static func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) async throws -> ShellCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            if let environment {
                var merged = ProcessInfo.processInfo.environment
                environment.forEach { merged[$0.key] = $0.value }
                process.environment = merged
            }
            if let currentDirectoryURL {
                process.currentDirectoryURL = currentDirectoryURL
            }

            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let stdoutData = OutputBuffer()
            let stderrData = OutputBuffer()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                stdoutData.append(handle.availableData)
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                stderrData.append(handle.availableData)
            }

            process.terminationHandler = { process in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                stdoutData.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                stderrData.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

                continuation.resume(
                    returning: ShellCommandResult(
                        stdout: String(decoding: stdoutData.snapshot(), as: UTF8.self),
                        stderr: String(decoding: stderrData.snapshot(), as: UTF8.self),
                        exitCode: process.terminationStatus
                    )
                )
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: ToolShellError.launchFailed(error.localizedDescription))
            }
        }
    }

    private final class OutputBuffer: @unchecked Sendable {
        private var data = Data()
        private let lock = NSLock()

        func append(_ chunk: Data) {
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }

        func snapshot() -> Data {
            lock.lock()
            let snapshot = data
            lock.unlock()
            return snapshot
        }
    }
}

// MARK: - Document Converter

struct DocumentConverterPanel: View {
    @StateObject private var viewModel: DocumentConverterViewModel

    init(toastManager: ToastManager) {
        self._viewModel = StateObject(wrappedValue: DocumentConverterViewModel(toastManager: toastManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    sourceCard
                    outputCard
                }
                .padding(20)
            }
        }
        .frame(width: 900, height: 760)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("文档转换")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("把 PDF、Word、网页导出文档和 Markdown 文件转换成可编辑的 Markdown。")
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
            Text("优先尝试 `markitdown`，如果本机没有装，就退回到本地解析。")
                .font(.body)

            Text("PDF 会用 PDFKit 抽取文本，DOCX / DOC / RTF / HTML 会优先用 `textutil`，Markdown 和纯文本直接读取。")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("源文件")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.pickFile()
                } label: {
                    Label("选择文件", systemImage: "doc")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.convert()
                } label: {
                    Text(viewModel.isConverting ? "处理中..." : "转换为 Markdown")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isConverting || viewModel.sourceURL == nil)
            }

            if let sourceURL = viewModel.sourceURL {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceURL.lastPathComponent)
                        .font(.headline)
                    Text(sourceURL.path)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text("还没有选择文档。")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
            }

            HStack(spacing: 12) {
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)

                Spacer()

                Text(viewModel.engineLabel)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(999)
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
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Markdown 输出")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.copyOutput()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.outputMarkdown.isEmpty)

                Button {
                    viewModel.saveOutput()
                } label: {
                    Label("保存为 .md", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.outputMarkdown.isEmpty)
            }

            TextEditor(text: $viewModel.outputMarkdown)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 360)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

@MainActor
final class DocumentConverterViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var outputMarkdown = ""
    @Published var statusText = "请选择一个文档"
    @Published var errorMessage: String?
    @Published var engineLabel = "waiting"
    @Published var isConverting = false
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

    func clear() {
        sourceURL = nil
        outputMarkdown = ""
        statusText = "请选择一个文档"
        errorMessage = nil
        engineLabel = "waiting"
        isConverting = false
    }

    func pickFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .pdf,
            UTType(filenameExtension: "doc"),
            UTType(filenameExtension: "docx"),
            .rtf,
            UTType(filenameExtension: "html"),
            UTType(filenameExtension: "htm"),
            .plainText,
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "odt"),
            UTType(filenameExtension: "pptx")
        ].compactMap { $0 }

        if panel.runModal() == .OK {
            sourceURL = panel.url
            outputMarkdown = ""
            errorMessage = nil
            statusText = "已选择文件，等待转换"
            engineLabel = "ready"
        }
    }

    func convert() {
        guard let sourceURL else {
            toastManager.show(.warning, "请选择要转换的文档")
            return
        }

        isConverting = true
        errorMessage = nil
        statusText = "正在转换..."
        outputMarkdown = ""
        engineLabel = "running"

        Task {
            do {
                let result = try await DocumentConversionSupport.convert(sourceURL: sourceURL)
                await MainActor.run {
                    self.outputMarkdown = result.markdown
                    self.statusText = "已转换为 Markdown"
                    self.engineLabel = result.engine
                    self.isConverting = false
                    toastManager.show(.success, "文档已转换为 Markdown")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = "转换失败"
                    self.engineLabel = "error"
                    self.isConverting = false
                    toastManager.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func copyOutput() {
        guard outputMarkdown.isEmpty == false else {
            toastManager.show(.warning, "没有可复制的 Markdown")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputMarkdown, forType: .string)
        toastManager.show(.success, "Markdown 已复制")
    }

    func saveOutput() {
        guard outputMarkdown.isEmpty == false else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = (sourceURL?.deletingPathExtension().lastPathComponent ?? "document") + ".md"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try outputMarkdown.write(to: url, atomically: true, encoding: .utf8)
                toastManager.show(.success, "已保存到 \(url.lastPathComponent)")
            } catch {
                toastManager.show(.error, "保存失败: \(error.localizedDescription)")
            }
        }
    }
}

struct DocumentConversionResult {
    let markdown: String
    let title: String
    let engine: String
}

enum DocumentConversionSupport {
    static func convert(sourceURL: URL) async throws -> DocumentConversionResult {
        let ext = sourceURL.pathExtension.lowercased()

        if ext == "md" || ext == "markdown" || ext == "txt" {
            return try convertPlainTextFile(sourceURL: sourceURL)
        }

        if let markitdown = try? await convertWithMarkItDown(sourceURL: sourceURL), !markitdown.markdown.isEmpty {
            return markitdown
        }

        switch ext {
        case "pdf":
            return try convertPDF(sourceURL: sourceURL)
        case "doc", "docx", "rtf", "html", "htm", "odt", "pptx":
            return try await convertWithTextUtil(sourceURL: sourceURL)
        default:
            throw ToolShellError.launchFailed("不支持的文件格式: \(ext)")
        }
    }

    private static func convertPlainTextFile(sourceURL: URL) throws -> DocumentConversionResult {
        let content = try String(contentsOf: sourceURL, encoding: .utf8)
        guard content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw ToolShellError.launchFailed("文件内容为空")
        }

        if sourceURL.pathExtension.lowercased() == "md" || sourceURL.pathExtension.lowercased() == "markdown" {
            return DocumentConversionResult(
                markdown: content,
                title: titleFromContent(content) ?? sourceURL.deletingPathExtension().lastPathComponent,
                engine: "local-markdown"
            )
        }

        let title = sourceURL.deletingPathExtension().lastPathComponent
        return DocumentConversionResult(
            markdown: "# \(title)\n\n\(content.trimmingCharacters(in: .whitespacesAndNewlines))",
            title: title,
            engine: "local-text"
        )
    }

    private static func convertPDF(sourceURL: URL) throws -> DocumentConversionResult {
        guard let document = PDFDocument(url: sourceURL) else {
            throw ToolShellError.launchFailed("无法打开 PDF")
        }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            if let page = document.page(at: index), let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false {
                pages.append(text)
            }
        }

        guard pages.isEmpty == false else {
            throw ToolShellError.launchFailed("PDF 中没有可提取的文本")
        }

        let rawTitle = (document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = rawTitle.flatMap { $0.isEmpty ? nil : $0 } ?? sourceURL.deletingPathExtension().lastPathComponent
        let markdown = "# \(title)\n\n" + pages.joined(separator: "\n\n---\n\n")
        return DocumentConversionResult(markdown: markdown, title: title, engine: "pdfkit")
    }

    private static func convertWithTextUtil(sourceURL: URL) async throws -> DocumentConversionResult {
        let result = try await ToolShellRunner.run(
            executablePath: "/usr/bin/textutil",
            arguments: ["-convert", "txt", "-stdout", sourceURL.path]
        )

        let text = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.exitCode == 0, text.isEmpty == false else {
            throw ToolShellError.launchFailed(result.stderr.isEmpty ? "textutil 转换失败" : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let title = sourceURL.deletingPathExtension().lastPathComponent
        return DocumentConversionResult(markdown: "# \(title)\n\n\(text)", title: title, engine: "textutil")
    }

    private static func convertWithMarkItDown(sourceURL: URL) async throws -> DocumentConversionResult {
        let result = try await ToolShellRunner.run(
            executablePath: "/usr/bin/env",
            arguments: ["markitdown", sourceURL.path]
        )

        let text = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.exitCode == 0, text.isEmpty == false else {
            throw ToolShellError.launchFailed(result.stderr.isEmpty ? "markitdown 失败" : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let title = titleFromContent(text) ?? sourceURL.deletingPathExtension().lastPathComponent
        return DocumentConversionResult(markdown: text, title: title, engine: "markitdown")
    }

    private static func titleFromContent(_ content: String) -> String? {
        if let match = content.range(of: #"(?m)^#\s+.+$"#, options: .regularExpression) {
            let line = String(content[match]).trimmingCharacters(in: .whitespacesAndNewlines)
            return line.hasPrefix("# ") ? String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines) : line
        }

        return content
            .components(separatedBy: .newlines)
            .first(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false })?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
