import SwiftUI
import AcMindKit

struct NotchV2LightStatusItem: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let accent: Color
    let highlighted: Bool
    let priority: Int
}

struct NotchV2LightStatusStrip: View {
    let items: [NotchV2LightStatusItem]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(displayItems) { item in
                statusChip(item)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.24), lineWidth: 0.8)
        )
    }

    private var sortedItems: [NotchV2LightStatusItem] {
        items.sorted {
            if $0.highlighted != $1.highlighted {
                return $0.highlighted && !$1.highlighted
            }
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.title < $1.title
        }
    }

    private var displayItems: [NotchV2LightStatusItem] {
        let prioritized = sortedItems.filter { $0.highlighted }
        if prioritized.isEmpty {
            return Array(sortedItems.prefix(4))
        }
        return Array((prioritized + sortedItems.filter { $0.highlighted == false }).prefix(4))
    }

    private func statusChip(_ item: NotchV2LightStatusItem) -> some View {
        HStack(spacing: 5) {
            NotchV2Glyph(
                symbol: item.icon,
                role: .statusStrip,
                tint: item.accent,
                isActive: item.highlighted
            )

            Text(item.title)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)

            Text(item.detail)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .scaleEffect(item.highlighted ? 1.02 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                .fill(item.highlighted ? NotchV2DesignTokens.panelBackground : NotchV2DesignTokens.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                .stroke(item.highlighted ? item.accent.opacity(0.12) : NotchV2DesignTokens.separator.opacity(0.12), lineWidth: 0.8)
        )
        .shadow(color: item.highlighted ? item.accent.opacity(0.03) : .clear, radius: 3, x: 0, y: 1)
        .animation(.easeOut(duration: 0.16), value: item.highlighted)
    }
}

extension NotchV2ViewModel {
    var lightStatusItems: [NotchV2LightStatusItem] {
        var items: [NotchV2LightStatusItem] = []

        items.append(
            NotchV2LightStatusItem(
                icon: batteryIconName,
                title: batteryInfo.isAvailable == false ? "无电池" : batteryInfo.isInLowPowerMode ? "低电量模式" : "电池",
                detail: batteryDisplayText,
                accent: batteryStatusAccent,
                highlighted: batteryInfo.isAvailable && (batteryInfo.isInLowPowerMode || batteryInfo.percentage <= 20),
                priority: 0
            )
        )

        items.append(
            NotchV2LightStatusItem(
                icon: batteryInfo.isCharging || batteryInfo.isPluggedIn ? "powerplug.fill" : "powerplug",
                title: batteryInfo.isCharging ? "充电中" : batteryInfo.isPluggedIn ? "接电" : "电源",
                detail: batteryInfo.isAvailable == false ? "无电池" : batteryInfo.powerSourceState.isEmpty ? "电池供电" : batteryInfo.powerSourceState,
                accent: NotchV2DesignTokens.secondaryText,
                highlighted: batteryInfo.isCharging,
                priority: 1
            )
        )

        items.append(
            NotchV2LightStatusItem(
                icon: microphonePermissionStatus == .authorized ? "mic.fill" : "mic.slash.fill",
                title: "麦克风",
                detail: microphonePermissionStatus.displayName,
                accent: microphoneAccent,
                highlighted: microphonePermissionStatus == .denied || microphonePermissionStatus == .restricted,
                priority: 2
            )
        )

        items.append(
            NotchV2LightStatusItem(
                icon: voiceDisplayIcon,
                title: voiceDisplayTitle ?? "说入法",
                detail: voiceDisplaySubtitle,
                accent: voiceDisplayAccent,
                highlighted: isVoicePriorityActive,
                priority: voiceDisplayPriority.rawValue
            )
        )

        items.append(
                NotchV2LightStatusItem(
                    icon: isCapturing ? "camera.viewfinder" : "camera",
                    title: isCapturing ? "截图处理中" : "截图",
                    detail: ActivityStateLabelFormatter.activityLabel(isActive: isCapturing, activeLabel: "处理中", idleLabel: "待命"),
                    accent: isCapturing ? .orange : NotchV2DesignTokens.secondaryText,
                    highlighted: isCapturing,
                    priority: 4
                )
            )

        if playbackState.isPlaying || playbackState.title.isEmpty == false || playbackState.sourceLabel.isEmpty == false || playbackState.bundleIdentifier != nil {
            items.append(
                NotchV2LightStatusItem(
                    icon: playbackState.isPlaying ? "play.fill" : "pause.fill",
                    title: NowPlayingSourceLabelFormatter.playbackStateLabel(
                        isPlaying: playbackState.isPlaying,
                        bundleIdentifier: playbackState.bundleIdentifier,
                        source: playbackState.sourceLabel,
                        playingPrefix: "播放中",
                        pausedPrefix: "已暂停"
                    ),
                    detail: NowPlayingSourceLabelFormatter.trackDetailLabel(
                        title: playbackState.title,
                        bundleIdentifier: playbackState.bundleIdentifier,
                        source: playbackState.sourceLabel
                    ),
                    accent: playbackState.isPlaying ? NotchV2DesignTokens.accentGreen : NotchV2DesignTokens.secondaryText,
                    highlighted: playbackState.isPlaying || playbackState.title.isEmpty == false || playbackState.sourceLabel.isEmpty == false || playbackState.bundleIdentifier != nil,
                    priority: NotchV2SurfacePriority.music.rawValue
                )
            )
        }

        if let volume = eventCenter.volumeLevel {
            items.append(
                NotchV2LightStatusItem(
                    icon: "speaker.wave.2.fill",
                    title: "音量",
                    detail: "\(Int(volume.rounded()))%",
                    accent: NotchV2DesignTokens.secondaryText,
                    highlighted: volume < 30,
                    priority: 5
                )
            )
        }

        if let brightness = eventCenter.brightnessLevel {
            items.append(
                NotchV2LightStatusItem(
                    icon: "sun.max.fill",
                    title: "亮度",
                    detail: "\(Int(brightness.rounded()))%",
                    accent: NotchV2DesignTokens.secondaryText,
                    highlighted: brightness < 30,
                    priority: 6
                )
            )
        }

        if items.count < 4 {
            items.append(
                NotchV2LightStatusItem(
                    icon: "shield.checkerboard",
                    title: "权限",
                    detail: "已接入",
                    accent: NotchV2DesignTokens.secondaryText,
                    highlighted: false,
                    priority: 99
                )
            )
        }

        return Array(items.sorted {
            if $0.highlighted != $1.highlighted {
                return $0.highlighted && !$1.highlighted
            }
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.title < $1.title
        }.prefix(6))
    }

