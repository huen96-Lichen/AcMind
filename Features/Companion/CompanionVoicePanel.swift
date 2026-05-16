import SwiftUI
import AppKit
import AcMindKit

struct CompanionVoicePanel: View {
    @ObservedObject private var session = CompanionVoiceSessionController.shared

    var body: some View {
        ZStack {
            panelBackground

            VStack(spacing: 0) {
                header

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        heroBlock
                        liveResultBlock
                        footerBlock
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 560, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 30, x: 0, y: 18)
        .onAppear {
            session.startIfNeeded()
        }
        .onDisappear {
            session.closePanel()
        }
    }

    private var panelBackground: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color(acHex: "#F5F8FF"),
                Color(acHex: "#EFF3FF")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text("说入法")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ACColors.primaryText)

                    statusBadge
                }

                Text(session.actionSubtitle)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if session.phase == .recording {
                    Text(session.elapsedTimeFormatted)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(ACColors.accentRed)
                }

                Button {
                    session.closePanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ACColors.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(ACColors.softFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(session.statusHint)
                .font(ACTypography.badge)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(statusColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 999, style: .continuous))
    }

    private var statusColor: Color {
        switch session.phase {
        case .idle:
            return ACColors.secondaryText
        case .arming:
            return ACColors.accentBlue
        case .recording:
            return ACColors.accentRed
        case .processing:
            return ACColors.accentOrange
        case .completed:
            return ACColors.accentGreen
        case .error:
            return ACColors.accentRed
        }
    }

    private var iconName: String {
        switch session.phase {
        case .idle:
            return "mic.fill"
        case .arming:
            return "mic.badge.plus"
        case .recording:
            return "waveform"
        case .processing:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var heroBlock: some View {
        ACCard(padding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.14))
                            .frame(width: 96, height: 96)

                        Circle()
                            .fill(statusColor.opacity(0.24))
                            .frame(width: 72, height: 72)

                        Circle()
                            .fill(statusColor)
                            .frame(width: session.phase == .recording ? 36 : 30, height: session.phase == .recording ? 36 : 30)
                            .scaleEffect(session.phase == .recording ? 1.08 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                                value: session.phase == .recording
                            )

                        Image(systemName: iconName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.actionTitle)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(ACColors.primaryText)

                        Text(session.actionSubtitle)
                            .font(ACTypography.body)
                            .foregroundStyle(ACColors.secondaryText)
                            .lineSpacing(3)

                        HStack(spacing: 8) {
                            ACBadge("Fn 长按", kind: .blue)
                            ACBadge("松开自动转写", kind: .neutral)
                        }
                    }

                    Spacer(minLength: 0)
                }

                waveform

                HStack(spacing: 10) {
                    if session.phase == .idle || session.phase == .error || session.phase == .completed {
                        ACButton("开始录音", kind: .primary) {
                            session.beginManualRecording()
                        }
                    }

                    if session.phase == .recording || session.phase == .arming {
                        ACButton("结束并输入", kind: .secondary) {
                            session.finishRecording()
                        }
                    }

                    if session.phase == .processing {
                        ACButton("处理中", kind: .secondary) {
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 7) {
            ForEach(0..<18, id: \.self) { index in
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(statusColor.opacity(0.78))
                    .frame(width: 6, height: barHeight(for: index))
                    .scaleEffect(session.phase == .recording ? 1.08 : 0.95)
                    .animation(
                        .easeInOut(duration: 0.55 + Double(index % 3) * 0.08).repeatForever(autoreverses: true),
                        value: session.phase == .recording
                    )
            }
        }
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(ACColors.softFill.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func barHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [14, 24, 36, 18, 30, 16, 28, 22, 40, 20, 32, 16, 26, 18, 34, 22, 16, 28]
        let base = pattern[index % pattern.count]
        switch session.phase {
        case .recording:
            return base + 10
        case .processing:
            return base
        default:
            return base * 0.72
        }
    }

    private var liveResultBlock: some View {
        Group {
            if session.transcriptText.isEmpty == false || session.phase == .processing || session.phase == .completed || session.phase == .error {
                ACCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("转写结果")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(ACColors.primaryText)

                            Spacer(minLength: 0)

                            if session.transcriptText.isEmpty == false {
                                Button("复制") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(session.transcriptText, forType: .string)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(ACColors.accentBlue)
                            }
                        }

                        if session.phase == .processing {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .scaleEffect(0.9)
                                Text("正在把语音变成文字...")
                                    .font(ACTypography.body)
                                    .foregroundStyle(ACColors.secondaryText)
                            }
                        } else {
                            Text(session.transcriptText.isEmpty ? (session.errorMessage ?? "暂无结果") : session.transcriptText)
                                .font(ACTypography.body)
                                .foregroundStyle(session.phase == .error ? ACColors.accentRed : ACColors.primaryText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var footerBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            infoChip(title: "插入方式", value: "当前光标 / 选区替换")
            infoChip(title: "备选", value: "复制到剪贴板")
            infoChip(title: "权限", value: "麦克风 + 辅助功能")
        }
    }

    private func infoChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ACTypography.mini)
                .foregroundStyle(ACColors.secondaryText)
            Text(value)
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.primaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ACColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}
