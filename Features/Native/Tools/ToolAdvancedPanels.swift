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

// MARK: - SRT Workbook FCPXML Converter

struct SRTWorkbenchFCPXMLSubtitle: Identifiable, Equatable {
    let id = UUID()
    var index: Int
    var startMs: Int
    var endMs: Int
    var text: String

    var startTimeString: String { Self.formatTime(startMs) }
    var endTimeString: String { Self.formatTime(endMs) }

    private static func formatTime(_ ms: Int) -> String {
        let safeMs = max(0, ms)
        let hours = safeMs / 3_600_000
        let minutes = (safeMs % 3_600_000) / 60_000
        let seconds = (safeMs % 60_000) / 1_000
        let millis = safeMs % 1_000
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, millis)
    }
}

struct SRTWorkbenchFCPXMLInspectorSettings: Equatable {
    var x: Double
    var y: Double
    var fontFamily: String
    var fontFace: String
    var fontSize: Double
    var alignment: String
}

enum SRTWorkbenchFCPXMLParser {
    struct ParseError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    private static let timeRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"^(\d{2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{1,3})$"#,
            options: []
        )
    }()

    static func parse(_ content: String) throws -> [SRTWorkbenchFCPXMLSubtitle] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.isEmpty == false else {
            return []
        }

        let blocks = normalized.components(separatedBy: "\n\n")
        var subtitles: [SRTWorkbenchFCPXMLSubtitle] = []

        for (blockIndex, block) in blocks.enumerated() {
            let lines = block
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.isEmpty == false }

            guard lines.count >= 2 else { continue }

            var timeLineIndex = 0
            if lines[0].range(of: #"^\d+$"#, options: .regularExpression) != nil {
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

            let text = lines[(timeLineIndex + 1)...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty == false else { continue }

            subtitles.append(
                SRTWorkbenchFCPXMLSubtitle(
                    index: subtitles.count + 1,
                    startMs: startMs,
                    endMs: endMs,
                    text: text
                )
            )
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
        var ms = (line as NSString).substring(with: msRange)
        while ms.count < 3 {
            ms += "0"
        }

        return (((h * 60) + m) * 60 + s) * 1_000 + (Int(ms) ?? 0)
    }
}

enum SRTWorkbenchFCPXMLGenerator {
    static func generate(
        subtitles: [SRTWorkbenchFCPXMLSubtitle],
        fps: Int,
        width: Int,
        height: Int,
        inspector: SRTWorkbenchFCPXMLInspectorSettings
    ) -> String {
        let timeline = buildContiguousTimeline(subtitles: subtitles, fps: fps)
        let durationFrames = timeline.last?.endFrame ?? max(fps, 1)
        let frameDuration = "1/\(fps)s"
        let projectDuration = "\(durationFrames)/\(fps)s"
        let titleEffectID = "r2"
        let position = toTitlePosition(x: inspector.x, y: inspector.y, width: width, height: height)

        let titleBlocks = timeline.map { subtitle in
            let styleID = "ts\(UUID().uuidString.prefix(8).lowercased())"
            let titleName = xmlEscape(buildTitleName(subtitle.text, index: subtitle.index))
            let text = xmlEscape(subtitle.text)
            let offset = "\(subtitle.startFrame)/\(fps)s"
            let duration = "\(subtitle.durationFrames)/\(fps)s"

            return """
                          <title ref="\(titleEffectID)" name="\(titleName)" lane="1" offset="\(offset)" start="0s" duration="\(duration)" role="title.title-1">
                            <param name="展平" key="9999/999166631/999166633/2/351" value="1" />
                            <param name="对齐" key="9999/999166631/999166633/2/354/999169573/401" value="\(alignmentLabel(for: inspector.alignment))" />
                            <param name="颜色" key="9999/999166631/999166633/5/999166635/14/16" value="1 1 1" />
                            <param name="融合模式" key="9999/999166631/999166633/5/999166635/14/18/5" value="1 (重复)" />
                            <param name="宽度" key="9999/999166631/999166633/5/999166635/30/36" value="2.5" />
                            <text>
                              <text-style ref="\(styleID)">\(text)</text-style>
                            </text>
                            <text-style-def id="\(styleID)">
                              <text-style font="\(xmlEscape(inspector.fontFamily))" fontSize="\(max(1, Int(inspector.fontSize.rounded())))" fontFace="\(xmlEscape(inspector.fontFace))" fontColor="1 1 1 1" strokeColor="0 0 0 1" strokeWidth="-2.5" alignment="\(inspector.alignment)" />
                            </text-style-def>
                            <adjust-transform position="\(position.x) \(position.y)" anchor="0 0" scale="1 1" />
                          </title>
            """
        }.joined(separator: "\n")

        return """
        <?xml version='1.0' encoding='utf-8'?>
        <fcpxml version="1.14">
          <resources>
            <format id="r1" frameDuration="\(frameDuration)" width="\(width)" height="\(height)" colorSpace="1-1-1 (Rec. 709)" />
            <effect id="\(titleEffectID)" name="基本字幕" uid=".../Titles.localized/Bumper:Opener.localized/Basic Title.localized/Basic Title.moti" />
          </resources>
          <library>
            <event name="SRT Import">
              <project name="SRT to FCPXML">
                <sequence format="r1" duration="\(projectDuration)" tcStart="0s" tcFormat="NDF" audioLayout="stereo" audioRate="48k">
                  <spine>
                    <gap name="Subtitle Gap" offset="0s" start="0s" duration="\(projectDuration)">
        \(titleBlocks)
                    </gap>
                  </spine>
                </sequence>
              </project>
            </event>
          </library>
        </fcpxml>
        """
    }

