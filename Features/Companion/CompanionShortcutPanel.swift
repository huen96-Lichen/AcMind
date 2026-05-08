import SwiftUI
import AppKit

// MARK: - Companion Shortcut Panel
// 随身快捷键面板 - 快捷键展示与配置

struct CompanionShortcutPanel: View {
    @StateObject private var viewModel = CompanionShortcutViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            header

            Divider()

            // 主内容
            ScrollView {
                VStack(spacing: 24) {
                    // 提示信息
                    infoBanner

                    // 快捷键列表
                    shortcutsList

                    // 自定义快捷键区域
                    customShortcutsSection
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("随身快捷键")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("系统级快捷键，可在任意应用中使用")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }

    // MARK: - Info Banner

    private var infoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("真实全局快捷键将在后续版本接入")
                    .font(.body)
                    .fontWeight(.medium)

                Text("当前为展示模式，快捷键仅在本应用中生效")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Shortcuts List

    private var shortcutsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("随身快捷键")
                    .font(.headline)

                Spacer()

                Toggle("启用", isOn: $viewModel.shortcutsEnabled)
                    .toggleStyle(.switch)
            }

            VStack(spacing: 0) {
                ForEach(Array(viewModel.shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    ShortcutRow(
                        shortcut: shortcut,
                        isLast: index == viewModel.shortcuts.count - 1
                    )

                    if index < viewModel.shortcuts.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }

    // MARK: - Custom Shortcuts Section

    private var customShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("应用内快捷键")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.appShortcuts.enumerated()), id: \.offset) { index, shortcut in
                    AppShortcutRow(
                        action: shortcut.action,
                        shortcut: shortcut.shortcut,
                        isLast: index == viewModel.appShortcuts.count - 1
                    )

                    if index < viewModel.appShortcuts.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let shortcut: CompanionShortcut
    let isLast: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: iconForAction(shortcut.action))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.action)
                    .font(.body)
                    .fontWeight(.medium)

                Text(shortcut.description)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            // 快捷键显示
            HStack(spacing: 4) {
                ForEach(shortcut.shortcut.split(separator: " "), id: \.self) { key in
                    Text(String(key))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            // 编辑按钮
            if isHovered {
                Button(action: {}) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Color.secondary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func iconForAction(_ action: String) -> String {
        switch action {
        case "随身语音": return "mic.fill"
        case "快速收集": return "tray.and.arrow.down"
        case "截图捕获": return "camera"
        case "打开 Agent": return "bubble.left.fill"
        case "今日日程": return "calendar"
        default: return "command"
        }
    }
}

// MARK: - App Shortcut Row

struct AppShortcutRow: View {
    let action: String
    let shortcut: String
    let isLast: Bool

    var body: some View {
        HStack(spacing: 16) {
            Text(action)
                .font(.body)

            Spacer()

            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - View Model

@MainActor
class CompanionShortcutViewModel: ObservableObject {
    @Published var shortcuts: [CompanionShortcut] = []
    @Published var shortcutsEnabled = true

    let appShortcuts: [(action: String, shortcut: String)] = [
        ("显示主窗口", "⌘0"),
        ("Agent", "⌘1"),
        ("收集箱", "⌘2"),
        ("剪贴板", "⌘3"),
        ("日程", "⌘4"),
        ("工作台", "⌘5"),
        ("工具", "⌘6"),
        ("设置", "⌘,")
    ]

    init() {
        loadShortcuts()
    }

    private func loadShortcuts() {
        shortcuts = CompanionMockData.shortcuts
    }
}
