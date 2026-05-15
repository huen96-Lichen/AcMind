import SwiftUI
import AppKit
import AcMindKit

// MARK: - Legacy Companion Capsule
// 旧版随身胶囊兼容层
// 主线已迁移到 NotchV2RootView，这里保留仅用于兼容旧调用路径
@available(*, deprecated, message: "Use NotchV2RootView as the mainline notch implementation.")
public struct CompanionCapsule: View {
    @StateObject private var viewModel = CompanionCapsuleViewModel()
    @State private var showQuickNote = false
    private let onExpansionChange: (Bool) -> Void

    public init(onExpansionChange: @escaping (Bool) -> Void = { _ in }) {
        self.onExpansionChange = onExpansionChange
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toast 反馈
            NotchToastView()
                .padding(.bottom, 4)

            // 收缩状态 - 刘海胶囊
            collapsedCapsule

            // 展开状态 - 扩展面板
            if viewModel.isExpanded {
                expandedPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: CompanionMenuBarLayout.springResponse, dampingFraction: CompanionMenuBarLayout.springDamping), value: viewModel.isExpanded)
        .onChange(of: viewModel.isExpanded) { _, newValue in
            onExpansionChange(newValue)
        }
        .sheet(isPresented: $showQuickNote) {
            QuickNotePanel()
        }
    }

    // MARK: - Collapsed Capsule

    private var collapsedCapsule: some View {
        HStack(spacing: 10) {
            ArtworkGlowView(
                artworkData: viewModel.playbackState.artwork,
                isPlaying: viewModel.playbackState.isPlaying
            )
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.playbackState.title.isEmpty ? "AcMind" : viewModel.playbackState.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(collapsedSubtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                CapsuleStatusDot(color: viewModel.isVoiceRecording ? .red : .secondary)
                CapsuleStatusDot(color: viewModel.playbackState.isPlaying ? .green : .secondary.opacity(0.7))
                CapsuleIconButton(
                    icon: viewModel.isExpanded ? "chevron.up" : "chevron.down",
                    isActive: viewModel.isExpanded,
                    isLoading: false,
                    action: { viewModel.toggleExpand() }
                )
            }
        }
        .padding(.horizontal, 12)
        .frame(width: CompanionMenuBarLayout.collapsedWidth, height: CompanionMenuBarLayout.collapsedHeight)
        .clipped()
        .background(
            NotchShape(topCornerRadius: 8, bottomCornerRadius: 18)
                .fill(Color.black.opacity(0.98))
                .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 2)
        )
        .overlay(
            NotchShape(topCornerRadius: 8, bottomCornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Expanded Panel

    private var expandedPanel: some View {
        VStack(spacing: CompanionMenuBarLayout.moduleSpacing) {
            NotchHeaderStrip(
                playbackState: viewModel.playbackState,
                status: viewModel.status,
                isVoiceRecording: viewModel.isVoiceRecording,
                isCapturing: viewModel.isCapturing
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: CompanionMenuBarLayout.moduleSpacing),
                    GridItem(.flexible(), spacing: CompanionMenuBarLayout.moduleSpacing)
                ],
                spacing: CompanionMenuBarLayout.moduleSpacing
            ) {
                ModuleCard(title: "音乐", subtitle: "播放链路", symbol: "music.note") {
                    ExpandedMusicCard(state: viewModel.playbackState)
                }

                ModuleCard(title: "日程", subtitle: "今日待办", symbol: "calendar") {
                    ExpandedScheduleCard()
                }

                ModuleCard(title: "Agent", subtitle: "任务中枢", symbol: "bubble.left.and.bubble.right") {
                    ExpandedAgentCard(status: viewModel.status)
                }

                ModuleCard(title: "工作台", subtitle: "快速入库", symbol: "tray.and.arrow.down") {
                    ExpandedWorkbenchCard(lastTranscription: viewModel.lastTranscription)
                }
            }

            HStack(alignment: .top, spacing: CompanionMenuBarLayout.moduleSpacing) {
                ModuleCard(title: "最近任务", subtitle: "快捷指令与动作", symbol: "bolt.fill") {
                    ForEach(viewModel.quickActions) { action in
                        QuickActionButton(action: action)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                ModuleCard(title: "暂存区", subtitle: "Obsidian / Markdown", symbol: "square.stack.3d.up") {
                    ShelfView()
                }
            }
        }
        .padding(20)
        .frame(width: CompanionMenuBarLayout.expandedWidth)
        .background(
            NotchShape(topCornerRadius: 12, bottomCornerRadius: CompanionMenuBarLayout.cornerRadiusExpanded)
                .fill(Color.black.opacity(0.98))
                .shadow(color: .black.opacity(0.55), radius: 42, x: 0, y: 22)
        )
        .overlay(
            NotchShape(topCornerRadius: 12, bottomCornerRadius: CompanionMenuBarLayout.cornerRadiusExpanded)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var collapsedSubtitle: String {
        if viewModel.playbackState.isPlaying {
            if viewModel.playbackState.artist.isEmpty {
                return "正在播放"
            }
            return viewModel.playbackState.artist
        }

        if viewModel.playbackState.title.isEmpty == false {
            return viewModel.playbackState.artist.isEmpty ? "已暂停" : viewModel.playbackState.artist
        }

        return "顶部信息中枢"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Notch Module Views

struct ModuleCard<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct NotchHeaderStrip: View {
    let playbackState: PlaybackState
    let status: CompanionStatus
    let isVoiceRecording: Bool
    let isCapturing: Bool

    var body: some View {
        HStack(spacing: 12) {
            CapsuleStatusChip(label: playbackState.isPlaying ? "音乐同步中" : "音乐待机", color: playbackState.isPlaying ? .green : .secondary)
            CapsuleStatusChip(label: status.displayName, color: status.color)
            CapsuleStatusChip(label: isVoiceRecording ? "语音录制中" : "语音待命", color: isVoiceRecording ? .red : .secondary)
            CapsuleStatusChip(label: isCapturing ? "截图处理中" : "工具在线", color: isCapturing ? .orange : .secondary)
            Spacer()
        }
    }
}

struct CapsuleStatusChip: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
    }
}

struct ExpandedMusicCard: View {
    let state: PlaybackState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ArtworkGlowView(artworkData: state.artwork, isPlaying: state.isPlaying)
                .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 8) {
                Text(state.title.isEmpty ? "暂无播放" : state.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                Text(expandedSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                ProgressView(value: state.duration > 0 ? state.currentTime / state.duration : 0)
                    .tint(.white)
                    .scaleEffect(x: 1, y: 0.9, anchor: .center)

                HStack(spacing: 10) {
                    CapsuleIconButton(icon: "backward.fill", action: { MusicService.shared.previousTrack() })
                    CapsuleIconButton(icon: state.isPlaying ? "pause.fill" : "play.fill", isActive: state.isPlaying, action: { MusicService.shared.togglePlay() })
                    CapsuleIconButton(icon: "forward.fill", action: { MusicService.shared.nextTrack() })
                    Spacer()
                }
            }
        }
    }

    private var expandedSubtitle: String {
        let artist = state.artist.isEmpty ? "未知艺术家" : state.artist
        let album = state.album.isEmpty ? "未知专辑" : state.album
        return "\(artist) · \(album)"
    }
}

struct ExpandedScheduleCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日待办")
                .font(.system(size: 14, weight: .semibold))
            ForEach(["整理输入队列", "推进 Agent 链路", "确认音乐同步"], id: \.self) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}

struct ExpandedAgentCard: View {
    let status: CompanionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Agent 状态")
                .font(.system(size: 14, weight: .semibold))
            Text(status.displayName)
                .font(.system(size: 18, weight: .semibold))
            Text("任务入口 / 工具调用 / 反馈循环预留")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

struct ExpandedWorkbenchCard: View {
    let lastTranscription: CompanionVoiceTranscription?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快速入库")
                .font(.system(size: 14, weight: .semibold))
            if let lastTranscription {
                Text(lastTranscription.text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(formatDate(lastTranscription.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                Text("等待输入内容")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ArtworkGlowView: View {
    let artworkData: Data?
    let isPlaying: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(glowColor.opacity(isPlaying ? 0.55 : 0.3))
                .blur(radius: 18)
                .scaleEffect(1.12)

            Circle()
                .fill(Color.black.opacity(0.92))

            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .padding(4)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var glowColor: Color {
        dominantColor(from: artworkData) ?? Color(red: 0.28, green: 0.6, blue: 1.0)
    }

    private func dominantColor(from data: Data?) -> Color? {
        guard let data, let image = NSImage(data: data), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let pixelCount = width * height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: pixelCount * 4)

        let success: Bool = pixels.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard success else { return nil }

        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0
        let sampleStep = max(1, pixelCount / 96)
        var samples = 0.0

        for index in stride(from: 0, to: pixels.count, by: sampleStep * 4) {
            red += Double(pixels[index])
            green += Double(pixels[index + 1])
            blue += Double(pixels[index + 2])
            samples += 1
        }

        guard samples > 0 else { return nil }
        return Color(
            red: red / (255.0 * samples),
            green: green / (255.0 * samples),
            blue: blue / (255.0 * samples)
        )
    }
}

// MARK: - Now Playing Capsule View (Replaces MiniMusicPlayerView)

struct NowPlayingCapsuleView: View {
    let state: PlaybackState

    var body: some View {
        HStack(spacing: 4) {
            if state.isPlaying {
                // 动态波形效果
                HStack(spacing: 1.5) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.accentColor)
                            .frame(width: 2, height: 6 + CGFloat(abs(sinf(Float(i) * 1.2 + Float(Date().timeIntervalSince1970 * 3))) * 6))
                            .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: Date().timeIntervalSince1970)
                    }
                }
                .frame(width: 12, height: 14)
            } else if !state.title.isEmpty {
                Image(systemName: "pause.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(state.title.isEmpty ? "播放中" : state.title)
                    .font(.system(size: 11, weight: state.isPlaying ? .medium : .regular))
                    .lineLimit(1)
                    .foregroundStyle(state.isPlaying ? Color.primary : (state.title.isEmpty ? Color.secondary.opacity(0.55) : Color.secondary))

                if let subtitle = subtitleText(for: state), subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .foregroundStyle(state.isPlaying ? Color.secondary : Color.secondary.opacity(0.55))
                } else if state.title.isEmpty {
                    Text("未播放")
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: 110, alignment: .leading)
        }
    }

    private func subtitleText(for state: PlaybackState) -> String? {
        if state.album.hasPrefix("Bilibili") {
            if state.artist.isEmpty {
                return state.album
            }
            if state.album.contains("已暂停") {
                return "\(state.artist) · 已暂停"
            }
            return state.artist
        }

        if state.artist.isEmpty == false, state.album.isEmpty == false, state.album != state.artist {
            return "\(state.artist) · \(state.album)"
        }

        if state.artist.isEmpty == false {
            return state.artist
        }

        if state.album.isEmpty == false {
            return state.album
        }

        return nil
    }
}

struct CapsuleStatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.35), radius: 5, x: 0, y: 0)
    }
}

