import SwiftUI
import AppKit

struct NotchV2OverviewPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            schedulePanel
                .position(x: 134, y: 183)

            musicPanel
                .position(x: 428, y: 65)

            shortcutPanel
                .position(x: 428, y: 181)

            taskPanel
                .position(x: 428, y: 299)

            agentPanel
                .position(x: 732, y: 183)
        }
        .frame(width: NotchV2DesignTokens.expandedWidth, height: 392, alignment: .topLeading)
    }

    private var schedulePanel: some View {
        panelShell(width: 160, height: 354) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("日程")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                    Text("今天 5月21日 星期二")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }
                .frame(width: 136, height: 42, alignment: .topLeading)
                .position(x: 80, y: 37)

                ZStack(alignment: .topLeading) {
                    scheduleRow(time: "09:00", title: "产品设计评审")
                        .position(x: 68, y: 22)

                    scheduleRow(time: "11:00", title: "需求沟通同步")
                        .position(x: 68, y: 86)

                    scheduleRow(time: "16:30", title: "音乐联动评估")
                        .position(x: 68, y: 150)

                    scheduleRow(time: "18:30", title: "健身锻炼")
                        .position(x: 68, y: 214)
                }
                .frame(width: 136, height: 236, alignment: .topLeading)
                .position(x: 80, y: 194)

                HStack(spacing: 4) {
                    Text("查看全部")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }
                .frame(width: 108, height: 20, alignment: .leading)
                .position(x: 92, y: 320)
            }
        }
    }

    private var musicPanel: some View {
        panelShell(width: 396, height: 118) {
            ZStack(alignment: .topLeading) {
                MusicCoverView(artworkData: viewModel.playbackState.artwork)
                    .frame(width: 66, height: 66)
                    .position(x: 53, y: 59)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.playbackState.title.isEmpty ? "未播放" : viewModel.playbackState.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                    Text("\(artistLabel) · \(albumLabel)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text("已暂停")
                        Text("·")
                        Text("0:00")
                    }
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .padding(.top, 2)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(NotchV2DesignTokens.innerCardBackground)
                            Capsule(style: .continuous)
                                .fill(NotchV2DesignTokens.accentPurple)
                                .frame(width: proxy.size.width * 0.18)
                        }
                    }
                    .frame(width: 154, height: 3)
                }
                .frame(width: 166, height: 70, alignment: .topLeading)
                .position(x: 189, y: 59)

                ZStack(alignment: .topLeading) {
                    controlButton(systemName: "backward.fill", size: 26) {
                        viewModel.previousTrack()
                    }
                    .position(x: 13, y: 22)

                    controlButton(systemName: viewModel.playbackState.isPlaying ? "pause.fill" : "play.fill", size: 40, isPrimary: true) {
                        viewModel.playPause()
                    }
                    .position(x: 50, y: 22)

                    controlButton(systemName: "forward.fill", size: 26) {
                        viewModel.nextTrack()
                    }
                    .position(x: 87, y: 22)
                }
                .frame(width: 100, height: 44, alignment: .topLeading)
                .position(x: 330, y: 58)
            }
        }
    }

    private var shortcutPanel: some View {
        panelShell(width: 396, height: 82) {
            ZStack(alignment: .topLeading) {
                shortcutTile(
                    icon: viewModel.quickActions[safe: 0]?.icon ?? "camera.viewfinder",
                    title: "截图",
                    subtitle: "Capture"
                )
                .frame(width: 68, height: 60)
                .position(x: 46, y: 41)

                shortcutTile(
                    icon: viewModel.quickActions[safe: 1]?.icon ?? "doc.text",
                    title: "MD",
                    subtitle: "Markdown"
                )
                .frame(width: 68, height: 60)
                .position(x: 122, y: 41)

                shortcutTile(
                    icon: viewModel.quickActions[safe: 2]?.icon ?? "pin",
                    title: "Pin",
                    subtitle: "Pin"
                )
                .frame(width: 68, height: 60)
                .position(x: 198, y: 41)

                shortcutTile(
                    icon: viewModel.quickActions[safe: 3]?.icon ?? "waveform",
                    title: "SRPT",
                    subtitle: "Speech"
                )
                .frame(width: 68, height: 60)
                .position(x: 274, y: 41)

                shortcutTile(
                    icon: "ellipsis",
                    title: "更多",
                    subtitle: "More"
                )
                .frame(width: 68, height: 60)
                .position(x: 350, y: 41)
            }
        }
    }

    private var taskPanel: some View {
        panelShell(width: 396, height: 122) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 8) {
                    Text("任务 · 2")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                    Text("当前焦点")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }
                .frame(width: 116, height: 20, alignment: .leading)
                .position(x: 74, y: 24)

                taskRow(
                    time: "16:30",
                    title: "音乐联动评估",
                    state: "即将开始",
                    accent: NotchV2DesignTokens.accentPurple
                )
                .frame(width: 364, height: 28, alignment: .leading)
                .position(x: 198, y: 58)

                taskRow(
                    time: "11:00",
                    title: "需求沟通同步",
                    state: "已完成",
                    accent: NotchV2DesignTokens.secondaryText
                )
                .frame(width: 364, height: 28, alignment: .leading)
                .position(x: 198, y: 98)
            }
        }
    }

    private var agentPanel: some View {
        panelShell(width: 180, height: 354) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Agent")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                        Text("在线")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }
                }
                .frame(width: 156, height: 40, alignment: .leading)
                .position(x: 90, y: 36)

                statusCard
                    .frame(width: 156, height: 58, alignment: .leading)
                    .position(x: 90, y: 103)

                modelCard
                    .frame(width: 156, height: 72, alignment: .leading)
                    .position(x: 90, y: 186)

                recentStatusCard
                    .frame(width: 156, height: 48, alignment: .leading)
                    .position(x: 90, y: 264)

                inputCard
                    .frame(width: 156, height: 24, alignment: .leading)
                    .position(x: 90, y: 326)
            }
        }
    }

    private func statusLine(_ title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(NotchV2DesignTokens.accentPurple)
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
            Spacer()
        }
    }

    private var statusCard: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(NotchV2DesignTokens.innerCardBackground)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(NotchV2DesignTokens.accentGreen)
                            .frame(width: 7, height: 7)
                        Text("待命 · 可接收指令")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                    }
                    Text("⌘ Space 语音 / 文本输入")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
            )
    }

    private var modelCard: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(NotchV2DesignTokens.innerCardBackground)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    Text("GPT-5.5 Thinking")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                    Text("本地模型可用")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    Text("可处理音乐联动")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
            )
    }

    private var recentStatusCard: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(NotchV2DesignTokens.innerCardBackground)
            .overlay(
                VStack(alignment: .leading, spacing: 7) {
                    Text("最近状态")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    VStack(alignment: .leading, spacing: 6) {
                        statusLine("等待音乐联动")
                        statusLine("本地模型可用")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
            )
    }

    private var inputCard: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(NotchV2DesignTokens.innerCardBackground)
            .overlay(
                Text("Input + Mic + Send")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            )
    }

    private func scheduleRow(time: String, title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(time)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.accentPurple)
                .frame(width: 44, alignment: .leading)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: 44, alignment: .center)
    }

    private func taskRow(time: String, title: String, state: String, accent: Color) -> some View {
        HStack(spacing: 32) {
            Text(time)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.accentPurple)
                .frame(width: 44, alignment: .leading)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
            Spacer()
            Text(state)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardActive)
        )
    }

    private func controlButton(systemName: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isPrimary ? 15 : 10, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : NotchV2DesignTokens.primaryText)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isPrimary ? NotchV2DesignTokens.accentPurple : NotchV2DesignTokens.cardBackgroundStrong)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isPrimary ? 0.08 : 0.04), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func statusBlock(title: String, subtitle: String?, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
            }
        }
    }

    private func shortcutTile(icon: String, title: String, subtitle: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(NotchV2DesignTokens.innerBorder, lineWidth: 1)
                )

            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.accentPurple)

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func panelShell<Content: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: width, height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NotchV2DesignTokens.panelBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(NotchV2DesignTokens.panelBorder, lineWidth: 1)
                    )
            )
    }

    private var artistLabel: String {
        viewModel.playbackState.artist.isEmpty ? "未知艺术家" : viewModel.playbackState.artist
    }

    private var albumLabel: String {
        viewModel.playbackState.album.isEmpty ? "未知专辑" : viewModel.playbackState.album
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
