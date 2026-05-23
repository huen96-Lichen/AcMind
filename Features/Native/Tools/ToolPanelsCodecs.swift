import AppKit
import SwiftUI

// MARK: - JSON Formatter Panel

struct JSONFormatterPanel: View {
    @StateObject private var viewModel: JSONFormatterViewModel

    init(toastManager: ToastManager) {
        self._viewModel = StateObject(wrappedValue: JSONFormatterViewModel(toastManager: toastManager))
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
        .frame(width: 860, height: 720)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("JSON 格式化")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("粘贴 JSON，直接美化、压缩、校验并复制结果。")
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
            Text("支持对象、数组、字符串、数字、布尔值和 `null`。")
                .font(.body)

            Text("如果是 JSON 片段，面板会先解析再重新输出；如果解析失败，会直接告诉你哪里不合法。")
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
                    viewModel.format(pretty: true)
                } label: {
                    Text(viewModel.isWorking ? "处理中..." : "美化 JSON")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isWorking)

                Button {
                    viewModel.format(pretty: false)
                } label: {
                    Text(viewModel.isWorking ? "处理中..." : "压缩 JSON")
                }
                .buttonStyle(.bordered)
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
                .frame(minHeight: 220)
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
final class JSONFormatterViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var outputText = ""
    @Published var statusText = "等待输入 JSON"
    @Published var errorMessage: String?
    @Published var isWorking = false
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

    func clear() {
        inputText = ""
        outputText = ""
        statusText = "等待输入 JSON"
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

    func format(pretty: Bool) {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            errorMessage = "请输入 JSON 再执行格式化"
            statusText = "等待输入 JSON"
            toastManager.show(.warning, "请输入 JSON")
            return
        }

        isWorking = true
        errorMessage = nil

        do {
            outputText = try JSONFormattingSupport.format(trimmed, pretty: pretty)
            statusText = pretty ? "JSON 已美化" : "JSON 已压缩"
            toastManager.show(.success, pretty ? "JSON 已美化" : "JSON 已压缩")
        } catch {
            outputText = ""
            statusText = "格式化失败"
            errorMessage = error.localizedDescription
            toastManager.show(.error, error.localizedDescription)
        }

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
    @StateObject private var viewModel: Base64CodecViewModel

    init(toastManager: ToastManager) {
        self._viewModel = StateObject(wrappedValue: Base64CodecViewModel(toastManager: toastManager))
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
        .frame(width: 860, height: 720)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Base64 编解码")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("文本和 Base64 互转，支持直接复制结果。")
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
            Text("支持文本编码与 Base64 解码。")
                .font(.body)

            Text("如果解码后的内容不是 UTF-8 文本，面板会转成十六进制预览，方便你确认原始字节。")
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

                Picker("模式", selection: $viewModel.mode) {
                    ForEach(Base64CodecMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
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
                    viewModel.execute()
                } label: {
                    Text(viewModel.isWorking ? "处理中..." : viewModel.mode.actionTitle)
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
                .frame(minHeight: 220)
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
    @Published var statusText = "等待输入文本"
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var mode: Base64CodecMode = .encode
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

    func clear() {
        inputText = ""
        outputText = ""
        statusText = "等待输入文本"
        errorMessage = nil
        isWorking = false
        mode = .encode
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

    func execute() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            errorMessage = "请输入文本再执行 Base64 操作"
            statusText = "等待输入文本"
            toastManager.show(.warning, "请输入文本")
            return
        }

        isWorking = true
        errorMessage = nil

        switch mode {
        case .encode:
            outputText = Data(trimmed.utf8).base64EncodedString()
            statusText = "已编码为 Base64"
            toastManager.show(.success, "已编码为 Base64")

        case .decode:
            let normalized = trimmed.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            guard let data = Data(base64Encoded: normalized, options: [.ignoreUnknownCharacters]) else {
                outputText = ""
                statusText = "解码失败"
                errorMessage = "输入不是有效的 Base64 字符串"
                toastManager.show(.error, "输入不是有效的 Base64 字符串")
                isWorking = false
                return
            }

            if let decoded = String(data: data, encoding: .utf8) {
                outputText = decoded
                statusText = "已解码为文本"
                toastManager.show(.success, "已解码为文本")
            } else {
                outputText = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                statusText = "已解码为字节十六进制"
                toastManager.show(.warning, "内容不是 UTF-8，已显示十六进制")
            }
        }

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