    private struct TimelineSubtitle {
        let index: Int
        let startFrame: Int
        let durationFrames: Int
        let endFrame: Int
        let text: String
    }

    private static func buildContiguousTimeline(subtitles: [SRTWorkbenchFCPXMLSubtitle], fps: Int) -> [TimelineSubtitle] {
        var previousEndFrame = 0

        return subtitles.enumerated().map { offset, subtitle in
            let durationFrames = max(1, Int(round(Double(subtitle.endMs - subtitle.startMs) * Double(fps) / 1_000.0)))
            let originalStartFrame = max(0, Int(round(Double(subtitle.startMs) * Double(fps) / 1_000.0)))
            let startFrame = offset == 0 ? originalStartFrame : previousEndFrame
            let endFrame = startFrame + durationFrames
            previousEndFrame = endFrame

            return TimelineSubtitle(
                index: subtitle.index,
                startFrame: startFrame,
                durationFrames: durationFrames,
                endFrame: endFrame,
                text: subtitle.text
            )
        }
    }

    private static func toTitlePosition(x: Double, y: Double, width: Int, height: Int) -> (x: String, y: String) {
        let scaleX = max(Double(width) / 100.0, 0.0001)
        let scaleY = max(Double(height) / 100.0, 0.0001)
        return (
            x: String(format: "%.4f", x / scaleX),
            y: String(format: "%.4f", y / scaleY)
        )
    }

    private static func buildTitleName(_ text: String, index: Int) -> String {
        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        let compact = firstLine
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard compact.isEmpty == false else {
            return "字幕 \(index)"
        }

        if compact.count > 28 {
            return String(compact.prefix(28)) + "..."
        }
        return compact
    }

    private static func alignmentLabel(for alignment: String) -> String {
        switch alignment {
        case "left":
            return "0 (左)"
        case "right":
            return "2 (右)"
        default:
            return "1 (居中)"
        }
    }

    private static func xmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

@MainActor
final class SRTWorkbenchFCPXMLViewModel: ObservableObject {
    @Published var subtitles: [SRTWorkbenchFCPXMLSubtitle] = []
    @Published var originalSubtitles: [SRTWorkbenchFCPXMLSubtitle] = []
    @Published var rawSRTContent = ""
    @Published var sourceFileName = ""
    @Published var errorMessage: String?
    @Published var statusText = "等待导入 SRT"
    @Published var isImporting = false
    @Published var generatedFCPXML = ""

