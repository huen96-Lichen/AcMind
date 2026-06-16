import SwiftUI
import AppKit
import AcMindKit

// MARK: - Capsule Panel

/// 悬浮胶囊面板 - 快速采集入口
/// 功能：
/// 1. 快速文本输入
/// 2. 截图（全屏/区域/窗口）
/// 3. 剪贴板采集
/// 4. 展开更多选项（网页/文件/语音）
final class CapsulePanel: NSPanel {
    static let shared = CapsulePanel()
    private let captureService: CaptureServiceProtocol
    private let voiceService: VoiceServiceProtocol
    private let storageService: StorageServiceProtocol

    private init(
        captureService: CaptureServiceProtocol = CaptureService(),
        voiceService: VoiceServiceProtocol = VoiceService(),
        storageService: StorageServiceProtocol = StorageService()
    ) {
        self.captureService = captureService
        self.voiceService = voiceService
        self.storageService = storageService
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 48),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.backgroundColor = .clear

        // 设置内容视图
        let contentView = CapsuleContentView(
            captureService: captureService,
            voiceService: voiceService,
            storageService: storageService
        )
        self.contentView = NSHostingView(rootView: contentView)

        // 居中显示
        center()
    }

    func show() {
        makeKeyAndOrderFront(nil)
    }

    func hide() {
        orderOut(nil)
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
}

// MARK: - Capsule Content View

struct CapsuleContentView: View {
    private static let logger = AcMindLogger(category: .capture)
    private let captureService: CaptureServiceProtocol
    private let voiceService: VoiceServiceProtocol
    private let storageService: StorageServiceProtocol

