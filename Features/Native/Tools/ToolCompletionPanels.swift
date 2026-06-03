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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    summaryCard
                    modelListCard
                }
                .padding(20)
            }
        }
        .frame(width: 940, height: 760)
        .background(AppSurfaceTokens.background)
        .task {
            await viewModel.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("模型管理")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("管理本地语音模型的下载、删除与位置。")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SenseVoice / Qwen3-ASR / FunASR 会下载到本地目录；WhisperKit 由其运行时自动管理。")
                .font(.body)
            Text("点击模型卡片右侧按钮即可下载、删除或打开目录。")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("模型目录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.modelsDirectory.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            Button {
                viewModel.revealModelsDirectory()
            } label: {
                Label("在 Finder 打开", systemImage: "folder")
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var modelListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本地模型")
                    .font(.headline)
                Spacer()
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.models.isEmpty {
                Text("正在加载模型状态...")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.models, id: \.id) { model in
                        ModelRow(
                            model: model,
                            isBusy: viewModel.busyModelId == model.id,
                            onDownload: { Task { await viewModel.download(model) } },
                            onDelete: { Task { await viewModel.delete(model) } },
                            onReveal: { viewModel.reveal(model) }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }
}

struct ModelRow: View {
    let model: LocalASRModelInfo
    let isBusy: Bool
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((model.isDownloaded ? Color.green : Color.secondary).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: model.isDownloaded ? "checkmark.seal.fill" : "circle.dashed")
                    .foregroundStyle(model.isDownloaded ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(model.name)
                        .font(.headline)
                    Text(model.type.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(999)
                    if model.type == .whisperKit {
                        Text("自动管理")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .cornerRadius(999)
                    }
                }

                Text("版本 \(model.version) · \(model.modelSize) · \(model.supportedLanguages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(model.storagePath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if model.type == .whisperKit {
                    Text("由 WhisperKit 运行时自动下载")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                } else if model.isDownloaded {
                    Text("已下载")
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else {
                    Text("未下载")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if model.type != .whisperKit {
                        Button(isBusy ? "处理中..." : (model.isDownloaded ? "删除" : "下载")) {
                            if model.isDownloaded {
                                onDelete()
                            } else {
                                onDownload()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isBusy)
                    }

                    Button("打开") {
                        onReveal()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppSurfaceTokens.cardBackgroundSoft))
    }
}

@MainActor
final class ModelManagementViewModel: ObservableObject {
    @Published var models: [LocalASRModelInfo] = []
    @Published var statusText = "等待加载"
    @Published var busyModelId: String?

    let modelsDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("AcMind", isDirectory: true)
        .appendingPathComponent("LocalModels", isDirectory: true)

    func refresh() async {
        statusText = "正在加载本地模型状态..."
        models = await LocalASRManager.shared.listAvailableModels()
        statusText = "已加载 \(models.count) 个模型"
    }

    func download(_ model: LocalASRModelInfo) async {
        guard model.type != .whisperKit else { return }
        busyModelId = model.id
        statusText = "正在下载 \(model.name)..."
        do {
            try await LocalASRManager.shared.downloadModel(model.id)
            await refresh()
            ToastManager.shared.show(.success, "\(model.name) 已下载")
        } catch {
            statusText = error.localizedDescription
            ToastManager.shared.show(.error, error.localizedDescription)
        }
        busyModelId = nil
    }

    func delete(_ model: LocalASRModelInfo) async {
        busyModelId = model.id
        statusText = "正在删除 \(model.name)..."
        do {
            try await LocalASRManager.shared.deleteModel(model.id)
            await refresh()
            ToastManager.shared.show(.success, "\(model.name) 已删除")
        } catch {
            statusText = error.localizedDescription
            ToastManager.shared.show(.error, error.localizedDescription)
        }
        busyModelId = nil
    }

    func reveal(_ model: LocalASRModelInfo) {
        let url = URL(fileURLWithPath: model.storagePath, isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func revealModelsDirectory() {
        NSWorkspace.shared.open(modelsDirectory)
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
                Text("API 测试")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("对当前配置的 AI Provider 做健康检查、模型列表查询和一次简短对话测试。")
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
            Text("优先用现有的 Provider 配置，不需要重复输入密钥。")
                .font(.body)
            Text("可以快速确认某个 Provider 是否连通、能否列出模型，并做一次最小对话请求。")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSurfaceTokens.cardBackgroundSoft))
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Provider")
                    .font(.headline)
                Spacer()
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.providers.isEmpty {
                Text("没有可测试的 Provider，请先到设置中添加。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Picker("Provider", selection: $viewModel.selectedProviderId) {
                    ForEach(viewModel.providers) { provider in
                        Text(provider.name).tag(Optional(provider.id))
                    }
                }
                .pickerStyle(.menu)

                if let provider = viewModel.selectedProvider {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("类型: \(provider.providerType.displayName)")
                        Text("模型: \(provider.modelId.isEmpty ? "未设置" : provider.modelId)")
                        Text("地址: \(provider.baseURL.isEmpty ? provider.providerType.defaultBaseURL : provider.baseURL)")
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
            Text("测试请求")
                .font(.headline)

            TextField("测试提示词", text: $viewModel.testPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    Task { await viewModel.runHealthCheck() }
                } label: {
                    Label("健康检查", systemImage: "checkmark.shield")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning || viewModel.selectedProviderId == nil)

                Button {
                    Task { await viewModel.listModels() }
                } label: {
                    Label("列出模型", systemImage: "list.bullet")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRunning || viewModel.selectedProviderId == nil)

                Button {
                    Task { await viewModel.runChatTest() }
                } label: {
                    Label("对话测试", systemImage: "bubble.left.and.bubble.right")
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
    @Published var testPrompt = "请用一句话回答：AcMind 的 API 连通性测试成功了吗？"
    @Published var outputText = ""
    @Published var statusText = "等待加载 Provider"
    @Published var isRunning = false
    @Published var lastSavedURL: URL?

    var selectedProvider: ProviderConfig? {
        providers.first(where: { $0.id == selectedProviderId })
    }

    func refreshProviders() async {
        providers = await ServiceContainer.shared.aiRuntime.listProviders()
        selectedProviderId = selectedProviderId ?? providers.first?.id
        statusText = providers.isEmpty ? "没有可测试的 Provider" : "已加载 \(providers.count) 个 Provider"
    }

    func runHealthCheck() async {
        guard let providerId = selectedProviderId else { return }
        isRunning = true
        outputText = ""
        lastSavedURL = nil
        statusText = "正在做健康检查..."
        do {
            let ok = try await ServiceContainer.shared.aiRuntime.healthCheck(providerId: providerId)
            outputText = ok ? "Health check: OK" : "Health check: FAIL"
            statusText = ok ? "健康检查通过" : "健康检查失败"
        } catch {
            outputText = error.localizedDescription
            statusText = "健康检查失败"
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
        statusText = "正在发送测试对话..."
        do {
            let modelId = selectedProvider?.modelId.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await ServiceContainer.shared.aiRuntime.chat(
                messages: [ChatMessage(role: "user", content: testPrompt)],
                providerId: providerId,
                model: (modelId?.isEmpty == false) ? modelId : nil
            )
            outputText = response.content
            statusText = "对话测试完成"
        } catch {
            outputText = error.localizedDescription
            statusText = "对话测试失败"
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
