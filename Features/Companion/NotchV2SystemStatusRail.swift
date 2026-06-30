import SwiftUI
import AppKit

struct NotchV2SystemStatusRail: View {
    @ObservedObject var viewModel: SystemStatusViewModel

    var body: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            CompanionPanel(title: "本机状态", subtitle: "系统和权限", symbol: "desktopcomputer") {
                VStack(alignment: .leading, spacing: 6) {
                    statusRow(title: "处理器", value: viewModel.cpuSummary, accent: .blue)
                    statusRow(title: "内存", value: viewModel.memorySummary, accent: .purple)
                    statusRow(title: "电池", value: viewModel.batterySummary, accent: .cyan)
                    statusRow(title: "网络", value: viewModel.networkSummary, accent: .green)

                    NotchV2StatusPill(
                        icon: "arrow.up.right.square",
                        title: "查看状态",
                        accent: NotchV2DesignTokens.innerCardBackground.opacity(0.92),
                        action: {
                            (NSApp.delegate as? AppDelegate)?.showSystemStatus()
                        }
                    )
                    .padding(.top, 4)
                }
            }
        }
    }

    private func statusRow(title: String, value: String, accent: Color) -> some View {
        NotchV2InfoRow(title: title, value: value, icon: nil, accent: accent, compactValue: true)
    }
}
