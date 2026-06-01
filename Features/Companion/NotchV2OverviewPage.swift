import SwiftUI
import AppKit

struct NotchV2OverviewPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    @StateObject private var scheduleViewModel = ScheduleViewModel()

    var body: some View {
        NotchV2DashboardLayout(leftColumnWidth: 208, rightColumnWidth: 232) {
            leftColumn
        } centerColumn: {
            centerColumn
        } rightColumn: {
            rightColumn
        }
    }

    private var leftColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            if viewModel.isOverviewModuleVisible(.schedule) {
                NotchV2Card(title: "今日日程", subtitle: todayTitle, symbol: "calendar") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(scheduleSummaryItems.isEmpty ? "今天暂无日程" : "最近 3 条")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(NotchV2DesignTokens.primaryText)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(scheduleSummaryItems.isEmpty ? "轻量空状态" : "\(scheduleSummaryItems.count) 条")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                                .lineLimit(1)
                        }

                        scheduleBody

                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .semibold))
                            Text("只保留摘要与下一步提示。")
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }
                }
            }

            NotchV2Card(title: "上下文", subtitle: "当前页面", symbol: "sparkles") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.overviewContextMetrics) { metric in
                        metricRow(label: metric.label, value: metric.value)
                    }
                }
            }
        }
    }

    private var centerColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            if viewModel.isOverviewModuleVisible(.music) {
                NotchV2Card(title: "媒体摘要", subtitle: "当前播放", symbol: "music.note") {
                    VStack(alignment: .leading, spacing: 10) {
                    if viewModel.playbackState.title.isEmpty {
                        mediaEmptyState
                    } else {
                            HStack(alignment: .center, spacing: 14) {
                                MusicCoverView(artworkData: viewModel.playbackState.artwork)
                                    .frame(width: 80, height: 80)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(titleText)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    Text("\(artistText) · \(albumText)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    progressRow

                                    HStack(spacing: 10) {
                                        playbackButton(systemName: "backward.fill", size: 36) {
                                            viewModel.previousTrack()
                                        }

                                        playbackButton(systemName: viewModel.playbackState.isPlaying ? "pause.fill" : "play.fill", size: 44, isPrimary: true) {
                                            viewModel.playPause()
                                        }

                                        playbackButton(systemName: "forward.fill", size: 36) {
                                            viewModel.nextTrack()
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }

            NotchV2Card(title: "快捷动作", subtitle: "一键入口", symbol: "bolt.fill") {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(viewModel.quickActions) { action in
                        NotchV2ActionButton(
                            icon: action.icon,
                            title: action.title,
                            isSelected: false,
                            action: action.action
                        )
                    }
                }
            }

            NotchV2Card(
                title: viewModel.activeRuntimeSurface.title,
                subtitle: viewModel.activeRuntimeSurface.subtitle,
                symbol: viewModel.activeRuntimeSurface.symbol
            ) {
                activeRuntimeSurfaceBody
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "Agent 状态", subtitle: "执行中心", symbol: "sparkles", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.overviewAgentStatusRows) { row in
                        statusRow(
                            icon: row.icon ?? "circle.fill",
                            title: row.title,
                            value: row.value,
                            accent: row.accent
                        )
                    }
                }
            }

            if viewModel.isOverviewModuleVisible(.systemStatus) {
                NotchV2Card(title: "辅助状态", subtitle: "异常优先", symbol: "waveform.path.ecg", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.overviewSystemStatusRows) { row in
                            compactStateRow(
                                title: row.title,
                                value: row.value,
                                accent: row.accent
                            )
                        }
                    }
                }
            }
        }
    }

    private var titleText: String {
        viewModel.playbackState.title.isEmpty ? "未播放" : viewModel.playbackState.title
    }

    private var artistText: String {
        viewModel.playbackState.artist.isEmpty ? "未知艺术家" : viewModel.playbackState.artist
    }

    private var albumText: String {
        viewModel.playbackState.album.isEmpty ? "未知专辑" : viewModel.playbackState.album
    }

    private var lastTaskText: String {
        if let transcription = viewModel.lastTranscription?.text, transcription.isEmpty == false {
            return transcription
        }
        return "等待下一条指令"
    }

    private var lastTaskDetailText: String {
        if let transcription = viewModel.lastTranscription {
            return "最近转写 · \(formatDate(transcription.timestamp))"
        }
        return "当前输入会直接落入当前焦点或进入收集区。"
    }

    @ViewBuilder
    private var activeRuntimeSurfaceBody: some View {
        switch viewModel.activeRuntimeSurface.kind {
        case .voice:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.activeRuntimeSurface.accentColor)
                        .frame(width: 7, height: 7)
                    Text(viewModel.voiceSurfaceState.displayTitle ?? "说入法")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                    Spacer(minLength: 0)
                }
                Text(viewModel.voiceSurfaceState.displaySubtitle ?? "等待输入")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(2)
                Text("当前输入会直接落入当前焦点或进入收集区。")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
            }
        case .screenshot:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                    Text("截图处理中")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                    Spacer(minLength: 0)
                }
                Text("系统会在完成后自动恢复灵动大陆。")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(2)
                Text("当前正在截取当前屏幕。")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
            }
        case .music:
            VStack(alignment: .leading, spacing: 6) {
                Text(titleText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(2)
                Text("\(artistText) · \(albumText)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                progressRow
            }
        case .systemStatus:
            VStack(alignment: .leading, spacing: 6) {
                compactStateRow(
                    title: "电池",
                    value: viewModel.batteryStateText,
                    accent: viewModel.batteryAccent
                )
                compactStateRow(
                    title: "麦克风",
                    value: viewModel.microphonePermissionStatus.displayName,
                    accent: viewModel.microphonePermissionStatus == .authorized ? NotchV2DesignTokens.accentGreen : .orange
                )
                compactStateRow(
                    title: "录屏",
                    value: viewModel.screenRecordingPermissionStatus.displayName,
                    accent: viewModel.screenRecordingPermissionStatus == .authorized ? NotchV2DesignTokens.accentGreen : .orange
                )
            }
        case .schedule:
            scheduleBody
        case .agent, .idle:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.status.color)
                        .frame(width: 7, height: 7)
                    Text(viewModel.status.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                Text(lastTaskText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Text(lastTaskDetailText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func compactStateRow(title: String, value: String, accent: Color) -> some View {
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

    private func statusRow(icon: String, title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 14)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 11, weight: .semibold))
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

    private var progressValue: Double {
        guard viewModel.playbackState.duration > 0 else { return 0 }
        return max(0, min(1, viewModel.playbackState.currentTime / viewModel.playbackState.duration))
    }

    private var progressRow: some View {
        HStack(spacing: 10) {
            Text(formatTime(viewModel.playbackState.currentTime))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(NotchV2DesignTokens.innerCardBackground)
                    Capsule(style: .continuous)
                        .fill(NotchV2DesignTokens.accentPurple)
                        .frame(width: proxy.size.width * progressValue)
                }
            }
            .frame(height: 4)

            Text(formatTime(viewModel.playbackState.duration))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
        }
    }

    private var mediaEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "music.note.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
            Text("当前没有播放内容")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
            Text("有内容时显示封面、标题、艺术家和进度。")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    }

    private func playbackButton(systemName: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isPrimary ? 16 : 13, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : NotchV2DesignTokens.primaryText)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isPrimary ? NotchV2DesignTokens.accentPurple : NotchV2DesignTokens.innerCardBackground)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isPrimary ? 0.08 : 0.04), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var currentClockText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var scheduleSummaryItems: [NotchV2ScheduleSummaryItem] {
        let events = scheduleViewModel.todayEvents.filter { $0.status != .cancelled }
        guard events.isEmpty == false else { return [] }

        let now = Date()
        let currentEvent = events.first(where: { $0.startAt <= now && $0.endAt > now })
        let nextEvent = events.first(where: { $0.startAt > now })
        let allDayEvent = events.first(where: { $0.isAllDay })

        var items: [NotchV2ScheduleSummaryItem] = []
        if let currentEvent {
            items.append(.init(kind: .current, event: currentEvent))
        }
        if let nextEvent, items.count < 3 {
            items.append(.init(kind: .next, event: nextEvent))
        }
        if let allDayEvent, items.count < 3 {
            items.append(.init(kind: .allDay, event: allDayEvent))
        }

        if items.isEmpty {
            return Array(events.prefix(3)).enumerated().map { index, event in
                NotchV2ScheduleSummaryItem(
                    kind: index == 0 ? .current : index == 1 ? .next : .allDay,
                    event: event
                )
            }
        }

        return Array(items.prefix(3))
    }

    private var todayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return "今天 \(formatter.string(from: Date()))"
    }

    @ViewBuilder
    private var scheduleBody: some View {
        if scheduleSummaryItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("今天暂无日程")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                Text("只保留轻摘要，等有事件再提醒你。")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(scheduleSummaryItems) { item in
                    scheduleRow(time: item.timeLabel, title: item.title, subtitle: item.subtitle, accent: item.accent)
                }
            }
        }
    }

    private func scheduleRow(time: String, title: String, subtitle: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(time)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 40, alignment: .leading)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(subtitle)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, 46)
        }
        .frame(height: 38, alignment: .topLeading)
    }
}

private struct NotchV2ScheduleSummaryItem: Identifiable {
    enum Kind {
        case current
        case next
        case allDay

        var label: String {
            switch self {
            case .current: return "当前"
            case .next: return "下一"
            case .allDay: return "全天"
            }
        }

        var accent: Color {
            switch self {
            case .current: return NotchV2DesignTokens.accentPurple
            case .next: return NotchV2DesignTokens.accentGreen
            case .allDay: return NotchV2DesignTokens.secondaryText
            }
        }
    }

    let kind: Kind
    let event: ScheduleEvent

    var id: String { "\(kind.label)-\(event.id)" }

    var title: String { event.title }

    var subtitle: String {
        if event.isAllDay {
            return "全天事件"
        }
        return "\(kind.label)事件"
    }

    var accent: Color { kind.accent }

    var timeLabel: String {
        if event.isAllDay {
            return "全天"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.startAt)
    }
}

private struct MusicCoverView: View {
    let artworkData: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(NotchV2DesignTokens.accentPurple)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(NotchV2DesignTokens.innerBorder.opacity(0.6), lineWidth: 1)
                )

            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
