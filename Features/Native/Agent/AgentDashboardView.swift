import SwiftUI
import AcMindKit

struct AgentDashboardView: View {
    @StateObject private var viewModel = AgentViewModel()
    @State private var selectedSidebarItem: String? = "normal"
    @State private var showRightPanel = true

    private var sidebarSections: [SecondarySidebarSection] {
        [
            SecondarySidebarSection(
                id: "mode",
                title: "对话模式",
                items: [
                    SecondarySidebarItem(id: "normal", title: "普通对话", icon: "bubble.left"),
                    SecondarySidebarItem(id: "task", title: "任务执行", icon: "play.circle"),
                    SecondarySidebarItem(id: "quickAsk", title: "Quick Ask", icon: "questionmark.circle"),
                    SecondarySidebarItem(id: "toolCall", title: "工具调用", icon: "wrench"),
                    SecondarySidebarItem(id: "automation", title: "自动化", icon: "arrow.triangle.2.circlepath", isComingSoon: true)
                ]
            ),
            SecondarySidebarSection(
                id: "recent",
                title: "最近对话",
                items: [
                    SecondarySidebarItem(id: "conv1", title: "AcMind UI 优化讨论", icon: "bubble.left", badge: "今天"),
                    SecondarySidebarItem(id: "conv2", title: "代码审查任务", icon: "bubble.left", badge: "昨天"),
                    SecondarySidebarItem(id: "conv3", title: "文档整理", icon: "bubble.left")
                ]
            ),
            SecondarySidebarSection(
                id: "context",
                title: "项目上下文",
                items: [
                    SecondarySidebarItem(id: "acmind", title: "AcMind", icon: "folder"),
                    SecondarySidebarItem(id: "pinmind", title: "PinMind", icon: "folder"),
                    SecondarySidebarItem(id: "obsidian", title: "Obsidian Vault", icon: "folder"),
                    SecondarySidebarItem(id: "default", title: "默认工作区", icon: "folder")
                ]
            )
        ]
    }

    var body: some View {
        HSplitView {
            SecondarySidebarWithHeader(
                title: "Agent",
                subtitle: "对话与任务执行",
                sections: sidebarSections,
                selectedItem: $selectedSidebarItem
            )
            .frame(width: 240)

            mainContent

            if showRightPanel {
                rightPanel
                    .frame(width: 280)
            }
        }
        .background(AppSurfaceTokens.background.ignoresSafeArea())
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .task {
            await viewModel.loadRecentItems()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    messageStream
                    executionFeedback
                }
                .padding(20)
                .frame(maxWidth: 780, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            Divider()

            composerBar
                .padding(16)
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("普通对话")
                    .font(.system(size: 17, weight: .semibold))
                Text("AcMind · 默认工作区")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                StatusPill(label: viewModel.isLoading ? "忙碌" : "待命", color: viewModel.isLoading ? .orange : AppSurfaceTokens.accentGreen)

                StatusPill(label: viewModel.recordingStatus.displayName, color: recordingColor(for: viewModel.recordingStatus))

                Menu {
                    Button("GPT-5.5 Thinking") {}
                    Button("Claude 4 Opus") {}
                    Button("本地模型") {}
                } label: {
                    HStack(spacing: 4) {
                        Text("GPT-5.5")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppSurfaceTokens.cardBackgroundSoft))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button(action: { showRightPanel.toggle() }) {
                    Image(systemName: showRightPanel ? "sidebar.right" : "sidebar.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var messageStream: some View {
        VStack(alignment: .leading, spacing: 16) {
            MessageBubble(isUser: false, content: "你好！我是 AcMind Agent，有什么可以帮你的吗？")

            if let transcript = viewModel.lastTranscript, !transcript.isEmpty {
                MessageBubble(isUser: true, content: transcript)
            }

            if let note = viewModel.distilledNote {
                MessageBubble(isUser: false, content: note.summary ?? "整理完成")
            }
        }
    }

    private var executionFeedback: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在处理...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppSurfaceTokens.cardBackgroundSoft))
            }
        }
    }

    private var composerBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: { Task { await viewModel.toggleRecording() } }) {
                    Image(systemName: viewModel.recordingStatus == .recording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(viewModel.recordingStatus == .recording ? .red : .secondary)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "wrench")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 36, maxHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppSurfaceTokens.cardBackgroundSoft))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )

                Button(action: { Task { await viewModel.distill() } }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppSurfaceTokens.accentPurple)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.isEmpty)
            }
        }
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("任务面板")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { showRightPanel = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    taskSection(title: "执行中的任务", items: viewModel.isLoading ? ["正在处理输入..."] : [])
                    recentTasksSection
                    quickActionsSection
                }
                .padding(16)
            }
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private func taskSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if items.isEmpty {
                Text("暂无任务")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppSurfaceTokens.cardBackgroundSoft))
            } else {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(item)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppSurfaceTokens.cardBackgroundSoft))
                }
            }
        }
    }

    private var recentTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近任务")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(viewModel.recentItems.prefix(5), id: \.id) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title ?? item.previewText ?? "未命名")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(item.status.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppSurfaceTokens.cardBackgroundSoft))
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷功能")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                quickActionRow(icon: "sparkles", title: "AI 整理", action: { Task { await viewModel.distill() } })
                quickActionRow(icon: "tray.and.arrow.down", title: "保存到收集箱", action: { Task { await viewModel.saveToInbox() } })
                quickActionRow(icon: "doc.on.clipboard", title: "复制结果", action: {})
            }
        }
    }

    private func quickActionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(AppSurfaceTokens.cardBackgroundSoft))
        }
        .buttonStyle(.plain)
    }
}

struct MessageBubble: View {
    let isUser: Bool
    let content: String

    var body: some View {
        HStack {
            if isUser { Spacer() }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(content)
                    .font(.system(size: 13))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isUser ? Color.accentColor.opacity(0.15) : AppSurfaceTokens.cardBackgroundSoft)
                    )

                Text(isUser ? "你" : "Agent")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if !isUser { Spacer() }
        }
    }
}

private struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.1)))
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
