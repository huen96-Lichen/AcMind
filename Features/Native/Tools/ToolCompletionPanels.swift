import AppKit
import AcMindKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared Helpers

enum ToolBinaryResolver {
    static func executablePath(named name: String) -> String? {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ]

        if let found = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) {
            return found
        }

        guard let pathValue = Foundation.ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for component in pathValue.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(component))
                .appendingPathComponent(name)
                .path
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}

enum ToolFileSupport {
    static func defaultDownloadDirectory(named name: String) -> URL {
        let base = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let folder = base.appendingPathComponent("AcMind", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func uniqueDestinationURL(in folder: URL, filename: String) -> URL {
        let fm = FileManager.default
        let base = folder.appendingPathComponent(filename, isDirectory: false)
        guard fm.fileExists(atPath: base.path) else { return base }

        let ext = base.pathExtension
        let stem = base.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let candidateName: String
            if ext.isEmpty {
                candidateName = "\(stem)-\(index)"
            } else {
                candidateName = "\(stem)-\(index).\(ext)"
            }
            let candidate = folder.appendingPathComponent(candidateName)
            if fm.fileExists(atPath: candidate.path) == false {
                return candidate
            }
            index += 1
        }
    }

    static func sanitizeFilename(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "asset" : trimmed
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return fallback.components(separatedBy: invalid).joined(separator: "_")
    }
}

// MARK: - Batch Download Panel

struct BatchDownloadPanel: View {
    @StateObject private var viewModel = BatchDownloadViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    inputCard
                    resultsCard
                }
                .padding(20)
            }
        }
        .frame(width: 860, height: 760)
        .background(AppSurfaceTokens.background)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("批量下载")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("抓取网页中的图片和文件链接，批量保存到本地。")
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
        VStack(alignment: .leading, spacing: 8) {
            Text("支持 `img` / `source` / `a` 中的网页资源链接。")
                .font(.body)

            Text("如果链接是相对路径，会自动按当前页面地址解析。")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("输入")
                .font(.headline)

            TextField("https://example.com", text: $viewModel.pageURLString)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("保存目录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.outputFolder.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    viewModel.openOutputFolder()
                } label: {
                    Label("打开目录", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.pickOutputFolder()
                } label: {
                    Label("选择目录", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.startDownload()
                } label: {
                    if viewModel.isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("开始下载")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)
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
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("结果")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.copySummary()
                } label: {
                    Label("复制摘要", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.results.isEmpty)
            }

            if viewModel.results.isEmpty {
                Text("还没有开始下载。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.results) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: item.isDownloaded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(item.isDownloaded ? .green : .red)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.sourceURL.absoluteString)
                                        .font(.caption)
                                        .lineLimit(2)
                                    Text(item.destinationURL.path)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }

                                Spacer()

                                Button {
                                    viewModel.openDownloadedFile(item)
                                } label: {
                                    Label("打开文件", systemImage: "arrow.up.right.square")
                                }
                                .buttonStyle(.bordered)
                                .disabled(item.isDownloaded == false)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
                        }
                    }
                }
                .frame(minHeight: 260)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }
}

struct BatchDownloadResultItem: Identifiable, Hashable {
    let id = UUID()
    let sourceURL: URL
    let destinationURL: URL
    let isDownloaded: Bool
}

@MainActor
final class BatchDownloadViewModel: ObservableObject {
    @Published var pageURLString = ""
    @Published var outputFolder: URL = ToolFileSupport.defaultDownloadDirectory(named: "BatchDownloads")
    @Published var statusText = "等待输入网页 URL"
    @Published var errorMessage: String?
    @Published var isRunning = false
    @Published var results: [BatchDownloadResultItem] = []

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func clear() {
        pageURLString = ""
        outputFolder = ToolFileSupport.defaultDownloadDirectory(named: "BatchDownloads")
        statusText = "等待输入网页 URL"
        errorMessage = nil
        isRunning = false
        results = []
    }

    func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
        }
    }

    func startDownload() {
        guard let pageURL = normalizeURL(pageURLString) else {
            statusText = "URL 无效"
            errorMessage = "请输入有效网页地址。"
            ToastManager.shared.show(.warning, "请输入有效网页地址")
            return
        }

        isRunning = true
        errorMessage = nil
        results = []
        statusText = "正在抓取网页资源..."

        Task {
            do {
                let assets = try await BatchDownloadSupport.collectAssets(pageURL: pageURL, session: session)
                let downloadResults = try await BatchDownloadSupport.downloadAssets(
                    assets,
                    to: outputFolder,
                    session: session
                )
                await MainActor.run {
                    self.results = downloadResults
                    self.statusText = "完成，下载了 \(downloadResults.filter(\.isDownloaded).count) 个资源"
                    self.isRunning = false
                    ToastManager.shared.show(.success, "批量下载完成")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = "下载失败"
                    self.isRunning = false
                    ToastManager.shared.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func copySummary() {
        guard results.isEmpty == false else { return }
        let summary = results.map { "\($0.sourceURL.absoluteString) -> \($0.destinationURL.path)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
        ToastManager.shared.show(.success, "摘要已复制")
    }

    func openOutputFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([outputFolder])
    }

    func openDownloadedFile(_ item: BatchDownloadResultItem) {
        guard item.isDownloaded else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.destinationURL])
    }

    private func normalizeURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
}

enum BatchDownloadSupport {
    static func collectAssets(pageURL: URL, session: URLSession) async throws -> [URL] {
        let (data, response) = try await session.data(from: pageURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ToolShellError.launchFailed("网页抓取失败")
        }

        let html = String(decoding: data, as: UTF8.self)
        let regex = try NSRegularExpression(
            pattern: #"(?i)<(img|source|a)[^>]*?(?:src|href|data-src|data-original)\s*=\s*["']([^"']+)["']"#
        )
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: range)

        var seen: Set<String> = []
        var assets: [URL] = []

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let tagRange = Range(match.range(at: 1), in: html),
                  let urlRange = Range(match.range(at: 2), in: html) else {
                continue
            }

            let tag = String(html[tagRange]).lowercased()
            let rawURL = String(html[urlRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard rawURL.isEmpty == false else { continue }
            guard rawURL.hasPrefix("javascript:") == false,
                  rawURL.hasPrefix("mailto:") == false,
                  rawURL.hasPrefix("#") == false else {
                continue
            }

            guard let absoluteURL = URL(string: rawURL, relativeTo: pageURL)?.absoluteURL else {
                continue
            }
            guard ["http", "https"].contains(absoluteURL.scheme?.lowercased() ?? "") else { continue }

            let isAssetCandidate: Bool
            if tag == "a" {
                let ext = absoluteURL.pathExtension.lowercased()
                isAssetCandidate = !ext.isEmpty && !["html", "htm", "php", "asp", "aspx", "jsp"].contains(ext)
                    || absoluteURL.query?.contains("download") == true
            } else {
                isAssetCandidate = true
            }

            guard isAssetCandidate else { continue }

            let key = absoluteURL.absoluteString
            if seen.insert(key).inserted {
                assets.append(absoluteURL)
            }
        }

        return assets
    }

    static func downloadAssets(
        _ assets: [URL],
        to folder: URL,
        session: URLSession
    ) async throws -> [BatchDownloadResultItem] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var results: [BatchDownloadResultItem] = []
        for (index, assetURL) in assets.enumerated() {
            do {
                let (tempURL, response) = try await session.download(from: assetURL)
                let filename = suggestedFilename(for: assetURL, response: response, index: index)
                let destination = ToolFileSupport.uniqueDestinationURL(in: folder, filename: filename)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tempURL, to: destination)
                results.append(BatchDownloadResultItem(sourceURL: assetURL, destinationURL: destination, isDownloaded: true))
            } catch {
                let fallbackFilename = suggestedFilename(for: assetURL, response: nil, index: index)
                let destination = folder.appendingPathComponent(fallbackFilename)
                results.append(BatchDownloadResultItem(sourceURL: assetURL, destinationURL: destination, isDownloaded: false))
            }
        }
        return results
    }

    private static func suggestedFilename(for url: URL, response: URLResponse?, index: Int) -> String {
        if let filename = (response as? HTTPURLResponse)?.suggestedFilename, filename.isEmpty == false {
            return ToolFileSupport.sanitizeFilename(filename)
        }

        let lastPathComponent = url.lastPathComponent
        if lastPathComponent.isEmpty == false {
            return ToolFileSupport.sanitizeFilename(lastPathComponent)
        }

        let ext = url.pathExtension
        if ext.isEmpty == false {
            return "asset-\(index + 1).\(ext)"
        }
        return "asset-\(index + 1)"
    }
}

