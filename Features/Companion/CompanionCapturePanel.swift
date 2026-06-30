import SwiftUI
import AppKit
import Foundation
import AcMindKit

// MARK: - Companion Capture Panel
// 随身捕获面板 - 快速捕获能力展示

struct CompanionCapturePanel: View {
    @StateObject private var viewModel = CompanionCaptureViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            header

            Divider()

            // 主内容
            ScrollView {
                VStack(spacing: 18) {
                    // 捕获类型网格
                    captureTypesGrid

                    // 最近捕获
                    if !viewModel.recentCaptures.isEmpty {
                        recentCapturesSection
                    }

                    // 快速设置
                    quickSettingsSection
                }
                .padding(20)
            }
        }
        .frame(width: 460, height: 540)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                        .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: AppSurfaceTokens.separator.opacity(0.10), radius: 10, x: 0, y: 5)
        )
        .onChange(of: viewModel.openDetailAfterCapture) { _, _ in
            viewModel.saveCapturePreferences()
        }
        .onChange(of: viewModel.showCaptureNotification) { _, _ in
            viewModel.saveCapturePreferences()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("随身捕获")
                    .font(.system(size: AppSurfaceTokens.Typography.cardTitle, weight: .semibold))

                Text("快速保存当前内容到收集箱")
                    .font(.system(size: AppSurfaceTokens.Typography.caption))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: AppSurfaceTokens.Typography.cardTitle))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Capture Types Grid

    private var captureTypesGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("捕获方式")
                .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CompanionCaptureType.allCases) { type in
                    CaptureTypeCard(
                        type: type,
                        isEnabled: viewModel.isCaptureTypeEnabled(type),
                        action: { viewModel.performCapture(type: type) }
                    )
                }
            }
        }
    }

    // MARK: - Recent Captures Section

    private var recentCapturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近捕获")
                    .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))

                Spacer()

                Button("查看全部") {
                    viewModel.showAllCaptures()
                }
                .font(.system(size: AppSurfaceTokens.Typography.badge))
                .buttonStyle(.plain)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.recentCaptures.prefix(3)) { capture in
                    RecentCaptureRow(
                        capture: capture,
                        onCopy: {
                            viewModel.copyCapture(capture)
                        },
                        onDelete: {
                            viewModel.deleteCapture(id: capture.id)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Quick Settings Section

    private var quickSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("快速设置")
                .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("自动保存到收集箱")
                            .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))

                        Spacer()

                        Text("始终开启")
                            .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
                    }

                    Text("捕获结果会自动写入收集箱。")
                        .font(.system(size: AppSurfaceTokens.Typography.body))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }

                Toggle("捕获后打开查看", isOn: $viewModel.openDetailAfterCapture)
                    .toggleStyle(.switch)

                Toggle("显示捕获通知", isOn: $viewModel.showCaptureNotification)
                    .toggleStyle(.switch)
            }
            .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.85), lineWidth: 1)
            )
        }
    }
}

// MARK: - Capture Type Card

struct CaptureTypeCard: View {
    let type: CompanionCaptureType
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius)
                        .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.08))
                        .frame(width: 48, height: 48)

                    Image(systemName: type.icon)
                        .font(.system(size: AppSurfaceTokens.Typography.cardTitle, weight: .medium))
                        .foregroundStyle(isHovered ? Color.accentColor : Color.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))

                    Text(descriptionForType(type))
                        .font(.system(size: AppSurfaceTokens.Typography.caption))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }

                Spacer()
            }
            .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .stroke(
                        isHovered && isEnabled ? Color.accentColor.opacity(0.3) : AppSurfaceTokens.separator.opacity(0.75),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
        .opacity(isEnabled ? 1.0 : 0.45)
    }

    private func descriptionForType(_ type: CompanionCaptureType) -> String {
        switch type {
        case .screenshot: return "⌥ S"
        case .scrollScreenshot: return "滚动拼接"
        case .clipboard: return "⌥ C"
        case .selectedText: return "自动检测"
        case .webpage: return "浏览器中"
        }
    }
}

