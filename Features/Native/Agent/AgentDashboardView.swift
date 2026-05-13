import SwiftUI
import AcMindKit

struct AgentDashboardView: View {
    @StateObject private var viewModel = AgentViewModel()

    var body: some View {
        ZStack {
            AppSurfaceTokens.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    topStatusRail
                    mainGrid
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .task {
            await viewModel.loadRecentItems()
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Agent")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text("任务输入、执行反馈、工具入口和最近任务")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()

            HStack(spacing: 10) {
                StatusPill(label: viewModel.isLoading ? "忙碌" : "待命", color: viewModel.isLoading ? .orange : AppSurfaceTokens.accentGreen)
                StatusPill(label: viewModel.recordingStatus.displayName, color: recordingColor(for: viewModel.recordingStatus))
            }
        }
    }

    private var topStatusRail: some View {
        HStack(spacing: 20) {
            AppSurfaceCard(title: "当前模型", subtitle: "正在响应的核心引擎") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GPT-5.5 Thinking")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    Text("⌘ Space 语音输入 · 工具调用预留")
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .font(.system(size: 13, weight: .medium))
                }
            }

            AppSurfaceCard(title: "系统状态", subtitle: "工具链与反馈循环") {
                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(label: "音频", value: "在线", color: AppSurfaceTokens.accentGreen)
                    StatusRow(label: "截图", value: "可用", color: AppSurfaceTokens.accentPurple)
                    StatusRow(label: "任务", value: viewModel.isLoading ? "运行中" : "等待指令", color: viewModel.isLoading ? AppSurfaceTokens.accentPurple : AppSurfaceTokens.secondaryText)
                }
            }

            AppSurfaceCard(title: "快捷指令", subtitle: "最常用的三步") {
                HStack(spacing: 10) {
                    ShortcutChip(title: "语音", icon: "mic.fill", action: { Task { await viewModel.toggleRecording() } })
                    ShortcutChip(title: "整理", icon: "sparkles", action: { Task { await viewModel.distill() } })
                    ShortcutChip(title: "保存", icon: "tray.and.arrow.down", action: { Task { await viewModel.saveToInbox() } })
                }
            }
        }
    }

    private var mainGrid: some View {
        HStack(alignment: .top, spacing: 20) {
            leftColumn
                .frame(width: 260)

            centerColumn
                .frame(maxWidth: .infinity)

            rightColumn
                .frame(width: 240)
        }
    }

    private var leftColumn: some View {
        VStack(spacing: 20) {
            AppSurfaceCard(title: "最近任务", subtitle: "输入与整理记录") {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.recentItems.isEmpty {
                        Text("暂无最近任务")
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    } else {
                        ForEach(viewModel.recentItems.prefix(5), id: \.id) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title ?? item.previewText ?? "未命名")
                                    .foregroundStyle(AppSurfaceTokens.primaryText)
                                    .lineLimit(1)
                                Text(item.status.displayName)
                                    .foregroundStyle(AppSurfaceTokens.tertiaryText)
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                    }
                }
            }

            AppSurfaceCard(title: "工具入口", subtitle: "任务编排入口") {
                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(label: "语音", value: viewModel.recordingStatus == .recording ? "录制中" : "待命", color: viewModel.recordingStatus == .recording ? .red : AppSurfaceTokens.accentGreen)
                    StatusRow(label: "截图", value: "可用", color: AppSurfaceTokens.accentPurple)
                    StatusRow(label: "反馈", value: viewModel.lastTranscript?.isEmpty == false ? "已收到" : "等待", color: AppSurfaceTokens.secondaryText)
                }
            }
        }
    }

    private var centerColumn: some View {
        VStack(spacing: 20) {
            AppSurfaceCard(title: "任务输入", subtitle: "可以直接开始说话或输入") {
                VStack(alignment: .leading, spacing: 14) {
                    TextEditor(text: $viewModel.inputText)
                        .frame(minHeight: 130)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppSurfaceTokens.cardBackgroundSoft))
                        .foregroundStyle(AppSurfaceTokens.primaryText)

                    HStack(spacing: 12) {
                        Button {
                            Task { await viewModel.toggleRecording() }
                        } label: {
                            Label(viewModel.recordingStatus == .recording ? "停止录音" : "语音输入", systemImage: "mic.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task { await viewModel.distill() }
                        } label: {
                            Label("AI 整理", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppSurfaceTokens.accentPurple)

                        Button {
                            Task { await viewModel.saveToInbox() }
                        } label: {
                            Label("保存到收集箱", systemImage: "tray.and.arrow.down")
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }
            }

            AppSurfaceCard(title: "执行反馈", subtitle: "当前任务与状态循环") {
                VStack(alignment: .leading, spacing: 12) {
                    if let note = viewModel.distilledNote {
                        Text(note.title ?? "整理完成")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                        Text(note.summary ?? "")
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .lineLimit(3)
                    } else {
                        Text("等待输入任务后生成执行反馈")
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }

                    if let transcript = viewModel.lastTranscript {
                        StatusRow(label: "最近转写", value: String(transcript.prefix(26)), color: AppSurfaceTokens.accentPurple)
                    }
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: 20) {
            AppSurfaceCard(title: "在线 Agent", subtitle: "Hermes-like 待命区") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Circle().fill(AppSurfaceTokens.accentGreen).frame(width: 8, height: 8)
                        Text("Agent · 在线")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    Text("待命 · 可接收指令")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    Text("工具调用、反馈循环、任务编排和状态播报会在这里接入。")
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .font(.system(size: 13, weight: .medium))
                }
            }

            AppSurfaceCard(title: "能力预留", subtitle: "未来可接入的工具") {
                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(label: "任务编排", value: "预留", color: AppSurfaceTokens.accentPurple)
                    StatusRow(label: "文件工具", value: "预留", color: AppSurfaceTokens.accentPurple)
                    StatusRow(label: "模型切换", value: "预留", color: AppSurfaceTokens.accentPurple)
                }
            }
        }
    }
}

private struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(AppSurfaceTokens.cardBackgroundStrong)
        )
    }
}

private struct StatusRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Spacer()
            Text(value)
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .font(.system(size: 13, weight: .medium))
    }
}

private struct ShortcutChip: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.accentPurple)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
        }
        .buttonStyle(.plain)
    }
}

private func recordingColor(for status: RecordingStatus) -> Color {
    switch status {
    case .idle:
        return AppSurfaceTokens.secondaryText
    case .recording:
        return .red
    case .processing:
        return AppSurfaceTokens.accentPurple
    case .error:
        return .red
    }
}
