import SwiftUI

struct AgentWorkspaceView: View {
    @State private var selectedTab: AgentSidebarTab = .conversations
    @State private var selectedConversationID: UUID = AgentConversation.mockItems[0].id
    @State private var searchText: String = ""
    @State private var inputText: String = "请分析本季度产品增长数据，并生成一份可视化汇报。"

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ACPageHeader(
                    title: "Agent",
                    subtitle: "对话、任务、历史、计划与结果预览统一放在同一工作台中。"
                ) {
                    HStack(spacing: 12) {
                        ACBadge("在线", kind: .green)
                        ACBadge("GPT-5.5 Thinking", kind: .purple)
                    }
                }
                .frame(height: ACLayout.headerHeightMedium)

                HStack(alignment: .top, spacing: ACLayout.gapL) {
                    leftPanel
                        .frame(width: 300)

                    centerPanel
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    rightPanel
                        .frame(width: 280)
                }
            }
            .padding(.horizontal, ACLayout.pagePaddingX)
            .padding(.top, ACLayout.pagePaddingY)
            .padding(.bottom, ACLayout.pagePaddingBottom)
            .frame(maxWidth: 1512, alignment: .center)
        }
        .background(ACColors.pageBackground.ignoresSafeArea())
    }

    private var leftPanel: some View {
        ACCard(padding: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    ACSegmentedControl(AgentSidebarTab.allCases, selection: $selectedTab) { option, isSelected in
                        Text(option.title)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                    }

                    HStack(spacing: 8) {
                        ACSearchField("搜索对话 / 任务", text: $searchText, width: 184, height: 36)

                        ACButton("新建", kind: .secondary, minWidth: 72) {}
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("今天")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.secondaryText)
                        .padding(.top, 4)

                    VStack(spacing: 8) {
                        ForEach(filteredConversations(prefix: 4)) { conversation in
                            Button {
                                selectedConversationID = conversation.id
                            } label: {
                                AgentConversationRow(conversation: conversation, isSelected: selectedConversationID == conversation.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("更早")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.secondaryText)
                        .padding(.top, 6)

                    VStack(spacing: 8) {
                        ForEach(filteredConversations(prefix: 2, offset: 4)) { conversation in
                            Button {
                                selectedConversationID = conversation.id
                            } label: {
                                AgentConversationRow(conversation: conversation, isSelected: selectedConversationID == conversation.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    private var centerPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            ACCard(padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedConversation.title)
                                .font(ACTypography.cardTitle)
                                .foregroundStyle(ACColors.primaryText)
                            Text(selectedConversation.subtitle)
                                .font(ACTypography.caption)
                                .foregroundStyle(ACColors.secondaryText)
                        }

                        Spacer(minLength: 0)

                        ACBadge(selectedConversation.stateTitle, kind: selectedConversation.stateKind)
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            AgentMessageBubble(
                                role: "用户",
                                text: selectedConversation.userMessage,
                                accent: ACColors.accentPurple,
                                alignedToTrailing: true
                            )

                            AgentMessageBubble(
                                role: "Agent",
                                text: selectedConversation.agentReply,
                                accent: ACColors.accentBlue,
                                alignedToTrailing: false
                            )

                            AgentPlanCard(steps: selectedConversation.planSteps)

                            AgentResultPreviewCard(items: selectedConversation.previewMetrics)
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(minHeight: 420)
                }
            }

            AgentInputComposerCard(text: $inputText)
        }
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            ACDetailPanel(width: 280, padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        Text("当前任务")
                            .font(ACTypography.panelTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Spacer()
                        ACBadge("执行中", kind: .blue)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedConversation.title)
                            .font(ACTypography.itemTitle)
                            .foregroundStyle(ACColors.primaryText)
                            .lineLimit(2)
                        Text("本季度产品增长分析")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    ACInfoTable([
                        .init("状态", value: "分析中", valueColor: ACColors.accentBlue),
                        .init("开始时间", value: "10:23"),
                        .init("预计剩余", value: "08 分钟"),
                        .init("来源", value: "聊天 / 语音 / 文件")
                    ])
                }
            }

            ACDetailPanel(width: 280, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("工具调用")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)

                    VStack(spacing: 8) {
                        ForEach(toolCalls) { call in
                            AgentSmallRow(title: call.title, subtitle: call.detail, status: call.status)
                        }
                    }
                }
            }

            ACDetailPanel(width: 280, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("参考文件")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)

                    VStack(spacing: 8) {
                        ForEach(referenceFiles) { file in
                            AgentReferenceRow(file: file)
                        }
                    }
                }
            }

            ACDetailPanel(width: 280, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("能力预留")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)

                    VStack(spacing: 8) {
                        AgentCapabilityRow(title: "任务编排", subtitle: "计划、拆解、结果回填", enabled: true)
                        AgentCapabilityRow(title: "文件工具", subtitle: "读取、整理、导出", enabled: true)
                        AgentCapabilityRow(title: "模型切换", subtitle: "多模型协作", enabled: false)
                    }
                }
            }
        }
    }

    private var selectedConversation: AgentConversation {
        AgentConversation.mockItems.first(where: { $0.id == selectedConversationID }) ?? AgentConversation.mockItems[0]
    }

    private func filteredConversations(prefix: Int, offset: Int = 0) -> [AgentConversation] {
        let filtered = AgentConversation.mockItems.filter {
            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
        let slice = filtered.dropFirst(offset).prefix(prefix)
        return Array(slice)
    }
}

