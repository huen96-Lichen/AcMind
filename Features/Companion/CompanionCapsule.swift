import SwiftUI
import AppKit
import AcMindKit

// MARK: - Companion Capsule
// 随身胶囊 - 顶部刘海式入口

public struct CompanionCapsule: View {
    @StateObject private var viewModel = CompanionCapsuleViewModel()
    @State private var isHovered = false
    @State private var showQuickNote = false

    public init() {}

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
        .sheet(isPresented: $showQuickNote) {
            QuickNotePanel()
        }
    }

    // MARK: - Collapsed Capsule

    private var collapsedCapsule: some View {
        HStack(spacing: 12) {
            // 电池状态
            BatteryIndicatorView(batteryWidth: 22, showPercentage: false)

            // 分隔线
            Divider()
                .frame(height: 16)

            // 品牌标识
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .medium))

                Text("AcMind")
                    .font(.system(size: 13, weight: .medium))
            }

            // 分隔线
            Divider()
                .frame(height: 16)

            // 音乐播放器（迷你）- 从 ViewModel 获取真实状态
            NowPlayingCapsuleView(state: viewModel.playbackState)

            // 分隔线
            Divider()
                .frame(height: 16)

            // 快捷操作图标
            HStack(spacing: 10) {
                CapsuleIconButton(
                    icon: "mic.fill",
                    isActive: viewModel.isVoiceRecording,
                    isLoading: false,
                    action: { viewModel.showVoicePanel() }
                )
                .help("随身语音")

                CapsuleIconButton(
                    icon: "square.and.pencil",
                    isActive: false,
                    isLoading: false,
                    action: { showQuickNote = true }
                )
                .help("快速记录")

                // 截图按钮 - 右键菜单选择截图模式
                Menu {
                    Button("全屏截图") {
                        viewModel.showScreenshot(mode: ScreenshotMode.fullscreen)
                    }
                    Button("区域截图") {
                        viewModel.showScreenshot(mode: ScreenshotMode.area)
                    }
                    Button("窗口截图") {
                        viewModel.showScreenshot(mode: ScreenshotMode.window)
                    }
                } label: {
                    CapsuleIconButton(
                        icon: "camera",
                        isActive: false,
                        isLoading: viewModel.isCapturing,
                        action: { viewModel.showScreenshot(mode: ScreenshotMode.fullscreen) }
                    )
                }
                .menuStyle(.borderlessButton)
                .help("截图收集")

                CapsuleIconButton(
                    icon: "calendar",
                    isActive: false,
                    isLoading: false,
                    action: { viewModel.showSchedule() }
                )
                .help("今日日程")
            }

            // 展开/收起按钮
            Button(action: { viewModel.toggleExpand() }) {
                Image(systemName: viewModel.isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(height: CompanionMenuBarLayout.collapsedHeight)
        .background(
            Capsule()
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.95))
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Expanded Panel

    private var expandedPanel: some View {
        VStack(spacing: 16) {
            // Shelf 暂存区
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "tray.and.arrow.down")
                        .foregroundStyle(Color.secondary)
                        .font(.caption)

                    Text("文件暂存")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                ShelfView()
            }

            Divider()

            // 快捷入口网格
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(viewModel.quickActions) { action in
                    QuickActionButton(action: action)
                }
            }

            Divider()

            // 最近语音转写
            if let lastTranscription = viewModel.lastTranscription {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(Color.secondary)
                            .font(.caption)

                        Text("最近转写")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)

                        Spacer()

                        Text(formatTime(lastTranscription.timestamp))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(lastTranscription.text)
                        .font(.body)
                        .lineLimit(2)
                        .foregroundStyle(Color.primary)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(10)
            }
        }
        .padding(16)
        .frame(width: CompanionMenuBarLayout.expandedWidth)
        .background(
            RoundedRectangle(cornerRadius: CompanionMenuBarLayout.cornerRadiusExpanded)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.98))
                .shadow(color: .black.opacity(0.18), radius: 44, x: 0, y: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionMenuBarLayout.cornerRadiusExpanded)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            NotchPanel.shared.show()
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