// MARK: - Capsule Icon Button

struct CapsuleIconButton: View {
    let icon: String
    var isActive: Bool = false
    var isLoading: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(width: 24, height: 24)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .disabled(isLoading)
    }

    private var foregroundColor: Color {
        if isActive {
            return .accentColor
        } else if isHovered {
            return .primary
        } else {
            return .secondary
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let action: QuickAction
    @State private var isHovered = false

    var body: some View {
        Button(action: { action.handler() }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: action.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isHovered ? Color.accentColor : Color.primary)
                }

                Text(action.title)
                    .font(.caption)
                    .foregroundStyle(Color.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Quick Action

struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let handler: () -> Void
}

// MARK: - View Model

@MainActor
class CompanionCapsuleViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var status: CompanionStatus = .idle
    @Published var lastTranscription: CompanionVoiceTranscription?
    @Published var isVoiceRecording = false
    @Published var isCapturing = false
    @Published var playbackState: PlaybackState = PlaybackState()

    var quickActions: [QuickAction] {
        [
            QuickAction(icon: "mic.fill", title: "随身语音", handler: { [weak self] in
                self?.showVoicePanel()
            }),
            QuickAction(icon: "square.and.pencil", title: "快速记录", handler: { [weak self] in
                self?.showQuickNote()
            }),
            QuickAction(icon: "camera", title: "截图", handler: { [weak self] in
                self?.showScreenshot()
            }),
            QuickAction(icon: "calendar", title: "日程", handler: { [weak self] in
                self?.showSchedule()
            }),
            QuickAction(icon: "tray.and.arrow.down", title: "收集箱", handler: { [weak self] in
                self?.showInbox()
            }),
            QuickAction(icon: "bubble.left", title: "Agent", handler: { [weak self] in
                self?.showAgent()
            })
        ]
    }

    init() {
        // 加载最近转写
        lastTranscription = CompanionMockData.recentTranscriptions.first

        // 订阅音乐播放状态
        setupMusicObserver()

        // 订阅语音录制状态
        setupVoiceObserver()

        // 订阅截图完成通知
        setupCaptureObserver()
    }

    // MARK: - Music Observer

    private func setupMusicObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStateChanged(_:)),
            name: .companionPlaybackStateChanged,
            object: nil
        )
    }

    // MARK: - Voice Observer

    private func setupVoiceObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceRecordingStarted(_:)),
            name: .companionVoiceRecordingStarted,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceRecordingStopped(_:)),
            name: .companionVoiceRecordingStopped,
            object: nil
        )
    }

    // MARK: - Capture Observer

    private func setupCaptureObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCaptureSuccess(_:)),
            name: .companionCaptureSuccess,
            object: nil
        )
    }

    @objc private func handlePlaybackStateChanged(_ notification: Notification) {
        if let state = notification.object as? PlaybackState {
            playbackState = state
        }
    }

    @objc private func handleVoiceRecordingStarted(_ notification: Notification) {
        isVoiceRecording = true
    }

    @objc private func handleVoiceRecordingStopped(_ notification: Notification) {
        isVoiceRecording = false
    }

    @objc private func handleCaptureSuccess(_ notification: Notification) {
        isCapturing = false
        ToastManager.shared.show(.success, "截图已完成")
    }

    // MARK: - Actions

    func toggleExpand() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
    }

    func showVoicePanel() {
        NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
        isExpanded = false
    }

    func showQuickNote() {
        NotificationCenter.default.post(name: .companionShowQuickNote, object: nil)
        isExpanded = false
    }

    func showScreenshot(mode: ScreenshotMode = ScreenshotMode.fullscreen) {
        isCapturing = true
        ToastManager.shared.show(.info, "正在截图...")
        
        // 隐藏刘海窗口避免截图遮挡
        NotchPanel.shared.orderOut(nil)
        
        // 触发截图（携带截图模式）
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureScreenshot"),
            object: ["mode": mode.rawValue]
        )
        
        // 截图完成后需要重新显示刘海
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            DynamicSurfaceCoordinator.shared.transition(to: .continentCompact, reason: .capture)
        }
        isExpanded = false
    }

    func showSchedule() {
        NotificationCenter.default.post(name: .companionShowSchedule, object: nil)
        isExpanded = false
        ToastManager.shared.show(.info, "打开日程")
    }

    func showInbox() {
        NotificationCenter.default.post(name: .companionShowInbox, object: nil)
        isExpanded = false
        ToastManager.shared.show(.info, "打开收集箱")
    }

    func showAgent() {
        NotificationCenter.default.post(name: .companionShowAgent, object: nil)
        isExpanded = false
        ToastManager.shared.show(.info, "打开 Agent")
    }

    func updateStatus(_ newStatus: CompanionStatus) {
        status = newStatus
    }
}

// MARK: - Notifications

extension Notification.Name {
    public static let companionShowVoicePanel = Notification.Name("companion.showVoicePanel")
    public static let companionShowCapturePanel = Notification.Name("companion.showCapturePanel")
    public static let companionShowSchedule = Notification.Name("companion.showSchedule")
    public static let companionShowInbox = Notification.Name("companion.showInbox")
    public static let companionShowAgent = Notification.Name("companion.showAgent")
    public static let companionPlaybackStateChanged = Notification.Name("companion.playbackStateChanged")
    public static let companionVoiceRecordingStarted = Notification.Name("companion.voiceRecordingStarted")
    public static let companionVoiceRecordingStopped = Notification.Name("companion.voiceRecordingStopped")
    public static let companionCaptureSuccess = Notification.Name("companion.captureSuccess")
    public static let companionShowQuickNote = Notification.Name("companion.showQuickNote")
    public static let companionQuickNoteSaved = Notification.Name("companion.quickNoteSaved")
    public static let companionSendToAgent = Notification.Name("companion.sendToAgent")
}
