import AppKit
import SwiftUI
import AcMindKit

struct ScreenshotWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    let clipboardPinActions: ClipboardPinActions

    private var screenshotSnapshot: ScreenshotPreferencesSnapshot {
        SettingsLocalPreferences.screenshotSnapshot()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                ScreenshotOptionsView(
                    snapshot: screenshotSnapshot,
                    onSelect: { mode in
                        postScreenshotCapture(mode: mode)
                    },
                    onSelectScroll: {
                        postScreenshotCapture(mode: .scroll)
                    }
                )
                recentCaptureCard
                quickAccessCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppSurfaceBackdrop())
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.accentBlue)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppSurfaceTokens.accentBlue.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("截图查看")
                        .font(.title2.weight(.semibold))
                    Text("这里是截图的主入口。可以直接选模式，也可以去设置调整预设和热键。")
                        .font(.callout)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }

            HStack(spacing: 8) {
                statusChip(title: "预设", value: screenshotSnapshot.activePreset.name, tint: .blue)
                statusChip(title: "输出", value: screenshotSnapshot.activePreset.defaultOutputAction.displayName, tint: .green)
                statusChip(title: "热键", value: screenshotSnapshot.hotkeyLabel, tint: .orange)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.55), lineWidth: 1)
        )
    }

    private var quickAccessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速入口")
                .font(.headline)

            HStack(spacing: 10) {
                Button("打开胶囊截图") {
                    openScreenshotOptionsPanel()
                }
                .buttonStyle(.borderedProminent)

                Button("打开截图历史") {
                    appState.navigate(to: .screenshotHistory)
                }
                .buttonStyle(.bordered)

                Button("前往设置") {
                    appState.navigate(to: .settings)
                }
                .buttonStyle(.bordered)
            }

            Text("菜单栏、首页、侧边栏和胶囊最终都会汇入同一套截图流程。这里适合做入口总览和下一步操作。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.55), lineWidth: 1)
        )
    }

    private var recentCaptureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近截图")
                .font(.headline)

            Text("截图完成后可以先从这里继续处理最近一次结果，再决定是否保存、复制、Pin 或重截。")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("继续处理最近截图") {
                    openLatestScreenshotPreview()
                }
                .buttonStyle(.borderedProminent)

                Button("查看截图历史") {
                    appState.navigate(to: .screenshotHistory)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.55), lineWidth: 1)
        )
    }

    private func statusChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.72), lineWidth: 1)
        )
    }

    private func openScreenshotPanel() {
        (NSApp.delegate as? AppDelegate)?.showScreenshotOptionsPanel()
    }

    private func openScreenshotOptionsPanel() {
        (NSApp.delegate as? AppDelegate)?.showScreenshotOptionsPanel()
    }

    private func openLatestScreenshotPreview() {
        (NSApp.delegate as? AppDelegate)?.openLatestScreenshotPreviewFromMenu()
    }

    private func postScreenshotCapture(mode: ScreenshotMode) {
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.captureScreenshot"),
            object: ["mode": mode.rawValue]
        )
    }
}
