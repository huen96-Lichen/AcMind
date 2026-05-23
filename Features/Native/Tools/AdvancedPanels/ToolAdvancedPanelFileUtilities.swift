import AppKit
import AcMindKit
import SwiftUI

// MARK: - Batch Rename

struct BatchRenamePanel: View {
    @StateObject private var viewModel: BatchRenameViewModel
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
        self._viewModel = StateObject(wrappedValue: BatchRenameViewModel(toastManager: toastManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    folderCard
                    rulesCard
                    previewCard
                }
                .padding(20)
            }
        }
        .frame(width: 980, height: 860)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("批量重命名")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("对文件夹中的一级项目批量改名，支持前缀、后缀、替换和预览。")
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
            Text("只处理所选文件夹的一级条目，先预览再执行。")
                .font(.body)

            Text("这样能尽量避免误改和路径连锁反应。")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
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
                    viewModel.refreshPreview()
                } label: {
                    Label("刷新预览", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.folderURL == nil)

                Button {
                    viewModel.applyRename()
                } label: {
                    Text(viewModel.isRenaming ? "处理中..." : "执行重命名")
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
                        .foregroundStyle(Color.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text("还没有选择文件夹。")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
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

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("重命名规则")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("前缀")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    TextField("例如 new_", text: $viewModel.prefixText)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("查找")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    TextField("要替换的文字", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("替换为")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    TextField("替换成", text: $viewModel.replaceText)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("后缀")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
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
                    Label("应用到预览", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("预览")
                    .font(.headline)

                Spacer()

                Text("共 \(viewModel.previewItems.count) 项")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
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
    @Published var statusText = "请选择文件夹"
    @Published var errorMessage: String?
    @Published var isRenaming = false
    @Published var prefixText = ""
    @Published var searchText = ""
    @Published var replaceText = ""
    @Published var suffixText = ""
    @Published var includeFolders = true
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

    func clear() {
        folderURL = nil
        previewItems = []
        statusText = "请选择文件夹"
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
            statusText = "已选择文件夹，正在读取文件"
            refreshPreview()
        }
    }

    func refreshPreview() {
        guard let folderURL else {
            toastManager.show(.warning, "请选择文件夹")
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

            statusText = previewItems.isEmpty ? "文件夹为空" : "已生成预览"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusText = "读取文件夹失败"
        }
    }

    func applyRename() {
        guard folderURL != nil else {
            toastManager.show(.warning, "请选择文件夹")
            return
        }

        guard previewItems.isEmpty == false else {
            toastManager.show(.warning, "没有可重命名的项目")
            return
        }

        let targetPaths = Set(previewItems.map(\.proposedURL.path))
        if targetPaths.count != previewItems.count {
            errorMessage = "预览中存在重复目标名称，请先调整规则"
            statusText = "存在命名冲突"
            toastManager.show(.error, "预览中存在重复目标名称")
            return
        }

        isRenaming = true
        errorMessage = nil
        statusText = "正在重命名..."

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

            toastManager.show(.success, "批量重命名完成")
            statusText = "重命名完成"
            if let folderURL {
                let refreshedFolder = folderURL
                self.folderURL = refreshedFolder
                refreshPreview()
            }
        } catch {
            errorMessage = error.localizedDescription
            statusText = "重命名失败"
            toastManager.show(.error, error.localizedDescription)
        }

        isRenaming = false
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
                .foregroundStyle(item.isDirectory ? Color.orange : Color.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalURL.lastPathComponent)
                    .font(.body)
                    .foregroundStyle(Color.primary)

                Text(item.originalURL.path)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .foregroundStyle(Color.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.proposedURL.lastPathComponent)
                    .font(.body)
                    .foregroundStyle(Color.primary)

                Text(item.proposedURL.path)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05))
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
        VStack(alignment: .leading, spacing: 16) {
            Text("SRT → FCPXML 转换器")
                .font(.title2)
                .fontWeight(.semibold)

            Text("将 SRT 字幕文件转换为 Final Cut Pro 可用的 FCPXML 格式")
                .font(.caption)
                .foregroundStyle(Color.secondary)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SRT 内容")
                        .font(.headline)
                    TextEditor(text: $srtContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("FCPXML 输出")
                        .font(.headline)
                    TextEditor(text: .constant(convertedXML))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .disabled(true)
                }
            }

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
                    Text("已复制!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 500)
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
