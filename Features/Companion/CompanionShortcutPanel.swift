import SwiftUI
import AppKit

// MARK: - Companion Shortcut Panel
// 随身快捷键面板 - 真实配置与编辑

struct CompanionShortcutPanel: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    infoBanner
                    shortcutsList
                }
                .padding(24)
            }
        }
        .frame(width: 620, height: 680)
        .background(AppSurfaceTokens.background)
        .onChange(of: viewModel.companionShortcuts) { _, _ in
            persistCompanionSettings()
        }
        .onChange(of: viewModel.companionShortcutsEnabled) { _, _ in
            persistCompanionSettings()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("随身快捷键")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("系统级快捷键，保存后会在下次启动和当前会话中生效")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("恢复默认") {
                    viewModel.companionShortcuts = CompanionShortcut.defaultShortcuts
                    persistCompanionSettings()
                }
                .buttonStyle(.bordered)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
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
                Text("这里展示的是可持久化的快捷键配置")
                    .font(.body)
                    .fontWeight(.medium)

                Text("启用状态、快捷键文本和说明都来自设置存储，不再依赖示例数据。")
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

                Toggle("启用", isOn: $viewModel.companionShortcutsEnabled)
                    .toggleStyle(.switch)
            }

            VStack(spacing: 0) {
                ForEach(viewModel.companionShortcuts.indices, id: \.self) { index in
                    ShortcutRow(shortcut: $viewModel.companionShortcuts[index])

                    if index < viewModel.companionShortcuts.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(AppSurfaceTokens.cardBackgroundSoft)
            .cornerRadius(10)
        }
    }

    private func persistCompanionSettings() {
        Task {
            await viewModel.saveCompanionSettings()
        }
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    @Binding var shortcut: CompanionShortcut
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: iconForAction(shortcut.action))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                if shortcut.isEditable {
                    TextField("动作名称", text: $shortcut.action)
                        .textFieldStyle(.plain)
                        .font(.body.weight(.medium))
                } else {
                    Text(shortcut.action)
                        .font(.body)
                        .fontWeight(.medium)
                }

                if shortcut.isEditable {
                    TextField("说明", text: $shortcut.description)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                } else {
                    Text(shortcut.description)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                if shortcut.isEditable {
                    TextField("快捷键", text: $shortcut.shortcut)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                } else {
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
            }

            Toggle("", isOn: $shortcut.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
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
        case "说入法": return "mic.fill"
        case "快速收集": return "tray.and.arrow.down"
        case "截图捕获": return "camera"
        case "打开 Agent": return "bubble.left.fill"
        case "今日日程": return "calendar"
        default: return "command"
        }
    }
}