    private var eventCenter: SystemEventCenter { systemEventCenter }

    private var batteryStatusAccent: Color {
        if batteryInfo.isAvailable == false {
            return NotchV2DesignTokens.secondaryText
        }
        if batteryInfo.isInLowPowerMode {
            return .orange
        }
        if batteryInfo.percentage <= 20 && batteryInfo.isCharging == false && batteryInfo.isPluggedIn == false {
            return .red
        }
        if batteryInfo.isCharging || batteryInfo.isPluggedIn {
            return .green
        }
        return NotchV2DesignTokens.secondaryText
    }

    private var microphoneAccent: Color {
        switch microphonePermissionStatus {
        case .authorized:
            return NotchV2DesignTokens.accentGreen
        case .needsSystemSettings, .denied:
            return .orange
        case .failed:
            return .red
        default:
            return NotchV2DesignTokens.secondaryText
        }
    }

}

// MARK: - System Rail

struct NotchV2SystemRail: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            CompanionPanel(
                title: "本机状态",
                symbol: "desktopcomputer",
                fillHeight: true
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    statusRow(title: "电池", value: viewModel.batteryStateText, accent: viewModel.batteryAccent)
                    statusRow(title: "麦克风", value: viewModel.microphonePermissionStatus.displayName, accent: permissionAccent(for: viewModel.microphonePermissionStatus))
                    statusRow(title: "录屏", value: viewModel.screenRecordingPermissionStatus.displayName, accent: permissionAccent(for: viewModel.screenRecordingPermissionStatus))
                    statusRow(title: "辅助功能", value: viewModel.accessibilityPermissionStatus.displayName, accent: permissionAccent(for: viewModel.accessibilityPermissionStatus))

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func statusRow(title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)

            Text(title)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(value)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.94))
        )
    }

    private func permissionAccent(for status: AppPermissionStatus) -> Color {
        switch status {
        case .authorized:
            return NotchV2DesignTokens.accentBlue
        case .denied, .restricted, .needsSystemSettings:
            return .orange
        case .failed:
            return .red
        case .requesting:
            return .blue
        case .notDetermined, .unknown:
            return NotchV2DesignTokens.secondaryText
        }
    }
}