// MARK: - Recent Capture Row

struct RecentCaptureRow: View {
    let capture: CaptureRecord
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(colorForType(capture.type).opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: iconForType(capture.type))
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
                    .foregroundStyle(colorForType(capture.type))
            }

            // 内容
            VStack(alignment: .leading, spacing: 2) {
                Text(capture.title)
                    .font(.body)
                    .lineLimit(1)

                Text(formatTime(capture.timestamp))
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            // 状态
            CompanionCaptureStatusBadge(status: capture.status)

            // 悬停操作
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? AppSurfaceTokens.separator.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func iconForType(_ type: CompanionCaptureType) -> String {
        switch type {
        case .screenshot: return "camera.viewfinder"
        case .scrollScreenshot: return "scroll"
        case .clipboard: return "doc.on.clipboard"
        case .selectedText: return "text.quote"
        case .webpage: return "globe"
        }
    }

    private func colorForType(_ type: CompanionCaptureType) -> Color {
        switch type {
        case .screenshot: return .blue
        case .scrollScreenshot: return .indigo
        case .clipboard: return .green
        case .selectedText: return .orange
        case .webpage: return .purple
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Status Badge

struct CompanionCaptureStatusBadge: View {
    let status: CaptureStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Capture Types

enum CaptureStatus {
    case success
    case pending
    case error

    var color: Color {
        switch self {
        case .success: return .green
        case .pending: return .orange
        case .error: return .red
        }
    }
}

/// Capture record used for previewing recent items
struct CaptureRecord: Identifiable {
    let id = UUID()
    let type: CompanionCaptureType
    let title: String
    let timestamp: Date
    let status: CaptureStatus
}

// MARK: - View Model

@MainActor
class CompanionCaptureViewModel: ObservableObject {
    private static let logger = AcMindLogger(category: .capture)
    // MARK: - Dependencies

    private let captureService: CaptureServiceProtocol
    private let storage: StorageServiceProtocol
    nonisolated(unsafe) private var companionConfigurationObserver: NSObjectProtocol?
    nonisolated(unsafe) private var captureCompletedObserver: NSObjectProtocol?
    private var destinationChoicePanel: CaptureDestinationChoiceWindowController?

    @Published var recentCaptures: [CaptureRecord] = []
    @Published var autoSaveToInbox = true
    @Published var openDetailAfterCapture = false
    @Published var showCaptureNotification = true
    @Published var textCaptureEnabled = true
    @Published var linkCaptureEnabled = true
    @Published var captureSaveDestinationIndex = CompanionCaptureSaveDestination.inbox.rawValue

    init(
        captureService: CaptureServiceProtocol = CaptureService(),
        storage: StorageServiceProtocol = StorageService()
    ) {
        self.captureService = captureService
        self.storage = storage
        loadRecentCaptures()
        loadCapturePreferences()
        loadCompanionCaptureConfiguration()
        companionConfigurationObserver = NotificationCenter.default.addObserver(
            forName: .companionConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadCompanionCaptureConfiguration()
            }
        }
        captureCompletedObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("AcMind.captureCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard notification.object is CaptureResult else { return }
            Task { @MainActor [weak self] in
                self?.loadRecentCaptures()
            }
        }
    }

    deinit {
        if let companionConfigurationObserver {
            NotificationCenter.default.removeObserver(companionConfigurationObserver)
        }
        if let captureCompletedObserver {
            NotificationCenter.default.removeObserver(captureCompletedObserver)
        }
    }

    private func loadCapturePreferences() {
        let preferences = SettingsLocalPreferences.loadOrDefault()
        autoSaveToInbox = preferences.companionCaptureAutoSaveToInbox
        openDetailAfterCapture = preferences.companionCaptureOpenDetailAfterCapture
        showCaptureNotification = preferences.companionCaptureShowNotification
    }

    func saveCapturePreferences() {
        let current = SettingsLocalPreferences.loadOrDefault()
        let preferences = SettingsLocalPreferences(
            autoBackupEnabled: current.autoBackupEnabled,
            lastAutoBackupAt: current.lastAutoBackupAt,
            restoreWindowPosition: current.restoreWindowPosition,
            notificationsEnabled: current.notificationsEnabled,
            taskCompletedNotificationsEnabled: current.taskCompletedNotificationsEnabled,
            updateAvailableNotificationsEnabled: current.updateAvailableNotificationsEnabled,
            captureOnlyWhenAppActive: current.captureOnlyWhenAppActive,
            captureScreenshotEnabled: current.captureScreenshotEnabled,
            companionCaptureAutoSaveToInbox: autoSaveToInbox,
            companionCaptureOpenDetailAfterCapture: openDetailAfterCapture,
            companionCaptureShowNotification: showCaptureNotification,
            voiceInputEnabled: current.voiceInputEnabled,
            localFirstMode: current.localFirstMode,
            sensitiveContentNotUpload: current.sensitiveContentNotUpload,
            apiKeyUsesKeychain: current.apiKeyUsesKeychain,
            aiCallLogEnabled: current.aiCallLogEnabled,
            errorLogEnabled: current.errorLogEnabled
        )
        preferences.save()
    }

    private func loadCompanionCaptureConfiguration() {
        Task {
            let configuration = await CompanionConfigurationStore.load(from: storage)
            textCaptureEnabled = configuration.captureTextEnabled
            linkCaptureEnabled = configuration.captureLinkEnabled
            captureSaveDestinationIndex = configuration.captureSaveDestinationIndex
        }
    }

    func isCaptureTypeEnabled(_ type: CompanionCaptureType) -> Bool {
        switch type {
        case .screenshot, .scrollScreenshot, .clipboard:
            return true
        case .selectedText:
            return textCaptureEnabled
        case .webpage:
            return linkCaptureEnabled
        }
    }

    // MARK: - Data Loading

    private func loadRecentCaptures() {
        Task {
            do {
                let items = try await storage.listSourceItems(
                    filter: SourceItemFilter(limit: 10)
                )
                // 按创建时间倒序，取最近 10 条
                recentCaptures = items
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(10)
                    .map { item in
                        CaptureRecord(
                            type: mapSourceItemToCaptureType(item),
                            title: item.title ?? "未命名捕获",
                            timestamp: item.createdAt,
                            status: mapStatusToCaptureStatus(item.status)
                        )
                    }
            } catch {
                Self.logger.error("加载最近捕获失败: \(error.localizedDescription)")
            }
        }
    }

    /// 将 SourceItem 映射到 CompanionCaptureType
    private func mapSourceItemToCaptureType(_ item: SourceItem) -> CompanionCaptureType {
        if item.type == .screenshot,
           let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           title.contains("滚动截图") {
            return .scrollScreenshot
        }

        switch item.type {
        case .screenshot: return .screenshot
        case .webpage: return .webpage
        case .text: return .selectedText
        default: return .clipboard
        }
    }

    /// 将 SourceItemStatus 映射到 CaptureStatus
    private func mapStatusToCaptureStatus(_ status: SourceItemStatus) -> CaptureStatus {
        switch status {
        case .inbox, .captured, .parsed, .distilled, .exported, .archived:
            return .success
        case .pending, .capturing, .parsing, .distilling, .exporting:
            return .pending
        case .deleted:
            return .error
        }
    }

    // MARK: - Actions

    func performCapture(type: CompanionCaptureType) {
        Task {
            do {
                if type == .screenshot, !SettingsLocalPreferences.isCaptureScreenshotEnabled() {
                    ToastManager.shared.show(.warning, "截图捕获已在设置中关闭")
                    return
                }

                if type == .scrollScreenshot, !SettingsLocalPreferences.isCaptureScreenshotEnabled() {
                    ToastManager.shared.show(.warning, "滚动截图已在设置中关闭")
                    return
                }

                if type == .selectedText, !textCaptureEnabled {
                    ToastManager.shared.show(.warning, "文本快速收集已在设置中关闭")
                    return
                }

                if type == .webpage, !linkCaptureEnabled {
                    ToastManager.shared.show(.warning, "链接快速收集已在设置中关闭")
                    return
                }

                switch type {
                case .screenshot:
                    triggerUnifiedScreenshotPreview(mode: .fullscreen, type: type)
                    return
                case .scrollScreenshot:
                    triggerUnifiedScreenshotPreview(mode: .scroll, type: type)
                    return
                case .clipboard:
                    guard let clipboardResult = try await captureService.captureFromClipboard() else {
                        Self.logger.warning("剪贴板为空")
                        return
                    }
                    await finishNonScreenshotCapture(result: clipboardResult, type: type)
                case .selectedText:
                    let context = await ContextCaptureService.shared.captureContext()
                    let selectedText = context.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let selectedText, !selectedText.isEmpty else {
                        Self.logger.warning("未检测到选中文本")
                        return
                    }
                    let result = try await captureService.captureFromManualText(selectedText)
                    await finishNonScreenshotCapture(result: result, type: type)
                case .webpage:
                    guard let url = Self.frontmostBrowserURL() else {
                        Self.logger.warning("未检测到当前网页地址")
                        return
                    }
                    let result = try await captureService.captureFromWebpage(url: url)
                    await finishNonScreenshotCapture(result: result, type: type)
                }
            } catch {
                Self.logger.error("捕获失败: \(error.localizedDescription)")
            }
        }
    }

    func showAllCaptures() {
        NotificationCenter.default.post(name: .companionShowInbox, object: nil)
    }

    func copyCapture(_ capture: CaptureRecord) {
        let text = "\(capture.title)\n\(formatDate(capture.timestamp))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func handleCaptureCompletion(result: CaptureResult, type: CompanionCaptureType) async {
        let destination = CompanionCaptureSaveDestination(rawValue: captureSaveDestinationIndex) ?? .inbox

        switch destination {
        case .inbox:
            if openDetailAfterCapture {
                NotificationCenter.default.post(name: .companionShowInbox, object: nil)
            }
            if showCaptureNotification {
                ToastManager.shared.show(.success, completionToastMessage(for: result, destination: .inbox))
            }
        case .clipboard:
            copyCaptureResultSummary(result)
            if showCaptureNotification {
                ToastManager.shared.show(.success, completionToastMessage(for: result, destination: .clipboard))
            }
        case .ask:
            let choice = await presentCaptureDestinationChoice(for: result, type: type)
            switch choice {
            case .inbox:
                if openDetailAfterCapture {
                    NotificationCenter.default.post(name: .companionShowInbox, object: nil)
                }
                if showCaptureNotification {
                    ToastManager.shared.show(.success, completionToastMessage(for: result, destination: .inbox))
                }
            case .clipboard:
                copyCaptureResultSummary(result)
                if showCaptureNotification {
                    ToastManager.shared.show(.success, completionToastMessage(for: result, destination: .clipboard))
                }
            case .some(.ask):
                break
            case .none:
                if showCaptureNotification {
                    ToastManager.shared.show(.info, "已取消后续操作")
                }
            }
        }
    }

    private func triggerUnifiedScreenshotPreview(mode: ScreenshotMode, type: CompanionCaptureType) {
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureScreenshot"),
            object: ["mode": mode.rawValue]
        )
        NotificationCenter.default.post(
            name: .companionCaptureCompleted,
            object: nil,
            userInfo: ["type": type]
        )
    }

    private func finishNonScreenshotCapture(result: CaptureResult, type: CompanionCaptureType) async {
        await handleCaptureCompletion(result: result, type: type)
        loadRecentCaptures()
        NotificationCenter.default.post(
            name: .companionCaptureCompleted,
            object: nil,
            userInfo: ["type": type]
        )
    }

    private func completionToastMessage(for result: CaptureResult, destination: CompanionCaptureSaveDestination) -> String {
        let title = result.sourceItem.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch destination {
        case .inbox:
            if let title, !title.isEmpty {
                return "已保存到收集箱: \(title)"
            }
            return "已保存到收集箱"
        case .clipboard:
            if let title, !title.isEmpty {
                return "已复制到剪贴板: \(title)"
            }
            return "已复制到剪贴板"
        case .ask:
            return "已完成"
        }
    }

    private func copyCaptureResultSummary(_ result: CaptureResult) {
        let summary = result.sourceItem.polishedTranscript
            ?? result.sourceItem.transcript
            ?? result.sourceItem.previewText
            ?? result.sourceItem.title
            ?? "已捕获内容"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    private func presentCaptureDestinationChoice(for result: CaptureResult, type: CompanionCaptureType) async -> CompanionCaptureSaveDestination? {
        let title = result.sourceItem.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentName = type.displayName
        let prompt = title.map { "“\($0)” (\(contentName)) 的结果要接下来怎么处理？" } ?? "这次 \(contentName) 的结果要接下来怎么处理？"

        let panel = CaptureDestinationChoiceWindowController()
        destinationChoicePanel = panel
        let choice = await panel.present(
            title: "捕获已完成",
            message: prompt
        )
        destinationChoicePanel = nil
        return choice
    }

    func deleteCapture(id: UUID) {
        recentCaptures.removeAll { $0.id == id }
    }

    private static func frontmostBrowserURL() -> URL? {
        let script = """
        on browserURL(appName)
            tell application appName
                if it is running then
                    try
                        if exists front window then
                            set tabRef to current tab of front window
                            if tabRef is not missing value then
                                return URL of tabRef
                            end if
                        end if
                    end try
                end if
            end tell
            return ""
        end browserURL

        set browserApps to {"Safari", "Google Chrome", "Microsoft Edge"}
        repeat with appName in browserApps
            set value to browserURL(appName)
            if value is not "" then return value
        end repeat
        return ""
        """

        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let output = appleScript.executeAndReturnError(&error)
        if error != nil { return nil }
        let urlString = output.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return URL(string: urlString)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Capture Destination Choice Panel

@MainActor
private final class CaptureDestinationChoiceWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var continuation: CheckedContinuation<CompanionCaptureSaveDestination?, Never>?
    private var didFinish = false

    func present(title: String, message: String) async -> CompanionCaptureSaveDestination? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 220),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.delegate = self
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true

            panel.contentView = NSHostingView(
                rootView: CaptureDestinationChoiceView(
                    title: title,
                    message: message,
                    onInbox: { [weak self] in
                        self?.finish(with: .inbox)
                    },
                    onClipboard: { [weak self] in
                        self?.finish(with: .clipboard)
                    },
                    onCancel: { [weak self] in
                        self?.finish(with: nil)
                    }
                )
            )

            self.panel = panel
            panel.center()
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        finish(with: nil)
    }

    private func finish(with destination: CompanionCaptureSaveDestination?) {
        guard didFinish == false else { return }
        didFinish = true
        panel?.orderOut(nil)
        panel = nil
        continuation?.resume(returning: destination)
        continuation = nil
    }
}

private struct CaptureDestinationChoiceView: View {
    let title: String
    let message: String
    let onInbox: () -> Void
    let onClipboard: () -> Void
    let onCancel: () -> Void

    var body: some View {
        AppSurfaceConfirmationCard(
            title: title,
            message: message,
            icon: "square.and.arrow.down",
            tint: .blue,
            primaryTitle: "保存到收集箱",
            secondaryTitle: "复制到剪贴板",
            tertiaryTitle: "取消",
            footerNote: "选完就会关闭窗口，不会再额外弹系统对话框。",
            primaryAction: onInbox,
            secondaryAction: onClipboard,
            tertiaryAction: onCancel
        )
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppSurfaceBackdrop())
    }
}
