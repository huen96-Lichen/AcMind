import Foundation
import AppKit
import SwiftUI
import AcMindKit

enum AgentActionMode: String, CaseIterable, Identifiable {
    case auto
    case chat
    case task
    case search
    case schedule
    case note

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "智能判断"
        case .chat: return "普通对话"
        case .task: return "创建任务"
        case .search: return "搜索信息"
        case .schedule: return "安排日程"
        case .note: return "记笔记"
        }
    }

    var suggestedPrompt: String {
        switch self {
        case .auto, .chat:
            return "帮我把这段内容整理成可执行的回复。"
        case .task:
            return "把这段话转成待办任务，并拆成步骤。"
        case .search:
            return "帮我搜索相关信息，并提炼成要点。"
        case .schedule:
            return "帮我把这段话安排成日程。"
        case .note:
            return "把这段内容记成一条笔记。"
        }
    }

    static var quickActions: [AgentActionMode] {
        [.task, .search, .schedule, .note]
    }
}

struct AgentProjectFolder: Identifiable {
    let id: String
    var name: String
    var subtitle: String
    var icon: String
    var tint: Color
    var order: Int
    var isSystem: Bool
    var sessionCount: Int = 0

    static let systemFolders: [AgentProjectFolder] = [
        .init(id: "all", name: "全部", subtitle: "所有对话", icon: "tray.full", tint: ACColors.accentBlue, order: 0, isSystem: true),
        .init(id: "task", name: "任务", subtitle: "待办与执行", icon: "checklist", tint: ACColors.accentGreen, order: 1, isSystem: true),
        .init(id: "research", name: "研究", subtitle: "搜索与分析", icon: "magnifyingglass", tint: ACColors.accentPurple, order: 2, isSystem: true),
        .init(id: "schedule", name: "日程", subtitle: "时间安排", icon: "calendar", tint: ACColors.accentOrange, order: 3, isSystem: true),
        .init(id: "notes", name: "笔记", subtitle: "记录与蒸馏", icon: "note.text", tint: ACColors.accentBlue, order: 4, isSystem: true)
    ]
}

struct AgentSessionSummary: Identifiable {
    let id: String
    let title: String
    let folderID: String
    let folderName: String
    let folder: AgentProjectFolder
    let preview: String
    let messageCount: Int
    let createdAt: Date
    let updatedAt: Date
    let timeLabel: String
    let icon: String
    let tint: Color
}

struct AgentRecentSessionSection: Identifiable {
    enum Kind: String, CaseIterable {
        case today
        case yesterday
        case thisWeek
        case thisMonth
        case earlier

        static var displayOrder: [Kind] { [.today, .yesterday, .thisWeek, .thisMonth, .earlier] }

        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .yesterday: return "moon.stars.fill"
            case .thisWeek: return "calendar"
            case .thisMonth: return "calendar.badge.clock"
            case .earlier: return "clock.arrow.circlepath"
            }
        }

        var tint: Color {
            switch self {
            case .today: return ACColors.accentBlue
            case .yesterday: return ACColors.accentPurple
            case .thisWeek: return ACColors.accentGreen
            case .thisMonth: return ACColors.accentOrange
            case .earlier: return ACColors.secondaryText
            }
        }

        var title: String {
            switch self {
            case .today: return "今天"
            case .yesterday: return "昨天"
            case .thisWeek: return "本周"
            case .thisMonth: return "本月"
            case .earlier: return "更早"
            }
        }

        var subtitle: String {
            switch self {
            case .today: return "最近更新"
            case .yesterday: return "昨天的对话"
            case .thisWeek: return "本周内的对话"
            case .thisMonth: return "这个月的对话"
            case .earlier: return "更早之前"
            }
        }
    }

    let kind: Kind
    var title: String { kind.title }
    var subtitle: String { kind.subtitle }
    let sessions: [AgentSessionSummary]

    var id: String { kind.rawValue }
}

struct AgentRailPresentation {
    let width: CGFloat
    let collapsed: Bool
    let visible: Bool
}

enum AgentWorkspacePreferences {
    static let managementRailWidthKey = "AgentWorkspace.managementRailWidth"
    static let managementRailCollapsedKey = "AgentWorkspace.managementRailCollapsed"
    static let managementRailVisibleKey = "AgentWorkspace.managementRailVisible"
    static let defaultManagementRailWidth: Double = 232
}

enum AgentWorkspaceLayout {
    static let centerMinWidth: CGFloat = 540
    static let managementRailMinWidth: CGFloat = 204
    static let managementRailMaxWidth: CGFloat = 260
    static let managementRailCollapsedWidth: CGFloat = 50
    static let managementRailCollapsedTrigger: CGFloat = 84
    static let defaultManagementRailWidth: CGFloat = 232
    static let auxiliaryDrawerMaxWidth: CGFloat = 388
    static let compactLayoutThreshold: CGFloat = 1180
    static let autoCollapseThreshold: CGFloat = 1100
}

