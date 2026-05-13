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
        HStack(alignment: .top, spacing: DynamicContinentLayoutMetrics.columnGap) {
            DynamicCard(title: "今日时间线", subtitle: "轻量状态", symbol: "calendar") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach([
                        ("09:00", "产品设计评审"),
                        ("11:00", "需求沟通同步"),
                        ("16:30", "音乐联动评估"),
                        ("18:30", "健身锻炼")
                    ], id: \.0) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(item.0)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DynamicContinentDesignTokens.accentPurple)
                                .frame(width: 54, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.1)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                                Text("当前可用")
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundStyle(DynamicContinentDesignTokens.tertiaryText)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .frame(width: 230)

            VStack(spacing: DynamicContinentLayoutMetrics.rowGap) {
                DynamicCard(title: "当前焦点", subtitle: "执行中", symbol: "target") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("编排音乐联动")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                        Text("状态：等待下一条指令")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                        Text("来源：音乐模块")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)

                        HStack(spacing: 8) {
                            NotchV2StatusPill(title: "继续", accent: DynamicContinentDesignTokens.accentPurple)
                            NotchV2StatusPill(title: "查看日志", accent: DynamicContinentDesignTokens.cardBackgroundStrong)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                DynamicCard(title: "下一项任务", subtitle: "待开始", symbol: "clock") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("16:30 音乐联动评估")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                        Text("还剩 2 项任务")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            DynamicCard(title: "日程负载", subtitle: "快速新增", symbol: "chart.bar") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今日剩余 2 项")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DynamicContinentDesignTokens.primaryText)
                        Text("负载状态：稳定")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DynamicContinentDesignTokens.secondaryText)
                    }

                    VStack(spacing: 8) {
                        NotchV2StatusPill(icon: "plus", title: "新增日程", accent: DynamicContinentDesignTokens.innerCardBackground)
                        NotchV2StatusPill(icon: "sparkles", title: "今日总结", accent: DynamicContinentDesignTokens.innerCardBackground)
                    }
                }
            }
            .frame(width: 180)
        }
        .padding(.horizontal, DynamicContinentLayoutMetrics.pageHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, DynamicContinentLayoutMetrics.pageBottomPadding)
    }
}
