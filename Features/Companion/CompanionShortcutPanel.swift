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
        .frame(width: 560, height: 620)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                        .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
                )
        )
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
                    .font(.system(size: AppSurfaceTokens.Typography.cardTitle, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text("系统级快捷键，保存后立即生效。")
                    .font(.system(size: AppSurfaceTokens.Typography.caption))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
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
                        .font(.system(size: AppSurfaceTokens.Typography.cardTitle))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    // MARK: - Info Banner

    private var infoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: AppSurfaceTokens.Typography.cardTitle))
                .foregroundStyle(AppSurfaceTokens.accentBlue)

            VStack(alignment: .leading, spacing: 4) {
                Text("这里显示已保存的快捷键配置")
                    .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                    Text("启用状态、快捷键文本和备注都来自设置存储。")
                    .font(.system(size: AppSurfaceTokens.Typography.caption))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(AppSurfaceTokens.accentBlue.opacity(0.18), lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
    }

    // MARK: - Shortcuts List

    private var shortcutsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("随身快捷键")
                    .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

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
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.mainCardRadius, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.85), lineWidth: 1)
            )
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
                    .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                if shortcut.isEditable {
                    TextField("动作名称", text: $shortcut.action)
                        .textFieldStyle(.plain)
                        .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                } else {
                    Text(shortcut.action)
                        .font(.system(size: AppSurfaceTokens.Typography.body, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                }

                if shortcut.isEditable {
                    TextField("备注", text: $shortcut.description)
                        .textFieldStyle(.plain)
                        .font(.system(size: AppSurfaceTokens.Typography.caption))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                } else {
                    Text(shortcut.description)
                        .font(.system(size: AppSurfaceTokens.Typography.caption))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                if shortcut.isEditable {
                    TextField("快捷键", text: $shortcut.shortcut)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 110)
                } else {
                    ForEach(shortcut.shortcut.split(separator: " "), id: \.self) { key in
                        Text(String(key))
                            .font(.system(size: AppSurfaceTokens.Typography.caption, design: .monospaced))
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
                    }
                }
            }

            Toggle("", isOn: $shortcut.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(isHovered ? AppSurfaceTokens.separator.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func iconForAction(_ action: String) -> String {
        switch action {
        case "说入法": return "mic.fill"
        case "快速收集": return "tray.and.arrow.down"
        case "截图捕获": return "camera"
        case "打开智能体": return "bubble.left.fill"
        case "今日日程": return "calendar"
        default: return "command"
        }
    }
}
