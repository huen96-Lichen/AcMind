import SwiftUI
import AcMindKit

struct NotchV2AgentPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

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
            NotchV2Card(title: "Agent 输入", subtitle: "输入中心", symbol: "sparkles") {
                VStack(alignment: .leading, spacing: 8) {
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

                    Text(viewModel.activeModelLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text("Fn 说入法 / 文本输入")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)

                    inputPreview

                    HStack(spacing: 6) {
                        NotchV2StatusPill(icon: "mic.fill", title: "说入法", accent: NotchV2DesignTokens.cardBackgroundStrong) {
                            viewModel.showVoicePanel()
                        }
                        NotchV2StatusPill(icon: "arrow.up.circle.fill", title: "执行", accent: NotchV2DesignTokens.accentPurple) {
                            viewModel.showAgent()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("最近状态")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                        ForEach(recentStatusItems.prefix(3), id: \.self) { item in
                            statusBullet(item)
                        }
                    }
                }
            }

            NotchV2Card(title: "模型", subtitle: "当前能力", symbol: "cpu") {
                VStack(alignment: .leading, spacing: 6) {
                    modelRow(label: "模型", value: viewModel.activeModelLabel)
                    modelRow(label: "状态", value: "本地可用")
                    modelRow(label: "用途", value: viewModel.isModuleEnabled(.music) ? "音乐模块已启用" : "音乐模块未启用")
                }
            }
        }
    }

    private var centerColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "最近任务", subtitle: "执行反馈", symbol: "list.bullet.rectangle") {
                VStack(alignment: .leading, spacing: 8) {
                    taskCard(
                        title: "编排音乐联动",
                        state: "等待下一条指令",
                        source: "音乐模块",
                        priority: "普通"
                    )

                    taskCard(
                        title: "清洗最近转写",
                        state: lastTranscriptionText,
                        source: "说入法",
                        priority: "自动"
                    )

                    HStack(spacing: 6) {
                        NotchV2StatusPill(title: "继续", accent: NotchV2DesignTokens.accentPurple)
                        NotchV2StatusPill(title: "查看日志", accent: NotchV2DesignTokens.cardBackgroundStrong)
                    }
                }
            }

            NotchV2Card(title: "当前任务", subtitle: "焦点信息", symbol: "target") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前焦点")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                    Text(currentTaskText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    Text(currentTaskDetailText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "工具状态", subtitle: "可用能力", symbol: "wrench.and.screwdriver", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(spacing: 6) {
                    ForEach(toolItems, id: \.0) { item in
                        toolRow(title: item.0, state: item.1, accent: item.2)
                    }
                }
            }

            NotchV2Card(title: "权限状态", subtitle: "异常优先", symbol: "shield.lefthalf.filled", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(spacing: 6) {
                    permissionRow(label: "麦克风", status: viewModel.microphonePermissionStatus.displayName, accent: permissionAccent(for: viewModel.microphonePermissionStatus))
                    permissionRow(label: "录屏", status: viewModel.screenRecordingPermissionStatus.displayName, accent: permissionAccent(for: viewModel.screenRecordingPermissionStatus))
                    permissionRow(label: "辅助功能", status: viewModel.accessibilityPermissionStatus.displayName, accent: permissionAccent(for: viewModel.accessibilityPermissionStatus))
                }
            }
        }
    }

    private var currentTaskText: String {
        if let text = viewModel.lastTranscription?.text, text.isEmpty == false {
            return "最近输入已记录"
        }
        return "等待下一条指令"
    }

    private var currentTaskDetailText: String {
        if let transcription = viewModel.lastTranscription {
            return "最近转写 · \(formatDate(transcription.timestamp))"
        }
        return "输入框保持轻量，只保留说入法与执行两个核心动作。"
    }

    private var lastTranscriptionText: String {
        if let text = viewModel.lastTranscription?.text, text.isEmpty == false {
            return text
        }
        return "暂无最近转写"
    }

    private var recentStatusItems: [String] {
        [
            viewModel.activeModelLabel,
            viewModel.isVoiceRecording ? "说入法正在收音" : "说入法待命",
            viewModel.isCapturing ? "截图处理中" : "截图待命",
            viewModel.isVoiceProcessing ? "文稿清洗中" : "文稿待命"
        ]
    }

    private var toolItems: [(String, String, Color)] {
        [
            ("截图", viewModel.isCapturing ? "处理中" : "可用", viewModel.isCapturing ? .orange : NotchV2DesignTokens.accentGreen),
            ("语音", viewModel.isVoiceRecording ? "收音中" : "可用", viewModel.isVoiceRecording ? .red : NotchV2DesignTokens.accentGreen),
            ("Markdown", "可用", NotchV2DesignTokens.accentGreen),
            ("模型", viewModel.activeModelLabel, NotchV2DesignTokens.accentGreen)
        ]
    }

    private var inputPreview: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(NotchV2DesignTokens.innerCardActive)
            .frame(height: 42)
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.lastTranscription?.text ?? "输入一个指令...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(viewModel.lastTranscription == nil ? NotchV2DesignTokens.weakText : NotchV2DesignTokens.primaryText)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    Text("保持输入框轻量，便于快速执行。")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
            )
    }

    private func statusBullet(_ text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(NotchV2DesignTokens.accentPurple)
                .frame(width: 4, height: 4)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }

    private func modelRow(label: String, value: String) -> some View {
        HStack {
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

    private func taskCard(title: String, state: String, source: String, priority: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("状态：\(state)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            HStack(spacing: 10) {
                Text("来源：\(source)")
                    .lineLimit(1)
                Text("优先级：\(priority)")
                    .lineLimit(1)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(NotchV2DesignTokens.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.88))
        )
    }

    private func toolRow(title: String, state: String, accent: Color) -> some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 5, height: 5)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(state)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
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

    private func permissionRow(label: String, status: String, accent: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(status)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
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

    private func permissionAccent(for status: AppPermissionStatus) -> Color {
        switch status {
        case .authorized:
            return NotchV2DesignTokens.accentGreen
        case .denied, .restricted, .needsSystemSettings:
            return .orange
        case .failed:
            return .red
        case .requesting:
            return .blue
        case .notDetermined, .unknown:
            return NotchV2DesignTokens.secondaryText
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
