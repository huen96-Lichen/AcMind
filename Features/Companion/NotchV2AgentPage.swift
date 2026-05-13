import SwiftUI

struct NotchV2AgentPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        HStack(alignment: .top, spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "Agent", subtitle: "输入中心", symbol: "sparkles") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(NotchV2DesignTokens.accentGreen)
                            .frame(width: 8, height: 8)
                        Text("待命中，可接收指令")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                    }

                    Text("GPT-5.5 Thinking")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)

                    Text("⌘ Space 语音 / 文本输入")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)

                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(NotchV2DesignTokens.innerCardActive)
                            .frame(height: 64)
                            .overlay(
                                Text("输入一个指令...")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(NotchV2DesignTokens.weakText)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .padding(12)
                            )

                        HStack(spacing: 8) {
                            NotchV2StatusPill(icon: "mic.fill", title: "语音输入", accent: NotchV2DesignTokens.cardBackgroundStrong)
                            NotchV2StatusPill(icon: "arrow.up.circle.fill", title: "执行", accent: NotchV2DesignTokens.accentPurple)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近状态")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)

                        ForEach(["等待音乐联动", "本地模型可用"], id: \.self) { item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(NotchV2DesignTokens.accentPurple)
                                    .frame(width: 5, height: 5)
                                Text(item)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                                Spacer()
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .frame(width: 300)

            VStack(spacing: NotchV2DesignTokens.cardSpacing) {
                NotchV2Card(title: "最近任务", subtitle: "执行反馈", symbol: "list.bullet.rectangle") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("编排音乐联动")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                        Text("状态：等待下一条指令")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        Text("来源：音乐模块")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        Text("优先级：普通")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)

                        HStack(spacing: 8) {
                            NotchV2StatusPill(title: "继续", accent: NotchV2DesignTokens.accentPurple)
                            NotchV2StatusPill(title: "查看日志", accent: NotchV2DesignTokens.cardBackgroundStrong)
                        }
                    }
                }

                NotchV2Card(title: "工具状态", subtitle: "可用能力", symbol: "wrench.and.screwdriver") {
                    VStack(spacing: 8) {
                        ForEach([
                            ("截图", "可用"),
                            ("语音", "可用"),
                            ("Markdown", "可用"),
                            ("本地模型", "待配置")
                        ], id: \.0) { item in
                            HStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(item.1 == "可用" ? NotchV2DesignTokens.accentGreen : NotchV2DesignTokens.accentPurple)
                                        .frame(width: 6, height: 6)
                                    Text(item.0)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                                }
                                Spacer()
                                Text(item.1)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(NotchV2DesignTokens.innerCardActive)
                                )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, NotchV2DesignTokens.pagePadding)
        .padding(.top, 18)
        .padding(.bottom, NotchV2DesignTokens.bottomPadding)
    }
}
