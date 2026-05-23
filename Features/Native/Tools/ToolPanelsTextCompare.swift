import AppKit
import SwiftUI

struct TextComparePanel: View {
    @StateObject private var viewModel: TextCompareViewModel

    init(toastManager: ToastManager) {
        self._viewModel = StateObject(wrappedValue: TextCompareViewModel(toastManager: toastManager))
    }

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
        .frame(width: 940, height: 760)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("文本对比")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("逐行比较两段文本，并给出删除、插入和相同内容。")
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
            Text("适合快速看两段文本到底改了哪里。")
                .font(.body)

            Text("这是逐行 LCS 对比，足够应付大多数文案、配置和 Markdown 变化。")
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
                    viewModel.compare()
                } label: {
                    Text(viewModel.isWorking ? "处理中..." : "开始比较")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isWorking)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("左侧文本")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)

                    TextEditor(text: $viewModel.leftText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 210)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("右侧文本")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)

                    TextEditor(text: $viewModel.rightText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 210)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        )
                }
            }

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(Color.secondary)

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
            }

            Text(viewModel.summaryText.isEmpty ? "比较完成后会显示摘要" : viewModel.summaryText)
                .font(.caption)
                .foregroundStyle(Color.secondary)

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
final class TextCompareViewModel: ObservableObject {
    @Published var leftText = ""
    @Published var rightText = ""
    @Published var diffLines: [DiffLine] = []
    @Published var summaryText = ""
    @Published var statusText = "等待输入两段文本"
    @Published var errorMessage: String?
    @Published var isWorking = false
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

    func clear() {
        leftText = ""
        rightText = ""
        diffLines = []
        summaryText = ""
        statusText = "等待输入两段文本"
        errorMessage = nil
        isWorking = false
    }

    func compare() {
        let leftLines = splitLines(leftText)
        let rightLines = splitLines(rightText)

        guard leftLines.isEmpty == false || rightLines.isEmpty == false else {
            errorMessage = "请输入两段文本再开始比较"
            statusText = "等待输入两段文本"
            toastManager.show(.warning, "请输入两段文本")
            return
        }

        isWorking = true
        errorMessage = nil

        let result = TextComparisonSupport.compare(leftLines: leftLines, rightLines: rightLines)
        diffLines = result.lines
        summaryText = result.summary
        statusText = "比较完成"
        toastManager.show(.success, "文本对比已完成")

        isWorking = false
    }

    func copySummary() {
        guard summaryText.isEmpty == false else {
            toastManager.show(.warning, "没有可复制的摘要")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summaryText, forType: .string)
        toastManager.show(.success, "摘要已复制")
    }

    private func splitLines(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}
