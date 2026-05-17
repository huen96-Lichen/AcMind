import SwiftUI
import AppKit

struct NotchV2OverviewPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        NotchThreeColumnLayout(
            left: { scheduleColumn },
            center: {
                VStack(alignment: .leading, spacing: NotchV2DesignTokens.cardSpacing) {
                    musicCard
                        .frame(height: 116)

                    shortcutCard
                        .frame(height: 82)

                    taskCard
                        .frame(height: 116)
                }
            },
            right: { agentColumn }
        )
        .frame(width: NotchV2DesignTokens.expandedWidth, height: 392, alignment: .topLeading)
    }

    private var scheduleColumn: some View {
        NotchV2Card(title: "日程", subtitle: "今天 5月21日 星期二", symbol: "calendar", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(scheduleRows, id: \.time) { row in
                    NotchV2CompactTimelineRow(time: row.time, title: row.title)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Text("查看全部")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }
            }
        }
        .frame(width: 160, height: 354, alignment: .topLeading)
    }

    private var musicCard: some View {
        NotchV2Card(title: titleText, subtitle: "\(artistLabel) · \(albumLabel)", symbol: "music.note", padding: 16) {
            HStack(alignment: .center, spacing: 12) {
                MusicCoverView(artworkData: viewModel.playbackState.artwork)
                    .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(viewModel.playbackState.isPlaying ? "播放中" : "已暂停")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                        Text("·")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        Text("0:00")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }

                    progressBar(progress: 0.18)
                        .frame(height: 4)

                    HStack(spacing: 8) {
                        smallPlaybackButton(systemName: "backward.fill") {
                            viewModel.previousTrack()
                        }

                        smallPlaybackButton(systemName: viewModel.playbackState.isPlaying ? "pause.fill" : "play.fill", primary: true) {
                            viewModel.playPause()
                        }

                        smallPlaybackButton(systemName: "forward.fill") {
                            viewModel.nextTrack()
                        }
                    }
                }
            }
        }
        .frame(width: 396, height: 118, alignment: .topLeading)
    }

    private var shortcutCard: some View {
        NotchV2Card(title: "快捷入口", subtitle: "Capture / Markdown / Pin / Speech", symbol: "bolt.circle", padding: 16) {
            HStack(spacing: 10) {
                ForEach(shortcutEntries) { item in
                    NotchV2QuickActionTile(icon: item.icon, title: item.title, subtitle: item.subtitle)
                }
            }
        }
        .frame(width: 396, height: 82, alignment: .topLeading)
    }

    private var taskCard: some View {
        NotchV2Card(title: "任务 · 2", subtitle: "当前焦点", symbol: "checklist", padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                NotchV2TaskRow(
                    time: "16:30",
                    title: "音乐联动评估",
                    state: "即将开始",
                    accent: NotchV2DesignTokens.accentPurple
                )

                NotchV2TaskRow(
                    time: "11:00",
                    title: "需求沟通同步",
                    state: "已完成",
                    accent: NotchV2DesignTokens.secondaryText
                )
            }
        }
        .frame(width: 396, height: 122, alignment: .topLeading)
    }

    private var agentColumn: some View {
        NotchV2Card(title: "Agent", subtitle: "在线", symbol: "bubble.left.and.bubble.right", padding: 16, fillHeight: true) {
            VStack(alignment: .leading, spacing: 10) {
                NotchV2StatusCard(
                    title: "待命 · 可接收指令",
                    subtitle: "⌘ Space 语音 / 文本输入",
                    accent: NotchV2DesignTokens.accentGreen
                )
                .frame(height: 72)

                NotchV2StatusCard(
                    title: "GPT-5.5 Thinking",
                    subtitle: "本地模型可用",
                    detail: "可处理音乐联动",
                    accent: NotchV2DesignTokens.accentPurple
                )
                .frame(height: 76)

                NotchV2Card(title: "最近状态", subtitle: nil, symbol: nil, padding: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(["等待音乐联动", "本地模型可用"], id: \.self) { item in
                            NotchV2StatusLine(title: item)
                        }
                    }
                }
                .frame(height: 86)

                NotchV2InputHintBar(text: "Input + Mic + Send")
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

    private var shortcutEntries: [NotchV2QuickActionEntry] {
        [
            .init(icon: quickActionIcon(at: 0, fallback: "camera.viewfinder"), title: "截图", subtitle: "Capture"),
            .init(icon: quickActionIcon(at: 1, fallback: "doc.text"), title: "MD", subtitle: "Markdown"),
            .init(icon: quickActionIcon(at: 2, fallback: "pin"), title: "Pin", subtitle: "Pin"),
            .init(icon: quickActionIcon(at: 3, fallback: "waveform"), title: "SRPT", subtitle: "Speech"),
            .init(icon: "ellipsis", title: "更多", subtitle: "More")
        ]
    }

    private var artistLabel: String {
        viewModel.playbackState.artist.isEmpty ? "未知艺术家" : viewModel.playbackState.artist
    }

    private var albumLabel: String {
        viewModel.playbackState.album.isEmpty ? "未知专辑" : viewModel.playbackState.album
    }

    private var titleText: String {
        viewModel.playbackState.title.isEmpty ? "未播放" : viewModel.playbackState.title
    }

    private func quickActionIcon(at index: Int, fallback: String) -> String {
        guard viewModel.quickActions.indices.contains(index) else { return fallback }
        return viewModel.quickActions[index].icon
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(NotchV2DesignTokens.innerCardBackground)
                Capsule(style: .continuous)
                    .fill(NotchV2DesignTokens.accentPurple)
                    .frame(width: proxy.size.width * progress)
            }
        }
    }

    private func smallPlaybackButton(systemName: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: primary ? 12 : 10, weight: .semibold))
                .foregroundStyle(primary ? .white : NotchV2DesignTokens.primaryText)
                .frame(width: primary ? 32 : 26, height: primary ? 32 : 26)
                .background(
                    Circle()
                        .fill(primary ? NotchV2DesignTokens.accentPurple : NotchV2DesignTokens.cardBackgroundStrong)
                )
        }
        .buttonStyle(.plain)
    }
}

struct NotchV2CompactTimelineRow: View {
    let time: String
    let title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(time)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.accentPurple)
                .frame(width: 42, alignment: .leading)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardActive)
        )
    }
}

private struct NotchV2TaskRow: View {
    let time: String
    let title: String
    let state: String
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(time)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.accentPurple)
                .frame(width: 42, alignment: .leading)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(state)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardActive)
        )
    }
}

private struct NotchV2QuickActionEntry: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

private struct NotchV2QuickActionTile: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(NotchV2DesignTokens.innerCardBackground)
                    .frame(height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.accentPurple)
            }

            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)

            Text(subtitle)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NotchV2StatusCard: View {
    let title: String
    let subtitle: String
    let detail: String?
    let accent: Color

    init(title: String, subtitle: String, detail: String? = nil, accent: Color) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.accent = accent
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(NotchV2DesignTokens.innerCardBackground)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(accent)
                            .frame(width: 7, height: 7)
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                    }

                    Text(subtitle)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)

                    if let detail {
                        Text(detail)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
            )
    }
}

private struct NotchV2InputHintBar: View {
    let text: String

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(NotchV2DesignTokens.innerCardBackground)
            .overlay(
                HStack {
                    Text(text)
                        .font(.system(size: 8, weight: .regular))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
            )
            .frame(height: 32)
    }
}

private struct MusicCoverView: View {
    let artworkData: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NotchV2DesignTokens.accentPurple)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NotchV2DesignTokens.innerBorder.opacity(0.6), lineWidth: 1)
                )

            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