// MARK: - Video Download Panel

struct VideoDownloadPanel: View {
    @StateObject private var viewModel = VideoDownloadViewModel()

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
        .frame(width: 860, height: 760)
        .background(AppSurfaceTokens.background)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("视频下载")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("使用本机 `yt-dlp` 下载在线视频或音频。")
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
        VStack(alignment: .leading, spacing: 8) {
            Text("支持 `best`、`mp4`、`audio` 三种输出模式。")
                .font(.body)
            Text("会自动调用 `yt-dlp` 和 `ffmpeg` 完成下载与合并。")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("输入")
                .font(.headline)

            TextField("https://youtube.com/watch?v=...", text: $viewModel.videoURLString)
                .textFieldStyle(.roundedBorder)

            Picker("格式", selection: $viewModel.format) {
                ForEach(VideoDownloadFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("保存目录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.outputFolder.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    viewModel.openOutputFolder()
                } label: {
                    Label("打开目录", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.pickOutputFolder()
                } label: {
                    Label("选择目录", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.startDownload()
                } label: {
                    if viewModel.isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("开始下载")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)
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
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输出")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.copyLatestOutput()
                } label: {
                    Label("复制路径", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.downloadedFiles.isEmpty)
            }

            if viewModel.downloadedFiles.isEmpty {
                Text("还没有下载结果。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.downloadedFiles) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: item.isDownloaded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(item.isDownloaded ? .green : .red)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.sourceURL.absoluteString)
                                        .font(.caption)
                                        .lineLimit(2)
                                    Text(item.destinationURL.path)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }

                                Spacer()

                                Button {
                                    viewModel.openResultFile(item.destinationURL)
                                } label: {
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
                        }
                    }
                }
                .frame(minHeight: 260)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }
}

struct VideoDownloadItem: Identifiable, Hashable {
    let id = UUID()
    let sourceURL: URL
    let destinationURL: URL
    let isDownloaded: Bool
}

enum VideoDownloadFormat: String, CaseIterable, Identifiable {
    case best
    case mp4
    case audio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .best: return "最佳"
        case .mp4: return "MP4"
        case .audio: return "音频"
        }
    }

    var ytDLPArguments: [String] {
        switch self {
        case .best:
            return ["-f", "bv*+ba/b", "--merge-output-format", "mp4"]
        case .mp4:
            return ["-f", "bestvideo[ext=mp4]+bestaudio/best", "--merge-output-format", "mp4"]
        case .audio:
            return ["-x", "--audio-format", "mp3"]
        }
    }
}

@MainActor
final class VideoDownloadViewModel: ObservableObject {
    @Published var videoURLString = ""
    @Published var format: VideoDownloadFormat = .best
    @Published var outputFolder: URL = ToolFileSupport.defaultDownloadDirectory(named: "VideoDownloads")
    @Published var statusText = "等待输入视频 URL"
    @Published var errorMessage: String?
    @Published var isRunning = false
    @Published var downloadedFiles: [VideoDownloadItem] = []

    func clear() {
        videoURLString = ""
        format = .best
        outputFolder = ToolFileSupport.defaultDownloadDirectory(named: "VideoDownloads")
        statusText = "等待输入视频 URL"
        errorMessage = nil
        isRunning = false
        downloadedFiles = []
    }

