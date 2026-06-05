import Foundation
import AppKit
import SwiftUI
import Combine
import AcMindKit

enum NotchPresentationState: Equatable {
    case hidden
    case compact
    case expanding
    case expanded
    case collapsing
    case blockedClose
    case transientHUD

    var isExpandedVisual: Bool {
        switch self {
        case .expanding, .expanded, .blockedClose:
            return true
        case .hidden, .compact, .collapsing, .transientHUD:
            return false
        }
    }

    var targetFrameIsExpanded: Bool {
        isExpandedVisual
    }

    var animationDuration: TimeInterval {
        switch self {
        case .hidden:
            return 0.15
        case .compact:
            return 0.24
        case .expanding, .expanded:
            return 0.32
        case .collapsing:
            return 0.24
        case .blockedClose:
            return 0.18
        case .transientHUD:
            return 0.2
        }
    }
}

enum NotchCloseBlocker: Equatable {
    case voice
    case screenshot

    var displayName: String {
        switch self {
        case .voice:
            return "说入法运行中"
        case .screenshot:
            return "截图处理中"
        }
    }
}

@MainActor
final class NotchV2ViewModel: ObservableObject {
    struct OverviewMetric: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    struct OverviewStatusRow: Identifiable {
        let id = UUID()
        let icon: String?
        let title: String
        let value: String
        let accent: Color
    }

    @Published var isExpanded = true
    @Published var presentationState: NotchPresentationState = .expanded
    @Published var selectedPage: NotchV2Page = .overview
    @Published var displaySettings: CompanionDisplaySettings = CompanionDisplaySettingsStore.load()
    @Published var collapsedSize: CGSize = CGSize(width: CompanionMenuBarLayout.collapsedWidth, height: CompanionMenuBarLayout.collapsedHeight)
    @Published var playbackState = PlaybackState()
    @Published var isVoiceRecording = false
    @Published var isVoiceProcessing = false
    @Published var voiceSurfaceState: NotchV2VoiceSurfaceState = .idle
    @Published var isCapturing = false
    @Published var status: CompanionStatus = .ready
    @Published var lastTranscription: CompanionVoiceTranscription?
    @Published var batteryInfo = BatteryInfo()
    @Published var microphonePermissionStatus: AppPermissionStatus = .unknown
    @Published var screenRecordingPermissionStatus: AppPermissionStatus = .unknown
    @Published var accessibilityPermissionStatus: AppPermissionStatus = .unknown
    @Published var activeModelLabel: String = "未配置模型"
    @Published var activeProviderStatus: String = "未配置"
    @Published var quickAskDraft: String = ""
    @Published var quickAskMessages: [ChatMessage] = []
    @Published var quickAskIsSending: Bool = false
    @Published var quickAskError: String?

    var playbackAccentColor: Color {
        guard let artworkData = playbackState.artwork,
              let image = NSImage(data: artworkData) else {
            return NotchV2DesignTokens.accentBlue
        }
        return extractDominantColor(from: image)
    }