private enum AgentSidebarTab: String, CaseIterable, Identifiable {
    case conversations = "对话"
    case tasks = "任务"
    case history = "历史"

    var id: String { rawValue }
    var title: String { rawValue }
}

private struct AgentConversation: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let stateTitle: String
    let stateKind: ACBadge.Kind
    let userMessage: String
    let agentReply: String
    let planSteps: [AgentPlanStep]
    let previewMetrics: [AgentPreviewMetric]

    static let mockItems: [AgentConversation] = [
        .init(
            title: "分析本季度产品增长",
            subtitle: "10:23 · 进行中",
            stateTitle: "进行中",
            stateKind: .blue,
            userMessage: "帮我分析本季度产品增长数据，生成可视化图表和关键结论，并输出一份汇报文档。",
            agentReply: "好的，我会先读取数据、清洗指标，再生成结论和图表预览，最后整理成可汇报的结构。",
            planSteps: [
                .init(title: "读取并整理数据结构", status: .completed),
                .init(title: "分析核心增长指标", status: .completed),
                .init(title: "生成可视化图表", status: .running),
                .init(title: "提炼关键结论", status: .waiting),
                .init(title: "输出汇报文档", status: .waiting)
            ],
            previewMetrics: [
                .init(title: "增长率", value: "23.4%", tint: ACColors.accentGreen),
                .init(title: "留存", value: "68.2%", tint: ACColors.accentBlue),
                .init(title: "转化", value: "18.7%", tint: ACColors.accentPurple),
                .init(title: "流失", value: "4.1%", tint: ACColors.accentOrange)
            ]
        ),
        .init(
            title: "整理竞品分析报告",
            subtitle: "昨天 · 已完成",
            stateTitle: "已完成",
            stateKind: .green,
            userMessage: "请整理一份竞品分析报告，重点比较功能、体验、定价和机会点。",
            agentReply: "已完成结构化整理，报告已拆分为功能对比、用户体验、商业模式和机会建议。",
            planSteps: [
                .init(title: "读取竞品资料", status: .completed),
                .init(title: "提炼功能差异", status: .completed),
                .init(title: "输出对比矩阵", status: .completed),
                .init(title: "生成建议摘要", status: .completed)
            ],
            previewMetrics: [
                .init(title: "功能差异", value: "12 项", tint: ACColors.accentBlue),
                .init(title: "体验问题", value: "4 项", tint: ACColors.accentOrange),
                .init(title: "机会点", value: "8 项", tint: ACColors.accentGreen)
            ]
        ),
        .init(
            title: "整理会议纪要",
            subtitle: "昨天 · 已完成",
            stateTitle: "已完成",
            stateKind: .green,
            userMessage: "把今天的会议纪要整理成可执行待办，并按优先级排序。",
            agentReply: "已提炼会议纪要和待办事项，正在准备保存到收集箱。",
            planSteps: [
                .init(title: "提取会议要点", status: .completed),
                .init(title: "生成待办清单", status: .completed),
                .init(title: "按优先级排序", status: .completed)
            ],
            previewMetrics: [
                .init(title: "待办", value: "6 项", tint: ACColors.accentGreen),
                .init(title: "决策", value: "3 项", tint: ACColors.accentBlue)
            ]
        ),
        .init(
            title: "设计调研问卷",
            subtitle: "昨天 · 已完成",
            stateTitle: "已完成",
            stateKind: .green,
            userMessage: "帮我设计一个用户调研问卷，重点围绕产品体验。",
            agentReply: "已生成 12 题问卷草稿，并按热身、核心体验和开放反馈分段。",
            planSteps: [
                .init(title: "分析调研目标", status: .completed),
                .init(title: "构造问题框架", status: .completed),
                .init(title: "生成问卷草稿", status: .completed)
            ],
            previewMetrics: [
                .init(title: "问题数", value: "12", tint: ACColors.accentPurple),
                .init(title: "开放题", value: "3", tint: ACColors.accentOrange)
            ]
        ),
        .init(
            title: "代码优化建议",
            subtitle: "05-07 · 待处理",
            stateTitle: "待处理",
            stateKind: .neutral,
            userMessage: "帮我优化这段代码，关注性能和可维护性。",
            agentReply: "等待你补充代码或文件上下文，我会基于实际内容给出优化建议。",
            planSteps: [
                .init(title: "收集上下文", status: .waiting),
                .init(title: "定位热点逻辑", status: .waiting),
                .init(title: "输出建议", status: .waiting)
            ],
            previewMetrics: [
                .init(title: "待分析", value: "3 段", tint: ACColors.accentBlue)
            ]
        ),
        .init(
            title: "翻译英文文档",
            subtitle: "05-06 · 已完成",
            stateTitle: "已完成",
            stateKind: .green,
            userMessage: "请帮我把这份英文说明翻译成中文，保持专业表达。",
            agentReply: "已完成初稿翻译，并保留了术语一致性和章节结构。",
            planSteps: [
                .init(title: "识别术语", status: .completed),
                .init(title: "完成翻译", status: .completed),
                .init(title: "检查一致性", status: .completed)
            ],
            previewMetrics: [
                .init(title: "章节", value: "8", tint: ACColors.accentGreen),
                .init(title: "术语", value: "24", tint: ACColors.accentBlue)
            ]
        )
    ]
}

