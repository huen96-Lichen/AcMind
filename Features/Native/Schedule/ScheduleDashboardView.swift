import SwiftUI

enum ScheduleDashboardMode: String, CaseIterable, Identifiable {
    case day = "日"
    case week = "周"
    case month = "月"
    case year = "年"

    var id: String { rawValue }
}

struct ScheduleDashboardView: View {
    @State private var mode: ScheduleDashboardMode = .week
    @State private var selectedDayIndex: Int = 2

    var body: some View {
        ACWorkspaceShell(
            title: "日程",
            subtitle: "个人时间轴与日程管理，优先展示今日和本周。",
            trailing: {
                HStack(spacing: 12) {
                    ACSegmentedControl(ScheduleDashboardMode.allCases, selection: $mode) { option, isSelected in
                        Text(option.rawValue)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                    }
                    .frame(width: 232)

                    ACButton("今天", kind: .secondary) {}
                    ACButton("新建", kind: .primary) {}
                }
            },
            left: { leftSidebar },
            center: { centerSurface },
            right: { rightInspector }
        )
    }

    private var leftSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            ACCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日概览")
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                    ScheduleStatCard(title: "已安排", value: "6", subtitle: "项任务")
                    ScheduleStatCard(title: "专注", value: "4.5", subtitle: "小时")
                    ScheduleStatCard(title: "饱和度", value: "72%", subtitle: "偏满")
                }
            }
            .frame(height: 146, alignment: .topLeading)

            ACCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("分类")
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)

                    VStack(spacing: 8) {
                        ForEach(scheduleCategories) { category in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                Text(category.title)
                                    .font(ACTypography.captionMedium)
                                    .foregroundStyle(ACColors.primaryText)
                                Spacer(minLength: 0)
                                Text(category.count)
                                    .font(ACTypography.miniMedium)
                                    .foregroundStyle(ACColors.secondaryText)
                            }
                        }
                    }
                }
            }
            .frame(height: 204, alignment: .topLeading)

            ACCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("工作饱和度")
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                    VStack(spacing: 8) {
                        ForEach(weekHeatmap) { day in
                            HStack(spacing: 8) {
                                Text(day.label)
                                    .font(ACTypography.miniMedium)
                                    .foregroundStyle(ACColors.tertiaryText)
                                    .frame(width: 24, alignment: .leading)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(day.tint)
                                    .frame(height: 16)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
            .frame(height: 120, alignment: .topLeading)

            Spacer(minLength: 0)
        }
    }

    private var centerSurface: some View {
        ACDetailPanel(width: nil, padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode == .day ? "日视图" : mode == .week ? "周视图" : mode == .month ? "月视图" : "年视图")
                            .font(ACTypography.sectionTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("主时间轴是视觉中心，支持快速浏览与创建。")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    Spacer(minLength: 0)

                    ACBadge("可用", kind: .green)
                }

                switch mode {
                case .day:
                    dayView
                case .week:
                    weekView
                case .month:
                    monthView
                case .year:
                    yearView
                }
            }
        }
    }

    private var rightInspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            ACDetailPanel(width: ACLayout.inspectorWidth, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("下一事件")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("产品例会")
                            .font(ACTypography.itemTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("14:00 - 15:00")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                        Text("还有 32 分钟")
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.accentBlue)
                    }
                }
            }

            ACDetailPanel(width: ACLayout.inspectorWidth, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("日视图")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)

                    VStack(spacing: 8) {
                        ForEach(weekAgenda, id: \.id) { event in
                            HStack(spacing: 10) {
                                ACTypeIcon("calendar", tint: event.tint, background: event.tint.opacity(0.12), size: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(ACTypography.captionMedium)
                                        .foregroundStyle(ACColors.primaryText)
                                    Text(event.time)
                                        .font(ACTypography.mini)
                                        .foregroundStyle(ACColors.secondaryText)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }

            ACDetailPanel(width: ACLayout.inspectorWidth, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("热力信息")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(weekHeatmap) { info in
                            HStack(spacing: 10) {
                                Text(info.label)
                                    .font(ACTypography.captionMedium)
                                    .foregroundStyle(ACColors.secondaryText)
                                    .frame(width: 18, alignment: .leading)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(info.tint)
                                    .frame(height: 10)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var dayView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(dayTimeline) { slot in
                HStack(alignment: .top, spacing: 12) {
                    Text(slot.time)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.accentBlue)
                        .frame(width: 52, alignment: .leading)

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                            .fill(ACColors.softFill)
                            .frame(height: 40)

                        if let event = slot.event {
                            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                                .fill(event.tint.opacity(0.16))
                                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                                .overlay(
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.title)
                                                .font(ACTypography.captionMedium)
                                                .foregroundStyle(ACColors.primaryText)
                                            Text(event.subtitle)
                                                .font(ACTypography.mini)
                                                .foregroundStyle(ACColors.secondaryText)
                                        }
                                        Spacer(minLength: 0)
                                        ACBadge(event.badgeTitle, kind: event.badgeKind)
                                    }
                                    .padding(.horizontal, 12)
                                )
                        } else {
                            Text("双击添加日程")
                                .font(ACTypography.mini)
                                .foregroundStyle(ACColors.tertiaryText)
                                .padding(.horizontal, 12)
                        }
                    }
                }
            }
        }
    }

    private var weekView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(weekColumns) { column in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(column.day)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(column.isToday ? ACColors.accentBlue : ACColors.secondaryText)
                        RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                            .fill(column.tint)
                            .frame(height: column.height)
                        Text("\(column.count) 项")
                            .font(ACTypography.mini)
                            .foregroundStyle(ACColors.tertiaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(weekAgenda, id: \.id) { event in
                    HStack(spacing: 12) {
                        ACTypeIcon("calendar", tint: event.tint, background: event.tint.opacity(0.12), size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(ACColors.primaryText)
                            Text(event.subtitle)
                                .font(ACTypography.mini)
                                .foregroundStyle(ACColors.secondaryText)
                        }
                        Spacer(minLength: 0)
                        Text(event.time)
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }
                    .padding(10)
                    .background(ACColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                            .stroke(ACColors.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var monthView: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(monthGrid) { day in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.label)
                            .font(ACTypography.miniMedium)
                            .foregroundStyle(day.isCurrentMonth ? ACColors.primaryText : ACColors.tertiaryText)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(day.tint)
                            .frame(height: 22)
                    }
                    .padding(8)
        .background(Color.white.opacity(0.0))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
                }
            }
        }
    }

    private var yearView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(yearSummary) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.secondaryText)
                        Text(item.value)
                            .font(ACTypography.sectionTitle)
                            .foregroundStyle(ACColors.primaryText)
                    }
                    .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.0))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 14), spacing: 4) {
                ForEach(yearHeatmap) { cell in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(cell.tint)
                        .frame(height: 10)
                }
            }
        }
    }
}

