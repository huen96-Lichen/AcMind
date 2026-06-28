import AppKit
import AcMindKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - JSON Formatter Panel

struct JSONFormatterPanel: View {
    @StateObject private var viewModel = JSONFormatterViewModel()

    var body: some View {
        ZStack {
            AppVisualBackdrop()

            VStack(spacing: 0) {
                header

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSurfaceCard(title: "格式概览", subtitle: "先了解能力，再进入输入与输出", padding: 16) {
                            introCard
                        }

                        AppSurfaceCard(title: "输入", subtitle: "粘贴 JSON 并执行处理", padding: 16) {
                            inputCard
                        }

                        AppSurfaceCard(title: "输出", subtitle: "查看、美化、压缩或保存", padding: 16) {
                            outputCard
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 860, height: 720)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("JSON 格式化")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("粘贴 JSON，直接美化、压缩、校验并复制结果。")
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
            Text("支持对象、数组、字符串、数字、布尔值和 `null`。")
                .font(.body)

            Text("如果是 JSON 片段，面板会先解析再重新输出；如果解析失败，会直接告诉你哪里不合法。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输入")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.loadFromClipboard()
                } label: {
                    Label("读取剪贴板", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
            }

            AppSurfaceTextEditorShell(text: $viewModel.inputText, minHeight: 220)

            HStack(spacing: 10) {
                Button {
                    viewModel.format(pretty: true)
                } label: {
                    Text(viewModel.isWorking ? ToolStatusLabelFormatter.processingText : "美化 JSON")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isWorking)

                Button {
                    viewModel.format(pretty: false)
                } label: {
                    Text(viewModel.isWorking ? ToolStatusLabelFormatter.processingText : "压缩 JSON")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isWorking)

                Spacer()

                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输出")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.copyOutput()
                } label: {
                    Label("复制结果", systemImage: "doc.on.doc")
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

            AppSurfaceTextEditorShell(text: $viewModel.outputText, minHeight: 220)
        }
    }
}

@MainActor
final class JSONFormatterViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var outputText = ""
    @Published var statusText = ToolStatusLabelFormatter.waitingToInput("JSON")
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var lastSavedURL: URL?

    func clear() {
        inputText = ""
        outputText = ""
        statusText = ToolStatusLabelFormatter.waitingToInput("JSON")
        errorMessage = nil
        isWorking = false
        lastSavedURL = nil
    }

    func loadFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string), !string.isEmpty {
            inputText = string
            statusText = ToolStatusLabelFormatter.clipboardLoadedText
            errorMessage = nil
        } else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.noClipboardText())
        }
    }

    func format(pretty: Bool) {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            errorMessage = ToolStatusLabelFormatter.enterInput("JSON")
            statusText = ToolStatusLabelFormatter.waitingToInput("JSON")
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.enterInput("JSON"))
            return
        }

        isWorking = true
        errorMessage = nil

        do {
            outputText = try JSONFormattingSupport.format(trimmed, pretty: pretty)
            statusText = ToolStatusLabelFormatter.jsonFormatted(pretty: pretty)
            lastSavedURL = nil
            ToastManager.shared.show(.success, ToolStatusLabelFormatter.jsonFormatted(pretty: pretty))
        } catch {
            outputText = ""
            statusText = ToolStatusLabelFormatter.failed("格式化")
            errorMessage = error.localizedDescription
            ToastManager.shared.show(.error, error.localizedDescription)
        }

        isWorking = false
    }

    func copyOutput() {
        guard outputText.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.nothingToCopy("结果"))
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.copied("结果"))
    }

    func saveOutput() {
        guard outputText.isEmpty == false else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json, .plainText]
        panel.nameFieldStringValue = "formatted.json"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try outputText.write(to: url, atomically: true, encoding: .utf8)
                lastSavedURL = url
                ToastManager.shared.show(.success, ToolStatusLabelFormatter.saved("结果"))
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

enum JSONFormattingSupport {
    static func format(_ text: String, pretty: Bool) throws -> String {
        let data = Data(text.utf8)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])

        if JSONSerialization.isValidJSONObject(object) {
            let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
            let rendered = try JSONSerialization.data(withJSONObject: object, options: options)
            return String(decoding: rendered, as: UTF8.self)
        }

        return try renderFragment(object, pretty: pretty)
    }

    private static func renderFragment(_ object: Any, pretty: Bool) throws -> String {
        let rendered = try JSONSerialization.data(
            withJSONObject: [object],
            options: pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        )

        let text = String(decoding: rendered, as: UTF8.self)
        guard text.count >= 2 else {
            return text
        }

        return String(text.dropFirst().dropLast())
    }
}

// MARK: - Base64 Codec Panel

struct Base64CodecPanel: View {
    @StateObject private var viewModel = Base64CodecViewModel()