    @State private var isExpanded = false
    @State private var inputText = ""
    @State private var showingScreenshotOptions = false
    @State private var showingWebpageInput = false
    @State private var webpageURL = ""
    @State private var isCapturing = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            // 收缩状态 - 横向胶囊
            HStack(spacing: 12) {
                Button(action: { toggleExpand() }) {
                    Image(systemName: isExpanded ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                }
                .buttonStyle(PlainButtonStyle())

                TextField("快速输入...", text: $inputText, onCommit: {
                    captureText()
                })
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(maxWidth: 200)
                    .disabled(isCapturing)

                Button(action: { showingScreenshotOptions = true }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isCapturing)
                .popover(isPresented: $showingScreenshotOptions) {
                    ScreenshotOptionsView(onSelect: { mode in
                        captureScreenshot(mode: mode)
                        showingScreenshotOptions = false
                    })
                }

                Button(action: { captureClipboard() }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isCapturing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground.opacity(0.96))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            )

            // 展开状态 - 更多选项
            if isExpanded {
                VStack(spacing: 8) {
                    Divider()

                    HStack(spacing: 16) {
                        CapsuleActionButton(
                            icon: "text.quote",
                            title: "文本",
                            isLoading: isCapturing
                        ) { captureText() }

                        CapsuleActionButton(
                            icon: "link",
                            title: "网页",
                            isLoading: isCapturing
                        ) { showingWebpageInput = true }

                        CapsuleActionButton(
                            icon: "folder",
                            title: "文件",
                            isLoading: isCapturing
                        ) { captureFile() }

                        CapsuleActionButton(
                            icon: isRecordingVoice ? "stop.fill" : "mic",
                            title: isRecordingVoice ? "停止 (\(Int(recordingDuration)))" : "语音",
                            isLoading: isCapturing,
                            tintColor: isRecordingVoice ? .red : nil
                        ) { captureVoice() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackground.opacity(0.96))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: 360)
        .alert("错误", isPresented: $showError) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .sheet(isPresented: $showingWebpageInput) {
            WebpageInputView(url: $webpageURL) { url in
                captureWebpage(url: url)
                showingWebpageInput = false
                webpageURL = ""
            }
        }
    }

    // MARK: - Actions

    private func toggleExpand() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
    }

    private func captureScreenshot(mode: ScreenshotMode) {
        guard SettingsLocalPreferences.isCaptureScreenshotEnabled() else {
            errorMessage = "截图捕获已在设置中关闭"
            showError = true
            return
        }

        isCapturing = true

        Task {
            do {
                let result = try await captureService.captureScreenshot(mode: mode)
                Self.logger.info("截图成功: \(result.sourceItem.id)")

                // 隐藏胶囊
                await MainActor.run {
                    CapsulePanel.shared.hide()
                    isCapturing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCapturing = false
                }
            }
        }
    }

    private func captureClipboard() {
        isCapturing = true

        Task {
            do {
                if let result = try await captureService.captureFromClipboard() {
                    Self.logger.info("剪贴板采集成功: \(result.sourceItem.id)")
                } else {
                    Self.logger.warning("剪贴板无内容")
                }

                await MainActor.run {
                    CapsulePanel.shared.hide()
                    isCapturing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCapturing = false
                }
            }
        }
    }

    private func captureText() {
        guard !inputText.isEmpty else { return }
        isCapturing = true

        Task {
            do {
                let result = try await captureService.captureFromManualText(inputText)
                Self.logger.info("文本采集成功: \(result.sourceItem.id)")

                await MainActor.run {
                    inputText = ""
                    CapsulePanel.shared.hide()
                    isCapturing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCapturing = false
                }
            }
        }
    }

    private func captureWebpage(url: URL) {
        isCapturing = true

        Task {
            do {
                let result = try await captureService.captureFromWebpage(url: url)
                Self.logger.info("网页采集成功: \(result.sourceItem.id)")

                await MainActor.run {
                    CapsulePanel.shared.hide()
                    isCapturing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCapturing = false
                }
            }
        }
    }

    private func captureFile() {
        isCapturing = true

        Task {
            await MainActor.run {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false

                guard panel.runModal() == .OK, let url = panel.url else {
                    isCapturing = false
                    return
                }

                Task {
                    do {
                        let result = try await captureService.captureFromFile(url: url)
                        Self.logger.info("文件采集成功: \(result.sourceItem.id)")

                        await MainActor.run {
                            CapsulePanel.shared.hide()
                            isCapturing = false
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showError = true
                            isCapturing = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Voice Capture

    @State private var isRecordingVoice = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?

    init(
        captureService: CaptureServiceProtocol = CaptureService(),
        voiceService: VoiceServiceProtocol = VoiceService(),
        storageService: StorageServiceProtocol = StorageService()
    ) {
        self.captureService = captureService
        self.voiceService = voiceService
        self.storageService = storageService
    }

    private func captureVoice() {
        guard SettingsLocalPreferences.isVoiceInputEnabled() else {
            errorMessage = "说入法输入已在设置中关闭"
            showError = true
            return
        }

        Task {
            if isRecordingVoice {
                await stopVoiceRecording()
            } else {
                await startVoiceRecording()
            }
        }
    }

    private func startVoiceRecording() async {
        do {
            try await voiceService.startRecording()

            await MainActor.run {
                isRecordingVoice = true
                recordingDuration = 0
                startRecordingTimer()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func stopVoiceRecording() async {
        do {
            let sourceItemId = try await voiceService.stopRecording()

            await MainActor.run {
                isRecordingVoice = false
                stopRecordingTimer()
                CapsulePanel.shared.hide()
            }

            // 等待转写完成
            await waitForVoiceTranscription(sourceItemId: sourceItemId)
        } catch {
            await MainActor.run {
                isRecordingVoice = false
                stopRecordingTimer()
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                recordingDuration += 1
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func waitForVoiceTranscription(sourceItemId: String) async {
        let storage = storageService
        var attempts = 0
        let maxAttempts = 30

        while attempts < maxAttempts {
            do {
                if let item = try await storage.getSourceItem(id: sourceItemId) {
                    if item.transcript != nil || item.status == .parsed {
                        Self.logger.info("语音转写完成: \(sourceItemId)")
                        return
                    }
                    if item.status == .deleted {
                        Self.logger.warning("语音转写出错")
                        return
                    }
                }
            } catch {
                Self.logger.error("获取 SourceItem 失败: \(error)")
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            attempts += 1
        }

        Self.logger.warning("等待语音转写超时")
    }
}

// MARK: - Screenshot Options View

struct ScreenshotOptionsView: View {
    let onSelect: (ScreenshotMode) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("选择截图模式")
                .font(.headline)

            HStack(spacing: 16) {
                ScreenshotModeButton(
                    icon: "desktopcomputer",
                    title: "全屏"
                ) {
                    onSelect(.fullscreen)
                }

                ScreenshotModeButton(
                    icon: "crop",
                    title: "区域"
                ) {
                    onSelect(.area)
                }

                ScreenshotModeButton(
                    icon: "uiwindow.split.2x1",
                    title: "窗口"
                ) {
                    onSelect(.window)
                }
            }
        }
        .padding()
        .frame(width: 240)
    }
}

struct ScreenshotModeButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground.opacity(0.94))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Webpage Input View

struct WebpageInputView: View {
    @Binding var url: String
    let onSubmit: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("输入网页地址")
                .font(.headline)

            TextField("https://...", text: $url)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)

            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }

                Button("采集") {
                    if let validURL = URL(string: url), url.hasPrefix("http") {
                        onSubmit(validURL)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(url.isEmpty || !url.hasPrefix("http"))
            }
        }
        .padding()
        .frame(width: 360)
    }
}

// MARK: - Capsule Action Button

struct CapsuleActionButton: View {
    let icon: String
    let title: String
    var isLoading: Bool = false
    var tintColor: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(tintColor ?? .primary)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(tintColor ?? .primary)
            }
            .frame(width: 60, height: 50)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Notifications (保留向后兼容)

extension Notification.Name {
    static let captureScreenshot = Notification.Name("captureScreenshot")
    static let captureClipboard = Notification.Name("captureClipboard")
    static let captureText = Notification.Name("captureText")
    static let captureWebpage = Notification.Name("captureWebpage")
    static let captureFile = Notification.Name("captureFile")
    static let captureVoice = Notification.Name("captureVoice")
}