    private func extractDominantColor(from image: NSImage) -> Color {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return NotchV2DesignTokens.accentBlue
        }
        let size = CGSize(width: 1, height: 1)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                       isPlanar: false, colorSpaceName: .calibratedRGB,
                                       bytesPerRow: 4, bitsPerPixel: 32)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.draw(cgImage, in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        let pixel = bitmap.bitmapData!
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    struct QuickAction: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let module: DynamicContinentModuleID?
        let action: () -> Void
    }

    private let batteryService = BatteryService.shared
    private let aiRuntime: AIRuntimeProtocol
    private let quickAskService: AgentQuickAskService
    private let systemEventCenter = SystemEventCenter.shared
    private let permissionManager: PermissionManager
    private var cancellables = Set<AnyCancellable>()
    private var voiceStateResetTask: Task<Void, Never>?
    private var presentationStateTransitionTask: Task<Void, Never>?
    private var quickAskSessionId = "companion-quick-ask"
    private var selectedQuickAskProviderId: String?
    private var selectedQuickAskModelId: String?

    private lazy var allQuickActions: [QuickAction] = [
        QuickAction(icon: "camera.viewfinder", title: "截图", module: nil, action: { [weak self] in self?.captureScreenshot() }),
        QuickAction(icon: "doc.text", title: "MD", module: nil, action: { [weak self] in self?.quickMarkdown() }),
        QuickAction(icon: "pin.fill", title: "Pin", module: .agent, action: { [weak self] in self?.showAgent() }),
        QuickAction(icon: "waveform", title: "SRPT", module: nil, action: { [weak self] in self?.showVoicePanel() })
    ]

    var quickActions: [QuickAction] {
        allQuickActions.filter { action in
            guard let module = action.module else { return true }
            return isModuleEnabled(module)
        }
    }

    private var runtimeSurfaceContext: NotchRuntimeSurfaceContext {
        NotchRuntimeSurfaceContext(
            displaySettings: displaySettings,
            selectedPage: effectiveSelectedPage,
            voiceSurfaceState: voiceSurfaceState,
            isCapturing: isCapturing,
            playbackState: playbackState,
            status: status,
            lastTranscription: lastTranscription,
            batteryInfo: batteryInfo,
            microphonePermissionStatus: microphonePermissionStatus,
            screenRecordingPermissionStatus: screenRecordingPermissionStatus,
            accessibilityPermissionStatus: accessibilityPermissionStatus
        )
    }

    var collapsedRuntimeSurface: NotchRuntimeSurface {
        NotchRuntimeSurfaceDispatcher.resolve(context: runtimeSurfaceContext, scope: .collapsed)
    }

    var activeRuntimeSurface: NotchRuntimeSurface {
        NotchRuntimeSurfaceDispatcher.resolve(context: runtimeSurfaceContext, scope: .primary)
    }

    var overviewAgentStatusRows: [OverviewStatusRow] {
        [
            .init(icon: status.icon, title: "Agent", value: status.displayName, accent: status.color),
            .init(icon: "cpu", title: "模型", value: activeModelLabel, accent: NotchV2DesignTokens.accentBlue),
            .init(icon: "mic.fill", title: "说入法", value: isVoiceRecording ? "正在收音" : "待命", accent: isVoiceRecording ? .red : NotchV2DesignTokens.secondaryText),
            .init(icon: "camera.viewfinder", title: "截图", value: isCapturing ? "处理中" : "待命", accent: isCapturing ? .orange : NotchV2DesignTokens.secondaryText)
        ]
    }

    var overviewSystemStatusRows: [OverviewStatusRow] {
        [
            .init(icon: nil, title: "电池", value: batteryStateText, accent: batteryAccent),
            .init(icon: nil, title: "麦克风", value: microphonePermissionStatus.displayName, accent: microphonePermissionStatus == .authorized ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.secondaryText),
            .init(icon: nil, title: "录屏", value: screenRecordingPermissionStatus.displayName, accent: screenRecordingPermissionStatus == .authorized ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.secondaryText),
            .init(icon: nil, title: "辅助功能", value: accessibilityPermissionStatus.displayName, accent: accessibilityPermissionStatus == .authorized ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.secondaryText)
        ]
    }

    var closeBlocker: NotchCloseBlocker? {
        if voiceSurfaceState == .listening || voiceSurfaceState == .processing {
            return .voice
        }
        if isCapturing {
            return .screenshot
        }
        return nil
    }

    init() {
        permissionManager = ServiceContainer.isInitialized() ? ServiceContainer.shared.permissionManager : PermissionManager()
        aiRuntime = ServiceContainer.isInitialized() ? ServiceContainer.shared.aiRuntime : AIRuntimeService()
        quickAskService = AgentQuickAskService(
            aiRuntime: aiRuntime,
            storage: ServiceContainer.isInitialized() ? ServiceContainer.shared.storageService : nil
        )
        playbackState = Self.snapshot()
        lastTranscription = nil
        quickAskMessages = [
            ChatMessage(
                sessionId: quickAskSessionId,
                role: .assistant,
                content: "直接说，我帮你快速处理。",
                status: .completed
            )
        ]
        syncDisplaySettings()
        setupObservers()
        setupSystemObservers()
        syncSystemStatus()
        Task { await syncAIState() }
    }

    func toggleExpansion() {
        withAnimation(.spring(response: NotchV2DesignTokens.springResponse, dampingFraction: NotchV2DesignTokens.springDampingFraction)) {
            if presentationState.isExpandedVisual {
                collapse()
            } else {
                requestOpen(page: effectiveSelectedPage)
            }
        }
    }

    func collapse() {
        guard presentationState != .compact && presentationState != .collapsing else { return }
        withAnimation(.spring(response: NotchV2DesignTokens.springResponse, dampingFraction: NotchV2DesignTokens.springDampingFraction)) {
            if closeBlocker == nil {
                transitionPresentationState(to: .collapsing, finalState: .compact)
            } else {
                setPresentationState(.blockedClose)
            }
        }
    }

    func select(_ page: NotchV2Page) {
        guard isPageEnabled(page) else { return }
        selectedPage = page
        requestOpen(page: page)
    }

    func requestHide() {
        presentationStateTransitionTask?.cancel()
        setPresentationState(.hidden)
    }

    func requestCompact() {
        if closeBlocker == nil {
            transitionPresentationState(to: .collapsing, finalState: .compact)
        } else {
            setPresentationState(.blockedClose)
        }
    }

    func requestOpen(page: NotchV2Page? = nil) {
        if let page {
            selectedPage = page
        }
        transitionPresentationState(to: .expanding, finalState: .expanded)
    }

    func requestTransientHUD() {
        setPresentationState(.transientHUD)
    }

    func playPause() {
        MusicService.shared.togglePlay()
    }

    func nextTrack() {
        MusicService.shared.nextTrack()
    }

    func previousTrack() {
        MusicService.shared.previousTrack()
    }

    var expandedHeight: CGFloat {
        switch effectiveSelectedPage {
        case .overview:
            return NotchV2DesignTokens.expandedOverviewHeight
        case .music:
            return NotchV2DesignTokens.expandedMusicHeight
        case .agent:
            return NotchV2DesignTokens.expandedAgentHeight
        case .schedule:
            return NotchV2DesignTokens.expandedScheduleHeight
        case .systemStatus:
            return NotchV2DesignTokens.expandedSystemStatusHeight
        }
    }

    var effectiveSelectedPage: NotchV2Page {
        isPageEnabled(selectedPage) ? selectedPage : .overview
    }

    private func setPresentationState(_ state: NotchPresentationState) {
        presentationStateTransitionTask?.cancel()
        presentationState = state
        isExpanded = state.isExpandedVisual
    }

    private func transitionPresentationState(to state: NotchPresentationState, finalState: NotchPresentationState) {
        presentationStateTransitionTask?.cancel()
        setPresentationState(state)

        presentationStateTransitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(state.animationDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.presentationState == state else { return }
                self.presentationState = finalState
                self.isExpanded = finalState.isExpandedVisual
            }
        }
    }

    func isModuleEnabled(_ module: DynamicContinentModuleID) -> Bool {
        displaySettings.enabledDynamicModules.contains(module)
    }

    func isOverviewModuleVisible(_ module: DynamicContinentModuleID) -> Bool {
        module.supportsOverviewSummary && displaySettings.overviewVisibleModules.contains(module) && isModuleEnabled(module)
    }

    func isRuntimeContentVisible(_ content: CompanionRuntimeContentID, scope: NotchRuntimeSurfaceScope) -> Bool {
        switch scope {
        case .collapsed:
            return displaySettings.collapsedVisibleContents.contains(content)
        case .primary:
            return displaySettings.primarySurfaceContents.contains(content)
        }
    }

    func isPageEnabled(_ page: NotchV2Page) -> Bool {
        switch page {
        case .overview:
            return true
        case .music:
            return isModuleEnabled(.music)
        case .agent:
            return isModuleEnabled(.agent)
        case .schedule:
            return isModuleEnabled(.schedule)
        case .systemStatus:
            return isModuleEnabled(.systemStatus)
        }
    }

    var voiceDisplayTitle: String? {
        voiceSurfaceState.displayTitle
    }

    var batteryStateText: String {
        let percentage = Int(batteryInfo.percentage.rounded())
        if batteryInfo.isInLowPowerMode {
            return "\(percentage)% · 低电量模式"
        }
        if batteryInfo.isCharging {
            return "\(percentage)% · 充电中"
        }
        if batteryInfo.isPluggedIn {
            return "\(percentage)% · 接电"
        }
        return "\(percentage)%"
    }

    var batteryAccent: Color {
        if batteryInfo.isInLowPowerMode {
            return .orange
        }
        if batteryInfo.percentage <= 20 && batteryInfo.isCharging == false {
            return .red
        }
        if batteryInfo.isCharging || batteryInfo.isPluggedIn {
            return NotchV2DesignTokens.accentBlue
        }
        return NotchV2DesignTokens.secondaryText
    }

    var voiceDisplaySubtitle: String? {
        voiceSurfaceState.displaySubtitle
    }

    var voiceDisplayIcon: String {
        voiceSurfaceState.displayIcon
    }

    var voiceDisplayAccent: Color {
        switch voiceSurfaceState {
        case .idle:
            return NotchV2DesignTokens.secondaryText
        case .listening, .completed:
            return NotchV2DesignTokens.accentBlue
        case .processing:
            return NotchV2DesignTokens.accentBlue
        case .cancelled:
            return .red
        }
    }

    var voiceWaveformMode: NotchV2VoiceWaveformMode {
        voiceSurfaceState.waveformMode
    }

    var showsVoiceWaveform: Bool {
        voiceSurfaceState.showsWaveform
    }

    var isVoicePriorityActive: Bool {
        voiceSurfaceState.isActive
    }

    var hasVoiceOverride: Bool {
        voiceSurfaceState != .idle
    }

    var voiceDisplayPriority: NotchV2SurfacePriority {
        voiceSurfaceState.surfacePriority
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStateChanged(_:)),
            name: .companionPlaybackStateChanged,
            object: nil
        )
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceProcessingStarted(_:)),
            name: .companionVoiceProcessingStarted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceProcessingFinished(_:)),
            name: .companionVoiceProcessingFinished,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceCancelled(_:)),
            name: .companionVoiceCancelled,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCaptureSuccess(_:)),
            name: .companionCaptureSuccess,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserDefaultsChanged(_:)),
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.standard
        )
    }

    private func setupSystemObservers() {
        batteryService.$batteryInfo
            .receive(on: RunLoop.main)
            .sink { [weak self] info in
                self?.batteryInfo = info
            }
            .store(in: &cancellables)

        permissionManager.$statuses
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncPermissions()
            }
            .store(in: &cancellables)

        systemEventCenter.$currentHUD
            .receive(on: RunLoop.main)
            .sink { [weak self] item in
                guard let self else { return }
                if item != nil {
                    if self.presentationState == .compact {
                        self.setPresentationState(.transientHUD)
                    }
                } else if self.presentationState == .transientHUD {
                    self.setPresentationState(.compact)
                }
            }
            .store(in: &cancellables)

        Task { [weak self] in
            await self?.permissionManager.refreshAll()
            await MainActor.run {
                self?.syncPermissions()
            }
        }
    }

    private func syncAIState() async {
        let providers = await aiRuntime.listProviders()
        guard let provider = providers.first(where: { $0.enabled }) ?? providers.first else {
            activeModelLabel = "未配置模型"
            activeProviderStatus = "未配置"
            selectedQuickAskProviderId = nil
            selectedQuickAskModelId = nil
            return
        }

        let providerName = provider.name.isEmpty ? provider.providerType.displayName : provider.name
        if provider.modelId.isEmpty {
            activeModelLabel = providerName
        } else {
            activeModelLabel = "\(providerName) · \(provider.modelId)"
        }
        selectedQuickAskProviderId = provider.id
        selectedQuickAskModelId = provider.modelId.isEmpty ? nil : provider.modelId

        switch provider.tier {
        case .localLight, .localHeavy:
            activeProviderStatus = "本地就绪"
        case .cloudLight, .cloudHeavy:
            activeProviderStatus = "云端就绪"
        }
    }

    func sendQuickAsk() async {
        let prompt = quickAskDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }

        quickAskDraft = ""
        quickAskError = nil
        quickAskIsSending = true

        quickAskMessages.append(
            ChatMessage(
                sessionId: quickAskSessionId,
                role: .user,
                content: prompt,
                status: .completed
            )
        )
        trimQuickAskMessages()

        do {
            let response = try await quickAskService.ask(
                question: prompt,
                providerId: selectedQuickAskProviderId,
                model: selectedQuickAskModelId,
                context: quickAskContextSummary
            )

            quickAskMessages.append(
                ChatMessage(
                    sessionId: quickAskSessionId,
                    role: .assistant,
                    content: response.content.trimmingCharacters(in: .whitespacesAndNewlines),
                    status: .completed,
                    modelId: response.model,
                    providerId: response.providerId,
                    promptTokens: response.promptTokens,
                    completionTokens: response.completionTokens,
                    latencyMs: response.latencyMs
                )
            )
            trimQuickAskMessages()
        } catch {
            quickAskError = error.localizedDescription
            quickAskMessages.append(
                ChatMessage(
                    sessionId: quickAskSessionId,
                    role: .assistant,
                    content: "未能发送：\(error.localizedDescription)",
                    status: .failed
                )
            )
            trimQuickAskMessages()
        }

        quickAskIsSending = false
    }

    func clearQuickAskDraft() {
        quickAskDraft = ""
    }

    private func trimQuickAskMessages() {
        if quickAskMessages.count > 4 {
            quickAskMessages = Array(quickAskMessages.suffix(4))
        }
    }

    private var quickAskContextSummary: String {
        let focus = activeRuntimeSurface.subtitle.isEmpty ? activeRuntimeSurface.title : activeRuntimeSurface.subtitle
        return "\(activeRuntimeSurface.title) · \(focus)"
    }

    @objc private func handlePlaybackStateChanged(_ notification: Notification) {
        if let state = notification.object as? PlaybackState {
            playbackState = state
        }
    }

    @objc private func handleVoiceRecordingStarted(_ notification: Notification) {
        updateVoiceState(.listening)
        if presentationState != .hidden {
            setPresentationState(.blockedClose)
        }
        SystemEventCenter.shared.publish(
            .sayInput,
            title: "说入法收音中",
            detail: "松开 Fn 完成 · Esc 取消",
            duration: 1.2
        )
    }

    @objc private func handleVoiceRecordingStopped(_ notification: Notification) {
        updateVoiceState(.processing)
        if presentationState != .hidden {
            setPresentationState(.blockedClose)
        }
        SystemEventCenter.shared.publish(
            .sayInput,
            title: "正在清洗文稿",
            detail: "准备写入当前光标",
            duration: 1.2
        )
    }

    @objc private func handleVoiceProcessingStarted(_ notification: Notification) {
        updateVoiceState(.processing)
        if presentationState != .hidden {
            setPresentationState(.blockedClose)
        }
        SystemEventCenter.shared.publish(
            .sayInput,
            title: "正在清洗文稿",
            detail: "准备写入当前光标",
            duration: 1.2
        )
    }

    @objc private func handleVoiceProcessingFinished(_ notification: Notification) {
        let destination = voiceDestination(from: notification.object) ?? .clipboard
        updateVoiceState(.completed(destination: destination), autoResetAfter: 1.0)
        if presentationState == .blockedClose {
            setPresentationState(.compact)
        }
        SystemEventCenter.shared.publish(
            .sayInput,
            title: destination.title,
            detail: destination.subtitle,
            duration: 1.0
        )
    }

    @objc private func handleVoiceCancelled(_ notification: Notification) {
        updateVoiceState(.cancelled, autoResetAfter: 0.7)
        if presentationState == .blockedClose {
            setPresentationState(.compact)
        }
        SystemEventCenter.shared.publish(
            .sayInput,
            title: "已取消",
            detail: "",
            duration: 0.8
        )
    }

    @objc private func handleCaptureSuccess(_ notification: Notification) {
        isCapturing = false
        if presentationState == .blockedClose {
            setPresentationState(.compact)
        }
        ToastManager.shared.show(.success, "截图已完成")
        SystemEventCenter.shared.dismiss(animated: true)
    }

    @objc private func handleUserDefaultsChanged(_ notification: Notification) {
        Task { @MainActor in
            self.syncDisplaySettings()
        }
    }

    private func updateVoiceState(_ state: NotchV2VoiceSurfaceState, autoResetAfter delay: TimeInterval? = nil) {
        voiceStateResetTask?.cancel()
        voiceSurfaceState = state

        switch state {
        case .idle:
            isVoiceRecording = false
            isVoiceProcessing = false
        case .listening:
            isVoiceRecording = true
            isVoiceProcessing = false
        case .processing:
            isVoiceRecording = false
            isVoiceProcessing = true
        case .completed, .cancelled:
            isVoiceRecording = false
            isVoiceProcessing = false
        }

        guard let delay else { return }
        voiceStateResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.updateVoiceState(.idle)
                if self?.presentationState == .blockedClose, self?.closeBlocker == nil {
                    self?.setPresentationState(.compact)
                }
            }
        }
    }

    private func voiceDestination(from object: Any?) -> NotchV2VoiceCompletionDestination? {
        if let object = object as? [String: Any], let destination = object["destination"] as? String {
            return NotchV2VoiceCompletionDestination(rawValue: destination)
        }
        if let destination = object as? String {
            return NotchV2VoiceCompletionDestination(rawValue: destination)
        }
        return nil
    }

    private func captureScreenshot() {
        guard SettingsLocalPreferences.isCaptureScreenshotEnabled() else {
            ToastManager.shared.show(.warning, "截图捕获已在设置中关闭")
            return
        }

        isCapturing = true
        setPresentationState(.hidden)
        SystemEventCenter.shared.publish(
            .screenshot,
            title: "截图处理中",
            detail: "正在截取当前屏幕",
            duration: 1.6
        )
        ToastManager.shared.show(.info, "正在截图...")
        NotchPanel.shared.hide()
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureScreenshot"),
            object: ["mode": ScreenshotMode.fullscreen.rawValue]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isCapturing = false
            NotchPanel.shared.showCompact()
        }
    }

    private func quickMarkdown() {
        NotificationCenter.default.post(name: Notification.Name("companion.quickMarkdown"), object: nil)
        ToastManager.shared.show(.info, "打开 MD")
        requestCompact()
    }

    func showVoicePanel() {
        guard SettingsLocalPreferences.isVoiceInputEnabled() else {
            ToastManager.shared.show(.warning, "说入法输入已在设置中关闭")
            return
        }

        SystemEventCenter.shared.publish(
            .sayInput,
            title: "说入法",
            detail: "准备收音",
            duration: 1.2
        )
        NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
        requestCompact()
    }

    func showAgent() {
        NotificationCenter.default.post(name: .companionShowAgent, object: nil)
        requestCompact()
    }

    func showMainHome() {
        NotificationCenter.default.post(name: Notification.Name("AcMind.openHome"), object: nil)
        requestCompact()
    }

    func showMainSettings() {
        NotificationCenter.default.post(name: Notification.Name("AcMind.openSettings"), object: nil)
        requestCompact()
    }

    private static func snapshot() -> PlaybackState {
        let service = MusicService.shared
        return PlaybackState(
            title: service.songTitle,
            artist: service.artistName,
            album: service.album,
            artwork: service.albumArt?.tiffRepresentation,
            isPlaying: service.isPlaying,
            duration: service.songDuration,
            currentTime: service.elapsedTime,
            playbackRate: service.playbackRate,
            isShuffled: service.isShuffled,
            repeatMode: service.repeatMode,
            bundleIdentifier: service.bundleIdentifier,
            lastUpdated: Date()
        )
    }

    private func syncPermissions() {
        microphonePermissionStatus = permissionManager.statuses[.microphone] ?? .unknown
        screenRecordingPermissionStatus = permissionManager.statuses[.screenRecording] ?? .unknown
        accessibilityPermissionStatus = permissionManager.statuses[.accessibility] ?? .unknown
    }

    private func syncSystemStatus() {
        batteryInfo = batteryService.batteryInfo
        syncPermissions()
        syncDisplaySettings()
    }

    private func syncDisplaySettings() {
        displaySettings = CompanionDisplaySettingsStore.load()
        let screen = NSScreen.main ?? NSScreen.screens.first
        let size: CGSize
        if let screen {
            let frame = CompanionScreenPositioning.collapsedFrame(on: screen.frame)
            size = frame.size
        } else {
            size = CGSize(width: CompanionMenuBarLayout.collapsedWidth, height: CompanionMenuBarLayout.collapsedHeight)
        }
        collapsedSize = size
        if isPageEnabled(selectedPage) == false {
            selectedPage = .overview
        }
        if presentationState == .blockedClose, closeBlocker == nil {
            setPresentationState(.compact)
        }
    }
}