struct FolderRenameSheet: View {
    let folderName: String
    let isSystemFolder: Bool
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftName: String

    init(folderName: String, isSystemFolder: Bool, onConfirm: @escaping (String) -> Void) {
        self.folderName = folderName
        self.isSystemFolder = isSystemFolder
        self.onConfirm = onConfirm
        self._draftName = State(initialValue: folderName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("重命名文件夹")
                .font(ACTypography.cardTitle)
                .foregroundStyle(ACColors.primaryText)

            Text(isSystemFolder ? "系统文件夹不可重命名。" : "输入新名称后保存，会同步到该文件夹下的所有会话。")
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
                .lineSpacing(2)

            TextField("文件夹名称", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .disabled(isSystemFolder)

            HStack {
                Button("取消") {
                    dismiss()
                }

                Spacer(minLength: 0)

                Button("保存") {
                    onConfirm(draftName)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSystemFolder || draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

struct AgentToolChainStep: Identifiable {
    enum State: String, Hashable {
        case done
        case running
        case waiting
        case failed
    }

    let id = UUID()
    let title: String
    let detail: String
    let state: State
    let accent: Color
}

struct AgentResultSummaryItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tint: Color
}

struct AgentExecutionEntry: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let state: AgentToolChainStep.State
    let accent: Color
    let timestamp: Date
}

struct AgentExecutionResult {
    let title: String
    let detail: String
    let reply: String
    let toolChain: [AgentToolChainStep]
    let summaryItems: [AgentResultSummaryItem]
    let statusLabel: String
    let statusKind: ACBadge.Kind
    let executionState: AgentToolChainStep.State
}

struct ScheduleDraft {
    let title: String
    let date: Date
    let hour: Int
    let minute: Int
    let duration: Int
}

struct WebSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let url: String
}

struct AgentQuickAskStrip: View {
    @Binding var draft: String
    let title: String
    let subtitle: String
    let primaryActionTitle: String
    let secondaryActionTitle: String
    let suggestions: [AgentActionMode]
    let onSend: () -> Void
    let onDismiss: () -> Void

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                    Text(subtitle)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                }

                Spacer(minLength: 0)

                Button(secondaryActionTitle, action: onDismiss)
                    .buttonStyle(.plain)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }

            HStack(spacing: 5) {
                ForEach(suggestions) { mode in
                    Button {
                        draft = mode.suggestedPrompt
                    } label: {
                        Text(mode.displayName)
                            .font(ACTypography.mini)
                            .foregroundStyle(ACColors.primaryText)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ACColors.softFill.opacity(0.68))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(ACColors.border.opacity(0.6), lineWidth: 1)
                    )
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ACColors.secondaryText)

                    TextField("输入一句话，直接进入现有 Agent 路由", text: $draft)
                        .font(ACTypography.caption)
                        .textFieldStyle(.plain)
                        .foregroundStyle(ACColors.primaryText)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(ACColors.softFill.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ACColors.border.opacity(0.75), lineWidth: 1)
                )

                Button(action: onSend) {
                    HStack(spacing: 5) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(primaryActionTitle)
                            .font(ACTypography.mini)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(ACColors.accentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(SendButtonHoverStyle())
                .disabled(trimmedDraft.isEmpty)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ACColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}

struct AgentMessageRow: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }
    private var isSystem: Bool { message.role == .system }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 0) }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isUser ? ACColors.accentPurple : (isSystem ? ACColors.secondaryText : ACColors.accentBlue))
                        .frame(width: 4, height: 4)
                    Text(roleLabel)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.primaryText)
                    Spacer(minLength: 0)
                    Text(message.createdAt.formattedAgentTime)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }

                Text(message.content)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.primaryText)
                    .lineSpacing(0.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: 500, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isUser ? ACColors.selectedFill.opacity(0.32) : ACColors.softFill.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isUser ? ACColors.accentPurple.opacity(0.08) : ACColors.border.opacity(0.32), lineWidth: 1)
            )

            if !isUser { Spacer(minLength: 0) }
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .system: return "系统"
        case .user: return "你"
        case .assistant: return "Agent"
        case .tool: return "工具"
        }
    }
}

struct ToolChainRow: View {
    let step: AgentToolChainStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(step.accent)
                .frame(width: 7, height: 7)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(step.title)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.primaryText)
                    Spacer(minLength: 0)
                    Text(statusText)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                }
                Text(step.detail)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ACColors.softFill)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var statusText: String {
        switch step.state {
        case .done: return "完成"
        case .running: return "进行中"
        case .waiting: return "等待"
        case .failed: return "失败"
        }
    }
}

struct ResultSummaryRow: View {
    let item: AgentResultSummaryItem

    var body: some View {
        HStack {
            Text(item.title)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
            Spacer(minLength: 0)
            Text(item.value)
                .font(ACTypography.caption)
                .foregroundStyle(item.tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ACColors.softFill)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

extension Date {
    var formattedAgentTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}
