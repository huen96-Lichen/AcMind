import SwiftUI
import AppKit
import AcMindKit

struct NotchV2TopBar: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        ZStack {
            NotchV2DesignTokens.rootBackground

            GeometryReader { proxy in
                let centerGapWidth = min(
                    NotchV2DesignTokens.notchSafeZoneWidth,
                    max(112, proxy.size.width * 0.13)
                )

                HStack(alignment: .center, spacing: 10) {
                    leftTabs
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)

                    Spacer(minLength: 10)

                    Color.clear
                        .frame(width: centerGapWidth, height: 1)
                        .allowsHitTesting(false)

                    Spacer(minLength: 10)

                    rightStatus
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                }
                .padding(.horizontal, 12)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            }
        }
        .frame(width: NotchV2DesignTokens.expandedWidth, height: NotchV2DesignTokens.topBarHeight)
        .overlay(
            Rectangle()
                .fill(NotchV2DesignTokens.separator.opacity(0.65))
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .bottom)
        )
    }

    private var leftTabs: some View {
        HStack(spacing: 6) {
            topNavPill(title: "本机", icon: "desktopcomputer", selected: viewModel.effectiveSelectedPage == .overview) {
                viewModel.select(.overview)
            }

            topNavPill(title: "启动器", icon: "square.grid.2x2", selected: viewModel.effectiveSelectedPage == .launcher) {
                viewModel.select(.launcher)
            }

            if viewModel.isModuleEnabled(.music) {
                topNavPill(title: "音乐", icon: "music.note", selected: viewModel.effectiveSelectedPage == .music) {
                    viewModel.select(.music)
                }
            }

            if viewModel.isModuleEnabled(.agent) {
                topNavPill(title: "智能", icon: "sparkles", selected: viewModel.effectiveSelectedPage == .agent) {
                    viewModel.select(.agent)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.82))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.8), lineWidth: 0.8)
        )
    }

    private var rightStatus: some View {
        ViewThatFits(in: .horizontal) {
            expandedRightStatus
            compactRightStatus
        }
    }

    private var expandedRightStatus: some View {
        HStack(spacing: 6) {
            statusPill(
                icon: batteryIconName,
                title: batteryText,
                accent: batteryAccent,
                isSelected: false
            )

            NotchV2StatusPill(
                icon: "desktopcomputer",
                title: "状态",
                accent: NotchV2DesignTokens.innerCardBackground,
                isSelected: viewModel.effectiveSelectedPage == .systemStatus,
                action: {
                    viewModel.openSystemStatusPage()
                }
            )

            if viewModel.hasVoiceOverride {
                voiceStatusPill
            }

            NotchV2StatusPill(
                icon: "gearshape",
                title: "设置",
                accent: NotchV2DesignTokens.innerCardBackground,
                isSelected: viewModel.effectiveSelectedPage == .settings,
                action: {
                    viewModel.select(.settings)
                }
            )

            NotchV2StatusPill(
                icon: "chevron.up",
                title: "收起",
                accent: NotchV2DesignTokens.innerCardBackground,
                action: {
                    viewModel.collapse()
                }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.82))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.8), lineWidth: 0.8)
        )
    }

    private var compactRightStatus: some View {
        HStack(spacing: 6) {
            statusPill(
                icon: batteryIconName,
                title: batteryText,
                accent: batteryAccent,
                isSelected: false
            )

            if viewModel.hasVoiceOverride {
                voiceStatusPill
            }

            Menu {
                Button("进入状态页") {
                    viewModel.openSystemStatusPage()
                }

                Button("打开设置") {
                    openSettingsWindow()
                }

                Button("收起") {
                    viewModel.collapse()
                }
            } label: {
                NotchV2StatusPill(
                    icon: "ellipsis",
                    title: "更多",
                    accent: NotchV2DesignTokens.innerCardBackground
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.82))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.8), lineWidth: 0.8)
        )
    }

    private var voiceStatusPill: some View {
        HStack(spacing: 6) {
            NotchV2Glyph(
                symbol: viewModel.voiceDisplayIcon,
                role: .pill,
                tint: viewModel.voiceDisplayAccent,
                isActive: viewModel.isVoicePriorityActive
            )

            Text(voiceCompactTitle)
                .font(.system(size: AppSurfaceTokens.Typography.badge))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            if viewModel.isVoicePriorityActive {
                MiniVoiceWaveform(mode: viewModel.voiceWaveformMode, accent: viewModel.voiceDisplayAccent)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(viewModel.voiceDisplayAccent.opacity(0.10))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(viewModel.voiceDisplayAccent.opacity(0.18), lineWidth: 1)
        )
    }

    private var voiceCompactTitle: String {
        ActivityStateLabelFormatter.voiceCompactLabel(
            state: viewModel.voiceSurfaceState,
            realtimeTranscript: viewModel.realtimeTranscript
        )
    }

    private func topNavPill(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        NotchV2StatusPill(
            icon: icon,
            title: title,
            accent: selected ? NotchV2DesignTokens.accentBlue : NotchV2DesignTokens.innerCardBackground,
            isSelected: selected,
            action: action
        )
    }

    private func statusPill(icon: String, title: String, accent: Color, isSelected: Bool) -> some View {
        NotchV2StatusPill(
            icon: icon,
            title: title,
            accent: accent,
            isSelected: isSelected
        )
    }

    private func openSettingsWindow() {
        (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
    }

    private var batteryText: String {
        viewModel.batteryDisplayText
    }

    private var batteryAccent: Color {
        if viewModel.batteryInfo.isAvailable == false {
            return NotchV2DesignTokens.secondaryText
        }
        if viewModel.batteryInfo.isInLowPowerMode {
            return .orange
        }
        if viewModel.batteryInfo.percentage <= 20 && viewModel.batteryInfo.isCharging == false {
            return .red
        }
        if viewModel.batteryInfo.isCharging || viewModel.batteryInfo.isPluggedIn {
            return NotchV2DesignTokens.accentGreen
        }
        return NotchV2DesignTokens.secondaryText
    }

    private var batteryIconName: String {
        viewModel.batteryIconName
    }
}

    struct MiniVoiceWaveform: View {
        let mode: NotchV2VoiceWaveformMode
        let accent: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            HStack(alignment: .center, spacing: 1.2) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(accent)
                        .frame(width: 2.2, height: barHeight(for: index, time: time))
                        .opacity(barOpacity(for: index, time: time))
                }
            }
            .frame(height: 10)
            .padding(.leading, 1)
        }
    }

    private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
        let base: CGFloat = mode == .processing ? 2.5 : 3.5
        let amplitude: CGFloat = mode == .processing ? 2.5 : 4.5
        let phase = time * (mode == .processing ? 4.0 : 6.0) + Double(index) * 0.62
        let sample = CGFloat((sin(phase) + 1.0) / 2.0)
        return base + amplitude * sample
    }

    private func barOpacity(for index: Int, time: TimeInterval) -> Double {
        let phase = time * 5.0 + Double(index) * 0.35
        return mode == .processing ? 0.62 + 0.2 * ((sin(phase) + 1.0) / 2.0) : 0.72 + 0.22 * ((sin(phase) + 1.0) / 2.0)
    }
}
