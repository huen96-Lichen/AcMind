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
                var merged = Foundation.ProcessInfo.processInfo.environment
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
    @StateObject private var viewModel = DocumentConverterViewModel()

    var body: some View {
        ZStack {
            AppVisualBackdrop()

            VStack(spacing: 0) {
                header

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSurfaceCard(title: "转换流程", subtitle: "先给出解析策略，再进入文件与结果", padding: 16) {
                            introCard
                        }

                        AppSurfaceCard(title: "源文件", subtitle: "选择文档并触发转换", padding: 16) {
                            sourceCard
                        }

                        AppSurfaceCard(title: "Markdown 输出", subtitle: "可复制、可保存、可回看", padding: 16) {
                            outputCard
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 900, height: 760)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("文档转换")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("把 PDF、Word、网页导出文档和 Markdown 文件转换成可编辑的 Markdown。")
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
            Text("优先尝试 `markitdown`，如果本机没有装，就退回到本地解析。")
                .font(.body)

            Text("PDF 会用 PDFKit 抽取文本，DOCX / DOC / RTF / HTML 会优先用 `textutil`，Markdown 和纯文本直接读取。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
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
                    Text(viewModel.isConverting ? ToolStatusLabelFormatter.processingText : "转换为 Markdown")
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
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .textSelection(.enabled)
                }
            } else {
                Text("还没有选择文档。")
                    .font(.body)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            HStack(spacing: 12) {
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Spacer()

                Text(viewModel.engineLabel)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppSurfaceTokens.secondaryText.opacity(0.12))
                    .cornerRadius(999)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

                Button {
                    viewModel.openSavedOutput()
                } label: {
                    Label("打开文件", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.lastSavedURL == nil)
            }

            AppSurfaceTextEditorShell(text: $viewModel.outputMarkdown, minHeight: 360)
        }
    }
}

@MainActor
final class DocumentConverterViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var outputMarkdown = ""
    @Published var statusText = ToolStatusLabelFormatter.promptToSelect("文档")
    @Published var errorMessage: String?
    @Published var engineLabel = "waiting"
    @Published var isConverting = false
    @Published var lastSavedURL: URL?

    func clear() {
        sourceURL = nil
        outputMarkdown = ""
        statusText = ToolStatusLabelFormatter.promptToSelect("文档")
        errorMessage = nil
        engineLabel = "waiting"
        isConverting = false
        lastSavedURL = nil
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
            statusText = ToolStatusLabelFormatter.selectedWaiting("文件", waitingFor: "转换")
            engineLabel = "ready"
        }
    }

        func convert() {
        guard let sourceURL else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.promptToSelect("文档"))
            return
        }

        isConverting = true
        errorMessage = nil
        statusText = ToolStatusLabelFormatter.running("转换")
        outputMarkdown = ""
        engineLabel = "running"

        Task {
            do {
                let result = try await DocumentConversionSupport.convert(sourceURL: sourceURL)
                await MainActor.run {
                    self.outputMarkdown = result.markdown
                    self.statusText = ToolStatusLabelFormatter.completed("转换为 Markdown")
                    self.engineLabel = result.engine
                    self.isConverting = false
                    ToastManager.shared.show(.success, ToolStatusLabelFormatter.convertedToMarkdown("文档"))
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = ToolStatusLabelFormatter.failed("转换")
                    self.engineLabel = "error"
                    self.isConverting = false
                    ToastManager.shared.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func copyOutput() {
        guard outputMarkdown.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.nothingToCopy("Markdown"))
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputMarkdown, forType: .string)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.copiedMarkdown())
    }

    func saveOutput() {
        guard outputMarkdown.isEmpty == false else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = (sourceURL?.deletingPathExtension().lastPathComponent ?? "document") + ".md"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try outputMarkdown.write(to: url, atomically: true, encoding: .utf8)
                lastSavedURL = url
                ToastManager.shared.show(.success, ToolStatusLabelFormatter.savedTo(url.lastPathComponent))
            } catch {
                ToastManager.shared.show(.error, ToolStatusLabelFormatter.saveFailed(error.localizedDescription))
            }
        }
    }

    func openSavedOutput() {
        guard let lastSavedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastSavedURL])
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

// MARK: - OCR Panel

struct OCRPanel: View {
    @StateObject private var viewModel = OCRViewModel()

