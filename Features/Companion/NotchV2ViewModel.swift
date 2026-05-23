import Combine
import Foundation
import AppKit
import SwiftUI
import AcMindKit

@MainActor
final class NotchV2ViewModel: ObservableObject {
    @Published var isExpanded = true
    @Published var selectedPage: NotchV2Page = .overview
    @Published var collapsedContentSettings: CompanionCollapsedContentSettings = .default
    @Published var systemMonitorSnapshot: SystemMonitorSnapshot?
    @Published var playbackState = PlaybackState()
    @Published var isVoiceRecording = false
    @Published var isCapturing = false
    @Published var status: CompanionStatus = .ready
    @Published var lastTranscription: CompanionVoiceTranscription?
    @Published var isHoverEmphasized = false
    @Published var continentTabs: [DynamicSurfaceContinentTabSnapshot] = []
    @Published var selectedContinentTabID: UUID = UUID()
    @Published var selectedWidgetIDs: Set<String> = []
    @Published var selectedFeatureIDs: Set<String> = []

    private var hoverOpenTask: Task<Void, Never>?
    private var hoverCollapseTask: Task<Void, Never>?
    private var musicStateCancellables = Set<AnyCancellable>()
    private var systemMonitorCancellables = Set<AnyCancellable>()
    private let musicService: MusicService
    private let systemMonitorService: SystemMonitorService
    private let toastManager: ToastManager