    func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
        }
    }

    func startDownload() {
        guard let url = normalizeURL(videoURLString) else {
            statusText = "URL 无效"
            errorMessage = "请输入有效视频地址。"
            ToastManager.shared.show(.warning, "请输入有效视频地址")
            return
        }

        guard let ytDLP = ToolBinaryResolver.executablePath(named: "yt-dlp") else {
            statusText = "未找到 yt-dlp"
            errorMessage = "请先安装 yt-dlp。"
            ToastManager.shared.show(.error, "未找到 yt-dlp")
            return
        }

        isRunning = true
        errorMessage = nil
        downloadedFiles = []
        statusText = "正在调用 yt-dlp..."

        Task {
            do {
                try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
                let startURL = outputFolder
                let result = try await ToolShellRunner.run(
                    executablePath: ytDLP,
                    arguments: buildArguments(for: url)
                )

                let latestFiles = recentFiles(in: startURL, since: Date().addingTimeInterval(-5 * 60))
                await MainActor.run {
                    self.downloadedFiles = latestFiles.map {
                        VideoDownloadItem(sourceURL: url, destinationURL: $0, isDownloaded: true)
                    }
                    if latestFiles.isEmpty {
                        self.statusText = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "下载完成"
                            : result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        self.statusText = "下载完成，生成 \(latestFiles.count) 个文件"
                    }
                    self.isRunning = false
                    ToastManager.shared.show(.success, "视频下载完成")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = "下载失败"
                    self.isRunning = false
                    ToastManager.shared.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func copyLatestOutput() {
        guard let latest = downloadedFiles.first else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latest.destinationURL.path, forType: .string)
        ToastManager.shared.show(.success, "文件路径已复制")
    }

    func openOutputFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([outputFolder])
    }

    func openResultFile(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func normalizeURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private func buildArguments(for url: URL) -> [String] {
        var args = [
            "--no-playlist",
            "--restrict-filenames",
            "--newline",
            "-P", outputFolder.path,
            "-o", "%(title).80s.%(ext)s"
        ]
        args.append(contentsOf: format.ytDLPArguments)
        args.append(url.absoluteString)
        return args
    }

    private func recentFiles(in folder: URL, since date: Date) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return items.filter {
            guard let modified = try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                return false
            }
            return modified >= date
        }
        .sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhs > rhs
        }
    }
}

// MARK: - Model Management Panel