    var body: some View {
        ZStack {
            AppVisualBackdrop()

            VStack(spacing: 0) {
                header

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSurfaceCard(title: "识别流程", subtitle: "支持文件和剪贴板输入", padding: 16) {
                            introCard
                        }

                        AppSurfaceCard(title: "图片来源", subtitle: "从文件或剪贴板读取", padding: 16) {
                            sourceCard
                        }

                        AppSurfaceCard(title: "识别结果", subtitle: "可编辑、可复制、可保存", padding: 16) {
                            outputCard
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 900, height: 760)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("OCR 识别")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("从图片中提取文字，支持文件和剪贴板图片。")
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
            Text("直接调用本机 Vision OCR。")
                .font(.body)

            Text("如果你已经把截图放进剪贴板，也可以直接从剪贴板识别。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("图片来源")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.pickImage()
                } label: {
                    Label("选择图片", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.recognizeFromClipboard()
                } label: {
                    Label("剪贴板识别", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.recognize()
                } label: {
                    Text(viewModel.isWorking ? ToolStatusLabelFormatter.processingText : "开始识别")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isWorking || viewModel.sourceURL == nil)
            }

            if let sourceURL = viewModel.sourceURL {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceURL.lastPathComponent)
                        .font(.headline)
                    Text(sourceURL.path)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .textSelection(.enabled)
                }
            } else {
                Text("还没有选择图片。")
                    .font(.body)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别结果")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.copyOutput()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.outputText.isEmpty)

                Button {
                    viewModel.saveOutput()
                } label: {
                    Label("保存结果", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.outputText.isEmpty)

                Button {
                    viewModel.openSavedOutput()
                } label: {
                    Label("打开文件", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.lastSavedURL == nil)
            }

            AppSurfaceTextEditorShell(text: $viewModel.outputText, minHeight: 380)
        }
    }
}

@MainActor
final class OCRViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var outputText = ""
    @Published var statusText = ToolStatusLabelFormatter.promptToSelect("图片或从剪贴板识别")
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var lastSavedURL: URL?

    func clear() {
        sourceURL = nil
        outputText = ""
        statusText = ToolStatusLabelFormatter.promptToSelect("图片或从剪贴板识别")
        errorMessage = nil
        isWorking = false
        lastSavedURL = nil
    }

    func pickImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ImageProcessingSupport.supportedImageContentTypes

        if panel.runModal() == .OK {
            sourceURL = panel.url
            outputText = ""
            errorMessage = nil
            statusText = ToolStatusLabelFormatter.selectedWaiting("图片", waitingFor: "识别")
            lastSavedURL = nil
        }
    }

    func recognizeFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.noClipboardImage())
            return
        }

        sourceURL = nil
        outputText = ""
        errorMessage = nil
        statusText = ToolStatusLabelFormatter.running("识别剪贴板图片")
        isWorking = true
        lastSavedURL = nil

        Task {
            do {
                let result = try await VisionOCR.recognizeText(in: image.tiffRepresentation ?? Data())
                await MainActor.run {
                    self.outputText = result.text
                    self.statusText = "\(ToolStatusLabelFormatter.completed("识别"))，共 \(result.blocks.count) 个文本块"
                    self.isWorking = false
                    ToastManager.shared.show(.success, ToolStatusLabelFormatter.ocrCompleted())
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = ToolStatusLabelFormatter.failed("识别")
                    self.isWorking = false
                    ToastManager.shared.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func recognize() {
        guard let sourceURL else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.chooseImage())
            return
        }

        isWorking = true
        errorMessage = nil
        outputText = ""
        statusText = ToolStatusLabelFormatter.running("识别")
        lastSavedURL = nil

        Task {
            do {
                let result = try await VisionOCR.recognizeText(inFileAtPath: sourceURL.path)
                await MainActor.run {
                    self.outputText = result.text
                    self.statusText = "\(ToolStatusLabelFormatter.completed("识别"))，共 \(result.blocks.count) 个文本块"
                    self.isWorking = false
                    ToastManager.shared.show(.success, ToolStatusLabelFormatter.ocrCompleted())
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = ToolStatusLabelFormatter.failed("识别")
                    self.isWorking = false
                    ToastManager.shared.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func copyOutput() {
        guard outputText.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.noRecognizedResults())
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.recognizedResultsCopied())
    }

    func saveOutput() {
        guard outputText.isEmpty == false else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "txt") ?? .plainText]
        panel.nameFieldStringValue = "ocr-result.txt"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try outputText.write(to: url, atomically: true, encoding: .utf8)
                lastSavedURL = url
                ToastManager.shared.show(.success, ToolStatusLabelFormatter.recognizedResultsSaved())
            } catch {
                ToastManager.shared.show(.error, ToolStatusLabelFormatter.saveFailed(error.localizedDescription))
            }
        }
    }

    func openSavedOutput() {
        guard let lastSavedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastSavedURL])
    }
}

