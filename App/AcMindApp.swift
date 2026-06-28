import SwiftUI
import AppKit
import AcMindKit

// MARK: - AcWork App

@main
struct AcMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 提供真实 Settings 内容，避免用户看到空白的系统设置窗口。
        Settings {
            SettingsView(initialCategory: .general)
                .background(AppSurfaceBackdrop())
        }
        .defaultSize(width: 1500, height: 920)
        .commands {
            AcMindCommands()
        }
    }
}

// MARK: - Commands

struct AcMindCommands: Commands {
    @ObservedObject private var appState = AppState.shared
    private var appDelegate: AppDelegate? { NSApp.delegate as? AppDelegate }

    var body: some Commands {
        // 替换标准菜单
        CommandGroup(replacing: .appInfo) {
            Button("关于 \(AcWorkBrand.displayName)") {
                appDelegate?.showAboutPanel()
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("立即截图") {
                (NSApp.delegate as? AppDelegate)?.showScreenshotOptionsPanel()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("新建文本") {
                appDelegate?.showQuickNotePanel()
            }
            .keyboardShortcut("t", modifiers: .command)
        }

        CommandGroup(replacing: .windowList) {
            Button("显示主窗口") {
                appDelegate?.showMainWindow()
            }
            .keyboardShortcut("0", modifiers: .command)

            Button("显示灵动胶囊") {
                appDelegate?.showDesktopCapsule()
            }
            .keyboardShortcut(KeyEquivalent(" "), modifiers: [.command, .shift])
        }

        CommandMenu("导航") {
            ForEach(SidebarItem.shortcutItems) { item in
                if let shortcut = item.shortcut {
                    Button(item.commandTitle) { navigate(to: item) }
                    .keyboardShortcut(
                        KeyEquivalent(shortcut.key.first!),
                        modifiers: shortcut.modifiers.toEventModifiers()
                    )
                }
            }
        }

        CommandMenu("截图") {
            Button("截图") {
                (NSApp.delegate as? AppDelegate)?.showScreenshotOptionsPanel()
            }
            .keyboardShortcut("4", modifiers: [.command, .shift])

            Button("截图历史") {
                appState.selectInboxWorkspace("screenshotHistory")
                appDelegate?.showMainWindow()
            }

            Button("区域截图") {
                appDelegate?.captureAreaScreenshot()
            }
            .keyboardShortcut("5", modifiers: [.command, .shift])

            Button("从剪贴板") {
                NotificationCenter.default.post(name: Notification.Name("AcMind.captureClipboard"), object: nil, userInfo: nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Button("说入法") {
                NotificationCenter.default.post(name: Notification.Name("AcMind.captureVoice"), object: nil, userInfo: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        CommandMenu("视图") {
            Button("切换侧边栏") {
                appState.toggleSidebar()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("全屏") {
                appDelegate?.toggleMainWindowFullScreen()
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
        }
    }

    private func navigate(to item: SidebarItem) {
        appState.navigate(to: item)
        appDelegate?.showMainWindow()
    }
}

// MARK: - Helper Extensions

extension Array where Element == ModifierKey {
    func toEventModifiers() -> EventModifiers {
        var modifiers: EventModifiers = []
        for key in self {
            switch key {
            case .command:
                modifiers.insert(.command)
            case .option:
                modifiers.insert(.option)
            case .control:
                modifiers.insert(.control)
            case .shift:
                modifiers.insert(.shift)
            }
        }
        return modifiers
    }
}

// MARK: - Launch View

/// 启动画面，显示初始化进度
struct LaunchView: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        VStack(spacing: 24) {
            // Logo
            if let iconImage = AppBranding.launchIconImage() {
                Image(nsImage: iconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
            }

            Text(AcWorkBrand.displayName)
                .font(.largeTitle)
                .fontWeight(.semibold)

            // 进度
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)

                Text("正在初始化: \(appState.initializationPhase.rawValue)")
                    .font(.caption)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            // 错误显示
            if let error = appState.initializationError {
                VStack(spacing: 8) {
                    Text("初始化失败")
                        .font(.headline)
                        .foregroundStyle(AppSurfaceTokens.accentOrange)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .multilineTextAlignment(.center)

                    Button("重试") {
                        Task {
                            await appState.retryInitialization()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                        .fill(AppSurfaceTokens.accentOrange.opacity(0.08))
                )
            }
        }
        .frame(width: 400, height: 300)
        .padding()
        .background(AppSurfaceBackdrop())
    }
}

private enum AppBranding {
    @MainActor
    static func launchIconImage() -> NSImage? {
        NSImage(named: "AppIcon") ?? NSApp.applicationIconImage
    }
}

// MARK: - Preview
