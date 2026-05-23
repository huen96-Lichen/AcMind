import AppKit
import SwiftUI
import UniformTypeIdentifiers

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

    private static let timeRegex: NSRegularExpression? = {
        try? NSRegularExpression(
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
        guard let timeRegex else {
            throw ParseError(message: "字幕时间戳解析器初始化失败")
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
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

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
                toastManager.show(.warning, "没有可生成的字幕")
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
            toastManager.show(.success, "FCPXML 已生成")
        }
    }

    func copyFCPXML() {
        guard generatedFCPXML.isEmpty == false else {
            fail("没有可复制的内容", status: "请先生成 FCPXML")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedFCPXML, forType: .string)
        toastManager.show(.success, "FCPXML 已复制到剪贴板")
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
                toastManager.show(.success, "文件已保存")
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
            toastManager.show(.success, "已导入 \(parsed.count) 条字幕")
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
        toastManager.show(.error, message)
    }
}

struct SRTWorkbenchFCPXMLPanel: View {
    @StateObject private var viewModel: SRTWorkbenchFCPXMLViewModel
    @State private var showImporter = false
    @State private var isDropTargeted = false
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
        self._viewModel = StateObject(wrappedValue: SRTWorkbenchFCPXMLViewModel(toastManager: toastManager))
    }

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
                toastManager.show(.error, error.localizedDescription)
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