private struct ScheduleCategorySummary: Identifiable {
    let id = UUID()
    let title: String
    let count: String
    let color: Color
}

private struct ScheduleHeatRow: Identifiable {
    let id = UUID()
    let label: String
    let tint: Color
}

private struct ScheduleTimelineSlot: Identifiable {
    let id = UUID()
    let time: String
    let event: ScheduleTimelineEvent?
}

private struct ScheduleTimelineEvent: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let time: String
    let tint: Color
    let badgeTitle: String
    let badgeKind: ACBadge.Kind
}

private struct ScheduleWeekColumn: Identifiable {
    let id = UUID()
    let day: String
    let count: Int
    let height: CGFloat
    let tint: Color
    let isToday: Bool
}

private struct ScheduleMonthDay: Identifiable {
    let id = UUID()
    let label: String
    let tint: Color
    let isCurrentMonth: Bool
}

private struct ScheduleYearSummary: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct ScheduleYearHeatCell: Identifiable {
    let id = UUID()
    let tint: Color
}

private struct ScheduleStatCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ACTypography.miniMedium)
                    .foregroundStyle(ACColors.secondaryText)
                Text("\(value) \(subtitle)")
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white.opacity(0.0))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}

private let scheduleCategories: [ScheduleCategorySummary] = [
    .init(title: "工作", count: "3", color: ACColors.accentBlue),
    .init(title: "会议", count: "2", color: ACColors.accentPurple),
    .init(title: "学习", count: "1", color: ACColors.accentGreen),
    .init(title: "生活", count: "2", color: ACColors.accentOrange)
]