// MARK: - Image Processing

struct ImageProcessingPanel: View {
    @StateObject private var viewModel = ImageProcessingViewModel()

    var body: some View {
        ZStack {
            AppVisualBackdrop()

            VStack(spacing: 0) {
                header

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSurfaceCard(title: "处理流程", subtitle: "先确认输入，再选择输出形式", padding: 16) {
                            introCard
                        }

                        AppSurfaceCard(title: "源图片", subtitle: "选择本地图片或导入剪贴板", padding: 16) {
                            sourceCard
                        }

                        AppSurfaceCard(title: "转换参数", subtitle: "控制尺寸、质量与格式", padding: 16) {
                            optionsCard
                        }

                        AppSurfaceCard(title: "输出结果", subtitle: "结果可直接查看和打开", padding: 16) {
                            outputCard
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 920, height: 820)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("图片处理")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("压缩、缩放和格式转换。")
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
            Text("支持 PNG、JPEG、TIFF 之间的转换。")
                .font(.body)

            Text("可以设置最大边长和 JPEG 压缩质量，适合先把大图压一遍再导出。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("源图片")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.pickImage()
                } label: {
                    Label("选择图片", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.loadFromClipboard()
                } label: {
                    Label("从剪贴板导入", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
            }

            if let sourceURL = viewModel.sourceURL {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceURL.lastPathComponent)
                        .font(.headline)
                    Text(sourceURL.path)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .textSelection(.enabled)
                }
            } else if let clipboardInfo = viewModel.clipboardInfo {
                Text(clipboardInfo)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            } else {
                Text("还没有选择图片。")
                    .font(.body)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("转换参数")
                .font(.headline)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("输出格式")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    Picker("输出格式", selection: $viewModel.outputFormat) {
                        ForEach(ImageOutputFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("最大边长")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    TextField("例如 1600", text: $viewModel.maxDimensionText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("JPEG 质量")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    Slider(value: $viewModel.quality, in: 0.1...1.0)
                        .frame(width: 180)
                }
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.process()
                } label: {
                    Text(viewModel.isProcessing ? ToolStatusLabelFormatter.processingText : "处理图片")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing || viewModel.hasSource == false)

                Button {
                    viewModel.saveOutput()
                } label: {
                    Label("保存结果", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.outputData == nil)

                Spacer()
            }
        }
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输出结果")
                    .font(.headline)

                Spacer()

                if let summary = viewModel.outputSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }

                Button {
                    viewModel.openSavedOutput()
                } label: {
                    Label("打开文件", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.lastSavedURL == nil)
            }

            if let previewImage = viewModel.previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .background(AppSurfaceTokens.primaryText.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("处理后会显示结果图。")
                    .font(.body)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .background(AppSurfaceTokens.primaryText.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

enum ImageOutputFormat: String, CaseIterable, Identifiable {
    case png
    case jpeg
    case tiff

    var id: String { rawValue }

    var title: String {
        rawValue.uppercased()
    }

    var fileExtension: String {
        rawValue
    }

    var contentType: UTType {
        switch self {
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        case .tiff:
            return .tiff
        }
    }
}

struct ImageProcessingResult {
    let data: Data
    let previewImage: NSImage
    let outputSize: NSSize
    let outputFormat: ImageOutputFormat
}

enum ImageProcessingSupport {
    static var supportedImageContentTypes: [UTType] {
        [
            .png,
            .jpeg,
            .tiff,
            .gif,
            .bmp,
            .heic,
            .heif,
            UTType(filenameExtension: "webp")
        ].compactMap { $0 }
    }

    static func process(
        sourceImage: NSImage,
        outputFormat: ImageOutputFormat,
        maxDimension: Int?,
        quality: CGFloat
    ) throws -> ImageProcessingResult {
        let baseSize = sourceImage.size
        let targetSize = scaledSize(for: baseSize, maxDimension: maxDimension)
        let renderedImage = render(image: sourceImage, size: targetSize)
        return try encode(renderedImage: renderedImage, outputFormat: outputFormat, quality: quality)
    }

    static func process(
        sourceURL: URL,
        outputFormat: ImageOutputFormat,
        maxDimension: Int?,
        quality: CGFloat
    ) throws -> ImageProcessingResult {
        guard let image = NSImage(contentsOf: sourceURL) else {
            throw ToolShellError.launchFailed("无法加载图片")
        }

        return try process(
            sourceImage: image,
            outputFormat: outputFormat,
            maxDimension: maxDimension,
            quality: quality
        )
    }

    private static func encode(
        renderedImage: NSImage,
        outputFormat: ImageOutputFormat,
        quality: CGFloat
    ) throws -> ImageProcessingResult {
        guard let tiff = renderedImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            throw ToolShellError.launchFailed("无法转换图片数据")
        }

        let data: Data?
        switch outputFormat {
        case .png:
            data = rep.representation(using: .png, properties: [:])
        case .jpeg:
            data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .tiff:
            data = rep.representation(using: .tiff, properties: [:])
        }

        guard let data else {
            throw ToolShellError.launchFailed("图片编码失败")
        }

        return ImageProcessingResult(
            data: data,
            previewImage: renderedImage,
            outputSize: renderedImage.size,
            outputFormat: outputFormat
        )
    }

    private static func scaledSize(for size: NSSize, maxDimension: Int?) -> NSSize {
        guard let maxDimension, maxDimension > 0 else {
            return size
        }

        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let scale = min(CGFloat(maxDimension) / max(width, height), 1)

        return NSSize(width: width * scale, height: height * scale)
    }

    private static func render(image: NSImage, size: NSSize) -> NSImage {
        if size == image.size {
            return image
        }

        let target = NSImage(size: size)
        target.lockFocus()
        defer { target.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: CGRect(origin: .zero, size: size),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        return target
    }
}

@MainActor
final class ImageProcessingViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var clipboardImage: NSImage?
    @Published var previewImage: NSImage?
    @Published var outputData: Data?
    @Published var outputSummary: String?
    @Published var clipboardInfo: String?
    @Published var statusText = ToolStatusLabelFormatter.promptToSelect("图片")
    @Published var errorMessage: String?
    @Published var isProcessing = false
    @Published var outputFormat: ImageOutputFormat = .jpeg
    @Published var maxDimensionText = "1600"
    @Published var quality: CGFloat = 0.82
    @Published var lastSavedURL: URL?

    var hasSource: Bool {
        sourceURL != nil || clipboardImage != nil
    }

    func clear() {
        sourceURL = nil
        clipboardImage = nil
        previewImage = nil
        outputData = nil
        outputSummary = nil
        clipboardInfo = nil
        statusText = ToolStatusLabelFormatter.promptToSelect("图片")
        errorMessage = nil
        isProcessing = false
        outputFormat = .jpeg
        maxDimensionText = "1600"
        quality = 0.82
        lastSavedURL = nil
    }

    func pickImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ImageProcessingSupport.supportedImageContentTypes

        if panel.runModal() == .OK {
            sourceURL = panel.url
            clipboardImage = nil
            clipboardInfo = nil
            previewImage = nil
            outputData = nil
            outputSummary = nil
            lastSavedURL = nil
            errorMessage = nil
            statusText = ToolStatusLabelFormatter.selectedWaiting("图片", waitingFor: "处理")
        }
    }

    func loadFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.noClipboardImage())
            return
        }

        sourceURL = nil
        clipboardImage = image
        previewImage = image
        outputData = image.tiffRepresentation
        outputSummary = "剪贴板图片：\(Int(image.size.width)) × \(Int(image.size.height))"
        clipboardInfo = outputSummary
        statusText = ToolStatusLabelFormatter.importedWaiting("剪贴板图片", waitingFor: "处理")
        errorMessage = nil
        lastSavedURL = nil
    }

    func process() {
        let maxDimension = Int(maxDimensionText.trimmingCharacters(in: .whitespacesAndNewlines))
        isProcessing = true
        errorMessage = nil
        statusText = ToolStatusLabelFormatter.running("处理图片")
        outputData = nil
        outputSummary = nil
        lastSavedURL = nil

        do {
            let result: ImageProcessingResult
            if let sourceURL {
                result = try ImageProcessingSupport.process(
                    sourceURL: sourceURL,
                    outputFormat: outputFormat,
                    maxDimension: maxDimension,
                    quality: quality
                )
            } else if let clipboardImage {
                result = try ImageProcessingSupport.process(
                    sourceImage: clipboardImage,
                    outputFormat: outputFormat,
                    maxDimension: maxDimension,
                    quality: quality
                )
            } else {
                throw ToolShellError.launchFailed(ToolStatusLabelFormatter.chooseImage())
            }

            previewImage = result.previewImage
            outputData = result.data
            outputSummary = "输出 \(Int(result.outputSize.width)) × \(Int(result.outputSize.height))，格式 \(result.outputFormat.title)"
            statusText = ToolStatusLabelFormatter.completed("图片处理")
            ToastManager.shared.show(.success, ToolStatusLabelFormatter.imageProcessed())
        } catch {
            errorMessage = error.localizedDescription
            statusText = ToolStatusLabelFormatter.failed("处理")
            ToastManager.shared.show(.error, error.localizedDescription)
        }

        isProcessing = false
    }

    func saveOutput() {
        guard let outputData else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [outputFormat.contentType]
        panel.nameFieldStringValue = (sourceURL?.deletingPathExtension().lastPathComponent ?? "image") + "." + outputFormat.fileExtension
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try outputData.write(to: url)
                lastSavedURL = url
                ToastManager.shared.show(.success, ToolStatusLabelFormatter.savedTo(url.lastPathComponent))
            } catch {
                ToastManager.shared.show(.error, ToolStatusLabelFormatter.saveFailed(error.localizedDescription))
            }
        }
    }

    func openSavedOutput() {
        guard let lastSavedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastSavedURL])
    }
}