    @Published var fps = 25
    @Published var width = 1920
    @Published var height = 1080
    @Published var positionX = 0.0
    @Published var positionY = -360.0
    @Published var fontFamily = "PingFang SC"
    @Published var fontFace = "Regular"
    @Published var fontSize = 54.0
    @Published var alignment = "center"

    @Published var batchFindText = ""
    @Published var batchReplaceText = ""
    @Published var deleteKeyword = ""

    var hasSubtitles: Bool {
        subtitles.isEmpty == false
    }

    var hasGeneratedXML: Bool {
        generatedFCPXML.isEmpty == false
    }

    var outputFileName: String {
        let baseName: String
        if sourceFileName.isEmpty {
            baseName = "subtitles"
        } else {
            baseName = URL(fileURLWithPath: sourceFileName).deletingPathExtension().lastPathComponent
        }
        return baseName + ".fcpxml"
    }

    func importFromFile(url: URL) {
        isImporting = true
        defer { isImporting = false }

        do {
            let data = try Data(contentsOf: url)
            importFromData(data, sourceName: url.lastPathComponent)
        } catch {
            fail(error.localizedDescription, status: "读取文件失败")
        }
    }

    func importFromClipboard() {
        guard let content = NSPasteboard.general.string(forType: .string), content.isEmpty == false else {
            fail("剪贴板为空", status: "剪贴板为空")
            return
        }

        loadSRT(content, sourceName: "clipboard.srt")
    }

    func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            return false
        }

        provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] url, error in
            if let error {
                Task { @MainActor in
                    self?.fail(error.localizedDescription, status: "拖拽读取失败")
                }
                return
            }

            guard let url else {
                Task { @MainActor in
                    self?.fail("未能读取拖拽文件", status: "拖拽读取失败")
                }
                return
            }

            do {
                let data = try Data(contentsOf: url)
                Task { @MainActor in
                    self?.importFromData(data, sourceName: url.lastPathComponent)
                }
            } catch {
                Task { @MainActor in
                    self?.fail(error.localizedDescription, status: "拖拽读取失败")
                }
            }
        }

        return true
    }

    func reloadFromOriginalSource() {
        guard rawSRTContent.isEmpty == false else {
            fail("当前没有可重新解析的原始 SRT", status: "没有原始内容")
            return
        }

        loadSRT(rawSRTContent, sourceName: sourceFileName)
    }

    func restoreOriginalSubtitles() {
        guard originalSubtitles.isEmpty == false else {
            fail("当前没有可恢复的原始字幕", status: "没有原始字幕")
            return
        }

        subtitles = originalSubtitles
        renumberSubtitles()
        statusText = "已恢复原始字幕"
        errorMessage = nil
        generateFCPXML(showToast: false)
    }

    func batchReplace() {
        let find = batchFindText
        guard find.isEmpty == false else {
            fail("请输入要替换的内容", status: "缺少替换文本")
            return
        }

        let replace = batchReplaceText
        subtitles = subtitles.map { subtitle in
            var updated = subtitle
            updated.text = updated.text.replacingOccurrences(of: find, with: replace)
            return updated
        }
        renumberSubtitles()
        statusText = "已批量替换 \(find) → \(replace.isEmpty ? "(空)" : replace)"
        errorMessage = nil
        generateFCPXML(showToast: false)
    }

    func deleteByKeyword() {
        let keyword = deleteKeyword
        guard keyword.isEmpty == false else {
            fail("请输入要删除的关键词", status: "缺少关键词")
            return
        }

        let before = subtitles.count
        subtitles.removeAll { $0.text.contains(keyword) }
        let removed = before - subtitles.count

        renumberSubtitles()
        if removed > 0 {
            statusText = "已删除包含「\(keyword)」的 \(removed) 条字幕"
            errorMessage = nil
        } else {
            statusText = "没有找到包含「\(keyword)」的字幕"
        }
        generateFCPXML(showToast: false)
    }

    func deleteSubtitle(at index: Int) {
        guard subtitles.indices.contains(index) else {
            return
        }

        subtitles.remove(at: index)
        renumberSubtitles()
        statusText = "已删除第 \(index + 1) 条字幕"
        errorMessage = nil
        generateFCPXML(showToast: false)
    }

    func generateFCPXML(showToast: Bool = true) {
        let activeSubtitles = subtitles.filter { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        guard activeSubtitles.isEmpty == false else {
            generatedFCPXML = ""
            statusText = subtitles.isEmpty ? "请先导入 SRT" : "当前没有可生成的字幕"
            if showToast {
                ToastManager.shared.show(.warning, "没有可生成的字幕")
            }
            return
        }

        let inspector = SRTWorkbenchFCPXMLInspectorSettings(
            x: positionX,
            y: positionY,
            fontFamily: fontFamily,
            fontFace: fontFace,
            fontSize: fontSize,
            alignment: alignment
        )

        generatedFCPXML = SRTWorkbenchFCPXMLGenerator.generate(
            subtitles: activeSubtitles,
            fps: max(1, fps),
            width: max(1, width),
            height: max(1, height),
            inspector: inspector
        )

        statusText = "已生成 FCPXML，包含 \(activeSubtitles.count) 条字幕"
        errorMessage = nil
        if showToast {
            ToastManager.shared.show(.success, "FCPXML 已生成")
        }
    }

    func copyFCPXML() {
        guard generatedFCPXML.isEmpty == false else {
            fail("没有可复制的内容", status: "请先生成 FCPXML")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedFCPXML, forType: .string)
        ToastManager.shared.show(.success, "FCPXML 已复制到剪贴板")
    }

    func downloadFCPXML() {
        guard generatedFCPXML.isEmpty == false else {
            fail("没有可下载的内容", status: "请先生成 FCPXML")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = outputFileName
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try generatedFCPXML.write(to: url, atomically: true, encoding: .utf8)
                statusText = "文件已保存"
                ToastManager.shared.show(.success, "文件已保存")
            } catch {
                fail("保存失败: \(error.localizedDescription)", status: "保存失败")
            }
        }
    }

    func clear() {
        subtitles = []
        originalSubtitles = []
        rawSRTContent = ""
        sourceFileName = ""
        errorMessage = nil
        statusText = "等待导入 SRT"
        isImporting = false
        generatedFCPXML = ""
        batchFindText = ""
        batchReplaceText = ""
        deleteKeyword = ""
    }

    private func importFromData(_ data: Data, sourceName: String) {
        guard let content = decodeSRTData(data) else {
            fail("无法识别 SRT 编码，请确保文件可由 UTF-8/UTF-16 读取", status: "读取文件失败")
            return
        }
        loadSRT(content, sourceName: sourceName)
    }

    private func loadSRT(_ content: String, sourceName: String) {
        isImporting = true
        defer { isImporting = false }

        do {
            let parsed = try SRTWorkbenchFCPXMLParser.parse(content)
            rawSRTContent = content
            sourceFileName = sourceName
            subtitles = parsed
            originalSubtitles = parsed
            renumberSubtitles()
            errorMessage = nil
            statusText = "已导入 \(parsed.count) 条字幕"
            generateFCPXML(showToast: false)
            ToastManager.shared.show(.success, "已导入 \(parsed.count) 条字幕")
        } catch {
            subtitles = []
            originalSubtitles = []
            generatedFCPXML = ""
            fail(error.localizedDescription, status: "解析失败")
        }
    }

    private func decodeSRTData(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }
        if let utf16LittleEndian = String(data: data, encoding: .utf16LittleEndian) {
            return utf16LittleEndian
        }
        if let utf16BigEndian = String(data: data, encoding: .utf16BigEndian) {
            return utf16BigEndian
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func renumberSubtitles() {
        for index in subtitles.indices {
            subtitles[index].index = index + 1
        }
        for index in originalSubtitles.indices {
            originalSubtitles[index].index = index + 1
        }
    }

    private func fail(_ message: String, status: String) {
        errorMessage = message
        statusText = status
        ToastManager.shared.show(.error, message)
    }
}