private let weekHeatmap: [ScheduleHeatRow] = [
    .init(label: "M", tint: ACColors.accentBlue.opacity(0.72)),
    .init(label: "T", tint: ACColors.accentBlue.opacity(0.54)),
    .init(label: "W", tint: ACColors.accentBlue.opacity(0.82)),
    .init(label: "T", tint: ACColors.accentBlue.opacity(0.42)),
    .init(label: "F", tint: ACColors.accentBlue.opacity(0.66))
]

private let dayTimeline: [ScheduleTimelineSlot] = [
    .init(time: "09:00", event: nil),
    .init(time: "10:00", event: .init(title: "产品评审", subtitle: "会议 / 45 分钟", time: "10:00", tint: ACColors.accentBlue, badgeTitle: "会议", badgeKind: .blue)),
    .init(time: "11:00", event: .init(title: "需求同步", subtitle: "团队 / 30 分钟", time: "11:00", tint: ACColors.accentPurple, badgeTitle: "同步", badgeKind: .purple)),
    .init(time: "14:00", event: .init(title: "设计审查", subtitle: "视觉 / 60 分钟", time: "14:00", tint: ACColors.accentGreen, badgeTitle: "设计", badgeKind: .green)),
    .init(time: "16:00", event: nil),
    .init(time: "18:00", event: .init(title: "复盘总结", subtitle: "总结 / 30 分钟", time: "18:00", tint: ACColors.accentOrange, badgeTitle: "复盘", badgeKind: .orange))
]

private let weekColumns: [ScheduleWeekColumn] = [
    .init(day: "一", count: 3, height: 62, tint: ACColors.accentBlue.opacity(0.52), isToday: false),
    .init(day: "二", count: 5, height: 88, tint: ACColors.accentBlue.opacity(0.70), isToday: false),
    .init(day: "三", count: 4, height: 74, tint: ACColors.accentBlue.opacity(0.60), isToday: true),
    .init(day: "四", count: 2, height: 48, tint: ACColors.accentBlue.opacity(0.38), isToday: false),
    .init(day: "五", count: 6, height: 96, tint: ACColors.accentBlue.opacity(0.78), isToday: false),
    .init(day: "六", count: 1, height: 34, tint: ACColors.accentBlue.opacity(0.22), isToday: false),
    .init(day: "日", count: 0, height: 18, tint: ACColors.softFill, isToday: false)
]

private let weekAgenda: [ScheduleTimelineEvent] = [
    .init(title: "产品评审", subtitle: "周会 / 上午", time: "09:30", tint: ACColors.accentBlue, badgeTitle: "会议", badgeKind: .blue),
    .init(title: "需求同步", subtitle: "团队 / 中午", time: "11:00", tint: ACColors.accentPurple, badgeTitle: "同步", badgeKind: .purple),
    .init(title: "代码检查", subtitle: "工程 / 下午", time: "15:00", tint: ACColors.accentGreen, badgeTitle: "开发", badgeKind: .green)
]

private let monthGrid: [ScheduleMonthDay] = (1...28).map { day in
    .init(
        label: "\(day)",
        tint: [ACColors.accentBlue.opacity(0.15), ACColors.accentPurple.opacity(0.15), ACColors.accentGreen.opacity(0.15), ACColors.softFill].randomElement() ?? ACColors.softFill,
        isCurrentMonth: true
    )
}

private let yearSummary: [ScheduleYearSummary] = [
    .init(title: "活跃日", value: "218"),
    .init(title: "平均饱和度", value: "64%"),
    .init(title: "高峰周", value: "第 23 周")
]

private let yearHeatmap: [ScheduleYearHeatCell] = (0..<98).map { index in
    let palette: [Color] = [
        ACColors.softFill,
        ACColors.accentBlue.opacity(0.14),
        ACColors.accentBlue.opacity(0.28),
        ACColors.accentBlue.opacity(0.44)
    ]
    return .init(tint: palette[index % palette.count])
}