// MARK: - Batch Rename

struct BatchRenamePanel: View {
    @StateObject private var viewModel = BatchRenameViewModel()

    var body: some View {
        ZStack {
            AppVisualBackdrop()

            VStack(spacing: 0) {
                header

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSurfaceCard(title: "改名流程", subtitle: "先查看结果，再执行", padding: 16) {
                            introCard
                        }

                        AppSurfaceCard(title: "目标文件夹", subtitle: "选择后同步读取一级条目", padding: 16) {
                            folderCard
                        }

                        AppSurfaceCard(title: "重命名规则", subtitle: "前缀、后缀与替换", padding: 16) {
                            rulesCard
                        }

                        AppSurfaceCard(title: "改名结果", subtitle: "确认改名结果后再执行", padding: 16) {
                            previewCard
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 980, height: 860)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("批量重命名")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("对文件夹中的一级项目批量改名，支持前缀、后缀、替换和结果查看。")
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
            Text("只处理所选文件夹的一级条目，先查看结果再执行。")
                .font(.body)

            Text("这样能尽量避免误改和路径连锁反应。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var folderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("目标文件夹")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.pickFolder()
                } label: {
                    Label("选择文件夹", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.openFolder()
                } label: {
                    Label("打开目录", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.folderURL == nil)

                Button {
                    viewModel.refreshPreview()
                } label: {
                    Label("刷新结果", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.folderURL == nil)

                Button {
                    viewModel.applyRename()
                } label: {
                    Text(viewModel.isRenaming ? ToolStatusLabelFormatter.processingText : "执行重命名")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRenaming || viewModel.previewItems.isEmpty)
            }

            if let folderURL = viewModel.folderURL {
                VStack(alignment: .leading, spacing: 4) {
                    Text(folderURL.lastPathComponent)
                        .font(.headline)
                    Text(folderURL.path)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .textSelection(.enabled)
                }
            } else {
                Text("还没有选择文件夹。")
                    .font(.body)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("重命名规则")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("前缀")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    TextField("例如 new_", text: $viewModel.prefixText)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("查找")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    TextField("要替换的文字", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("替换为")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    TextField("替换成", text: $viewModel.replaceText)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("后缀")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    TextField("例如 _done", text: $viewModel.suffixText)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Toggle("包含文件夹", isOn: $viewModel.includeFolders)
                .toggleStyle(.switch)

            HStack {
                    Button {
                        viewModel.refreshPreview()
                    } label: {
                        Label("更新结果", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("结果")
                    .font(.headline)

                Spacer()

                Text("共 \(viewModel.previewItems.count) 项")
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.previewItems) { item in
                        RenamePreviewRow(item: item)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 260)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppSurfaceTokens.secondaryText.opacity(0.18), lineWidth: 1)
            )
        }
    }
}

struct RenamePreviewItem: Identifiable {
    let id = UUID()
    let originalURL: URL
    let proposedURL: URL
    let isDirectory: Bool
}

@MainActor
final class BatchRenameViewModel: ObservableObject {
    @Published var folderURL: URL?
    @Published var previewItems: [RenamePreviewItem] = []
    @Published var statusText = ToolStatusLabelFormatter.promptToSelect("文件夹")
    @Published var errorMessage: String?
    @Published var isRenaming = false
    @Published var prefixText = ""
    @Published var searchText = ""
    @Published var replaceText = ""
    @Published var suffixText = ""
    @Published var includeFolders = true

    func clear() {
        folderURL = nil
        previewItems = []
        statusText = ToolStatusLabelFormatter.promptToSelect("文件夹")
        errorMessage = nil
        isRenaming = false
        prefixText = ""
        searchText = ""
        replaceText = ""
        suffixText = ""
        includeFolders = true
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            folderURL = panel.url
            errorMessage = nil
            statusText = ToolStatusLabelFormatter.selectedRunning("文件夹", action: "读取文件")
            refreshPreview()
        }
    }

    func refreshPreview() {
        guard let folderURL else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.chooseFolder())
            return
        }

        do {
            let items = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            previewItems = items.compactMap { url in
                guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory else {
                    return nil
                }
                if isDirectory == true, includeFolders == false {
                    return nil
                }

                let proposed = proposedURL(for: url)
                return RenamePreviewItem(originalURL: url, proposedURL: proposed, isDirectory: isDirectory == true)
            }

            statusText = previewItems.isEmpty ? ToolStatusLabelFormatter.emptyState("文件夹") : ToolStatusLabelFormatter.completed("生成结果")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusText = ToolStatusLabelFormatter.failed("读取文件夹")
        }
    }

    func applyRename() {
        guard folderURL != nil else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.chooseFolder())
            return
        }

        guard previewItems.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.noRenamableItems())
            return
        }

        let targetPaths = Set(previewItems.map(\.proposedURL.path))
        if targetPaths.count != previewItems.count {
            errorMessage = "结果中存在重复目标名称，请先调整规则"
            statusText = ToolStatusLabelFormatter.conflictState("命名")
            ToastManager.shared.show(.error, ToolStatusLabelFormatter.duplicateTargetNames())
            return
        }

        isRenaming = true
        errorMessage = nil
        statusText = ToolStatusLabelFormatter.running("重命名")

        do {
            for item in previewItems {
                if item.originalURL.path == item.proposedURL.path {
                    continue
                }

                if FileManager.default.fileExists(atPath: item.proposedURL.path) {
                    throw ToolShellError.launchFailed("目标已存在: \(item.proposedURL.lastPathComponent)")
                }

                try FileManager.default.moveItem(at: item.originalURL, to: item.proposedURL)
            }

            ToastManager.shared.show(.success, ToolStatusLabelFormatter.batchRenameCompleted())
            statusText = ToolStatusLabelFormatter.completed("重命名")
            if let folderURL {
                let refreshedFolder = folderURL
                self.folderURL = refreshedFolder
                refreshPreview()
            }
        } catch {
            errorMessage = error.localizedDescription
            statusText = ToolStatusLabelFormatter.failed("重命名")
            ToastManager.shared.show(.error, error.localizedDescription)
        }

        isRenaming = false
    }

    func openFolder() {
        guard let folderURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
    }

    private func proposedURL(for url: URL) -> URL {
        let directory = url.deletingLastPathComponent()
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let originalName = isDirectory ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
        let ext = isDirectory ? "" : url.pathExtension

        var name = originalName
        if searchText.isEmpty == false {
            name = name.replacingOccurrences(of: searchText, with: replaceText)
        }
        if prefixText.isEmpty == false {
            name = prefixText + name
        }
        if suffixText.isEmpty == false {
            name = name + suffixText
        }

        let finalName = isDirectory ? name : name + (ext.isEmpty ? "" : ".\(ext)")
        return directory.appendingPathComponent(finalName)
    }
}

