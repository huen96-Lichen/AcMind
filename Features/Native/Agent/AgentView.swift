import SwiftUI
import AcMindKit

// MARK: - Agent View

/// Agent 主页面
/// 支持四种状态：loading / empty / error / ready
struct AgentView: View {
    @StateObject private var viewModel = AgentViewModel()

    var body: some View {
        ZStack {
            // 背景
            AppSurfaceTokens.background
                .ignoresSafeArea()

            // 状态切换
            Group {
                if viewModel.isLoading && viewModel.recentItems.isEmpty {
                    loadingState
                } else if let error = viewModel.errorMessage, viewModel.recentItems.isEmpty {
                    errorState(error)
                } else {
                    readyState
                }
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .onAppear {
            Task { await viewModel.loadRecentItems() }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("加载失败")
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("重试") {
                Task { await viewModel.loadRecentItems() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ready State

    private var readyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 欢迎区
                welcomeSection

                // 输入区
                inputSection

                // 快捷按钮
                actionButtons

                // AI 整理结果卡片
                if let note = viewModel.distilledNote {
                    distilledCard(note)
                }

                // 最近记录
                if viewModel.recentItems.isEmpty {
                    emptyRecentState
                } else {
                    recentSection
                }
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    // MARK: - Empty Recent State

    private var emptyRecentState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("暂无记录")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("在上方输入框记录你的想法，或点击「保存到收集箱」")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今天想记录什么？")
                .font(.system(size: 28, weight: .bold))
            Text("输入你的想法，保存到收集箱或让 AI 帮你整理。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $viewModel.inputText)
                    .font(.body)
                    .frame(minHeight: 100)
                    .padding(12)
                    .padding(.trailing, 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )

                // 说入法按钮
                VoiceInputButton(viewModel: viewModel)
                    .padding(8)
            }

            HStack {
                if viewModel.isSaved {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .transition(.opacity)
                }

                if let transcript = viewModel.lastTranscript {
                    Label("清洗: \(transcript.prefix(30))...", systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                Spacer()

                // 录音状态指示
                if viewModel.recordingStatus == .recording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("收音中 \(viewModel.recordingDuration, specifier: "%.0f")s")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } else if viewModel.recordingStatus == .processing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("处理中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { Task { await viewModel.saveToInbox() } }) {
                Label("保存到收集箱", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(action: { Task { await viewModel.distill() } }) {
                Label("AI 整理", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)

            Button(action: { viewModel.clear() }) {
                Label("清空", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.secondary)

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Distilled Card

    private func distilledCard(_ note: DistilledNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text("AI 整理结果")
                    .font(.headline)
                Spacer()
            }

            Text(note.title ?? "未命名")
                .font(.title3)
                .fontWeight(.semibold)

            Text(note.summary ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if !note.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(note.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            Divider()

            Text(note.contentMarkdown ?? "")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(10)
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Recent Section

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近记录")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("刷新") {
                    Task { await viewModel.loadRecentItems() }
                }
                .font(.caption)
                .buttonStyle(.plain)
            }

            ForEach(viewModel.recentItems) { item in
                RecentItemRow(item: item)
            }
        }
    }

    private func iconForType(_ type: SourceType) -> String {
        switch type {
        case .text: return "text.quote"
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .pdf: return "doc.text"
        case .docx: return "doc.text.fill"
        case .screenshot: return "camera"
        case .webpage: return "link"
        case .unknownFile: return "doc"
        }
    }
}

// MARK: - Recent Item Row

struct RecentItemRow: View {
    let item: SourceItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(item.type))
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? "未命名")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            AgentStatusBadge(status: item.status)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            Button("复制内容") {
                if let text = item.previewText ?? item.transcript {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
        }
    }

    private func iconForType(_ type: SourceType) -> String {
        switch type {
        case .text: return "text.quote"
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .pdf: return "doc.text"
        case .docx: return "doc.text.fill"
        case .screenshot: return "camera"
        case .webpage: return "link"
        case .unknownFile: return "doc"
        }
    }
}

// MARK: - Status Badge

struct AgentStatusBadge: View {
    let status: SourceItemStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .inbox: return Color.gray.opacity(0.15)
        case .pending: return Color.orange.opacity(0.2)
        case .capturing: return Color.blue.opacity(0.2)
        case .captured: return Color.gray.opacity(0.2)
        case .parsing: return Color.yellow.opacity(0.2)
        case .parsed: return Color.cyan.opacity(0.2)
        case .distilled: return Color.blue.opacity(0.2)
        case .distilling: return Color.purple.opacity(0.2)
        case .exporting: return Color.orange.opacity(0.16)
        case .exported: return Color.green.opacity(0.2)
        case .archived: return Color.purple.opacity(0.2)
        case .deleted: return Color.red.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .inbox: return .secondary
        case .pending: return .orange
        case .capturing: return .blue
        case .captured: return .secondary
        case .parsing: return .yellow
        case .parsed: return .cyan
        case .distilled: return .blue
        case .distilling: return .purple
        case .exporting: return .orange
        case .exported: return .green
        case .archived: return .purple
        case .deleted: return .red
        }
    }
}

// MARK: - Voice Input Button

struct VoiceInputButton: View {
    @ObservedObject var viewModel: AgentViewModel
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            Task {
                await viewModel.toggleRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(viewModel.recordingStatus == .recording ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: viewModel.recordingStatus == .recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(viewModel.recordingStatus == .recording ? .red : .accentColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .help(viewModel.recordingStatus == .recording ? "停止说入法" : "开始说入法")
    }
}