struct ModelManagementPanel: View {
    @StateObject private var viewModel = ModelManagementViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            GeometryReader { proxy in
                // Give the list column more room so the detail pane stays visually balanced.
                let leftWidth = min(max(proxy.size.width * 0.52, 520), 900)

                HStack(spacing: 0) {
                    leftPane
                        .frame(width: leftWidth)

                    Divider()

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(AppSurfaceTokens.background)
            }
        }
        .frame(minWidth: 1220, idealWidth: 1360, minHeight: 860, idealHeight: 920)
        .background(AppSurfaceTokens.background)
        .task {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.searchQuery) { _, _ in
            viewModel.ensureSelectionVisible()
        }
        .onChange(of: viewModel.selectedDomain) { _, _ in
            viewModel.ensureSelectionVisible()
        }
        .onChange(of: viewModel.selectedDeploymentKind) { _, _ in
            viewModel.ensureSelectionVisible()
        }
        .onChange(of: viewModel.onlyEnabled) { _, _ in
            viewModel.ensureSelectionVisible()
        }
        .onChange(of: viewModel.onlyAvailable) { _, _ in
            viewModel.ensureSelectionVisible()
        }
        .onChange(of: viewModel.onlyDownloaded) { _, _ in
            viewModel.ensureSelectionVisible()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("模型管理")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("管理应用里真实可用的模型。")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.filteredItems.count) / \(viewModel.items.count) 个条目")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
    }

    private var leftPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewCard
                filterBar

                if let errorMessage = viewModel.errorMessage {
                    warningBanner(message: errorMessage)
                }

                if shouldShowSection(.ai) {
                modelListSection(
                        title: "AI 提供商",
                        description: "真实提供商、默认项和启用状态",
                        count: viewModel.filteredAIItems.count
                    ) {
                        let items = viewModel.filteredAIItems
                        if items.isEmpty {
                            emptyState(title: "没有匹配的 AI 提供商", subtitle: "调整筛选条件后再看。")
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(items) { item in
                                    ModelManagementListRow(
                                        item: item,
                                        availableModels: viewModel.availableModels(for: item.providerId ?? ""),
                                        isSelected: viewModel.selectedItemID == item.id,
                                        onTap: {
                                            viewModel.selectItem(item.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }

                if shouldShowSection(.speechRecognition) || shouldShowSection(.localModel) {
                    modelListSection(
                        title: "语音识别",
                        description: "云端引擎、系统听写和本地 ASR",
                        count: viewModel.filteredSpeechItems.count
                    ) {
                        let cloudItems = viewModel.filteredSpeechItems.filter { $0.deploymentKind != .local }
                        let localItems = viewModel.filteredSpeechItems.filter { $0.deploymentKind == .local }

                        if cloudItems.isEmpty && localItems.isEmpty {
                            emptyState(title: "没有匹配的语音识别模型", subtitle: "当前筛选条件下没有可显示的条目。")
                        } else {
                            if !cloudItems.isEmpty {
                                subgroupHeader("云端 / 系统")
                                LazyVStack(spacing: 10) {
                                    ForEach(cloudItems) { item in
                                        ModelManagementListRow(
                                            item: item,
                                            availableModels: [],
                                            isSelected: viewModel.selectedItemID == item.id,
                                            onTap: {
                                                viewModel.selectItem(item.id)
                                            }
                                        )
                                    }
                                }
                            }

                            if !localItems.isEmpty {
                                subgroupHeader("本地 ASR")
                                LazyVStack(spacing: 10) {
                                    ForEach(localItems) { item in
                                        ModelManagementListRow(
                                            item: item,
                                            availableModels: [],
                                            isSelected: viewModel.selectedItemID == item.id,
                                            onTap: {
                                                viewModel.selectItem(item.id)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                if shouldShowSection(.voiceClone) {
                    modelListSection(
                        title: "语音克隆",
                        description: "语音克隆功能暂未开放",
                        count: 0
                    ) {
                        emptyState(title: "暂无语音克隆模型", subtitle: "语音克隆功能暂未开放。")
                    }
                }
            }
            .padding(20)
        }
        .background(AppSurfaceTokens.background)
    }

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let item = viewModel.selectedItem {
                    detailHeader(item)
                    detailFacts(item)
                    detailActions(item)
                    detailNotes(item)
                } else {
                    detailEmptyState
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [
                    AppSurfaceTokens.background,
                    AppSurfaceTokens.cardBackgroundSoft.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("模型总控台")
                        .font(.headline)
                    Text("从这里统一查看、筛选和控制应用里真实可用的模型。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                metricPill(title: "总条目", value: "\(viewModel.summary.totalCount)")
                metricPill(title: "已启用", value: "\(viewModel.summary.enabledCount)")
                metricPill(title: "默认项", value: "\(viewModel.summary.defaultCount)")
                metricPill(title: "已下载", value: "\(viewModel.summary.downloadedCount)")
            }

            HStack(spacing: 10) {
                summaryPill(
                    label: "默认 AI",
                    value: viewModel.defaultAIProviderName,
                    icon: "cpu",
                    tint: .blue
                )
                summaryPill(
                    label: "默认语音识别",
                    value: viewModel.defaultSpeechProviderName,
                    icon: "mic.fill",
                    tint: .green
                )
                summaryPill(
                    label: "语音克隆",
                    value: viewModel.voiceCloneStatusText,
                    icon: "person.wave.2",
                    tint: .orange
                )
            }

            HStack(spacing: 8) {
                Button("清除筛选") {
                    viewModel.clearFilters()
                }
                .buttonStyle(.bordered)

                Menu {
                    ForEach(ModelManagementSortOption.allCases) { option in
                        Button(option.displayName) {
                            viewModel.sortOption = option
                        }
                    }
                } label: {
                    Label("排序: \(viewModel.sortOption.displayName)", systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("语音克隆功能暂未开放。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.5)))
    }

    private func summaryPill(label: String, value: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.5)))
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索模型 / 提供商 / 关键词", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(12)

                Button("清除") {
                    viewModel.clearFilters()
                }
                .buttonStyle(.bordered)
            }

            FlowLayout(spacing: 8) {
                filterChip(title: "全部", isSelected: viewModel.selectedDomain == nil) {
                    viewModel.selectedDomain = nil
                    viewModel.selectedDeploymentKind = nil
                }
                filterChip(title: "AI", isSelected: viewModel.selectedDomain == .ai) {
                    viewModel.selectedDomain = .ai
                    viewModel.selectedDeploymentKind = nil
                }
                filterChip(title: "语音识别", isSelected: viewModel.selectedDomain == .speechRecognition) {
                    viewModel.selectedDomain = .speechRecognition
                    viewModel.selectedDeploymentKind = nil
                }
                filterChip(title: "语音克隆", isSelected: viewModel.selectedDomain == .voiceClone) {
                    viewModel.selectedDomain = .voiceClone
                    viewModel.selectedDeploymentKind = nil
                }
                filterChip(title: ModelManagementDomain.localModel.displayName, isSelected: viewModel.selectedDomain == .localModel || viewModel.selectedDeploymentKind == .local) {
                    viewModel.selectedDomain = .localModel
                    viewModel.selectedDeploymentKind = .local
                }
            }

            Text("统一查看本地 AI 和本地 ASR。")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Toggle("仅启用", isOn: $viewModel.onlyEnabled)
                    .toggleStyle(.switch)
                Toggle("仅可用", isOn: $viewModel.onlyAvailable)
                    .toggleStyle(.switch)
                Toggle("仅已下载", isOn: $viewModel.onlyDownloaded)
                    .toggleStyle(.switch)

                Spacer(minLength: 0)

                Text("当前显示 \(viewModel.filteredItems.count) 项")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(Capsule(style: .continuous))
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.14) : AppSurfaceTokens.cardBackgroundSoft)
                .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : .primary)
                .cornerRadius(999)
        }
        .buttonStyle(.plain)
    }

    private func modelListSection<Content: View>(
        title: String,
        description: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 999).fill(Color.black.opacity(0.05)))
            }

            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private func detailHeader(_ item: ModelManagementItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(iconTint(for: item).opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: iconName(for: item))
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(iconTint(for: item))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(item.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        if item.isDefault {
                            badge("默认", tint: .blue)
                        }
                        badge(item.domain.displayName, tint: .secondary)
                    }

                    Text(item.detailText ?? item.statusLabel)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        badge(item.statusLabel, tint: item.isAvailable ? .green : .orange)
                        badge(item.deploymentKind.displayName, tint: deploymentTint(for: item))
                        badge(item.sizeLabel, tint: .secondary)
                    }
                }

                Spacer()
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private func detailFacts(_ item: ModelManagementItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("详情")
                .font(.headline)

            VStack(spacing: 0) {
                infoRow(label: "域", value: item.domain.displayName)
                Divider()
                infoRow(label: "形态", value: item.deploymentKind.displayName)
                Divider()
                infoRow(label: "大小 / 计费", value: item.sizeLabel)
                Divider()
                infoRow(label: "状态", value: item.statusLabel)
                Divider()
                infoRow(label: "可用性", value: item.isAvailable ? "可直接使用" : "需先配置或下载")
                if let providerId = item.providerId {
                    Divider()
                    infoRow(label: "提供商 ID", value: providerId)
                }
                if let modelId = item.modelId, modelId.isEmpty == false {
                    Divider()
                    infoRow(label: "模型 ID", value: modelId)
                }
                if item.tags.isEmpty == false {
                    Divider()
                    infoRow(label: "标签", value: item.tags.joined(separator: " · "))
                }
            }
            .background(RoundedRectangle(cornerRadius: 18).fill(AppSurfaceTokens.cardBackgroundSoft))
        }
    }

    private func detailActions(_ item: ModelManagementItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .font(.headline)

            let isBusy = viewModel.busyItemID == item.id

            HStack(spacing: 10) {
                Button {
                    if item.domain == .ai {
                        Task { await viewModel.setDefaultAIProvider(item) }
                    } else if item.domain == .speechRecognition {
                        Task { await viewModel.setDefaultSpeechProvider(item) }
                    }
                } label: {
                    Label("设为默认", systemImage: "star.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(item.isDefault || isBusy)

                if item.domain == .ai {
                    Button(item.isEnabled ? "停用" : "启用") {
                        Task { await viewModel.toggleAIProviderEnabled(item) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)

                    if let providerId = item.providerId, viewModel.availableModels(for: providerId).isEmpty == false {
                        Menu {
                            ForEach(viewModel.availableModels(for: providerId), id: \.self) { model in
                                Button(model) {
                                    Task { await viewModel.updateAIProviderModel(item, modelID: model) }
                                }
                            }
                        } label: {
                            Label("切换模型", systemImage: "chevron.down")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isBusy)
                    }

                    Button("去设置") {
                        viewModel.openSettings()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                }

                if item.domain == .speechRecognition {
                    if item.deploymentKind == .local {
                        Button(item.isDownloaded ? "删除本地 ASR" : "下载本地 ASR") {
                            Task { await viewModel.toggleLocalModel(item) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isBusy)

                        Button("打开位置") {
                            viewModel.revealLocalModel(item)
                        }
                        .buttonStyle(.bordered)
                        .disabled(item.isDownloaded == false || isBusy)
                    } else {
                        Button("去设置") {
                            viewModel.openSettings()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isBusy)
                    }
                }

                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }
            }
        }
    }

    private func detailNotes(_ item: ModelManagementItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("简介")
                .font(.headline)

            Text(detailDescription(for: item))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18).fill(AppSurfaceTokens.cardBackgroundSoft))
        }
    }

    private var detailEmptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有选中模型")
                .font(.title3)
                .fontWeight(.semibold)
            Text("选择左侧模型后，这里会显示状态和操作。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func detailDescription(for item: ModelManagementItem) -> String {
        switch item.domain {
        case .ai:
            if item.isAvailable {
                return "可切默认、启用或切换模型。"
            } else {
                return "需要先完成配置。"
            }
        case .speechRecognition:
            if item.deploymentKind == .local {
                return item.isDownloaded
                ? "可删除或打开位置。"
                : "尚未下载。"
            } else if item.deploymentKind == .system {
                return "系统级语音识别。"
            } else {
                return "云端语音识别。"
            }
        case .voiceClone:
            return "语音克隆功能暂未开放。"
        case .localModel:
            return "管理本地 AI 与本地 ASR。"
        }
    }

    private func subgroupHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .center)
        .padding(.vertical, 12)
    }

    private func iconName(for item: ModelManagementItem) -> String {
        switch item.domain {
        case .ai:
            return "cpu"
        case .speechRecognition:
            return item.deploymentKind == .local ? "waveform" : "mic.fill"
        case .voiceClone:
            return "person.wave.2"
        case .localModel:
            return "square.stack.3d.up.fill"
        }
    }

    private func iconTint(for item: ModelManagementItem) -> Color {
        switch item.deploymentKind {
        case .local:
            return .green
        case .cloud:
            return .blue
        case .api:
            return .orange
        case .system:
            return .gray
        }
    }

    private func deploymentTint(for item: ModelManagementItem) -> Color {
        iconTint(for: item)
    }

    private func warningBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.08)))
    }

    private func shouldShowSection(_ domain: ModelManagementDomain) -> Bool {
        guard let selected = viewModel.selectedDomain else { return true }
        if selected == .localModel {
            return domain == .ai || domain == .speechRecognition || domain == .voiceClone
        }
        return selected == domain
    }
}