struct RenamePreviewRow: View {
    let item: RenamePreviewItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalURL.lastPathComponent)
                    .font(.body)
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text(item.originalURL.path)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .textSelection(.enabled)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.proposedURL.lastPathComponent)
                    .font(.body)
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text(item.proposedURL.path)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppSurfaceTokens.secondaryText.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 8)
    }
}

// MARK: - SRT to FCPXML Converter

struct SRTToFCPXMLPanel: View {
    @State private var srtContent = ""
    @State private var convertedXML = ""
    @State private var showCopied = false

    var body: some View {
        ZStack {
            AppVisualBackdrop()

            VStack(alignment: .leading, spacing: 16) {
                AppSurfaceCard(title: "SRT → FCPXML 转换器", subtitle: "把字幕稿转换成可直接导入剪辑的软件格式", padding: 16) {
                    Text("将 SRT 字幕文件转换为 Final Cut Pro 可用的 FCPXML 格式")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }

                AppSurfaceCard(title: "内容转换", subtitle: "左右对照输入与输出", padding: 16, fillHeight: true) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SRT 内容")
                                .font(.headline)
                            AppSurfaceTextEditorShell(text: $srtContent, minHeight: 200)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("FCPXML 输出")
                                .font(.headline)
                            AppSurfaceTextEditorShell(text: .constant(convertedXML), minHeight: 200)
                                .disabled(true)
                        }
                    }
                }