    var body: some View {
        ZStack {
            AppVisualBackdrop()

            VStack(spacing: 0) {
                header

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSurfaceCard(title: "编解码流程", subtitle: "文本和 Base64 之间来回转换", padding: 16) {
                            introCard
                        }

                        AppSurfaceCard(title: "输入", subtitle: "切换模式后执行", padding: 16) {
                            inputCard
                        }

                        AppSurfaceCard(title: "输出", subtitle: "复制或保存结果", padding: 16) {
                            outputCard
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 860, height: 720)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Base64 编解码")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("文本和 Base64 互转，支持直接复制结果。")
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
            Text("支持文本编码与 Base64 解码。")
                .font(.body)

            Text("如果解码后的内容不是 UTF-8 文本，面板会转成十六进制预览，方便你确认原始字节。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输入")
                    .font(.headline)

                Spacer()

                Picker("模式", selection: $viewModel.mode) {
                    ForEach(Base64CodecMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            AppSurfaceTextEditorShell(text: $viewModel.inputText, minHeight: 220)

            HStack(spacing: 10) {
                Button {
                    viewModel.execute()
                } label: {
                    Text(viewModel.isWorking ? ToolStatusLabelFormatter.processingText : viewModel.mode.actionTitle)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isWorking)

                Button {
                    viewModel.loadFromClipboard()
                } label: {
                    Label("读取剪贴板", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输出")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.copyOutput()
                } label: {
                    Label("复制结果", systemImage: "doc.on.doc")
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

            AppSurfaceTextEditorShell(text: $viewModel.outputText, minHeight: 220)
        }
    }
}

enum Base64CodecMode: String, CaseIterable, Identifiable {
    case encode
    case decode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .encode:
            return "编码"
        case .decode:
            return "解码"
        }
    }

    var actionTitle: String {
        switch self {
        case .encode:
            return "执行编码"
        case .decode:
            return "执行解码"
        }
    }
}

@MainActor
final class Base64CodecViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var outputText = ""
    @Published var statusText = ToolStatusLabelFormatter.waitingToInput("文本")
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var mode: Base64CodecMode = .encode
    @Published var lastSavedURL: URL?

    func clear() {
        inputText = ""
        outputText = ""
        statusText = ToolStatusLabelFormatter.waitingToInput("文本")
        errorMessage = nil
        isWorking = false
        mode = .encode
        lastSavedURL = nil
    }

    func loadFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string), !string.isEmpty {
            inputText = string
            statusText = ToolStatusLabelFormatter.clipboardLoadedText
            errorMessage = nil
        } else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.noClipboardText())
        }
    }

    func execute() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            errorMessage = ToolStatusLabelFormatter.enterInput("文本")
            statusText = ToolStatusLabelFormatter.waitingToInput("文本")
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.enterInput("文本"))
            return
        }

        isWorking = true
        errorMessage = nil
        lastSavedURL = nil

        switch mode {
        case .encode:
            outputText = Data(trimmed.utf8).base64EncodedString()
            statusText = ToolStatusLabelFormatter.base64Encoded()
            ToastManager.shared.show(.success, ToolStatusLabelFormatter.base64Encoded())

        case .decode:
            let normalized = trimmed.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            guard let data = Data(base64Encoded: normalized, options: [.ignoreUnknownCharacters]) else {
                outputText = ""
                statusText = ToolStatusLabelFormatter.decodeFailed()
                errorMessage = ToolStatusLabelFormatter.invalidBase64()
                ToastManager.shared.show(.error, ToolStatusLabelFormatter.invalidBase64())
                isWorking = false
                return
            }

            if let decoded = String(data: data, encoding: .utf8) {
                outputText = decoded
                statusText = ToolStatusLabelFormatter.base64DecodedText()
                ToastManager.shared.show(.success, ToolStatusLabelFormatter.base64DecodedText())
            } else {
                outputText = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                statusText = ToolStatusLabelFormatter.base64DecodedHex()
                ToastManager.shared.show(.warning, ToolStatusLabelFormatter.nonUTF8ShownAsHex())
            }
        }

        isWorking = false
    }

    func copyOutput() {
        guard outputText.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.nothingToCopy("结果"))
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.copied("结果"))
    }

    func saveOutput() {
        guard outputText.isEmpty == false else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = mode == .encode ? "base64.txt" : "decoded.txt"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try outputText.write(to: url, atomically: true, encoding: .utf8)
                lastSavedURL = url
                ToastManager.shared.show(.success, ToolStatusLabelFormatter.saved("结果"))
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

// MARK: - Markdown Cleaner Panel

struct MarkdownCleanerPanel: View {
    @StateObject private var viewModel = MarkdownCleanerViewModel()

    var body: some View {
        ZStack {
            AppVisualBackdrop()

            VStack(spacing: 0) {
                header

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSurfaceCard(title: "整理流程", subtitle: "先整理原文，再输出干净文本", padding: 16) {
                            introCard
                        }

                        AppSurfaceCard(title: "输入", subtitle: "从剪贴板读入 Markdown", padding: 16) {
                            inputCard
                        }

                        AppSurfaceCard(title: "输出", subtitle: "整理后的结果可继续复制", padding: 16) {
                            outputCard
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 860, height: 740)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Markdown 整理")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("清理多余空行、尾随空格和一些常见排版噪音。")
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
            Text("适合把剪贴板里的 Markdown 初稿快速整理一下。")
                .font(.body)

            Text("会保留代码块内容，减少连着的空行，并清掉尾随空格。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输入")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.loadFromClipboard()
                } label: {
                    Label("读取剪贴板", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
            }

            AppSurfaceTextEditorShell(text: $viewModel.inputText, minHeight: 220)

            HStack(spacing: 10) {
                Button {
                    viewModel.clean()
                } label: {
                    Text(viewModel.isWorking ? ToolStatusLabelFormatter.processingText : "整理 Markdown")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isWorking)

                Spacer()

                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输出")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.copyOutput()
                } label: {
                    Label("复制结果", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.outputText.isEmpty)
            }

            AppSurfaceTextEditorShell(text: $viewModel.outputText, minHeight: 240)
        }
    }
}

@MainActor
final class MarkdownCleanerViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var outputText = ""
    @Published var statusText = ToolStatusLabelFormatter.waitingToInput("Markdown")
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var lastSavedURL: URL?

    func clear() {
        inputText = ""
        outputText = ""
        statusText = ToolStatusLabelFormatter.waitingToInput("Markdown")
        errorMessage = nil
        isWorking = false
        lastSavedURL = nil
    }

    func loadFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string), !string.isEmpty {
            inputText = string
            statusText = ToolStatusLabelFormatter.clipboardLoadedText
            errorMessage = nil
        } else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.noClipboardText())
        }
    }

    func clean() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            errorMessage = ToolStatusLabelFormatter.enterInput("Markdown")
            statusText = ToolStatusLabelFormatter.waitingToInput("Markdown")
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.enterInput("Markdown"))
            return
        }

        isWorking = true
        errorMessage = nil

        let result = MarkdownCleaningSupport.clean(trimmed)
        outputText = result.text
        statusText = ToolStatusLabelFormatter.markdownCleanedSummary(
            trimmedTrailingSpaces: result.trimmedTrailingSpaces,
            collapsedBlankLines: result.collapsedBlankLines
        )
        lastSavedURL = nil
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.saved("Markdown"))

        isWorking = false
    }

    func copyOutput() {
        guard outputText.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.nothingToCopy("结果"))
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.copied("结果"))
    }

    func saveOutput() {
        guard outputText.isEmpty == false else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, .plainText]
        panel.nameFieldStringValue = "cleaned-markdown.md"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try outputText.write(to: url, atomically: true, encoding: .utf8)
                lastSavedURL = url
                ToastManager.shared.show(.success, ToolStatusLabelFormatter.saved("结果"))
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

