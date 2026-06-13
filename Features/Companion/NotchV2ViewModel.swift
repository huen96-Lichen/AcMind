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

typealias NotchV2SystemAttentionHintCard = NotchV2ViewModel.SystemAttentionHintCard

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

enum FanControlPreset: String, CaseIterable, Identifiable {
    case low = "10%"
    case medium = "50%"
    case high = "100%"

    var id: String { rawValue }

    var speedRatio: Double {
        switch self {
        case .low: return 0.10
        case .medium: return 0.50
        case .high: return 1.0
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

    struct AttentionHint: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let subtitle: String
        let accent: Color
    }

    struct SystemAttentionHintCard: View {
        let hint: AttentionHint
        let openStatusAction: () -> Void

        var body: some View {
            NotchV2Card(title: hint.title, symbol: hint.symbol, cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(hint.accent)
                            .frame(width: 7, height: 7)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(hint.subtitle)
                                .font(NotchV2DesignTokens.Typography.body)
                                .foregroundStyle(NotchV2DesignTokens.primaryText)
                                .lineLimit(2)
                                .truncationMode(.tail)

                            Text("不抢主位，只作提醒。")
                                .font(NotchV2DesignTokens.Typography.caption)
                                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Button("查看状态") {
                        openStatusAction()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    @Published var isExpanded = true
    @Published var presentationState: NotchPresentationState = .expanded
    @Published var selectedPage: NotchV2Page = .overview
    @Published var displaySettings: CompanionDisplaySettings = CompanionDisplaySettingsStore.load()
    @Published var collapsedSize: CGSize = CGSize(width: CompanionMenuBarLayout.collapsedWidth, height: CompanionMenuBarLayout.collapsedHeight)
    @Published var playbackState = PlaybackState()
    @Published var lyrics: String?
    @Published var isLoadingLyrics = false
    @Published var isVoiceRecording = false
    @Published var isVoiceProcessing = false
    @Published var voiceSurfaceState: NotchV2VoiceSurfaceState = .idle
    @Published var isCapturing = false
    @Published var status: CompanionStatus = .ready
    @Published var lastTranscription: CompanionVoiceTranscription?
    @Published var batteryInfo = BatteryInfo()
    @Published private(set) var systemStatusSnapshot = SystemStatusSnapshot()
    @Published var microphonePermissionStatus: AppPermissionStatus = .unknown
    @Published var screenRecordingPermissionStatus: AppPermissionStatus = .unknown
    @Published var accessibilityPermissionStatus: AppPermissionStatus = .unknown
    @Published var activeModelLabel: String = SettingsStatusLabelFormatter.unconfiguredModelText
    @Published var activeProviderStatus: String = SettingsStatusLabelFormatter.unconfiguredProviderText
    @Published var fanControlPreset: FanControlPreset = .medium
    @Published var quickAskDraft: String = ""
    @Published var quickAskMessages: [ChatMessage] = []
    @Published var quickAskIsSending: Bool = false
    @Published var quickAskError: String?
    @Published var realtimeTranscript: String = ""
    @Published var isRecordingActive: Bool = false

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

    private let batteryService: BatteryService
    private let aiRuntime: AIRuntimeProtocol
    private let quickAskService: AgentQuickAskService
    private let systemStatusService: SystemStatusService
    let systemEventCenter: SystemEventCenter
    let musicService: MusicService
    private let permissionManager: PermissionManager
    private let panelController: NotchPanelControlling
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

    var hasPlaybackContext: Bool {
        playbackState.title.isEmpty == false ||
        playbackState.artist.isEmpty == false ||
        playbackState.album.isEmpty == false ||
        playbackState.bundleIdentifier != nil ||
        playbackState.sourceLabel.isEmpty == false
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
            .init(icon: "mic.fill", title: "说入法", value: ActivityStateLabelFormatter.activityLabel(isActive: isVoiceRecording, activeLabel: "正在收音", idleLabel: "待命"), accent: isVoiceRecording ? .red : NotchV2DesignTokens.secondaryText),
            .init(icon: "camera.viewfinder", title: "截图", value: ActivityStateLabelFormatter.activityLabel(isActive: isCapturing, activeLabel: "处理中", idleLabel: "待命"), accent: isCapturing ? .orange : NotchV2DesignTokens.secondaryText)
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

    init(
        panelController: NotchPanelControlling,
        batteryService: BatteryService,
        systemStatusService: SystemStatusService,
        systemEventCenter: SystemEventCenter,
        musicService: MusicService
    ) {
        self.panelController = panelController
        self.batteryService = batteryService
        self.systemStatusService = systemStatusService
        self.systemEventCenter = systemEventCenter
        self.musicService = musicService
        permissionManager = PermissionManager()
        aiRuntime = AIRuntimeService()
        quickAskService = AgentQuickAskService(
            aiRuntime: aiRuntime,
            storage: StorageService()
        )
        playbackState = snapshot()
        systemStatusSnapshot = systemStatusService.snapshot
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
        bindMusicService()
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

    func openSystemStatusPage() {
        selectedPage = .systemStatus
        requestOpen(page: .systemStatus)
    }

    func openSystemStatusWindow() {
        (NSApp.delegate as? AppDelegate)?.showSystemStatus()
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
        musicService.togglePlay()
    }

    func nextTrack() {
        musicService.nextTrack()
    }

    func previousTrack() {
        musicService.previousTrack()
    }

    var expandedHeight: CGFloat {
        CompanionMenuBarLayout.expandedHeight
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
            return true
        }
    }

    var voiceDisplayTitle: String? {
        voiceSurfaceState.displayTitle
    }

    var batteryDisplayText: String {
        guard batteryInfo.isAvailable else { return "♾️" }
        return "\(Int(batteryInfo.percentage.rounded()))%"
    }

    var batteryStateText: String {
        guard batteryInfo.isAvailable else { return "♾️ · 无电池" }
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

    var batteryIconName: String {
        guard batteryInfo.isAvailable else { return "infinity" }
        if batteryInfo.isCharging {
            return "bolt.fill"
        }
        if batteryInfo.isPluggedIn {
            return "plug.fill"
        }

        let level = batteryInfo.percentage
        switch level {
        case ..<10: return "battery.0"
        case ..<25: return "battery.25"
        case ..<50: return "battery.50"
        case ..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    var batteryAccent: Color {
        if batteryInfo.isAvailable == false {
            return NotchV2DesignTokens.secondaryText
        }
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

    var systemBatterySummary: String {
        batteryDisplayText
    }

    var systemNetworkSummary: String {
        guard let download = systemStatusSnapshot.networkDownloadMBps,
              let upload = systemStatusSnapshot.networkUploadMBps else {
            return "—"
        }
        return "↓ \(formatMBps(download)) · ↑ \(formatMBps(upload))"
    }

    var systemNetworkDownloadSummary: String {
        guard let download = systemStatusSnapshot.networkDownloadMBps else { return "—" }
        return formatMBps(download)
    }

    var systemNetworkUploadSummary: String {
        guard let upload = systemStatusSnapshot.networkUploadMBps else { return "—" }
        return formatMBps(upload)
    }

    var systemTemperatureSummary: String {
        if let sensor = systemStatusSnapshot.temperatureSensors.first(where: { $0.isAvailable && $0.value != nil }) {
            return sensor.value.map { formatTemperature($0) } ?? "—"
        }
        if let batteryTemperature = systemStatusSnapshot.battery?.temperatureC {
            return formatTemperature(batteryTemperature)
        }
        return "—"
    }

    var systemTemperatureDetail: String {
        if let sensor = systemStatusSnapshot.temperatureSensors.first(where: { $0.isAvailable && $0.value != nil }) {
            return sensor.name
        }
        if systemStatusSnapshot.battery?.temperatureC != nil {
            return "电池温度"
        }
        return "采样中"
    }

    var systemFanSummary: String {
        let values = systemStatusSnapshot.fanSensors.compactMap { $0.value }
        guard values.isEmpty == false else { return "—" }
        let average = values.reduce(0, +) / Double(values.count)
        return formatRPM(average)
    }

    var systemFanDetail: String {
        guard systemStatusSnapshot.fanSensors.isEmpty == false else { return "采样中" }
        if systemStatusSnapshot.fanSensors.allSatisfy({ $0.isAutomatic == true }) {
            return "\(systemStatusSnapshot.fanSensors.count) 个风扇 · 自动"
        }
        return "\(systemStatusSnapshot.fanSensors.count) 个风扇 · 只读"
    }

    var systemCPUUsageSummary: String {
        formatPercent(systemStatusSnapshot.cpuUsage)
    }

    var systemMemoryUsageSummary: String {
        formatPercent(systemStatusSnapshot.memoryUsagePercent)
    }

    var systemFanControlPresets: [FanControlPreset] {
        FanControlPreset.allCases
    }

    func selectFanControlPreset(_ preset: FanControlPreset) {
        fanControlPreset = preset
    }

    var voiceDisplaySubtitle: String {
        ActivityStateLabelFormatter.activityLabel(
            isActive: voiceSurfaceState.isActive,
            activeLabel: voiceSurfaceState.displaySubtitle ?? "等待输入",
            idleLabel: "待命"
        )
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

    var systemAttentionHint: AttentionHint? {
        guard isModuleEnabled(.systemStatus) else { return nil }
        guard let hint = systemAttentionHintData else { return nil }
        return hint
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
            selector: #selector(handleRealtimeTranscript(_:)),
            name: .companionVoiceRealtimeTranscript,
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

    private var systemAttentionHintData: AttentionHint? {
        if permissionNeedsAttention(microphonePermissionStatus) {
            return AttentionHint(
                symbol: "mic.fill",
                title: "系统提醒",
                subtitle: "麦克风权限需要处理",
                accent: .orange
            )
        }

        if permissionNeedsAttention(screenRecordingPermissionStatus) {
            return AttentionHint(
                symbol: "display",
                title: "系统提醒",
                subtitle: "录屏权限需要处理",
                accent: .orange
            )
        }

        if permissionNeedsAttention(accessibilityPermissionStatus) {
            return AttentionHint(
                symbol: "accessibility",
                title: "系统提醒",
                subtitle: "辅助功能权限需要处理",
                accent: .orange
            )
        }

        if batteryInfo.isAvailable, batteryInfo.percentage <= 20, batteryInfo.isCharging == false {
            return AttentionHint(
                symbol: "battery.25",
                title: "系统提醒",
                subtitle: "电量较低",
                accent: .red
            )
        }

        return nil
    }

    private func permissionNeedsAttention(_ status: AppPermissionStatus) -> Bool {
        switch status {
        case .denied, .restricted, .needsSystemSettings:
            return true
        case .unknown, .notDetermined, .requesting, .authorized, .failed:
            return false
        }
    }

    private func setupSystemObservers() {
        batteryService.$batteryInfo
            .receive(on: RunLoop.main)
            .sink { [weak self] info in
                self?.batteryInfo = info
            }
            .store(in: &cancellables)

        systemStatusService.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.systemStatusSnapshot = snapshot
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

    private func bindMusicService() {
        musicService.$lyrics
            .receive(on: RunLoop.main)
            .sink { [weak self] lyrics in
                self?.lyrics = lyrics
            }
            .store(in: &cancellables)

        musicService.$isLoadingLyrics
            .receive(on: RunLoop.main)
            .sink { [weak self] isLoading in
                self?.isLoadingLyrics = isLoading
            }
            .store(in: &cancellables)
    }

    private func syncAIState() async {
        let providers = await aiRuntime.listProviders()
        guard let provider = providers.first(where: { $0.enabled }) ?? providers.first else {
            activeModelLabel = SettingsStatusLabelFormatter.unconfiguredModelText
            activeProviderStatus = SettingsStatusLabelFormatter.unconfiguredProviderText
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

    private func formatMBps(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return String(format: "%.1f MB/s", value)
    }

    private func formatTemperature(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return String(format: "%.1f°C", value)
    }

    private func formatPercent(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return String(format: "%.0f%%", value)
    }

    private func formatRPM(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return String(format: "%.0f RPM", value)
    }

    @objc private func handlePlaybackStateChanged(_ notification: Notification) {
        if let state = notification.object as? PlaybackState {
            playbackState = state
        }
    }

    @objc private func handleVoiceRecordingStarted(_ notification: Notification) {
        isRecordingActive = true
        realtimeTranscript = ""
        updateVoiceState(.listening)
        if presentationState != .hidden {
            setPresentationState(.blockedClose)
        }
        systemEventCenter.publish(
            .sayInput,
            title: "说入法收音中",
            detail: "松开 Fn 完成 · Esc 取消",
            duration: 1.2
        )
    }

    @objc private func handleVoiceRecordingStopped(_ notification: Notification) {
        isRecordingActive = false
        realtimeTranscript = ""
        updateVoiceState(.processing)
        if presentationState != .hidden {
            setPresentationState(.blockedClose)
        }
        systemEventCenter.publish(
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
        systemEventCenter.publish(
            .sayInput,
            title: "正在清洗文稿",
            detail: "准备写入当前光标",
            duration: 1.2
        )
    }

    @objc private func handleVoiceProcessingFinished(_ notification: Notification) {
        isRecordingActive = false
        realtimeTranscript = ""
        let destination = voiceDestination(from: notification.object) ?? .clipboard
        updateVoiceState(.completed(destination: destination), autoResetAfter: 1.0)
        if presentationState == .blockedClose {
            setPresentationState(.compact)
        }
        systemEventCenter.publish(
            .sayInput,
            title: destination.title,
            detail: destination.subtitle,
            duration: 1.0
        )
    }

    @objc private func handleVoiceCancelled(_ notification: Notification) {
        isRecordingActive = false
        realtimeTranscript = ""
        updateVoiceState(.cancelled, autoResetAfter: 0.7)
        if presentationState == .blockedClose {
            setPresentationState(.compact)
        }
        systemEventCenter.publish(
            .sayInput,
            title: "已取消",
            detail: "",
            duration: 0.8
        )
    }

    @objc private func handleRealtimeTranscript(_ notification: Notification) {
        guard let text = notification.object as? String else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 20 {
            realtimeTranscript = String(trimmed.prefix(20)) + "..."
        } else {
            realtimeTranscript = trimmed
        }
    }

    @objc private func handleCaptureSuccess(_ notification: Notification) {
        isCapturing = false
        if presentationState == .blockedClose {
            setPresentationState(.compact)
        }
        ToastManager.shared.show(.success, "截图已完成")
        systemEventCenter.dismiss(animated: true)
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
        systemEventCenter.publish(
            .screenshot,
            title: "截图处理中",
            detail: "正在截取当前屏幕",
            duration: 1.6
        )
        ToastManager.shared.show(.info, "正在截图...")
        panelController.hide()
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureScreenshot"),
            object: ["mode": ScreenshotMode.fullscreen.rawValue]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isCapturing = false
            self.panelController.showCompact(on: nil)
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

        systemEventCenter.publish(
            .sayInput,
            title: SayInputPresentationLabelFormatter.hudTitle(for: .idle),
            detail: SayInputPresentationLabelFormatter.openingText,
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

    private func snapshot() -> PlaybackState {
        let service = musicService
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
            sourceLabel: service.sourceLabel,
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