                AppSurfaceCard(title: "操作", subtitle: "转换并复制结果", padding: 16) {
                    HStack {
                        Button("转换") {
                            convertSRTToFCPXML()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("复制 XML") {
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(convertedXML, forType: .string)
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopied = false
                            }
                            #endif
                        }
                        .buttonStyle(.bordered)
                        .disabled(convertedXML.isEmpty)

                        if showCopied {
                            Text(ToolStatusLabelFormatter.copiedText())
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        Spacer()
                    }
                }

                Spacer()
            }
            .padding(20)
            .frame(minWidth: 700, minHeight: 500)
        }
    }

    private func convertSRTToFCPXML() {
        let lines = srtContent.components(separatedBy: .newlines)
        var fcpxml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.10">
            <resources>
                <format id="r1" name="FFVideoFormat1080p30" frameDuration="1s/30s" width="1920" height="1080"/>
            </resources>
            <library>
                <event name="Imported from SRT">
                    <project name="Subtitles">
                        <sequence format="r1" duration="99/25s">
                            <spine>

        """

        var inSubtitle = false
        var subtitleNumber = ""
        var startTime = ""
        var endTime = ""
        var text = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if inSubtitle && !subtitleNumber.isEmpty {
                    fcpxml += formatSubtitleFCPXML(number: subtitleNumber, start: startTime, end: endTime, text: text)
                }
                inSubtitle = false
                subtitleNumber = ""
                startTime = ""
                endTime = ""
                text = ""
                continue
            }

            if trimmed.contains("-->") {
                let times = trimmed.components(separatedBy: "-->")
                if times.count == 2 {
                    startTime = times[0].trimmingCharacters(in: .whitespaces)
                    endTime = times[1].trimmingCharacters(in: .whitespaces)
                }
                inSubtitle = true
            } else if inSubtitle && subtitleNumber.isEmpty {
                subtitleNumber = trimmed
            } else if inSubtitle {
                if !text.isEmpty {
                    text += "\n"
                }
                text += trimmed
            }
        }

        fcpxml += """
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """

        convertedXML = fcpxml
    }

    private func formatSubtitleFCPXML(number: String, start: String, end: String, text: String) -> String {
        let startSeconds = parseTimeToSeconds(start)
        let endSeconds = parseTimeToSeconds(end)
        let duration = endSeconds - startSeconds

        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        return """
                    <title name="\(escapedText)" start="\(formatSecondsToFCPTime(startSeconds))" duration="\(formatSecondsToFCPTime(duration))">
                        <text>\(escapedText)</text>
                    </title>

        """
    }

    private func parseTimeToSeconds(_ time: String) -> Double {
        let parts = time.replacingOccurrences(of: ",", with: ".").components(separatedBy: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else {
            return 0
        }
        return hours * 3600 + minutes * 60 + seconds
    }

    private func formatSecondsToFCPTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let frames = Int((seconds.truncatingRemainder(dividingBy: 1)) * 30)
        return String(format: "%02d:%02d:%02d/%02ds", hours, minutes, secs, frames)
    }
}
