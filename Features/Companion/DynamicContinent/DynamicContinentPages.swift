import SwiftUI

struct DynamicContinentTodayPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2OverviewPage(viewModel: viewModel)
    }
}

struct DynamicContinentMusicPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2MusicPage(viewModel: viewModel)
    }
}

struct DynamicContinentAgentPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchV2AgentPage(viewModel: viewModel)
    }
}

struct DynamicContinentSchedulePage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchThreeColumnLayout(
            left: { timelineCard },
            center: { focusColumn },
            right: { loadCard }
        )
        .frame(width: NotchV2DesignTokens.expandedWidth, height: 392, alignment: .topLeading)
    }

    private var timelineCard: some View {
        NotchV2Card(title: "今日时间线", subtitle: "轻量状态", symbol: "calendar", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(scheduleRows, id: \.time) { item in
                    NotchV2CompactTimelineRow(time: item.time, title: item.title)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(width: 160, height: 354, alignment: .topLeading)
    }

    private var focusColumn: some View {
        VStack(alignment: .leading, spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "当前焦点", subtitle: "执行中", symbol: "target", padding: 16, fillHeight: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("编排音乐联动")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)

                    Text("状态：等待下一条指令")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)

                    Text("来源：音乐模块")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)

                    HStack(spacing: 8) {
                        NotchV2StatusPill(title: "继续", accent: NotchV2DesignTokens.accentPurple)
                        NotchV2StatusPill(title: "查看日志", accent: NotchV2DesignTokens.cardBackgroundStrong)
                    }
                }
            }
            .frame(height: 164)

            NotchV2Card(title: "下一项任务", subtitle: "待开始", symbol: "clock", padding: 16, fillHeight: true) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("16:30 音乐联动评估")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(2)

                    Text("还剩 2 项任务")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }
            }
            .frame(height: 170)
        }
        .frame(width: 396, height: 354, alignment: .topLeading)
    }

    private var loadCard: some View {
        NotchV2Card(title: "日程负载", subtitle: "快速新增", symbol: "chart.bar", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日剩余 2 项")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                    Text("负载状态：稳定")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }

                VStack(spacing: 8) {
                    NotchV2StatusPill(icon: "plus", title: "新增日程", accent: NotchV2DesignTokens.innerCardBackground)
                    NotchV2StatusPill(icon: "sparkles", title: "今日总结", accent: NotchV2DesignTokens.innerCardBackground)
                }
            }
        }
        .frame(width: 180, height: 354, alignment: .topLeading)
    }

    private var scheduleRows: [(time: String, title: String)] {
        [
            ("09:00", "产品设计评审"),
            ("11:00", "需求沟通同步"),
            ("16:30", "音乐联动评估"),
            ("18:30", "健身锻炼")
        ]
    }
}