private struct AgentPlanStep: Identifiable {
    enum Status {
        case completed
        case running
        case waiting
    }

    let id = UUID()
    let title: String
    let status: Status
}

private struct AgentPreviewMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tint: Color
}

private struct AgentConversationRow: View {
    let conversation: AgentConversation
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ACTypeIcon("bubble.left.and.bubble.right.fill", tint: isSelected ? ACColors.accentBlue : ACColors.secondaryText, background: isSelected ? ACColors.selectedFill : ACColors.softFill, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(conversation.subtitle.split(separator: "·").last.map(String.init) ?? "")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }

                Text(conversation.stateTitle)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(isSelected ? ACColors.selectedFill : ACColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(isSelected ? ACColors.accentBlue.opacity(0.35) : ACColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
    }
}

private struct AgentMessageBubble: View {
    let role: String
    let text: String
    let accent: Color
    let alignedToTrailing: Bool

    var body: some View {
        HStack {
            if alignedToTrailing { Spacer(minLength: 0) }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                    Text(role)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                }

                Text(text)
                    .font(ACTypography.body)
                    .foregroundStyle(ACColors.primaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: 520, alignment: .leading)
            .background(ACColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                    .stroke(ACColors.border, lineWidth: 1)
            )

            if !alignedToTrailing { Spacer(minLength: 0) }
        }
    }
}

private struct AgentPlanCard: View {
    let steps: [AgentPlanStep]

    var body: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("执行计划")
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Spacer(minLength: 0)
                    ACBadge("\(steps.count) 步", kind: .blue)
                }

                VStack(spacing: 8) {
                    ForEach(steps) { step in
                        HStack(spacing: 10) {
                            stepMarker(step.status)
                            Text(step.title)
                                .font(ACTypography.body)
                                .foregroundStyle(ACColors.primaryText)
                            Spacer(minLength: 0)
                        }
                        .frame(height: 28)
                    }
                }
            }
        }
    }

    private func stepMarker(_ status: AgentPlanStep.Status) -> some View {
        Group {
            switch status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ACColors.accentGreen)
            case .running:
                Circle()
                    .fill(ACColors.accentBlue)
                    .frame(width: 12, height: 12)
            case .waiting:
                Circle()
                    .fill(ACColors.tertiaryText)
                    .frame(width: 12, height: 12)
            }
        }
    }
}

