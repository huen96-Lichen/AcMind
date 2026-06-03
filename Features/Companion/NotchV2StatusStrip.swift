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
        HStack(spacing: 8) {
            ForEach(sortedItems.prefix(6)) { item in
                statusChip(item)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(NotchV2DesignTokens.cardBackgroundDeep.opacity(0.80))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.36), lineWidth: 1)
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

    private func statusChip(_ item: NotchV2LightStatusItem) -> some View {
        HStack(spacing: 5) {
            Image(systemName: item.icon)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(item.accent)

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(item.highlighted ? item.accent.opacity(0.12) : NotchV2DesignTokens.innerCardBackground.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(item.highlighted ? item.accent.opacity(0.18) : NotchV2DesignTokens.separator.opacity(0.18), lineWidth: 1)
        )
    }
}

extension NotchV2ViewModel {
    var lightStatusItems: [NotchV2LightStatusItem] {
        var items: [NotchV2LightStatusItem] = []

        items.append(
            NotchV2LightStatusItem(
                icon: batteryInfo.isCharging ? "bolt.fill" : batteryInfo.isPluggedIn ? "plug.fill" : "battery.100",
                title: batteryInfo.isInLowPowerMode ? "低电量模式" : "电池",
                detail: batteryDetailText,
                accent: batteryStatusAccent,
                highlighted: batteryInfo.isInLowPowerMode || batteryInfo.percentage <= 20,
                priority: 0
            )
        )

        items.append(
            NotchV2LightStatusItem(
                icon: batteryInfo.isCharging || batteryInfo.isPluggedIn ? "powerplug.fill" : "powerplug",
                title: batteryInfo.isCharging ? "充电中" : batteryInfo.isPluggedIn ? "接电" : "电源",
                detail: batteryInfo.powerSourceState.isEmpty ? "电池供电" : batteryInfo.powerSourceState,
                accent: batteryInfo.isCharging ? .green : batteryInfo.isPluggedIn ? .blue : NotchV2DesignTokens.secondaryText,
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
                highlighted: microphonePermissionStatus != .authorized,
                priority: 2
            )
        )

        items.append(
            NotchV2LightStatusItem(
                icon: voiceDisplayIcon,
                title: voiceDisplayTitle ?? "说入法",
                detail: voiceDisplaySubtitle ?? "待命",
                accent: voiceDisplayAccent,
                highlighted: isVoicePriorityActive,
                priority: voiceDisplayPriority.rawValue
            )
        )

        items.append(
            NotchV2LightStatusItem(
                icon: isCapturing ? "camera.viewfinder" : "camera",
                title: isCapturing ? "截图处理中" : "截图",
                detail: isCapturing ? "处理中" : "待命",
                accent: isCapturing ? .orange : NotchV2DesignTokens.secondaryText,
                highlighted: isCapturing,
                priority: 4
            )
        )

        if playbackState.isPlaying || playbackState.title.isEmpty == false {
            items.append(
                NotchV2LightStatusItem(
                    icon: playbackState.isPlaying ? "play.fill" : "pause.fill",
                    title: playbackState.isPlaying ? "媒体播放" : "媒体暂停",
                    detail: playbackState.title.isEmpty ? "未命名" : playbackState.title,
                    accent: playbackState.isPlaying ? NotchV2DesignTokens.accentGreen : NotchV2DesignTokens.secondaryText,
                    highlighted: playbackState.isPlaying,
                    priority: 7
                )
            )
        }

        if let volume = eventCenter.volumeLevel {
            items.append(
                NotchV2LightStatusItem(
                    icon: "speaker.wave.2.fill",
                    title: "音量",
                    detail: "\(Int(volume.rounded()))%",
                    accent: .blue,
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
                    accent: .orange,
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
                    accent: NotchV2DesignTokens.accentGreen,
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

    private var eventCenter: SystemEventCenter {
        SystemEventCenter.shared
    }

    private var batteryDetailText: String {
        "\(Int(batteryInfo.percentage.rounded()))%"
    }

    private var batteryStatusAccent: Color {
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
            NotchV2Card(title: "本机状态", symbol: "desktopcomputer", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    statusRow(title: "电池", value: viewModel.batteryStateText, accent: viewModel.batteryAccent)
                    statusRow(title: "麦克风", value: viewModel.microphonePermissionStatus.displayName, accent: permissionAccent(for: viewModel.microphonePermissionStatus))
                    statusRow(title: "录屏", value: viewModel.screenRecordingPermissionStatus.displayName, accent: permissionAccent(for: viewModel.screenRecordingPermissionStatus))
                    statusRow(title: "辅助功能", value: viewModel.accessibilityPermissionStatus.displayName, accent: permissionAccent(for: viewModel.accessibilityPermissionStatus))
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
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.88))
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