    struct QuickAction: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let action: () -> Void
    }

    lazy var quickActions: [QuickAction] = [
        QuickAction(icon: "camera.viewfinder", title: "截图", action: { [weak self] in self?.captureScreenshot() }),
        QuickAction(icon: "doc.text", title: "MD", action: { [weak self] in self?.quickMarkdown() }),
        QuickAction(icon: "pin.fill", title: "Pin", action: { [weak self] in self?.showAgent() }),
        QuickAction(icon: "waveform", title: "SRPT", action: { [weak self] in self?.showVoicePanel() }),
        QuickAction(icon: "ellipsis", title: "更多", action: { [weak self] in self?.showMoreActions() })
    ]

    init(musicService: MusicService, systemMonitorService: SystemMonitorService, toastManager: ToastManager) {
        self.musicService = musicService
        self.systemMonitorService = systemMonitorService
        self.toastManager = toastManager
        playbackState = Self.snapshot(from: musicService)
        systemMonitorSnapshot = systemMonitorService.snapshot
        lastTranscription = CompanionMockData.recentTranscriptions.first
        loadCollapsedContentSettings()
        loadDynamicSurfacePreferences()
        setupObservers()
        setupMusicObservation()
        setupSystemMonitorObservation()
        systemMonitorService.start(cadence: .collapsed)
    }

    func toggleExpansion() {
        cancelHoverTasks()
        isExpanded.toggle()
        updateSystemMonitorCadence()
    }

    func collapse() {
        guard isExpanded else { return }
        cancelHoverTasks()
        isExpanded = false
        updateSystemMonitorCadence()
    }

    func setPanelHovered(_ hovering: Bool) {
        isHoverEmphasized = hovering
        cancelHoverTasks()

        if hovering {
            guard !isExpanded, canAutoOpen else { return }
            scheduleHoverOpen()
        } else {
            isHoverEmphasized = false
            guard isExpanded, canAutoCollapse else { return }
            scheduleHoverCollapse()
        }
    }

    func select(_ page: NotchV2Page) {
        selectedPage = page
        if isExpanded == false {
            isExpanded = true
        }
        updateSystemMonitorCadence()
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
        switch selectedPage {
        case .overview:
            return NotchV2DesignTokens.expandedOverviewHeight
        case .music:
            return NotchV2DesignTokens.expandedMusicHeight
        case .agent:
            return NotchV2DesignTokens.expandedAgentHeight
        case .schedule:
            return NotchV2DesignTokens.expandedScheduleHeight
        case .systemMonitor:
            return NotchV2DesignTokens.expandedSystemMonitorHeight
        }
    }

    var collapsedContent: NotchV2CollapsedContent {
        switch collapsedContentSettings.mode {
        case .currentStatus:
            return currentStatusCollapsedContent
        case .custom:
            return NotchV2CollapsedContent(
                label: collapsedContentSettings.customLabel,
                title: collapsedContentSettings.customTitle,
                subtitle: collapsedContentSettings.customSubtitle.isEmpty ? nil : collapsedContentSettings.customSubtitle,
                symbol: collapsedContentSettings.customSymbol,
                tint: NotchV2DesignTokens.accentPurple
            )
        }
    }

    var activeContinentTab: DynamicSurfaceContinentTabSnapshot {
        continentTabs.first(where: { $0.id == selectedContinentTabID }) ?? continentTabs.first ?? Self.defaultContinentTabs[0]
    }

    var topBarPageTitles: [String] {
        let titles = continentTabs.prefix(4).map(\.name)
        return titles.count == 4 ? Array(titles) : NotchV2Page.allCases.map(\.title)
    }

    func isWidgetEnabled(_ widgetID: String) -> Bool {
        selectedWidgetIDs.contains(widgetID)
    }

    func isFeatureEnabled(_ featureID: String) -> Bool {
        selectedFeatureIDs.contains(featureID)
    }

    func refreshDynamicSurfacePreferences() {
        loadDynamicSurfacePreferences()
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
            selector: #selector(handleCaptureSuccess(_:)),
            name: .companionCaptureSuccess,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCollapsedContentSettingsChanged(_:)),
            name: .companionCollapsedContentSettingsChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDynamicSurfacePreferencesChanged(_:)),
            name: DynamicSurfacePreferencesStore.preferencesDidChange,
            object: nil
        )
    }

    private func setupMusicObservation() {
        musicService.$timestampDate
            .sink { [weak self] _ in
                guard let self else { return }
                self.playbackState = Self.snapshot(from: self.musicService)
            }
            .store(in: &musicStateCancellables)
    }

    private func setupSystemMonitorObservation() {
        systemMonitorService.$snapshot
            .sink { [weak self] snapshot in
                self?.systemMonitorSnapshot = snapshot
            }
            .store(in: &systemMonitorCancellables)
    }

    private func cancelHoverTasks() {
        hoverOpenTask?.cancel()
        hoverCollapseTask?.cancel()
        hoverOpenTask = nil
        hoverCollapseTask = nil
    }

    private func scheduleHoverOpen() {
        hoverOpenTask?.cancel()
        hoverOpenTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, !self.isExpanded else { return }
                self.isExpanded = true
            }
        }
    }

    private func scheduleHoverCollapse() {
        hoverCollapseTask?.cancel()
        hoverCollapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isExpanded, self.canAutoCollapse else { return }
                self.collapse()
            }
        }
    }

    private var canAutoOpen: Bool {
        DynamicSurfaceCoordinator.shared.dragPhase == .idle && !isCapturing && !isVoiceRecording
    }

    private var canAutoCollapse: Bool {
        DynamicSurfaceCoordinator.shared.dragPhase == .idle && !isCapturing && !isVoiceRecording
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
        toastManager.show(.success, "截图已完成")
    }

    @objc private func handleCollapsedContentSettingsChanged(_ notification: Notification) {
        loadCollapsedContentSettings()
    }

    @objc private func handleDynamicSurfacePreferencesChanged(_ notification: Notification) {
        loadDynamicSurfacePreferences()
    }

    private func loadCollapsedContentSettings() {
        guard
            let data = UserDefaults.standard.data(forKey: CompanionCollapsedContentStorage.key),
            let decoded = try? JSONDecoder().decode(CompanionCollapsedContentSettings.self, from: data)
        else {
            collapsedContentSettings = .default
            return
        }

        collapsedContentSettings = decoded
    }

    private func loadDynamicSurfacePreferences() {
        let tabs = DynamicSurfacePreferencesStore.loadContinentTabs(default: Self.defaultContinentTabs)
        continentTabs = tabs
        selectedContinentTabID = DynamicSurfacePreferencesStore.loadSelectedContinentTabID(default: tabs.first?.id ?? Self.defaultContinentTabs[0].id)
        selectedWidgetIDs = DynamicSurfacePreferencesStore.loadSelectedWidgetIDs(default: Self.defaultWidgetIDs)
        selectedFeatureIDs = DynamicSurfacePreferencesStore.loadSelectedFeatureIDs(default: Self.defaultFeatureIDs)

        if !continentTabs.contains(where: { $0.id == selectedContinentTabID }),
           let first = continentTabs.first {
            selectedContinentTabID = first.id
        }
    }

    private func captureScreenshot() {
        isCapturing = true
        toastManager.show(.info, "正在截图...")
        NotchPanel.shared.orderOut(nil)
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureScreenshot"),
            object: ["mode": ScreenshotMode.fullscreen.rawValue]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            DynamicSurfaceCoordinator.shared.transition(to: .continentCompact, reason: .capture)
        }
        collapse()
    }

    private func quickMarkdown() {
        NotificationCenter.default.post(name: Notification.Name("companion.quickMarkdown"), object: nil)
        toastManager.show(.info, "打开 MD")
        collapse()
    }

    private func showVoicePanel() {
        NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
        collapse()
    }

    private func showAgent() {
        NotificationCenter.default.post(name: .companionShowAgent, object: nil)
        collapse()
    }

    private func showMoreActions() {
        toastManager.show(.info, "更多入口待接入")
    }

    private var currentStatusCollapsedContent: NotchV2CollapsedContent {
        if selectedPage == .systemMonitor {
            return systemMonitorCollapsedContent
        }

        if isVoiceRecording {
            return NotchV2CollapsedContent(
                label: "状态",
                title: "录音中",
                subtitle: "正在转写",
                symbol: "mic.fill",
                tint: NotchV2DesignTokens.accentGreen
            )
        }

        if isCapturing {
            return NotchV2CollapsedContent(
                label: "状态",
                title: "截图中",
                subtitle: "正在收集内容",
                symbol: "camera.viewfinder",
                tint: NotchV2DesignTokens.accentPurple
            )
        }

        if playbackState.isPlaying {
            return NotchV2CollapsedContent(
                label: "状态",
                title: "播放中",
                subtitle: playbackState.artist.isEmpty ? "正在播放" : playbackState.artist,
                symbol: "music.note",
                tint: NotchV2DesignTokens.accentPurple
            )
        }

        switch status {
        case .listening:
            return NotchV2CollapsedContent(
                label: "状态",
                title: "监听中",
                subtitle: "等待输入",
                symbol: status.icon,
                tint: status.color
            )
        case .transcribing:
            return NotchV2CollapsedContent(
                label: "状态",
                title: "转写中",
                subtitle: "处理中",
                symbol: status.icon,
                tint: status.color
            )
        case .error:
            return NotchV2CollapsedContent(
                label: "状态",
                title: status.displayName,
                subtitle: "请检查服务",
                symbol: status.icon,
                tint: status.color
            )
        case .idle:
            return NotchV2CollapsedContent(
                label: "状态",
                title: "待命",
                subtitle: "可自定义内容",
                symbol: status.icon,
                tint: status.color
            )
        case .ready:
            return NotchV2CollapsedContent(
                label: "状态",
                title: "待命",
                subtitle: "可自定义内容",
                symbol: status.icon,
                tint: status.color
            )
        }
    }

    private var systemMonitorCollapsedContent: NotchV2CollapsedContent {
        guard let snapshot = systemMonitorSnapshot else {
            return NotchV2CollapsedContent(
                label: "状态",
                title: "系统监控",
                subtitle: "正在采样",
                symbol: "cpu",
                tint: NotchV2DesignTokens.secondaryText
            )
        }

        let cpu = formatPercent(snapshot.cpu.usagePercent)
        let memory = formatPercent(memoryUsagePercent(snapshot.memory))
        let battery = snapshot.battery.map { formatPercent($0.percentage) } ?? "—"
        let networkDown = formatRate(snapshot.network.downloadBytesPerSecond)

        let tint: Color
        switch snapshot.health.level {
        case .good:
            tint = NotchV2DesignTokens.accentGreen
        case .attention:
            tint = Color(red: 1.0, green: 0.78, blue: 0.24)
        case .highLoad:
            tint = Color(red: 1.0, green: 0.38, blue: 0.33)
        case .unknown:
            tint = NotchV2DesignTokens.secondaryText
        }

        return NotchV2CollapsedContent(
            label: "状态",
            title: "CPU \(cpu) · MEM \(memory)",
            subtitle: "BAT \(battery) · ↓ \(networkDown)",
            symbol: "cpu",
            tint: tint
        )
    }

    private func updateSystemMonitorCadence() {
        if isExpanded && selectedPage == .systemMonitor {
            systemMonitorService.setCadence(.expanded)
        } else {
            systemMonitorService.setCadence(.collapsed)
        }
    }

    private func memoryUsagePercent(_ memory: MemoryStats) -> Double {
        guard memory.totalBytes > 0 else { return 0 }
        return Double(memory.usedBytes) / Double(memory.totalBytes) * 100
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private func formatRate(_ bytesPerSecond: UInt64) -> String {
        switch bytesPerSecond {
        case 0..<1_024:
            return "\(bytesPerSecond)B/s"
        case 1_024..<1_048_576:
            return String(format: "%.0fKB/s", Double(bytesPerSecond) / 1_024.0)
        default:
            return String(format: "%.1fMB/s", Double(bytesPerSecond) / 1_048_576.0)
        }
    }

    private static func snapshot(from service: MusicService) -> PlaybackState {
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

    private static let defaultContinentTabs: [DynamicSurfaceContinentTabSnapshot] = [
        .init(name: "今日", icon: "sun.max", enabledModuleTitles: ["日程", "天气", "任务", "消息"], isDefault: true),
        .init(name: "音乐", icon: "music.note", enabledModuleTitles: ["播放", "歌单", "歌词"], isDefault: true),
        .init(name: "AI", icon: "sparkles", enabledModuleTitles: ["状态", "任务", "快捷入口", "参考"], isDefault: true),
        .init(name: "日程", icon: "calendar", enabledModuleTitles: ["日历", "时间线", "提醒"], isDefault: true)
    ]

    private static let defaultWidgetIDs: Set<String> = Set([
        "continent-timeline",
        "continent-agent",
        "continent-task",
        "continent-weather",
        "continent-notes",
        "continent-media"
    ])

    private static let defaultFeatureIDs: Set<String> = Set([
        "feature-agent",
        "feature-voice",
        "feature-capture",
        "feature-schedule",
        "feature-notes"
    ])
}
