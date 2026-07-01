import AppKit
import SwiftUI
import AcMindKit

struct ScreenshotWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    let clipboardPinActions: ClipboardPinActions
    private let storageService: any StorageServiceProtocol
    @State private var latestScreenshot: CollectedItem?
    @State private var latestScreenshotError: String?
    @State private var isLoadingLatestScreenshot = false

    init(
        clipboardPinActions: ClipboardPinActions,
        storageService: any StorageServiceProtocol = StorageService()
    ) {
        self.clipboardPinActions = clipboardPinActions
        self.storageService = storageService
    }

    private var screenshotSnapshot: ScreenshotPreferencesSnapshot {
        SettingsLocalPreferences.screenshotSnapshot()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pageHeader
                capturePanel

                HStack(alignment: .top, spacing: 16) {
                    recentScreenshotCard
                    preferencesCard
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(AppSurfaceBackdrop())
        .task {
            await loadLatestScreenshot()
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("截图")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text("选择一种方式开始，完成后统一进入预览。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer(minLength: 16)

            Button {
                appState.navigate(to: .screenshotHistory)
            } label: {
                Label("历史", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.borderless)

            Button {
                appState.navigate(to: .inbox)
            } label: {
                Label("收集箱", systemImage: "tray.full")
            }
            .buttonStyle(.borderless)

            Button {
                openScreenshotOptionsPanel()
            } label: {
                Label("打开胶囊截图", systemImage: "capsule")
            }
            .buttonStyle(.borderless)

            Button {
                appState.navigate(to: .settings, settingsCategory: .captureInput)
            } label: {
                Label("捕获设置", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
        }
        .font(.system(size: 12, weight: .medium))
    }

    private var capturePanel: some View {
        ScreenshotWorkspaceCard {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("选择截图方式")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)

                    Text("全屏是默认动作，区域、窗口和滚动截图按需选择。")
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }

                HStack(spacing: 12) {
                    Button {
                        postScreenshotCapture(mode: .fullscreen)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 22, weight: .semibold))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("立即截图")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("全屏")
                                    .font(.system(size: 11, weight: .medium))
                                    .opacity(0.78)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                                .opacity(0.78)
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 108)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppSurfaceTokens.accentBlue)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 330)

                    captureModeButton(icon: "crop", title: "区域", subtitle: "自由选择") {
                        postScreenshotCapture(mode: .area)
                    }

                    captureModeButton(icon: "uiwindow.split.2x1", title: "窗口", subtitle: "单个窗口") {
                        postScreenshotCapture(mode: .window)
                    }

                    captureModeButton(icon: "scroll", title: "滚动", subtitle: "长页面") {
                        postScreenshotCapture(mode: .scroll)
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    summaryItem(
                        icon: "square.stack.3d.up",
                        title: "预设",
                        value: screenshotSnapshot.activePreset.name
                    )

                    statusDivider

                    summaryItem(
                        icon: "tray.and.arrow.down",
                        title: "完成后",
                        value: screenshotSnapshot.activePreset.defaultOutputAction.displayName
                    )

                    Spacer(minLength: 12)

                    Label(screenshotSnapshot.hotkeyLabel, systemImage: "command")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }

    private var recentScreenshotCard: some View {
        ScreenshotWorkspaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    workspaceIcon("photo.on.rectangle.angled", tint: AppSurfaceTokens.accentBlue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("最近截图")
                            .font(.system(size: 14, weight: .semibold))
                        Text(latestScreenshotSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }

                if let latestScreenshot {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            screenshotBadge(title: latestScreenshot.source.displayName, icon: latestScreenshot.source.iconName)
                            screenshotBadge(
                                title: processingStatusTitle(latestScreenshot.processingStatus),
                                icon: processingStatusIcon(latestScreenshot.processingStatus)
                            )
                            if let mode = screenshotModeLabel(for: latestScreenshot) {
                                screenshotBadge(title: mode, icon: "camera.viewfinder")
                            }
                        }

                        Text(latestScreenshot.workflowTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .lineLimit(2)

                        Text(latestScreenshot.workflowBody)
                            .font(.system(size: 11))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .lineLimit(3)
                    }
                } else if isLoadingLatestScreenshot {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(latestScreenshotError ?? "暂无最近截图")
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Button("继续处理最近一次截图") {
                        openLatestScreenshotPreview()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("固定") {
                        openLatestScreenshotPinWindow()
                    }
                    .buttonStyle(.bordered)

                    Button("查看历史") {
                        appState.navigate(to: .screenshotHistory)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var preferencesCard: some View {
        ScreenshotWorkspaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    workspaceIcon("slider.horizontal.3", tint: AppSurfaceTokens.secondaryText)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前设置")
                            .font(.system(size: 14, weight: .semibold))
                        Text("截图时自动沿用，无需重复确认。")
                            .font(.system(size: 11))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }

                    Spacer(minLength: 8)

                    Button("管理") {
                        appState.navigate(to: .settings)
                    }
                    .buttonStyle(.borderless)
                }

                HStack(spacing: 18) {
                    settingValue(title: "预设", value: screenshotSnapshot.activePreset.name)
                    settingValue(title: "输出", value: screenshotSnapshot.activePreset.defaultOutputAction.displayName)
                    settingValue(title: "热键", value: compactHotkeyLabel)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func captureModeButton(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 108)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.38), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func summaryItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(title)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .font(.system(size: 11))
        .lineLimit(1)
    }

    private var statusDivider: some View {
        Rectangle()
            .fill(AppSurfaceTokens.separator)
            .frame(width: 1, height: 16)
    }

    private func workspaceIcon(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
    }

    private func settingValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func screenshotBadge(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(AppSurfaceTokens.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground.opacity(0.58))
            )
    }

    private var latestScreenshotSubtitle: String {
        if isLoadingLatestScreenshot {
            return "正在加载最近截图"
        }
        if let latestScreenshot {
            return latestScreenshot.createdAt.formatted(date: .abbreviated, time: .shortened)
        }
        return latestScreenshotError ?? "继续编辑、固定或回看上一张截图。"
    }

    private func loadLatestScreenshot() async {
        isLoadingLatestScreenshot = true
        defer { isLoadingLatestScreenshot = false }

        let repository = CollectedItemRepository(storage: storageService)
        let result = await repository.list(
            filter: CollectedItemFilter(
                sources: [.screenshot, .screenshotOCR],
                limit: 1
            ),
            sort: .newestFirst
        )
        latestScreenshot = result.items.first
        latestScreenshotError = result.partialErrors.first
    }

    private func processingStatusTitle(_ status: ProcessingStatus) -> String {
        switch status {
        case .pending: return "待整理"
        case .captured: return "已采集"
        case .processing: return "处理中"
        case .refined: return "已整理"
        case .archived: return "已归档"
        case .exported: return "已导出"
        case .deleted: return "已删除"
        }
    }

    private func processingStatusIcon(_ status: ProcessingStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .captured: return "tray.and.arrow.down"
        case .processing: return "gearshape.2"
        case .refined: return "checkmark.circle"
        case .archived: return "archivebox"
        case .exported: return "square.and.arrow.up"
        case .deleted: return "trash"
        }
    }

    private func screenshotModeLabel(for item: CollectedItem) -> String? {
        guard item.source == .screenshot,
              let rawValue = item.metadata[CaptureService.screenshotModeMetadataKey],
              let mode = ScreenshotMode(rawValue: rawValue) else {
            return nil
        }
        return "\(mode.displayName)截图"
    }

    private var compactHotkeyLabel: String {
        screenshotSnapshot.hotkeyLabel
            .replacingOccurrences(of: "全局热键：", with: "")
    }

    private func openScreenshotOptionsPanel() {
        (NSApp.delegate as? AppDelegate)?.showScreenshotOptionsPanel()
    }

    private func openLatestScreenshotPreview() {
        (NSApp.delegate as? AppDelegate)?.openLatestScreenshotPreviewFromMenu()
    }

    private func openLatestScreenshotPinWindow() {
        (NSApp.delegate as? AppDelegate)?.openLatestScreenshotPinWindowFromMenu()
    }

    private func postScreenshotCapture(mode: ScreenshotMode) {
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureScreenshot"),
            object: ["mode": mode.rawValue]
        )
    }
}

private struct ScreenshotWorkspaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.42), lineWidth: 1)
            )
    }
}