struct MarkdownCleaningResult {
    let text: String
    let trimmedTrailingSpaces: Int
    let collapsedBlankLines: Int
}

enum MarkdownCleaningSupport {
    static func clean(_ text: String) -> MarkdownCleaningResult {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var output: [String] = []
        var inCodeFence = false
        var previousWasHeading = false
        var trimmedTrailingSpaces = 0
        var collapsedBlankLines = 0

        for rawLine in lines {
            let line = rawLine
            let fenceCandidate = line.trimmingCharacters(in: .whitespaces)

            if fenceCandidate.hasPrefix("```") || fenceCandidate.hasPrefix("~~~") {
                inCodeFence.toggle()
                previousWasHeading = false
                output.append(line.trimmingTrailingWhitespace())
                continue
            }

            if inCodeFence {
                output.append(line)
                continue
            }

            let trimmedLine = line.trimmingTrailingWhitespace()
            if trimmedLine != line {
                trimmedTrailingSpaces += 1
            }

            if trimmedLine.isEmpty {
                if output.isEmpty || output.last?.isEmpty == true {
                    collapsedBlankLines += 1
                    continue
                }

                output.append("")
                previousWasHeading = false
                continue
            }

            if isMarkdownHeading(trimmedLine) {
                if output.last?.isEmpty == false, output.isEmpty == false {
                    output.append("")
                }
                output.append(trimmedLine)
                previousWasHeading = true
                continue
            }

            if previousWasHeading, output.last?.isEmpty == false {
                output.append("")
            }

            previousWasHeading = false
            output.append(trimmedLine)
        }

        return MarkdownCleaningResult(
            text: output.joined(separator: "\n"),
            trimmedTrailingSpaces: trimmedTrailingSpaces,
            collapsedBlankLines: collapsedBlankLines
        )
    }

    private static func isMarkdownHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "#" else {
            return false
        }

        let hashes = trimmed.prefix { $0 == "#" }
        guard hashes.count >= 1, hashes.count <= 6 else {
            return false
        }

        let remainder = trimmed.dropFirst(hashes.count)
        return remainder.first == " "
    }
}

// MARK: - Text Compare Panel

struct TextComparePanel: View {
    @StateObject private var viewModel = TextCompareViewModel()