struct SRTWorkbenchFCPXMLPanel: View {
    @StateObject private var viewModel = SRTWorkbenchFCPXMLViewModel()
    @State private var showImporter = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    importCard
                    settingsGrid
                    subtitleCard
                    outputCard
                }
                .padding(20)
            }

            Divider()

            bottomBar
        }
        .frame(width: 1200, height: 840)
        .background(Color(NSColor.windowBackgroundColor))
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "srt") ?? .plainText, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                viewModel.importFromFile(url: url)
            case let .failure(error):
                viewModel.statusText = "读取失败"
                viewModel.errorMessage = error.localizedDescription
                ToastManager.shared.show(.error, error.localizedDescription)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDroppedProviders(providers)
        }
        .onChange(of: viewModel.subtitles) { _, _ in
            viewModel.generateFCPXML(showToast: false)
        }
        .onChange(of: viewModel.fps) { _, _ in
            viewModel.generateFCPXML(showToast: false)
        }
        .onChange(of: viewModel.width) { _, _ in
            viewModel.generateFCPXML(showToast: false)
        }
        .onChange(of: viewModel.height) { _, _ in
            viewModel.generateFCPXML(showToast: false)
        }
        .onChange(of: viewModel.positionX) { _, _ in
            viewModel.generateFCPXML(showToast: false)
        }
        .onChange(of: viewModel.positionY) { _, _ in
            viewModel.generateFCPXML(showToast: false)
        }
        .onChange(of: viewModel.fontFamily) { _, _ in
            viewModel.generateFCPXML(showToast: false)
        }
        .onChange(of: viewModel.fontFace) { _, _ in
            viewModel.generateFCPXML(showToast: false)
        }
        .onChange(of: viewModel.fontSize) { _, _ in
            viewModel.generateFCPXML(showToast: false)
        }
        .onChange(of: viewModel.alignment) { _, _ in
            viewModel.generateFCPXML(showToast: false)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SRT → FCPXML 转换器")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("将 SRT 字幕文件转换为 Final Cut Pro 可用的 FCPXML 格式。")
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

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("导入 SRT")
                        .font(.title3.weight(.semibold))
                    Text("文件进来之后，立刻就进入生成链路，不需要切换板块。")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                if viewModel.sourceFileName.isEmpty == false {
                    Text(viewModel.sourceFileName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            SRTWorkbenchDropZone(isTargeted: $isDropTargeted)

            HStack(spacing: 10) {
                Button {
                    showImporter = true
                } label: {
                    Label("选择 .srt 文件", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isImporting)

                Button {
                    viewModel.importFromClipboard()
                } label: {
                    Label("从剪贴板导入", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.reloadFromOriginalSource()
                } label: {
                    Label("重新解析", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.rawSRTContent.isEmpty)

                Spacer()

                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var settingsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 260), spacing: 14),
                GridItem(.flexible(minimum: 260), spacing: 14),
                GridItem(.flexible(minimum: 260), spacing: 14)
            ],
            spacing: 14
        ) {
            compositionCard
            batchEditingCard
            inspectorCard
        }
    }

    private var compositionCard: some View {
        settingsCard(title: "合成设置", subtitle: "决定时间轴和画布尺寸。") {
            VStack(alignment: .leading, spacing: 12) {
                settingRow("FPS") {
                    Picker("", selection: $viewModel.fps) {
                        Text("24").tag(24)
                        Text("25").tag(25)
                        Text("30").tag(30)
                        Text("60").tag(60)
                    }
                    .labelsHidden()
                    .frame(width: 92)
                }

                settingRow("宽度") {
                    TextField("", value: $viewModel.width, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                }

                settingRow("高度") {
                    TextField("", value: $viewModel.height, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                }
            }
        }
    }

    private var batchEditingCard: some View {
        settingsCard(title: "字幕批量调整", subtitle: "把逐条修修改成一张编辑卡片里的动作。") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Button {
                        viewModel.restoreOriginalSubtitles()
                    } label: {
                        Label("恢复原始解析", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.originalSubtitles.isEmpty)

                    Button {
                        viewModel.reloadFromOriginalSource()
                    } label: {
                        Label("重新从文件解析", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.rawSRTContent.isEmpty)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("查找文本")
                        .font(.caption.weight(.medium))
                    TextField("输入要查找的文本", text: $viewModel.batchFindText)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("替换为")
                        .font(.caption.weight(.medium))
                    TextField("输入替换文本", text: $viewModel.batchReplaceText)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 8) {
                    Button {
                        viewModel.batchReplace()
                    } label: {
                        Text("批量替换")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.hasSubtitles == false)

                    Button {
                        viewModel.deleteByKeyword()
                    } label: {
                        Text("删除包含查找文本的字幕")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.hasSubtitles == false)
                }
            }
        }
    }

    private var inspectorCard: some View {
        settingsCard(title: "显示文本检查器", subtitle: "控制字形、字号、对齐和位置。") {
            VStack(alignment: .leading, spacing: 12) {
                settingRow("字体") {
                    TextField("", text: $viewModel.fontFamily)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                }

                settingRow("字重样式") {
                    Picker("", selection: $viewModel.fontFace) {
                        Text("Regular").tag("Regular")
                        Text("Medium").tag("Medium")
                        Text("Semibold").tag("Semibold")
                        Text("Bold").tag("Bold")
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                settingRow("大小") {
                    TextField("", value: $viewModel.fontSize, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 88)
                }

                settingRow("对齐") {
                    Picker("", selection: $viewModel.alignment) {
                        Text("居中").tag("center")
                        Text("左对齐").tag("left")
                        Text("右对齐").tag("right")
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }

                settingRow("X 位置") {
                    TextField("", value: $viewModel.positionX, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                }

                settingRow("Y 位置") {
                    TextField("", value: $viewModel.positionY, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                }
            }
        }
    }

    private var subtitleCard: some View {
        settingsCard(title: "字幕批量编辑", subtitle: "可直接改字幕内容，删除后会自动重编号。") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("字幕列表")
                            .font(.headline)
                        Text("\(viewModel.subtitles.count) 条字幕")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    Text(viewModel.hasGeneratedXML ? "已生成 FCPXML" : "尚未生成")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(viewModel.hasGeneratedXML ? Color.green : Color.secondary)
                }

                if viewModel.subtitles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("请先导入一个 .srt 文件", systemImage: "tray.and.arrow.down")
                            .font(.headline)
                        Text("导入后这里会展开成可编辑的字幕列表。")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(0.06))
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.subtitles.indices, id: \.self) { index in
                                SRTWorkbenchSubtitleRow(
                                    subtitle: $viewModel.subtitles[index],
                                    onDelete: {
                                        viewModel.deleteSubtitle(at: index)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(minHeight: 280)
                }
            }
        }
    }

    private var outputCard: some View {
        settingsCard(title: "FCPXML 输出", subtitle: "生成后可复制或直接保存为 .fcpxml。") {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView {
                    Text(viewModel.generatedFCPXML.isEmpty ? "生成后的 FCPXML 会显示在这里。" : viewModel.generatedFCPXML)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(viewModel.generatedFCPXML.isEmpty ? Color.secondary : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .frame(minHeight: 180)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )

                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
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
            .disabled(viewModel.hasSubtitles == false)

            Button {
                viewModel.copyFCPXML()
            } label: {
                Label("复制 XML", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.hasGeneratedXML == false)

            Button {
                viewModel.downloadFCPXML()
            } label: {
                Label("下载 .fcpxml", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.hasGeneratedXML == false)

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

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.secondary)
            Spacer(minLength: 12)
            content()
        }
    }
}

struct SRTWorkbenchDropZone: View {
    @Binding var isTargeted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.secondary.opacity(isTargeted ? 0.08 : 0.03))
                )

            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)

                Text("点击选择 .srt 文件，或直接拖拽到这里")
                    .font(.headline)

                Text("导入后会自动解析为字幕列表，并立刻生成可编辑的 FCPXML 结果。")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SRTWorkbenchSubtitleRow: View {
    @Binding var subtitle: SRTWorkbenchFCPXMLSubtitle
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("#\(subtitle.index)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.secondary)
                    .frame(width: 32, alignment: .trailing)

                Text("\(subtitle.startTimeString) → \(subtitle.endTimeString)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.secondary)

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

            TextEditor(text: $subtitle.text)
                .font(.system(.body))
                .frame(minHeight: 72)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
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
    @StateObject private var viewModel = DocumentConverterViewModel()

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
            ToastManager.shared.show(.warning, "请选择要转换的文档")
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
                    ToastManager.shared.show(.success, "文档已转换为 Markdown")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = "转换失败"
                    self.engineLabel = "error"
                    self.isConverting = false
                    ToastManager.shared.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func copyOutput() {
        guard outputMarkdown.isEmpty == false else {
            ToastManager.shared.show(.warning, "没有可复制的 Markdown")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputMarkdown, forType: .string)
        ToastManager.shared.show(.success, "Markdown 已复制")
    }

    func saveOutput() {
        guard outputMarkdown.isEmpty == false else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = (sourceURL?.deletingPathExtension().lastPathComponent ?? "document") + ".md"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try outputMarkdown.write(to: url, atomically: true, encoding: .utf8)
                ToastManager.shared.show(.success, "已保存到 \(url.lastPathComponent)")
            } catch {
                ToastManager.shared.show(.error, "保存失败: \(error.localizedDescription)")
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

// MARK: - OCR Panel

struct OCRPanel: View {
    @StateObject private var viewModel = OCRViewModel()

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
                Text("OCR 识别")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("从图片中提取文字，支持文件和剪贴板图片。")
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
            Text("直接调用本机 Vision OCR。")
                .font(.body)

            Text("如果你已经把截图放进剪贴板，也可以直接从剪贴板识别。")
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
                    Text(viewModel.isWorking ? "处理中..." : "开始识别")
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
                        .foregroundStyle(Color.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text("还没有选择图片。")
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
            }

            TextEditor(text: $viewModel.outputText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 380)
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
final class OCRViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var outputText = ""
    @Published var statusText = "请选择图片或从剪贴板识别"
    @Published var errorMessage: String?
    @Published var isWorking = false

    func clear() {
        sourceURL = nil
        outputText = ""
        statusText = "请选择图片或从剪贴板识别"
        errorMessage = nil
        isWorking = false
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
            statusText = "已选择图片，等待识别"
        }
    }

    func recognizeFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            ToastManager.shared.show(.warning, "剪贴板里没有图片")
            return
        }

        sourceURL = nil
        outputText = ""
        errorMessage = nil
        statusText = "正在识别剪贴板图片..."
        isWorking = true

        Task {
            do {
                let result = try await VisionOCR.recognizeText(in: image.tiffRepresentation ?? Data())
                await MainActor.run {
                    self.outputText = result.text
                    self.statusText = "识别完成，共 \(result.blocks.count) 个文本块"
                    self.isWorking = false
                    ToastManager.shared.show(.success, "OCR 识别完成")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = "识别失败"
                    self.isWorking = false
                    ToastManager.shared.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func recognize() {
        guard let sourceURL else {
            ToastManager.shared.show(.warning, "请选择图片")
            return
        }

        isWorking = true
        errorMessage = nil
        outputText = ""
        statusText = "正在识别..."

        Task {
            do {
                let result = try await VisionOCR.recognizeText(inFileAtPath: sourceURL.path)
                await MainActor.run {
                    self.outputText = result.text
                    self.statusText = "识别完成，共 \(result.blocks.count) 个文本块"
                    self.isWorking = false
                    ToastManager.shared.show(.success, "OCR 识别完成")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = "识别失败"
                    self.isWorking = false
                    ToastManager.shared.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func copyOutput() {
        guard outputText.isEmpty == false else {
            ToastManager.shared.show(.warning, "没有可复制的识别结果")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        ToastManager.shared.show(.success, "识别结果已复制")
    }
}

// MARK: - Image Processing

struct ImageProcessingPanel: View {
    @StateObject private var viewModel = ImageProcessingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    sourceCard
                    optionsCard
                    outputCard
                }
                .padding(20)
            }
        }
        .frame(width: 920, height: 820)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("图片处理")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("压缩、缩放和格式转换。")
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
            Text("支持 PNG、JPEG、TIFF 之间的转换。")
                .font(.body)

            Text("可以设置最大边长和 JPEG 压缩质量，适合先把大图压一遍再导出。")
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
                        .foregroundStyle(Color.secondary)
                        .textSelection(.enabled)
                }
            } else if let clipboardInfo = viewModel.clipboardInfo {
                Text(clipboardInfo)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            } else {
                Text("还没有选择图片。")
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

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("转换参数")
                .font(.headline)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("输出格式")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)

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
                        .foregroundStyle(Color.secondary)

                    TextField("例如 1600", text: $viewModel.maxDimensionText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("JPEG 质量")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)

                    Slider(value: $viewModel.quality, in: 0.1...1.0)
                        .frame(width: 180)
                }
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.process()
                } label: {
                    Text(viewModel.isProcessing ? "处理中..." : "处理图片")
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输出预览")
                    .font(.headline)

                Spacer()

                if let summary = viewModel.outputSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            if let previewImage = viewModel.previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .background(Color.black.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("处理后会显示预览图。")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .background(Color.black.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
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
    @Published var statusText = "请选择图片"
    @Published var errorMessage: String?
    @Published var isProcessing = false
    @Published var outputFormat: ImageOutputFormat = .jpeg
    @Published var maxDimensionText = "1600"
    @Published var quality: CGFloat = 0.82

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
        statusText = "请选择图片"
        errorMessage = nil
        isProcessing = false
        outputFormat = .jpeg
        maxDimensionText = "1600"
        quality = 0.82
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
            errorMessage = nil
            statusText = "已选择图片，等待处理"
        }
    }

    func loadFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            ToastManager.shared.show(.warning, "剪贴板里没有图片")
            return
        }

        sourceURL = nil
        clipboardImage = image
        previewImage = image
        outputData = image.tiffRepresentation
        outputSummary = "剪贴板图片：\(Int(image.size.width)) × \(Int(image.size.height))"
        clipboardInfo = outputSummary
        statusText = "已导入剪贴板图片，等待处理"
        errorMessage = nil
    }

    func process() {
        let maxDimension = Int(maxDimensionText.trimmingCharacters(in: .whitespacesAndNewlines))
        isProcessing = true
        errorMessage = nil
        statusText = "正在处理图片..."
        outputData = nil
        outputSummary = nil

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
                throw ToolShellError.launchFailed("请选择图片")
            }

            previewImage = result.previewImage
            outputData = result.data
            outputSummary = "输出 \(Int(result.outputSize.width)) × \(Int(result.outputSize.height))，格式 \(result.outputFormat.title)"
            statusText = "图片处理完成"
            ToastManager.shared.show(.success, "图片已处理")
        } catch {
            errorMessage = error.localizedDescription
            statusText = "处理失败"
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
                ToastManager.shared.show(.success, "已保存到 \(url.lastPathComponent)")
            } catch {
                ToastManager.shared.show(.error, "保存失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Batch Rename

struct BatchRenamePanel: View {
    @StateObject private var viewModel = BatchRenameViewModel()

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
            ToastManager.shared.show(.warning, "请选择文件夹")
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
            ToastManager.shared.show(.warning, "请选择文件夹")
            return
        }

        guard previewItems.isEmpty == false else {
            ToastManager.shared.show(.warning, "没有可重命名的项目")
            return
        }

        let targetPaths = Set(previewItems.map(\.proposedURL.path))
        if targetPaths.count != previewItems.count {
            errorMessage = "预览中存在重复目标名称，请先调整规则"
            statusText = "存在命名冲突"
            ToastManager.shared.show(.error, "预览中存在重复目标名称")
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

            ToastManager.shared.show(.success, "批量重命名完成")
            statusText = "重命名完成"
            if let folderURL {
                let refreshedFolder = folderURL
                self.folderURL = refreshedFolder
                refreshPreview()
            }
        } catch {
            errorMessage = error.localizedDescription
            statusText = "重命名失败"
            ToastManager.shared.show(.error, error.localizedDescription)
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
