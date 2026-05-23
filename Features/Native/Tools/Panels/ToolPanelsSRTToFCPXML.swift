import AppKit
import SwiftUI

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
    @Published var statusText = "等待导入 SRT"
    @Published var isLoading = false
    @Published var generatedFCPXML: String = ""

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
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

    var hasSubtitles: Bool { !subtitles.isEmpty }
    var hasGenerated: Bool { !generatedFCPXML.isEmpty }

    func loadFromClipboard() {
        guard let content = NSPasteboard.general.string(forType: .string), !content.isEmpty else {
            errorMessage = nil
            statusText = "剪贴板为空"
            toastManager.show(.warning, "剪贴板为空")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            subtitles = try SRTParser.parse(content)
            originalSubtitles = subtitles
            statusText = "已导入 \(subtitles.count) 条字幕"
            toastManager.show(.success, "已导入 \(subtitles.count) 条字幕")
        } catch {
            subtitles = []
            originalSubtitles = []
            errorMessage = error.localizedDescription
            statusText = "解析失败"
            toastManager.show(.error, error.localizedDescription)
        }

        isLoading = false
    }

    func batchReplace() {
        let find = batchFindText
        let replace = batchReplaceText
        guard find.isEmpty == false else {
            toastManager.show(.warning, "请输入要替换的内容")
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

        statusText = "已批量替换 \(find) → \(replace.isEmpty ? "(空)" : replace)"
        toastManager.show(.success, "批量替换完成")
    }

    func deleteByKeyword() {
        let keyword = deleteKeyword
        guard keyword.isEmpty == false else {
            toastManager.show(.warning, "请输入要删除的关键词")
            return
        }

        let before = subtitles.count
        subtitles = subtitles.filter { !$0.text.contains(keyword) }
        let removed = before - subtitles.count

        if removed > 0 {
            statusText = "已删除包含「\(keyword)」的 \(removed) 条字幕"
            toastManager.show(.success, "已删除 \(removed) 条字幕")
        } else {
            statusText = "没有找到包含「\(keyword)」的字幕"
            toastManager.show(.info, "没有找到匹配的字幕")
        }
    }

    func deleteSubtitle(at index: Int) {
        guard index >= 0 && index < subtitles.count else { return }
        subtitles.remove(at: index)
        statusText = "已删除第 \(index + 1) 条字幕"
        toastManager.show(.success, "已删除字幕")
    }

    func restoreOriginal() {
        subtitles = originalSubtitles
        statusText = "已恢复原始字幕"
        toastManager.show(.info, "已恢复原始字幕")
    }

    func generateFCPXML() {
        guard subtitles.isEmpty == false else {
            toastManager.show(.warning, "没有可生成的字幕")
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

        statusText = "已生成 FCPXML，包含 \(subtitles.count) 条字幕"
        toastManager.show(.success, "FCPXML 已生成")
    }

    func copyFCPXML() {
        guard generatedFCPXML.isEmpty == false else {
            toastManager.show(.warning, "没有可复制的内容")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedFCPXML, forType: .string)
        toastManager.show(.success, "FCPXML 已复制到剪贴板")
    }

    func downloadFCPXML() {
        guard generatedFCPXML.isEmpty == false else {
            toastManager.show(.warning, "没有可下载的内容")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.xml]
        savePanel.nameFieldStringValue = "subtitles.fcpxml"
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try generatedFCPXML.write(to: url, atomically: true, encoding: .utf8)
                toastManager.show(.success, "文件已保存")
            } catch {
                toastManager.show(.error, "保存失败: \(error.localizedDescription)")
            }
        }
    }

    func clear() {
        subtitles = []
        originalSubtitles = []
        errorMessage = nil
        statusText = "等待导入 SRT"
        isLoading = false
        generatedFCPXML = ""
    }
}

struct SRTTFCPXMLPanel: View {
    @StateObject private var viewModel: SRTTFCPXMLViewModel
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
        self._viewModel = StateObject(wrappedValue: SRTTFCPXMLViewModel(toastManager: toastManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(alignment: .top, spacing: 16) {
                leftPanel
                    .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 600)

                rightPanel
                    .frame(width: 280)
            }
            .padding(20)

            Divider()

            bottomBar
        }
        .frame(width: 1100, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SRT → FCPXML 字幕转换")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("将 SRT 字幕文件转换为 Final Cut Pro 的 FCPXML 格式。")
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

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("字幕列表")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.subtitles.count) 条")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)

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
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("合成设置")
                .font(.headline)

            GroupBox("时间轴") {
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

            GroupBox("分辨率") {
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
                            .foregroundStyle(Color.secondary)
                    }
                }
            }

            Text("样式检查器")
                .font(.headline)
                .padding(.top, 8)

            GroupBox("文本样式") {
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

            GroupBox("位置") {
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

            Spacer()

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.red)
            }

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(Color.secondary)
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
                .foregroundStyle(Color.secondary)
                .frame(width: 30, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(subtitle.text)
                    .font(.body)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Text("\(subtitle.startTimeString) → \(subtitle.endTimeString)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(Color.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