    var body: some View {
        ZStack {
            AppVisualBackdrop()

            VStack(spacing: 0) {
                header

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSurfaceCard(title: "对比流程", subtitle: "逐行比较两段文本", padding: 16) {
                            introCard
                        }

                        AppSurfaceCard(title: "输入", subtitle: "左右文本同时编辑", padding: 16) {
                            inputCard
                        }

                        AppSurfaceCard(title: "比较结果", subtitle: "摘要与差异分开看", padding: 16) {
                            resultCard
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 940, height: 760)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("文本对比")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("逐行比较两段文本，并给出删除、插入和相同内容。")
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
            Text("适合快速看两段文本到底改了哪里。")
                .font(.body)

            Text("这是逐行 LCS 对比，足够应付大多数文案、配置和 Markdown 变化。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输入")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.compare()
                } label: {
                    Text(viewModel.isWorking ? ToolStatusLabelFormatter.processingText : "开始比较")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isWorking)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("左侧文本")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    AppSurfaceTextEditorShell(text: $viewModel.leftText, minHeight: 210)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("右侧文本")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    AppSurfaceTextEditorShell(text: $viewModel.rightText, minHeight: 210)
                }
            }

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)

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
                Text("比较结果")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.copySummary()
                } label: {
                    Label("复制摘要", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.summaryText.isEmpty)

                Button {
                    viewModel.copyDiff()
                } label: {
                    Label("复制差异", systemImage: "arrow.up.doc")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.diffText.isEmpty)

                Button {
                    viewModel.saveDiff()
                } label: {
                    Label("保存差异", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.diffText.isEmpty)

                Button {
                    viewModel.openSavedDiff()
                } label: {
                    Label("打开文件", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.lastSavedURL == nil)
            }

            Text(viewModel.summaryText.isEmpty ? "比较完成后会显示摘要" : viewModel.summaryText)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.diffLines) { line in
                        DiffLineRow(line: line)
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

@MainActor
final class TextCompareViewModel: ObservableObject {
    @Published var leftText = ""
    @Published var rightText = ""
    @Published var diffLines: [DiffLine] = []
    @Published var summaryText = ""
    @Published var statusText = ToolStatusLabelFormatter.waitingToInput("两段文本")
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var lastSavedURL: URL?

    var diffText: String {
        TextComparisonSupport.render(diffLines: diffLines)
    }

    func clear() {
        leftText = ""
        rightText = ""
        diffLines = []
        summaryText = ""
        statusText = ToolStatusLabelFormatter.waitingToInput("两段文本")
        errorMessage = nil
        isWorking = false
        lastSavedURL = nil
    }

    func compare() {
        let leftLines = splitLines(leftText)
        let rightLines = splitLines(rightText)

        guard leftLines.isEmpty == false || rightLines.isEmpty == false else {
            errorMessage = ToolStatusLabelFormatter.enterInput("两段文本")
            statusText = ToolStatusLabelFormatter.waitingToInput("两段文本")
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.enterInput("两段文本"))
            return
        }

        isWorking = true
        errorMessage = nil

        let result = TextComparisonSupport.compare(leftLines: leftLines, rightLines: rightLines)
        diffLines = result.lines
        summaryText = result.summary
        statusText = ToolStatusLabelFormatter.completed("比较")
        lastSavedURL = nil
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.completed("文本对比"))

        isWorking = false
    }

    func copySummary() {
        guard summaryText.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.nothingToCopy("摘要"))
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summaryText, forType: .string)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.copied("摘要"))
    }

    func copyDiff() {
        guard diffLines.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.nothingToCopy("差异"))
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diffText, forType: .string)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.copied("差异"))
    }

    func saveDiff() {
        guard diffLines.isEmpty == false else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "text-diff.txt"
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try diffText.write(to: url, atomically: true, encoding: .utf8)
                lastSavedURL = url
                ToastManager.shared.show(.success, ToolStatusLabelFormatter.saved("差异"))
            } catch {
                ToastManager.shared.show(.error, ToolStatusLabelFormatter.saveFailed(error.localizedDescription))
            }
        }
    }

    func openSavedDiff() {
        guard let lastSavedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastSavedURL])
    }

    private func splitLines(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}

struct DiffLine: Identifiable {
    enum Kind {
        case same
        case insert
        case delete
    }

    let id = UUID()
    let kind: Kind
    let text: String
    let leftLineNumber: Int?
    let rightLineNumber: Int?
}

struct TextComparisonResult {
    let lines: [DiffLine]
    let summary: String
}

