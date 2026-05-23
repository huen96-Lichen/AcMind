import AppKit
import AcMindKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct OCRPanel: View {
    @StateObject private var viewModel: OCRViewModel
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
        self._viewModel = StateObject(wrappedValue: OCRViewModel(toastManager: toastManager))
    }

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
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

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
            toastManager.show(.warning, "剪贴板里没有图片")
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
                    toastManager.show(.success, "OCR 识别完成")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = "识别失败"
                    self.isWorking = false
                    toastManager.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func recognize() {
        guard let sourceURL else {
            toastManager.show(.warning, "请选择图片")
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
                    toastManager.show(.success, "OCR 识别完成")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusText = "识别失败"
                    self.isWorking = false
                    toastManager.show(.error, error.localizedDescription)
                }
            }
        }
    }

    func copyOutput() {
        guard outputText.isEmpty == false else {
            toastManager.show(.warning, "没有可复制的识别结果")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        toastManager.show(.success, "识别结果已复制")
    }
}

// MARK: - Image Processing

struct ImageProcessingPanel: View {
    @StateObject private var viewModel: ImageProcessingViewModel
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
        self._viewModel = StateObject(wrappedValue: ImageProcessingViewModel(toastManager: toastManager))
    }

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
    private let toastManager: ToastManager

    init(toastManager: ToastManager) {
        self.toastManager = toastManager
    }

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
            toastManager.show(.warning, "剪贴板里没有图片")
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
            toastManager.show(.success, "图片已处理")
        } catch {
            errorMessage = error.localizedDescription
            statusText = "处理失败"
            toastManager.show(.error, error.localizedDescription)
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
                toastManager.show(.success, "已保存到 \(url.lastPathComponent)")
            } catch {
                toastManager.show(.error, "保存失败: \(error.localizedDescription)")
            }
        }
    }
}