private struct AgentResultPreviewCard: View {
    let items: [AgentPreviewMetric]

    var body: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("结果预览")
                    .font(ACTypography.cardTitle)
                    .foregroundStyle(ACColors.primaryText)

                HStack(spacing: 12) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(ACTypography.miniMedium)
                                .foregroundStyle(ACColors.secondaryText)
                            Text(item.value)
                                .font(ACTypography.sectionTitle)
                                .foregroundStyle(item.tint)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ACColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                                .stroke(ACColors.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}

private struct AgentInputComposerCard: View {
    @Binding var text: String

    var body: some View {
        ACCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: $text)
                    .font(ACTypography.body)
                    .foregroundStyle(ACColors.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(height: 56)
                    .background(ACColors.softFill, in: RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                            .stroke(ACColors.border, lineWidth: 1)
                    )

                HStack(spacing: 8) {
                    ACButton("语音输入", kind: .secondary) {}
                    ACButton("上传文件", kind: .secondary) {}
                    ACButton("调用工具", kind: .secondary) {}

                    Spacer(minLength: 0)

                    ACButton("发送", kind: .primary) {}
                }
            }
        }
        .frame(height: 116)
    }
}

private struct AgentSmallRow: View {
    let title: String
    let subtitle: String
    let status: AgentToolStatus

    var body: some View {
        HStack(spacing: 10) {
            ACTypeIcon(status.icon, tint: status.tint, background: status.tint.opacity(0.12), size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            ACBadge(status.title, kind: status.badge)
        }
        .padding(10)
        .background(ACColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}

private struct AgentReferenceRow: View {
    let file: AgentReferenceFile

    var body: some View {
        HStack(spacing: 10) {
            ACTypeIcon(file.symbol, tint: file.tint, background: file.tint.opacity(0.12), size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(1)
                Text(file.size)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(ACColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}

private struct AgentCapabilityRow: View {
    let title: String
    let subtitle: String
    let enabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
                Text(subtitle)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: .constant(enabled))
                .labelsHidden()
                .tint(ACColors.accentBlue)
                .allowsHitTesting(false)
        }
        .padding(10)
        .background(ACColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}

private enum AgentToolStatus {
    case completed
    case running
    case waiting

    var title: String {
        switch self {
        case .completed: return "完成"
        case .running: return "进行中"
        case .waiting: return "等待"
        }
    }

    var badge: ACBadge.Kind {
        switch self {
        case .completed: return .green
        case .running: return .blue
        case .waiting: return .neutral
        }
    }

    var tint: Color {
        switch self {
        case .completed: return ACColors.accentGreen
        case .running: return ACColors.accentBlue
        case .waiting: return ACColors.tertiaryText
        }
    }

    var icon: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .running: return "sparkles"
        case .waiting: return "clock"
        }
    }
}

private struct AgentToolCall: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let status: AgentToolStatus
}

private struct AgentReferenceFile: Identifiable {
    let id = UUID()
    let name: String
    let size: String
    let symbol: String
    let tint: Color
}

private let toolCalls: [AgentToolCall] = [
    .init(title: "数据读取", detail: "读取产品数据表", status: .completed),
    .init(title: "数据清洗", detail: "清洗缺失值与异常点", status: .completed),
    .init(title: "数据分析", detail: "生成增长结论", status: .running),
    .init(title: "图表生成", detail: "输出可视化预览", status: .waiting)
]

private let referenceFiles: [AgentReferenceFile] = [
    .init(name: "产品增长数据_2025Q2.csv", size: "2.3 MB", symbol: "doc.text", tint: ACColors.accentBlue),
    .init(name: "渠道数据统计.xlsx", size: "1.1 MB", symbol: "tablecells", tint: ACColors.accentGreen),
    .init(name: "用户行为分析报告.pdf", size: "3.6 MB", symbol: "doc.richtext", tint: ACColors.accentRed)
]
