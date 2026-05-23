import SwiftUI
import AppKit
import AcMindKit
import struct AcMindKit.KeyboardShortcut

struct AcMindCommands: Commands {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    private var appDelegate: AppDelegate? { NSApp.delegate as? AppDelegate }

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于 AcMind") {
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("新建采集") {
                NotificationCenter.default.post(name: Notification.Name("AcMind.captureScreenshot"), object: nil, userInfo: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("新建文本") {
            }
            .keyboardShortcut("t", modifiers: .command)
        }

        CommandGroup(replacing: .windowList) {
            Button("显示主窗口") {
                appDelegate?.showMainWindow()
            }
            .keyboardShortcut("0", modifiers: .command)

            Button("显示胶囊") {
                appDelegate?.showDesktopCapsule()
            }
            .keyboardShortcut(KeyEquivalent(" "), modifiers: [.command, .shift])

            Divider()

            ForEach(SidebarItem.mainItems) { item in
                if let shortcut = item.shortcut, let firstKey = shortcut.key.first {
                    Button(item.displayName) {
                        appState.selectSidebarItem(item)
                        appDelegate?.showMainWindow()
                    }
                    .keyboardShortcut(
                        KeyEquivalent(firstKey),
                        modifiers: shortcut.modifiers.toEventModifiers()
                    )
                }
            }
        }

        CommandMenu("采集") {
            Button("截图") {
                NotificationCenter.default.post(name: Notification.Name("AcMind.captureScreenshot"), object: nil, userInfo: nil)
            }
            .keyboardShortcut("4", modifiers: [.command, .shift])

            Button("区域截图") {
            }
            .keyboardShortcut("5", modifiers: [.command, .shift])

            Button("从剪贴板") {
                NotificationCenter.default.post(name: Notification.Name("AcMind.captureClipboard"), object: nil, userInfo: nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Button("语音输入") {
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
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
        }
    }
}

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

struct LaunchView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(Color.primary)

            Text("AcMind")
                .font(.largeTitle)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)

                Text("正在初始化: \(appState.initializationPhase.rawValue)")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            if let error = appState.initializationError {
                VStack(spacing: 8) {
                    Text("初始化失败")
                        .font(.headline)
                        .foregroundStyle(Color.red)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)

                    Button("重试") {
                        Task {
                            await appState.retryInitialization()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}