enum TextComparisonSupport {
    static func compare(leftLines: [String], rightLines: [String]) -> TextComparisonResult {
        let n = leftLines.count
        let m = rightLines.count

        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)

        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    if leftLines[i] == rightLines[j] {
                        dp[i][j] = dp[i + 1][j + 1] + 1
                    } else {
                        dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                    }
                }
            }
        }

        var lines: [DiffLine] = []
        var i = 0
        var j = 0
        var leftLineNumber = 1
        var rightLineNumber = 1
        var sameCount = 0
        var insertCount = 0
        var deleteCount = 0

        while i < n && j < m {
            if leftLines[i] == rightLines[j] {
                lines.append(
                    DiffLine(
                        kind: .same,
                        text: leftLines[i],
                        leftLineNumber: leftLineNumber,
                        rightLineNumber: rightLineNumber
                    )
                )
                sameCount += 1
                i += 1
                j += 1
                leftLineNumber += 1
                rightLineNumber += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                lines.append(
                    DiffLine(
                        kind: .delete,
                        text: leftLines[i],
                        leftLineNumber: leftLineNumber,
                        rightLineNumber: nil
                    )
                )
                deleteCount += 1
                i += 1
                leftLineNumber += 1
            } else {
                lines.append(
                    DiffLine(
                        kind: .insert,
                        text: rightLines[j],
                        leftLineNumber: nil,
                        rightLineNumber: rightLineNumber
                    )
                )
                insertCount += 1
                j += 1
                rightLineNumber += 1
            }
        }

        while i < n {
            lines.append(
                DiffLine(
                    kind: .delete,
                    text: leftLines[i],
                    leftLineNumber: leftLineNumber,
                    rightLineNumber: nil
                )
            )
            deleteCount += 1
            i += 1
            leftLineNumber += 1
        }

        while j < m {
            lines.append(
                DiffLine(
                    kind: .insert,
                    text: rightLines[j],
                    leftLineNumber: nil,
                    rightLineNumber: rightLineNumber
                )
            )
            insertCount += 1
            j += 1
            rightLineNumber += 1
        }

        let summary = "左侧 \(n) 行，右侧 \(m) 行，相同 \(sameCount) 行，新增 \(insertCount) 行，删除 \(deleteCount) 行"
        return TextComparisonResult(lines: lines, summary: summary)
    }

    static func render(diffLines: [DiffLine]) -> String {
        diffLines.map { line in
            let left = line.leftLineNumber.map(String.init) ?? "-"
            let right = line.rightLineNumber.map(String.init) ?? "-"
            let marker: String
            switch line.kind {
            case .same:
                marker = " "
            case .insert:
                marker = "+"
            case .delete:
                marker = "-"
            }
            return "[L\(left) R\(right)] \(marker) \(line.text)"
        }
        .joined(separator: "\n")
    }
}

struct DiffLineRow: View {
    let line: DiffLine

    private var tint: Color {
        switch line.kind {
        case .same:
            return .secondary
        case .insert:
            return .green
        case .delete:
            return .red
        }
    }

    private var background: Color {
        switch line.kind {
        case .same:
            return Color.clear
        case .insert:
            return AppSurfaceTokens.cardBackgroundSoft
        case .delete:
            return AppSurfaceTokens.cardBackgroundSoft
        }
    }

    private var marker: String {
        switch line.kind {
        case .same:
            return " "
        case .insert:
            return "+"
        case .delete:
            return "−"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(line.leftLineNumber.map(String.init) ?? " ")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .frame(width: 36, alignment: .trailing)

            Text(line.rightLineNumber.map(String.init) ?? " ")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .frame(width: 36, alignment: .trailing)

            Text(marker)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(line.text.isEmpty ? " " : line.text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 8)
    }
}

// MARK: - String Helpers

private extension String {
    func trimmingTrailingWhitespace() -> String {
        replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
    }
}

// MARK: - SRT to FCPXML Panel

struct SRTSubtitle: Identifiable {
    let id = UUID()
    let index: Int
    let startMs: Int
    let endMs: Int
    let text: String

    var startTimeString: String {
        formatTime(startMs)
    }

    var endTimeString: String {
        formatTime(endMs)
    }

    private func formatTime(_ ms: Int) -> String {
        let h = ms / 3600000
        let m = (ms % 3600000) / 60000
        let s = (ms % 60000) / 1000
        let millis = ms % 1000
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, millis)
    }
}

enum SRTParser {
    struct ParseError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func parse(_ content: String) throws -> [SRTSubtitle] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.isEmpty == false else {
            return []
        }

        let timePattern = #"^(\d{2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{1,3})$"#
        let timeRegex = try NSRegularExpression(pattern: timePattern, options: [])

        let blocks = normalized.components(separatedBy: "\n\n")
        var subtitles: [SRTSubtitle] = []

        for (blockIndex, block) in blocks.enumerated() {
            let lines = block.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            guard lines.count >= 2 else { continue }

            var timeLineIndex = 0
            if lines[0].trimmingCharacters(in: .whitespaces).range(of: #"^\d+$"#, options: .regularExpression) != nil {
                timeLineIndex = 1
            }

            guard timeLineIndex < lines.count else { continue }

            let timeLine = lines[timeLineIndex]
            let range = NSRange(timeLine.startIndex..., in: timeLine)
            guard let match = timeRegex.firstMatch(in: timeLine, options: [], range: range) else {
                throw ParseError(message: "第 \(blockIndex + 1) 个字幕块时间戳格式无效: \(timeLine)")
            }

            let startMs = parseTimestamp(timeLine, match: match, startGroup: 1)
            let endMs = parseTimestamp(timeLine, match: match, startGroup: 5)

            guard endMs > startMs else {
                throw ParseError(message: "第 \(blockIndex + 1) 个字幕结束时间必须大于开始时间")
            }

            let textLines = lines[(timeLineIndex + 1)...]
            let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

            guard text.isEmpty == false else { continue }

            subtitles.append(SRTSubtitle(index: subtitles.count + 1, startMs: startMs, endMs: endMs, text: text))
        }

