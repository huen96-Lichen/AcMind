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
                    }
                    .padding(22)
                }
            }
        }
        .frame(width: 500, height: 540)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.50), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 14)
        .onAppear {
            session.startIfNeeded()
        }
        .onDisappear {
            session.closePanel()
        }
    }

    private var panelBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    Color(acHex: "#F7F9FC"),
                    Color(acHex: "#EEF3FF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    ACColors.accentBlue.opacity(0.14),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 280
            )
            .blendMode(.plusLighter)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("说入法")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ACColors.primaryText)

                    Text(session.actionTitle)
                        .font(ACTypography.badge)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text("按住 Fn 说话，松开后直接写入当前光标。")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if session.phase == .recording {
                    Text(session.elapsedTimeFormatted)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ACColors.accentRed)
                }

                Button {
                    session.closePanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ACColors.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(ACColors.softFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.14))
                            .frame(width: 84, height: 84)

                        Circle()
                            .fill(statusColor.opacity(0.24))
                            .frame(width: 60, height: 60)

                        Circle()
                            .fill(statusColor)
                            .frame(width: session.phase == .recording ? 30 : 26, height: session.phase == .recording ? 30 : 26)
                            .scaleEffect(session.phase == .recording ? 1.06 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                                value: session.phase == .recording
                            )

                        Image(systemName: iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.actionTitle)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(ACColors.primaryText)

                        Text(session.actionSubtitle)
                            .font(ACTypography.body)
                            .foregroundStyle(ACColors.secondaryText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            ACBadge("Fn 长按", kind: .blue)
                            ACBadge("直写光标", kind: .neutral)
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
        HStack(alignment: .center, spacing: 6) {
            ForEach(0..<18, id: \.self) { index in
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(statusColor.opacity(0.78))
                    .frame(width: 5, height: barHeight(for: index))
                    .scaleEffect(session.phase == .recording ? 1.08 : 0.95)
                    .animation(
                        .easeInOut(duration: 0.55 + Double(index % 3) * 0.08).repeatForever(autoreverses: true),
                        value: session.phase == .recording
                    )
            }
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(ACColors.softFill.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                ACCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("结果")
                                .font(.system(size: 15, weight: .semibold))
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
                                Text("正在转写")
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
}