private struct ModelManagementListRow: View {
    let item: ModelManagementItem
    let availableModels: [String]
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconTint.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .foregroundStyle(iconTint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.displayName)
                            .font(.headline)
                        if item.isDefault {
                            badge("默认", tint: .blue)
                        }
                    }

                    Text(item.detailText ?? item.statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        badge(item.statusLabel, tint: item.isAvailable ? .green : .orange)
                        badge(item.deploymentKind.displayName, tint: deploymentTint)
                        if item.domain == .ai {
                            Text("\(availableModels.count) 个模型")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if item.modelId?.isEmpty == false {
                                badge(item.modelId ?? "", tint: .secondary)
                            } else if availableModels.isEmpty == false {
                                badge("未选择模型", tint: .orange)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : AppSurfaceTokens.cardBackgroundSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor.opacity(0.25) : AppSurfaceTokens.separator.opacity(0.65), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(Capsule(style: .continuous))
    }

    private var iconName: String {
        switch item.domain {
        case .ai:
            return "cpu"
        case .speechRecognition:
            return item.deploymentKind == .local ? "waveform" : "mic.fill"
        case .voiceClone:
            return "person.wave.2"
        case .localModel:
            return "square.stack.3d.up.fill"
        }
    }

    private var iconTint: Color {
        switch item.deploymentKind {
        case .local:
            return .green
        case .cloud:
            return .blue
        case .api:
            return .orange
        case .system:
            return .gray
        }
    }

    private var deploymentTint: Color {
        iconTint
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    struct Cache {
        var sizes: [CGSize] = []
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: Array(repeating: .zero, count: subviews.count))
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        updateCache(&cache, subviews: subviews)
        let maxWidth = proposal.width ?? 0
        guard maxWidth > 0 else {
            let totalHeight = cache.sizes.map(\.height).max() ?? 0
            let totalWidth = cache.sizes.reduce(0) { $0 + $1.width } + CGFloat(max(0, cache.sizes.count - 1)) * spacing
            return CGSize(width: totalWidth, height: totalHeight)
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for size in cache.sizes {
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            usedWidth = max(usedWidth, min(maxWidth, x))
        }

        return CGSize(width: usedWidth, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        updateCache(&cache, subviews: subviews)

        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = cache.sizes[index]
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

@MainActor
final class ModelManagementViewModel: ObservableObject {
    @Published var items: [ModelManagementItem] = []
    @Published var statusText = "等待加载"
    @Published var busyItemID: String?
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    @Published var selectedDomain: ModelManagementDomain?
    @Published var selectedDeploymentKind: ModelManagementDeploymentKind?
    @Published var onlyEnabled = false
    @Published var onlyAvailable = false
    @Published var onlyDownloaded = false
    @Published var sortOption: ModelManagementSortOption = .recommended
    @Published var selectedItemID: String?

    private var providerModelsByID: [String: [String]] = [:]
    private var providerConfigs: [ProviderConfig] = []
    private var localModels: [LocalASRModelInfo] = []
    private var appSettings = AppSettings()
    private var voiceSettings = VoiceSettings()
    private var apiKeyAvailabilityByProviderID: [String: Bool] = [:]

    var summary: ModelManagementSummary {
        ModelManagementSummary(items: filteredItems)
    }

    var aiCount: Int {
        filteredItems.filter { $0.domain == .ai }.count
    }

    var speechCount: Int {
        filteredItems.filter { $0.domain == .speechRecognition }.count
    }

    var localCount: Int {
        filteredItems.filter { $0.deploymentKind == .local }.count
    }

    var voiceCloneCount: Int {
        filteredItems.filter { $0.domain == .voiceClone }.count
    }

    var defaultAIProviderName: String {
        items.first(where: { $0.domain == .ai && $0.isDefault })?.displayName ?? "未设置"
    }

    var defaultSpeechProviderName: String {
        items.first(where: { $0.domain == .speechRecognition && $0.isDefault })?.displayName ?? "未设置"
    }

    var voiceCloneStatusText: String {
        "未开放"
    }

    var filteredItems: [ModelManagementItem] {
        let baseFilter = ModelManagementFilter(
            query: searchQuery,
            domain: selectedDomain == .localModel ? nil : selectedDomain,
            deploymentKind: selectedDomain == .localModel ? .local : selectedDeploymentKind,
            onlyEnabled: onlyEnabled,
            onlyAvailable: onlyAvailable,
            onlyDownloaded: onlyDownloaded
        )
        return sortOption.sort(baseFilter.apply(to: items))
    }

    var filteredAIItems: [ModelManagementItem] {
        filteredItems.filter { $0.domain == .ai }
    }

    var filteredSpeechItems: [ModelManagementItem] {
        filteredItems.filter { $0.domain == .speechRecognition }
    }

    var selectedItem: ModelManagementItem? {
        if let selectedItemID, let item = filteredItems.first(where: { $0.id == selectedItemID }) {
            return item
        }
        return filteredItems.first
    }

    func selectItem(_ id: String) {
        selectedItemID = id
    }

    func ensureSelectionVisible() {
        if filteredItems.isEmpty {
            selectedItemID = nil
            return
        }

        if let selectedItemID, filteredItems.contains(where: { $0.id == selectedItemID }) {
            return
        }

        selectedItemID = filteredItems.first?.id
    }

    func clearFilters() {
        searchQuery = ""
        selectedDomain = nil
        selectedDeploymentKind = nil
        onlyEnabled = false
        onlyAvailable = false
        onlyDownloaded = false
        sortOption = .recommended
        ensureSelectionVisible()
    }

    func availableModels(for providerId: String) -> [String] {
        providerModelsByID[providerId] ?? []
    }

    func refresh() async {
        statusText = "正在加载模型数据..."
        errorMessage = nil

        async let settingsTask = ServiceContainer.shared.settingsService.getSettings()
        async let voiceTask = ServiceContainer.shared.settingsService.getVoiceSettings()
        async let providersTask = ServiceContainer.shared.settingsService.listProviders()
        async let localTask = LocalASRManager.shared.listAvailableModels()

        do {
            let settings = await settingsTask
            let voice = await voiceTask
            let providers = try await providersTask
            let local = await localTask

            appSettings = settings
            voiceSettings = voice
            providerConfigs = providers
            localModels = local
            providerModelsByID = await loadAvailableModels(for: providers)
            apiKeyAvailabilityByProviderID = await loadKeyAvailability(for: keyProbeIDs(for: providers))
            items = buildItems()
            ensureSelectionVisible()
            statusText = "已加载 \(items.count) 个条目"
        } catch {
            errorMessage = error.localizedDescription
            statusText = "加载失败"
        }
    }

    func setDefaultAIProvider(_ item: ModelManagementItem) async {
        guard let providerId = item.providerId else { return }
        busyItemID = item.id
        defer { busyItemID = nil }

        appSettings.defaultProviderId = providerId
        do {
            try await ServiceContainer.shared.settingsService.updateSettings(appSettings)
            if let runtime = ServiceContainer.shared.aiRuntime as? AIRuntimeService {
                try? runtime.setDefaultProvider(id: providerId)
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleAIProviderEnabled(_ item: ModelManagementItem) async {
        guard let provider = providerConfigs.first(where: { $0.id == item.providerId }) else { return }
        busyItemID = item.id
        defer { busyItemID = nil }

        var updated = provider
        updated.enabled.toggle()
        do {
            try await ServiceContainer.shared.settingsService.updateProvider(updated, apiKey: nil)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateAIProviderModel(_ item: ModelManagementItem, modelID: String) async {
        guard let provider = providerConfigs.first(where: { $0.id == item.providerId }) else { return }
        busyItemID = item.id
        defer { busyItemID = nil }

        var updated = provider
        updated.modelId = modelID
        do {
            try await ServiceContainer.shared.settingsService.updateProvider(updated, apiKey: nil)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDefaultSpeechProvider(_ item: ModelManagementItem) async {
        guard let providerId = item.providerId else { return }
        busyItemID = item.id
        defer { busyItemID = nil }

        voiceSettings.defaultProvider = providerId
        do {
            try await ServiceContainer.shared.settingsService.updateVoiceSettings(voiceSettings)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLocalModel(_ item: ModelManagementItem) async {
        guard let model = localModels.first(where: { $0.id == item.modelId }) else { return }
        busyItemID = item.id
        defer { busyItemID = nil }

        do {
            if model.isDownloaded {
                try await LocalASRManager.shared.deleteModel(model.id)
            } else {
                try await LocalASRManager.shared.downloadModel(model.id)
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealLocalModel(_ item: ModelManagementItem) {
        guard let model = localModels.first(where: { $0.id == item.modelId }) else { return }
        let url = URL(fileURLWithPath: model.storagePath, isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openSettings() {
        AppState.shared.selectSidebarItem(.settings)
    }

    private func buildItems() -> [ModelManagementItem] {
        let aiItems = providerConfigs.map { provider in
            let models = providerModelsByID[provider.id] ?? []
            let hasKey = apiKeyAvailabilityByProviderID[provider.id] ?? false
            let status: String
            if provider.enabled == false {
                status = "已停用"
            } else if provider.providerType == .local || hasKey {
                status = "可用"
            } else {
                status = "待配置"
            }

            return ModelManagementItem(
                id: "ai.\(provider.id)",
                displayName: provider.name.isEmpty ? provider.providerType.displayName : provider.name,
                domain: .ai,
                deploymentKind: provider.tier.isLocal ? .local : .cloud,
                isDefault: appSettings.defaultProviderId == provider.id,
                isEnabled: provider.enabled,
                isAvailable: provider.enabled && (provider.providerType == .local || hasKey),
                isDownloaded: provider.providerType == .local || provider.tier.isLocal,
                sizeLabel: provider.modelId.isEmpty ? "未配置模型" : provider.modelId,
                statusLabel: status,
                tags: [
                    provider.providerType.displayName,
                    provider.tier.displayName,
                    models.isEmpty ? "暂无可选模型" : "\(models.count) 个可选模型"
                ],
                detailText: provider.baseURL.isEmpty ? "本地地址" : provider.baseURL,
                providerId: provider.id,
                modelId: provider.modelId
            )
        }

        let speechItems = buildSpeechItems()
        return aiItems + speechItems
    }

    private func buildSpeechItems() -> [ModelManagementItem] {
        var items: [ModelManagementItem] = []

        for provider in supportedSpeechProviders {
            let isDefault = resolvedSpeechProviderID(voiceSettings.defaultProvider) == provider.rawValue
            let isAvailable = speechAvailability(for: provider)
            let isDownloaded = isLocalSpeechProvider(provider)
            let sizeLabel = speechSizeLabel(for: provider)
            let detail = speechDetail(for: provider)
            let tags = speechTags(for: provider)
            let status = speechStatus(for: provider)

            items.append(
                ModelManagementItem(
                    id: "speech.\(provider.rawValue)",
                    displayName: speechDisplayName(for: provider),
                    domain: .speechRecognition,
                    deploymentKind: speechDeployment(for: provider),
                    isDefault: isDefault,
                    isEnabled: isAvailable,
                    isAvailable: isAvailable,
                    isDownloaded: isDownloaded,
                    sizeLabel: sizeLabel,
                    statusLabel: status,
                    tags: tags,
                    detailText: detail,
                    providerId: provider.rawValue,
                    modelId: nil
                )
            )
        }

        for model in localModels {
            let providerID = speechProviderID(for: model.type)
            let isDefault = resolvedSpeechProviderID(voiceSettings.defaultProvider) == providerID
            items.append(
                ModelManagementItem(
                    id: "local.\(model.id)",
                    displayName: model.name,
                    domain: .speechRecognition,
                    deploymentKind: .local,
                    isDefault: isDefault,
                    isEnabled: model.isDownloaded,
                    isAvailable: model.isDownloaded,
                    isDownloaded: model.isDownloaded,
                    sizeLabel: model.modelSize,
                    statusLabel: model.isDownloaded ? "已下载" : "未下载",
                    tags: [model.type.displayName, model.supportedLanguages],
                    detailText: model.storagePath,
                    providerId: providerID,
                    modelId: model.id
                )
            )
        }

        return items
    }

    private var supportedSpeechProviders: [STTProvider] {
        [.appleSpeech, .senseVoice, .whisperKit, .funASR, .qwen3ASR, .parakeet, .openAI, .aliCloud, .doubao, .mimoASR]
    }

    private func speechDisplayName(for provider: STTProvider) -> String {
        switch provider {
        case .appleSpeech: return "苹果听写"
        case .senseVoice: return "SenseVoice"
        case .whisperKit: return "WhisperKit"
        case .funASR: return "FunASR"
        case .qwen3ASR: return "Qwen3-ASR"
        case .parakeet: return "Parakeet"
        case .openAI: return "Whisper 接口"
        case .aliCloud: return "阿里云 ASR"
        case .doubao: return "火山引擎 ASR"
        case .googleCloud: return "Google 云语音"
        case .groq: return "Groq 语音"
        case .mimoASR: return "MiMo ASR"
        case .freeModel: return "免费模型"
        }
    }

    private func speechDeployment(for provider: STTProvider) -> ModelManagementDeploymentKind {
        provider.isLocal ? .local : (provider == .appleSpeech ? .system : .api)
    }

    private func speechStatus(for provider: STTProvider) -> String {
        if provider == .appleSpeech {
            return "系统可用"
        }
        if provider.isLocal {
            return isLocalSpeechProvider(provider) ? "已下载" : "未下载"
        }
        return speechAvailability(for: provider) ? "可用" : "待配置"
    }

    private func speechAvailability(for provider: STTProvider) -> Bool {
        switch provider {
        case .appleSpeech:
            return true
        case .senseVoice, .whisperKit, .qwen3ASR, .funASR, .parakeet:
            return isLocalSpeechProvider(provider)
        case .openAI:
            return apiKeyAvailabilityByProviderID["openai"] ?? false
        case .aliCloud:
            return (apiKeyAvailabilityByProviderID["alicloud_app_id"] ?? false) &&
                (apiKeyAvailabilityByProviderID["alicloud_token"] ?? false)
        case .doubao:
            return (apiKeyAvailabilityByProviderID["doubao_app_id"] ?? false) &&
                (apiKeyAvailabilityByProviderID["doubao_token"] ?? false)
        case .mimoASR:
            return apiKeyAvailabilityByProviderID["mimo"] ?? false
        case .googleCloud, .groq, .freeModel:
            return false
        }
    }

    private func speechSizeLabel(for provider: STTProvider) -> String {
        switch provider {
        case .appleSpeech:
            return "系统"
        case .senseVoice:
            return "~350 MB"
        case .whisperKit:
            return "~1.5 GB"
        case .funASR:
            return "~180 MB"
        case .qwen3ASR:
            return "~1.3 GB"
        case .parakeet:
            return "~600 MB"
        case .openAI, .aliCloud, .doubao, .mimoASR:
            return "接口"
        case .googleCloud, .groq, .freeModel:
            return "未接入"
        }
    }

    private func speechDetail(for provider: STTProvider) -> String {
        switch provider {
        case .appleSpeech:
            return "使用系统听写能力。"
        case .senseVoice:
            return "本地多语言 ASR。"
        case .whisperKit:
            return "WhisperKit 本地运行时。"
        case .funASR:
            return "中文优化的本地 ASR。"
        case .qwen3ASR:
            return "Qwen3-ASR 本地识别。"
        case .parakeet:
            return "英文优化的本地 ASR。"
        case .openAI:
            return "Whisper 接口。"
        case .aliCloud:
            return "阿里云语音识别。"
        case .doubao:
            return "火山引擎语音识别。"
        case .mimoASR:
            return "MiMo 云端识别。"
        case .googleCloud:
            return "暂未开放。"
        case .groq:
            return "暂未开放。"
        case .freeModel:
            return "免费模型通道暂未开放。"
        }
    }

    private func speechTags(for provider: STTProvider) -> [String] {
        var tags: [String] = [provider.displayName]
        if provider.isLocal {
            tags.append("本地")
        } else if provider == .appleSpeech {
            tags.append("系统")
        } else {
            tags.append("云端")
        }
        if provider == .whisperKit {
            tags.append("自动管理")
        }
        return tags
    }

    private func isLocalSpeechProvider(_ provider: STTProvider) -> Bool {
        guard let localModel = localModels.first(where: { speechProviderID(for: $0.type) == provider.rawValue }) else {
            return false
        }
        return localModel.isDownloaded
    }

    private func speechProviderID(for type: LocalASRModelType) -> String {
        switch type {
        case .senseVoice:
            return STTProvider.senseVoice.rawValue
        case .whisperKit:
            return STTProvider.whisperKit.rawValue
        case .funASR:
            return STTProvider.funASR.rawValue
        case .qwen3ASR:
            return STTProvider.qwen3ASR.rawValue
        case .parakeet:
            return STTProvider.parakeet.rawValue
        }
    }

    private func resolvedSpeechProviderID(_ rawValue: String) -> String {
        switch rawValue {
        case "whisper", "whisper_api":
            return STTProvider.openAI.rawValue
        case "whisper_local":
            return STTProvider.senseVoice.rawValue
        case "system":
            return STTProvider.appleSpeech.rawValue
        default:
            return rawValue
        }
    }

    private func keyProbeIDs(for providers: [ProviderConfig]) -> [String] {
        let providerIDs = providers.map(\.id)
        let speechKeyIDs = [
            "openai",
            "alicloud_app_id",
            "alicloud_token",
            "doubao_app_id",
            "doubao_token",
            "mimo",
        ]
        return Array(Set(providerIDs + speechKeyIDs))
    }

    private func loadKeyAvailability(for providerIDs: [String]) async -> [String: Bool] {
        await withTaskGroup(of: (String, Bool).self) { group in
            for providerID in providerIDs {
                group.addTask {
                    let hasKey = await SecretStore.shared.getAPIKey(for: providerID) != nil
                    return (providerID, hasKey)
                }
            }

            var result: [String: Bool] = [:]
            for await (providerID, hasKey) in group {
                result[providerID] = hasKey
            }
            return result
        }
    }

    private func loadAvailableModels(for providers: [ProviderConfig]) async -> [String: [String]] {
        await withTaskGroup(of: (String, [String]).self) { group in
            for provider in providers {
                group.addTask {
                    let models = (try? await ServiceContainer.shared.aiRuntime.listModels(providerId: provider.id)) ?? []
                    return (provider.id, models)
                }
            }

            var result: [String: [String]] = [:]
            for await (providerID, models) in group {
                result[providerID] = models
            }
            return result
        }
    }
}

// MARK: - API Test Panel

struct APITestPanel: View {
    @StateObject private var viewModel = APITestViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    providerCard
                    testCard
                    outputCard
                }
                .padding(20)
            }
        }
        .frame(width: 940, height: 820)
        .background(AppSurfaceTokens.background)
        .task {
            await viewModel.refreshProviders()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("接口连通检查")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("查看提供商连通性、模型和简短对话。")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button {
                Task { await viewModel.refreshProviders() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用现有提供商配置，无需重复输入密钥。")
                .font(.body)
            Text("可快速确认连通性、查看模型，并做一次简短对话。")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当前提供商")
                    .font(.headline)
                Spacer()
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.providers.isEmpty {
                Text("请先到设置里添加提供商。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Picker("提供商", selection: $viewModel.selectedProviderId) {
                    ForEach(viewModel.providers) { provider in
                        Text(provider.name).tag(Optional(provider.id))
                    }
                }
                .pickerStyle(.menu)

                if let provider = viewModel.selectedProvider {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("类型：\(provider.providerType.displayName)")
                        Text("模型 ID: \(provider.modelId.isEmpty ? "未设置" : provider.modelId)")
                        Text("基础地址: \(provider.baseURL.isEmpty ? provider.providerType.defaultBaseURL : provider.baseURL)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("检查内容")
                .font(.headline)

            TextField("检查提示词", text: $viewModel.testPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    Task { await viewModel.runHealthCheck() }
                } label: {
                    Label("连通检查", systemImage: "checkmark.shield")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning || viewModel.selectedProviderId == nil)

                Button {
                    Task { await viewModel.listModels() }
                } label: {
                    Label("获取模型", systemImage: "list.bullet")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRunning || viewModel.selectedProviderId == nil)

                Button {
                    Task { await viewModel.runChatTest() }
                } label: {
                    Label("对话验证", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRunning || viewModel.selectedProviderId == nil)

                Spacer()

                if viewModel.isRunning {
                    ProgressView()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("结果")
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

            TextEditor(text: $viewModel.outputText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 260)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }
}

@MainActor
final class APITestViewModel: ObservableObject {
    @Published var providers: [ProviderConfig] = []
    @Published var selectedProviderId: String?
    @Published var testPrompt = "请用一句话回答：AcMind 的连通检查成功了吗？"
    @Published var outputText = ""
    @Published var statusText = "等待加载提供商"
    @Published var isRunning = false
    @Published var lastSavedURL: URL?

    var selectedProvider: ProviderConfig? {
        providers.first(where: { $0.id == selectedProviderId })
    }

    func refreshProviders() async {
        providers = await ServiceContainer.shared.aiRuntime.listProviders()
        selectedProviderId = selectedProviderId ?? providers.first?.id
        statusText = providers.isEmpty ? "暂无提供商可检查" : "已加载 \(providers.count) 个提供商"
    }

    func runHealthCheck() async {
        guard let providerId = selectedProviderId else { return }
        isRunning = true
        outputText = ""
        lastSavedURL = nil
        statusText = "正在进行连通检查..."
        do {
            let ok = try await ServiceContainer.shared.aiRuntime.healthCheck(providerId: providerId)
            outputText = ok ? "连通检查：正常" : "连通检查：失败"
            statusText = ok ? "连通检查通过" : "连通检查失败"
        } catch {
            outputText = error.localizedDescription
            statusText = "连通检查失败"
        }
        isRunning = false
    }

    func listModels() async {
        guard let providerId = selectedProviderId else { return }
        isRunning = true
        outputText = ""
        lastSavedURL = nil
        statusText = "正在拉取模型列表..."
        do {
            let models = try await ServiceContainer.shared.aiRuntime.listModels(providerId: providerId)
            outputText = models.isEmpty ? "没有返回模型列表" : models.joined(separator: "\n")
            statusText = "模型列表已获取"
        } catch {
            outputText = error.localizedDescription
            statusText = "模型列表获取失败"
        }
        isRunning = false
    }

    func runChatTest() async {
        guard let providerId = selectedProviderId else { return }
        isRunning = true
        outputText = ""
        lastSavedURL = nil
        statusText = "正在发送对话验证..."
        do {
            let modelId = selectedProvider?.modelId.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await ServiceContainer.shared.aiRuntime.chat(
                messages: [ChatMessage(role: "user", content: testPrompt)],
                providerId: providerId,
                model: (modelId?.isEmpty == false) ? modelId : nil
            )
            outputText = response.content
            statusText = "对话验证完成"
        } catch {
            outputText = error.localizedDescription
            statusText = "对话验证失败"
        }
        isRunning = false
    }

    func copyOutput() {
        guard outputText.isEmpty == false else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        ToastManager.shared.show(.success, "结果已复制")
    }

    func saveOutput() {
        guard outputText.isEmpty == false else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "api-test-result.txt"
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try outputText.write(to: url, atomically: true, encoding: .utf8)
                lastSavedURL = url
                ToastManager.shared.show(.success, "结果已保存")
            } catch {
                ToastManager.shared.show(.error, "保存失败: \(error.localizedDescription)")
            }
        }
    }

    func openSavedOutput() {
        guard let lastSavedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastSavedURL])
    }
}
