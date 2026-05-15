import SwiftUI

struct CompanionView: View {
    @State private var isEnabled = true
    @State private var capsuleEnabled = true
    @State private var voiceEnabled = true
    @State private var shortcutsEnabled = true
    @State private var captureEnabled = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ACPageHeader(
                    title: "随身",
                    subtitle: "跨页面、跨应用、随时调用的系统能力域",
                    trailing: {
                        HStack(spacing: 12) {
                            Text("全局启用")
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(ACColors.secondaryText)
                            Toggle("", isOn: $isEnabled)
                                .labelsHidden()
                        }
                    }
                )
                .frame(height: 76)

                ACCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("定位")
                            .font(ACTypography.panelTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("随身页不是业务页，而是桌面入口、语音转写、全局快捷键和捕获动作的统一控制中心。")
                            .font(ACTypography.body)
                            .foregroundStyle(ACColors.secondaryText)
                            .lineSpacing(4)
                    }
                }
                .frame(maxWidth: 1060)

                VStack(spacing: 16) {
                    CompanionCapabilitySection(
                        title: "随身胶囊",
                        subtitle: "桌面入口与顶部大陆能力",
                        symbol: "capsule.portrait.fill",
                        tint: ACColors.accentBlue,
                        enabled: $capsuleEnabled
                    ) {
                        CompanionCapsulePreview()
                    }

                    CompanionCapabilitySection(
                        title: "随身语音",
                        subtitle: "快捷键、转写后操作、保存到收集箱",
                        symbol: "mic.fill",
                        tint: ACColors.accentPurple,
                        enabled: $voiceEnabled
                    ) {
                        CompanionVoicePreview()
                    }

                    CompanionCapabilitySection(
                        title: "随身快捷键",
                        subtitle: "全局快捷键列表与快捷触发",
                        symbol: "command",
                        tint: ACColors.accentGreen,
                        enabled: $shortcutsEnabled
                    ) {
                        CompanionShortcutGrid()
                    }

                    CompanionCapabilitySection(
                        title: "随身捕获",
                        subtitle: "截图、剪贴板、网页、文件捕获",
                        symbol: "viewfinder",
                        tint: ACColors.accentOrange,
                        enabled: $captureEnabled
                    ) {
                        CompanionCapturePreview()
                    }
                }
                .frame(maxWidth: 1060)
            }
            .padding(.horizontal, ACLayout.pagePaddingX)
            .padding(.vertical, ACLayout.pagePaddingY)
            .padding(.bottom, ACLayout.pagePaddingBottom)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ACColors.pageBackground)
    }
}

private struct CompanionCapabilitySection<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    @Binding var enabled: Bool
    @ViewBuilder let content: Content

    var body: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ACTypeIcon(symbol, tint: tint, background: tint.opacity(0.12), size: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text(subtitle)
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    Spacer(minLength: 0)

                    Toggle("", isOn: $enabled)
                        .labelsHidden()
                }

                content
                    .opacity(enabled ? 1 : 0.45)
            }
        }
    }
}

private struct CompanionCapsulePreview: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ACColors.blackCapsule)
                .frame(width: 220, height: 92)
                .overlay(
                    HStack {
                        Circle().fill(ACColors.accentBlue).frame(width: 14, height: 14)
                        Spacer()
                        Circle().fill(ACColors.accentPurple).frame(width: 14, height: 14)
                        Spacer()
                        Circle().fill(ACColors.accentGreen).frame(width: 14, height: 14)
                    }
                    .padding(.horizontal, 18)
                )

            VStack(alignment: .leading, spacing: 8) {
                Text("桌面入口")
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                Text("顶部胶囊与大陆联动")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)

                HStack(spacing: 8) {
                    ACBadge("可用", kind: .blue)
                    ACBadge("联动中", kind: .purple)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct CompanionVoicePreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Keycap("⌥")
                Keycap("Space")
                Text("开始语音转写并保存到收集箱")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                ForEach([0.25, 0.48, 0.66, 0.34, 0.74, 0.52, 0.42, 0.58], id: \.self) { height in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ACColors.accentPurple)
                        .frame(width: 12, height: 28 + height * 36)
                }
            }
            .frame(height: 72, alignment: .bottom)
        }
    }
}

private struct CompanionShortcutGrid: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(shortcutItems) { item in
                HStack(spacing: 10) {
                    Keycap(item.shortcut)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.primaryText)
                        Text(item.subtitle)
                            .font(ACTypography.mini)
                            .foregroundStyle(ACColors.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(ACColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                        .stroke(ACColors.border, lineWidth: 1)
                )
            }
        }
    }
}

private struct CompanionCapturePreview: View {
    var body: some View {
        HStack(spacing: 12) {
            ACTypeIcon("camera.viewfinder", tint: ACColors.accentOrange, background: ACColors.accentOrange.opacity(0.12), size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("截图 / 剪贴板 / 网页 / 文件")
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                Text("一键捕获后可直接发送到收集箱或 Agent。")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                ACBadge("已启用", kind: .green)
                ACBadge("快捷触发", kind: .orange)
            }
        }
    }
}

private struct Keycap: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(ACTypography.captionMedium)
            .foregroundStyle(ACColors.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(ACColors.softFill)
            .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                    .stroke(ACColors.border, lineWidth: 1)
            )
    }
}

private struct ShortcutItem: Identifiable {
    let id = UUID()
    let shortcut: String
    let title: String
    let subtitle: String
}

private let shortcutItems: [ShortcutItem] = [
    .init(shortcut: "⌘⇧V", title: "打开语音面板", subtitle: "语音"),
    .init(shortcut: "⌘⇧C", title: "快速捕获", subtitle: "捕获"),
    .init(shortcut: "⌘⌥A", title: "发送到 Agent", subtitle: "联动"),
    .init(shortcut: "⌘⌥I", title: "保存到收集箱", subtitle: "归档"),
    .init(shortcut: "⌘⌥K", title: "打开胶囊", subtitle: "入口"),
    .init(shortcut: "⌘⌥S", title: "开始总结", subtitle: "转写")
]
