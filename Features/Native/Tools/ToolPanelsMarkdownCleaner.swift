import AppKit
import SwiftUI

struct MarkdownCleanerPanel: View {
    @StateObject private var viewModel: MarkdownCleanerViewModel

    init(toastManager: ToastManager) {
        self._viewModel = StateObject(wrappedValue: MarkdownCleanerViewModel(toastManager: toastManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    inputCard
                    outputCard
                }
                .padding(20)
            }
        }
        .frame(width: 860, height: 740)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Markdown 整理")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("清理多余空行、尾随空格和一些常见排版噪音。")
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
            Text("适合把剪贴板里的 Markdown 草稿快速收拾一下。")
                .font(.body)

            Text("会保留代码块内容，减少连着的空行，并清掉尾随空格。")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
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

            TextEditor(text: $viewModel.inputText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )

            HStack(spacing: 10) {
                Button {
                    viewModel.clean()
                } label: {
                    Text(viewModel.isWorking ? "处理中..." : "整理 Markdown")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isWorking)

                Spacer()

                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
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

            TextEditor(text: $viewModel.outputText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 240)
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
final class MarkdownCleanerViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var outputText = ""
    @Published var statusText = "等待输入 Markdown"
    @Published var errorMessage: String?
    @Published var isWorking = false
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

    func clear() {
        inputText = ""
        outputText = ""
        statusText = "等待输入 Markdown"
        errorMessage = nil
        isWorking = false
    }

    func loadFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string), !string.isEmpty {
            inputText = string
            statusText = "已读取剪贴板内容"
            errorMessage = nil
        } else {
            toastManager.show(.warning, "剪贴板里没有可用文本")
        }
    }

    func clean() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            errorMessage = "请输入 Markdown 再执行整理"
            statusText = "等待输入 Markdown"
            toastManager.show(.warning, "请输入 Markdown")
            return
        }

        isWorking = true
        errorMessage = nil

        let result = MarkdownCleaningSupport.clean(trimmed)
        outputText = result.text
        statusText = "已整理 Markdown，清理了 \(result.trimmedTrailingSpaces) 处尾随空格，压缩了 \(result.collapsedBlankLines) 处空行"
        toastManager.show(.success, "Markdown 已整理")

        isWorking = false
    }

    func copyOutput() {
        guard outputText.isEmpty == false else {
            toastManager.show(.warning, "没有可复制的结果")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        toastManager.show(.success, "结果已复制")
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

private extension String {
    func trimmingTrailingWhitespace() -> String {
        replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
    }
}
