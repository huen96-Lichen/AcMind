import SwiftUI
import AcMindKit

struct NotchV2SystemStatusRail: View {
    @ObservedObject var viewModel: SystemStatusViewModel

    var body: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "本机状态", symbol: "desktopcomputer", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    statusRow(title: "电池", value: "\(viewModel.batteryLevel)% · \(viewModel.batteryState)", accent: batteryAccent)
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
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 10, weight: .semibold))
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

    private var batteryAccent: Color {
        if viewModel.batteryInfo.isInLowPowerMode {
            return .orange
        }
        if viewModel.batteryInfo.percentage <= 20 && viewModel.batteryInfo.isCharging == false {
            return .red
        }
        if viewModel.batteryInfo.isCharging || viewModel.batteryInfo.isPluggedIn {
            return NotchV2DesignTokens.accentBlue
        }
        return NotchV2DesignTokens.secondaryText
    }
}