        return subtitles
    }

    private static func parseTimestamp(_ line: String, match: NSTextCheckingResult, startGroup: Int) -> Int {
        let hRange = match.range(at: startGroup)
        let mRange = match.range(at: startGroup + 1)
        let sRange = match.range(at: startGroup + 2)
        let msRange = match.range(at: startGroup + 3)

        let h = Int((line as NSString).substring(with: hRange)) ?? 0
        let m = Int((line as NSString).substring(with: mRange)) ?? 0
        let s = Int((line as NSString).substring(with: sRange)) ?? 0
        var msStr = (line as NSString).substring(with: msRange)
        while msStr.count < 3 { msStr += "0" }
        let ms = Int(msStr) ?? 0

        return ((h * 60) + m) * 60 * 1000 + s * 1000 + ms
    }
}

enum FCPXMLGenerator {
    static func generate(
        subtitles: [SRTSubtitle],
        fps: Int,
        titleX: Double,
        titleY: Double,
        width: Int,
        height: Int,
        fontSize: Double,
        fontColor: String,
        alignment: String,
        fontFace: String
    ) -> String {
        let maxEndMs = subtitles.map(\.endMs).max() ?? 1000
        let projectDurationFrames = Int(round(Double(maxEndMs) * Double(fps) / 1000.0))
        let projectDuration = "\(projectDurationFrames)/\(fps)s"
        let frameDuration = "1/\(fps)s"

        let formatName: String
        if width == 3840 && height == 2160 {
            formatName = "FFVideoFormat2160p\(fps)"
        } else if width == 1920 && height == 1080 {
            formatName = "FFVideoFormat1080p\(fps)"
        } else if width == 1280 && height == 720 {
            formatName = "FFVideoFormat720p\(fps)"
        } else {
            formatName = "CustomFormat"
        }

        var xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <fcpxml version="1.11">
          <resources>
            <format id="r1" name="\(formatName)" frameDuration="\(frameDuration)" width="\(width)" height="\(height)" colorSpace="1-1-1 (Rec. 709)" />
          </resources>
          <library>
            <event name="SRT Import">
              <project name="SRT to FCPXML">
                <sequence format="r1" duration="\(projectDuration)" tcStart="0s" tcFormat="NDF" audioLayout="stereo" audioRate="48k">
                  <spine>
                    <gap name="Subtitle Gap" offset="0s" start="0s" duration="\(projectDuration)">

        """

        for (i, sub) in subtitles.enumerated() {
            let offsetFrames = Int(round(Double(sub.startMs) * Double(fps) / 1000.0))
            let durationFrames = Int(round(Double(sub.endMs - sub.startMs) * Double(fps) / 1000.0))
            let styleId = "ts\(UUID().uuidString.prefix(8).lowercased())"
            let escapedText = sub.text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")

            xml += """
                          <title name="SRT \(i + 1)" lane="1" offset="\(offsetFrames)/\(fps)s" start="0s" duration="\(durationFrames)/\(fps)s" role="title">
                            <adjust-transform position="\(titleX) \(titleY)" anchor="0 0" scale="1 1" />
                            <text>
                              <text-style ref="\(styleId)">\(escapedText)</text-style>
                            </text>
                            <text-style-def id="\(styleId)">
                              <text-style font="\(fontFace)" fontSize="\(Int(fontSize))" fontFace="Regular" fontColor="\(fontColor)" bold="0" italic="0" strokeColor="0 0 0 1" strokeWidth="2" alignment="\(alignment)" />
                            </text-style-def>
                          </title>

            """
        }

        xml += """
                    </gap>
                  </spine>
                </sequence>
              </project>
            </event>
          </library>
        </fcpxml>
        """

        return xml
    }
}

@MainActor
final class SRTTFCPXMLViewModel: ObservableObject {
    @Published var subtitles: [SRTSubtitle] = []
    @Published var originalSubtitles: [SRTSubtitle] = []
    @Published var errorMessage: String?
    @Published var statusText = ToolStatusLabelFormatter.waitingToImport("SRT")
    @Published var isLoading = false
    @Published var generatedFCPXML: String = ""
    @Published var lastSavedURL: URL?

    @Published var fps: Int = 25
    @Published var width: Int = 1920
    @Published var height: Int = 1080
    @Published var titleX: Double = 0.0
    @Published var titleY: Double = -360.0
    @Published var fontSize: Double = 54.0
    @Published var fontColor: String = "1 1 1 1"
    @Published var alignment: String = "center"
    @Published var fontFace: String = "PingFang SC"

    @Published var batchFindText: String = ""
    @Published var batchReplaceText: String = ""
    @Published var deleteKeyword: String = ""

    var hasSubtitles: Bool { !subtitles.isEmpty }
    var hasGenerated: Bool { !generatedFCPXML.isEmpty }

    func loadFromClipboard() {
        guard let content = NSPasteboard.general.string(forType: .string), !content.isEmpty else {
            errorMessage = nil
            statusText = ToolStatusLabelFormatter.clipboardEmpty()
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.clipboardEmpty())
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            subtitles = try SRTParser.parse(content)
            originalSubtitles = subtitles
            statusText = ToolStatusLabelFormatter.loadedCount(subtitles.count, noun: "字幕")
            ToastManager.shared.show(.success, ToolStatusLabelFormatter.loadedCount(subtitles.count, noun: "字幕"))
        } catch {
            subtitles = []
            originalSubtitles = []
            errorMessage = error.localizedDescription
            statusText = ToolStatusLabelFormatter.failed("解析")
            ToastManager.shared.show(.error, error.localizedDescription)
        }

        isLoading = false
    }

    func batchReplace() {
        let find = batchFindText
        let replace = batchReplaceText
        guard find.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.enterInput("要替换的内容"))
            return
        }

        subtitles = subtitles.map { sub in
            SRTSubtitle(
                index: sub.index,
                startMs: sub.startMs,
                endMs: sub.endMs,
                text: sub.text.replacingOccurrences(of: find, with: replace)
            )
        }

        statusText = ToolStatusLabelFormatter.completed("批量替换")
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.completed("批量替换"))
    }

    func deleteByKeyword() {
        let keyword = deleteKeyword
        guard keyword.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.enterInput("要删除的关键词"))
            return
        }

        let before = subtitles.count
        subtitles = subtitles.filter { !$0.text.contains(keyword) }
        let removed = before - subtitles.count

        if removed > 0 {
            statusText = ToolStatusLabelFormatter.deletedSubtitleSummary(keyword: keyword, removed: removed)
            ToastManager.shared.show(.success, ToolStatusLabelFormatter.deleted("字幕"))
        } else {
            statusText = ToolStatusLabelFormatter.noSubtitleMatch(keyword)
            ToastManager.shared.show(.info, ToolStatusLabelFormatter.noMatchFound("字幕"))
        }
    }

    func deleteSubtitle(at index: Int) {
        guard index >= 0 && index < subtitles.count else { return }
        subtitles.remove(at: index)
        statusText = ToolStatusLabelFormatter.deletedSubtitle(index: index + 1)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.deleted("字幕"))
    }

    func restoreOriginal() {
        subtitles = originalSubtitles
        statusText = ToolStatusLabelFormatter.restored("原始字幕")
        ToastManager.shared.show(.info, ToolStatusLabelFormatter.restored("原始字幕"))
    }

    func generateFCPXML() {
        guard subtitles.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.noContentToGenerate("字幕"))
            return
        }

        generatedFCPXML = FCPXMLGenerator.generate(
            subtitles: subtitles,
            fps: fps,
            titleX: titleX,
            titleY: titleY,
            width: width,
            height: height,
            fontSize: fontSize,
            fontColor: fontColor,
            alignment: alignment,
            fontFace: fontFace
        )

        statusText = ToolStatusLabelFormatter.generatedFCPXMLSummary(subtitleCount: subtitles.count)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.generated("FCPXML"))
    }

    func copyFCPXML() {
        guard generatedFCPXML.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.nothingToCopy("内容"))
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedFCPXML, forType: .string)
        ToastManager.shared.show(.success, ToolStatusLabelFormatter.copiedToClipboard("FCPXML"))
    }

    func downloadFCPXML() {
        guard generatedFCPXML.isEmpty == false else {
            ToastManager.shared.show(.warning, ToolStatusLabelFormatter.noContentToGenerate("下载的内容"))
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.xml]
        savePanel.nameFieldStringValue = "subtitles.fcpxml"
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try generatedFCPXML.write(to: url, atomically: true, encoding: .utf8)
                lastSavedURL = url
                ToastManager.shared.show(.success, ToolStatusLabelFormatter.saved("文件"))
            } catch {
                ToastManager.shared.show(.error, ToolStatusLabelFormatter.saveFailed(error.localizedDescription))
            }
        }
    }

    func openSavedFile() {
        guard let lastSavedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastSavedURL])
    }

    func clear() {
        subtitles = []
        originalSubtitles = []
        errorMessage = nil
        statusText = ToolStatusLabelFormatter.waitingToImport("SRT")
        isLoading = false
        generatedFCPXML = ""
        lastSavedURL = nil
    }
}

struct SRTTFCPXMLPanel: View {
    @StateObject private var viewModel = SRTTFCPXMLViewModel()

    var body: some View {
        ZStack {
            AppVisualBackdrop()

            VStack(spacing: 0) {
                header

                Divider()

                HStack(alignment: .top, spacing: 16) {
                    AppSurfaceCard(title: "字幕列表", subtitle: "输入与解析结果", padding: 14) {
                        leftPanel
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 600)

                    AppSurfaceCard(title: "导出操作", subtitle: "保存和复制结果", padding: 14) {
                        rightPanel
                    }
                    .frame(width: 240)
                }
                .padding(20)

                Divider()

                bottomBar
            }
        }
        .frame(width: 1040, height: 700)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SRT → FCPXML 字幕转换")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("将 SRT 字幕文件转换为 Final Cut Pro 的 FCPXML 格式。")
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

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("字幕列表")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.subtitles.count) 条")
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Button {
                    viewModel.loadFromClipboard()
                } label: {
                    Label("从剪贴板导入", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.subtitles) { sub in
                        SubtitleRow(
                            subtitle: sub,
                            onDelete: { viewModel.deleteSubtitle(at: viewModel.subtitles.firstIndex(where: { $0.id == sub.id }) ?? 0) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 340)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppSurfaceTokens.secondaryText.opacity(0.18), lineWidth: 1)
            )

            if !viewModel.originalSubtitles.isEmpty {
                batchOperationsCard
            }
        }
    }

    private var batchOperationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("批量操作")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                TextField("查找", text: $viewModel.batchFindText)
                    .textFieldStyle(.roundedBorder)

                TextField("替换为", text: $viewModel.batchReplaceText)
                    .textFieldStyle(.roundedBorder)

                Button("替换") {
                    viewModel.batchReplace()
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                TextField("删除关键词", text: $viewModel.deleteKeyword)
                    .textFieldStyle(.roundedBorder)

                Button("删除") {
                    viewModel.deleteByKeyword()
                }
                .buttonStyle(.bordered)

                Button("恢复原始") {
                    viewModel.restoreOriginal()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("合成设置")
                .font(.headline)

            AppSurfaceCard(title: "时间轴", subtitle: "帧率与合成节奏", padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("FPS")
                        Spacer()
                        Picker("", selection: $viewModel.fps) {
                            Text("24").tag(24)
                            Text("25").tag(25)
                            Text("30").tag(30)
                            Text("60").tag(60)
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }
                }
            }

            AppSurfaceCard(title: "分辨率", subtitle: "输出尺寸与预设", padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("预设", selection: Binding(
                        get: { "\(viewModel.width)x\(viewModel.height)" },
                        set: { new in
                            switch new {
                            case "3840x2160": viewModel.width = 3840; viewModel.height = 2160
                            case "1280x720": viewModel.width = 1280; viewModel.height = 720
                            default: viewModel.width = 1920; viewModel.height = 1080
                            }
                        }
                    )) {
                        Text("1920×1080").tag("1920x1080")
                        Text("3840×2160").tag("3840x2160")
                        Text("1280×720").tag("1280x720")
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("\(viewModel.width) × \(viewModel.height)")
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
            }

            Text("样式检查器")
                .font(.headline)
                .padding(.top, 8)

            AppSurfaceCard(title: "文本样式", subtitle: "字体、字号和对齐方式", padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("字体")
                        Spacer()
                        Picker("", selection: $viewModel.fontFace) {
                            Text("苹方").tag("PingFang SC")
                            Text("黑体").tag("Hei SC")
                            Text("宋体").tag("STSong")
                            Text("Helvetica").tag("Helvetica")
                            Text("Arial").tag("Arial")
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }

                    HStack {
                        Text("大小")
                        Spacer()
                        TextField("", value: $viewModel.fontSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("px")
                            .font(.caption)
                    }

                    HStack {
                        Text("对齐")
                        Spacer()
                        Picker("", selection: $viewModel.alignment) {
                            Text("居中").tag("center")
                            Text("左对齐").tag("left")
                            Text("右对齐").tag("right")
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                }
            }

            AppSurfaceCard(title: "位置", subtitle: "标题坐标", padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("X")
                        Spacer()
                        TextField("", value: $viewModel.titleX, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }

                    HStack {
                        Text("Y")
                        Spacer()
                        TextField("", value: $viewModel.titleY, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                }
            }

            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.generateFCPXML()
            } label: {
                Label("生成 FCPXML", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.subtitles.isEmpty)

            Button {
                viewModel.copyFCPXML()
            } label: {
                Label("复制结果", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.hasGenerated)

            Button {
                viewModel.downloadFCPXML()
            } label: {
                Label("下载 .fcpxml", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.hasGenerated)

            Button {
                viewModel.openSavedFile()
            } label: {
                Label("打开文件", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.lastSavedURL == nil)

            Spacer()

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
            }

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(16)
    }
}

struct SubtitleRow: View {
    let subtitle: SRTSubtitle
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(subtitle.index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .frame(width: 30, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(subtitle.text)
                    .font(.body)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Text("\(subtitle.startTimeString) → \(subtitle.endTimeString)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
    }
}
