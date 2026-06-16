import SwiftUI

struct SchedulePlanningSnapshotCard: View {
    let viewModel: ScheduleViewModel
    let snapshot: SchedulePlanningSnapshot

    var body: some View {
        AppSurfaceCard(
            title: "规划摘要",
            subtitle: snapshot.selectedDateLabel,
            padding: 16
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前时间")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)

                        Text(snapshot.currentTimeLabel)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppSurfaceTokens.primaryText)

                        Text(snapshot.currentEvent.map { "正在进行：\($0.title)" } ?? "当前没有进行中的任务")
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        planningMetric(
                            label: "下一件",
                            value: snapshot.nextEvent?.title ?? "暂无",
                            subtitle: snapshot.nextEvent.map { $0.displayTimeRange() } ?? "今天没有后续安排"
                        )

                        planningMetric(
                            label: "空闲窗口",
                            value: snapshot.freeWindow.map { scheduleFreeWindowTitle(for: $0) } ?? "未找到",
                            subtitle: snapshot.freeWindow.map { "\($0.durationMinutes) 分钟" } ?? "今天暂时没有满足条件的空窗"
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 8) {
                    StatusBadge(text: "总计 \(snapshot.totalEventCount)", tone: .neutral, compact: true)
                    StatusBadge(text: "进行中 \(snapshot.activeEventCount)", tone: .info, compact: true)
                    StatusBadge(text: "全天 \(snapshot.allDayEventCount)", tone: .success, compact: true)
                    StatusBadge(text: "逾期 \(snapshot.overdueEventCount)", tone: snapshot.overdueEventCount > 0 ? .warning : .neutral, compact: true)
                }

                if let conflict = snapshot.conflict {
                    planningAlertRow(
                        title: "冲突",
                        detail: "\(conflict.first.title) 与 \(conflict.second.title) 时间重叠",
                        tone: .danger
                    )
                } else {
                    planningAlertRow(
                        title: "冲突",
                        detail: "未发现明显时间重叠",
                        tone: .success
                    )
                }
            }
        }
    }

    private func planningMetric(label: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
    }

    private func planningAlertRow(title: String, detail: String, tone: StatusBadgeTone) -> some View {
        HStack(alignment: .top, spacing: 10) {
            StatusBadge(text: title, tone: tone, compact: true)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
    }

    private func scheduleFreeWindowTitle(for window: ScheduleFreeWindow) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: window.start)) - \(formatter.string(from: window.end))"
    }
}

struct ScheduleEventCompactRow: View {
    let event: ScheduleEvent
    let categoryName: String
    let categoryColor: Color
    let referenceDate: Date
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    StatusBadge(text: event.timingState(referenceDate: referenceDate).displayName, tone: badgeTone(for: event.timingState(referenceDate: referenceDate)), compact: true)
                }

                HStack(spacing: 6) {
                    StatusBadge(
                        text: event.displayTimeRange(),
                        tone: event.isAllDay ? .info : .neutral,
                        compact: true
                    )

                    if let tag = event.tag, tag.isEmpty == false {
                        StatusBadge(text: tag, tone: .neutral, compact: true)
                    }

                    Text(categoryName)
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .contextMenu {
            if let onEdit {
                Button("编辑", action: onEdit)
            }

            if let onDelete {
                Button("删除", role: .destructive, action: onDelete)
            }
        }
    }

    private var borderColor: Color {
        switch event.timingState(referenceDate: referenceDate) {
        case .ongoing:
            return AppSurfaceTokens.accentBlue.opacity(0.28)
        case .overdue:
            return Color.red.opacity(0.28)
        case .done:
            return AppSurfaceTokens.accentGreen.opacity(0.24)
        case .cancelled:
            return AppSurfaceTokens.separator.opacity(0.6)
        case .allDay, .upcoming:
            return AppSurfaceTokens.separator.opacity(0.7)
        }
    }

    private func badgeTone(for state: ScheduleEventTimingState) -> StatusBadgeTone {
        switch state {
        case .ongoing:
            return .info
        case .upcoming:
            return .neutral
        case .overdue:
            return .warning
        case .allDay:
            return .success
        case .done:
            return .success
        case .cancelled:
            return .unavailable
        }
    }
}
