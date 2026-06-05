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
                .padding(.horizontal, 16)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            }
        }
        .frame(width: NotchV2DesignTokens.expandedWidth, height: NotchV2DesignTokens.topBarHeight)
    }

    private var leftTabs: some View {
        HStack(spacing: 6) {
            topNavButton(title: "本机", icon: "desktopcomputer", selected: viewModel.effectiveSelectedPage == .overview) {
                viewModel.select(.overview)
            }

            if viewModel.isModuleEnabled(.music) {
                topNavButton(title: "音乐", icon: "music.note", selected: viewModel.effectiveSelectedPage == .music) {
                    viewModel.select(.music)
                }
            }

            if viewModel.isModuleEnabled(.agent) {
                topNavButton(title: "AI", icon: "sparkles", selected: viewModel.effectiveSelectedPage == .agent) {
                    viewModel.select(.agent)
                }
            }
        }
    }

    private var rightStatus: some View {
        HStack(spacing: 5) {
            statusPill(
                icon: batteryIconName,
                title: batteryText,
                accent: batteryAccent
            )

            NotchV2StatusPill(
                icon: "desktopcomputer",
                title: "状态",
                accent: NotchV2DesignTokens.cardBackgroundStrong,
                action: {
                    (NSApp.delegate as? AppDelegate)?.showSystemStatus()
                }
            )

            if viewModel.hasVoiceOverride {
                voiceStatusPill
            }

            NotchV2StatusPill(
                icon: "gearshape",
                title: "设置",
                accent: NotchV2DesignTokens.cardBackgroundStrong,
                action: {
                    (NSApp.delegate as? NSObject)?.perform(Selector(("showSettings")))
                }
            )

            collapseButton
        }
    }

    private var voiceStatusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.voiceDisplayIcon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(viewModel.voiceDisplayAccent)

            Text(voiceCompactTitle)
                .font(NotchV2DesignTokens.Typography.caption)
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
        switch viewModel.voiceSurfaceState {
        case .idle:
            return "说入法"
        case .listening:
            return "收音中"
        case .processing:
            return "清洗中"
        case .completed:
            return "已写入"
        case .cancelled:
            return "已取消"
        }
    }

    private func statusPill(icon: String, title: String, accent: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(accent)

            Text(title)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.84))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private var collapseButton: some View {
        Button(action: { viewModel.collapse() }) {
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(NotchV2DesignTokens.cardBackgroundStrong.opacity(0.84))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var batteryText: String {
        "\(Int(viewModel.batteryInfo.percentage.rounded()))%"
    }

    private var batteryAccent: Color {
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
        if viewModel.batteryInfo.isCharging {
            return "bolt.fill"
        }
        if viewModel.batteryInfo.isPluggedIn {
            return "plug.fill"
        }

        let level = viewModel.batteryInfo.percentage
        switch level {
        case ..<10: return "battery.0"
        case ..<25: return "battery.25"
        case ..<50: return "battery.50"
        case ..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private func topNavButton(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .frame(height: 24)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? NotchV2DesignTokens.accentPurple.opacity(0.94) : NotchV2DesignTokens.cardBackgroundStrong.opacity(0.46))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selected ? Color.white.opacity(0.06) : Color.white.opacity(0.02), lineWidth: 1)
            )
            .shadow(color: selected ? NotchV2DesignTokens.accentPurple.opacity(0.10) : .clear, radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

    private struct MiniVoiceWaveform: View {
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
