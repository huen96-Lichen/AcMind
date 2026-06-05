import SwiftUI
import AppKit

struct NotchV2SystemStatusRail: View {
    @ObservedObject var viewModel: SystemStatusViewModel

    var body: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "状态", symbol: "desktopcomputer", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    statusRow(title: "CPU", value: viewModel.cpuSummary, accent: .blue)
                    statusRow(title: "内存", value: viewModel.memorySummary, accent: .purple)
                    statusRow(title: "电池", value: viewModel.batterySummary, accent: .cyan)
                    statusRow(title: "网络", value: viewModel.networkSummary, accent: .green)

                    Button("查看状态") {
                        (NSApp.delegate as? AppDelegate)?.showSystemStatus()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 4)
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
}
