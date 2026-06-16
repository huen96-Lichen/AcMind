import SwiftUI

enum ToolWorkspaceStage: String, CaseIterable, Identifiable {
    case selection
    case configuration
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selection: return "选择工具"
        case .configuration: return "配置运行"
        case .review: return "查看结果"
        }
    }

    var subtitle: String {
        switch self {
        case .selection: return "筛选、定位并打开一个真实工具"
        case .configuration: return "输入参数、选择目录，然后开始执行"
        case .review: return "复制结果、打开文件，或者继续交给 Agent"
        }
    }

    var icon: String {
        switch self {
        case .selection: return "square.grid.2x2"
        case .configuration: return "slider.horizontal.3"
        case .review: return "tray.full"
        }
    }

    var tint: Color {
        switch self {
        case .selection: return AppSurfaceTokens.accentBlue
        case .configuration: return AppSurfaceTokens.accentOrange
        case .review: return AppSurfaceTokens.accentGreen
        }
    }
}

struct ToolWorkspaceStageRail: View {
    let activeStage: ToolWorkspaceStage
    let selectionSummary: String
    let configurationSummary: String
    let reviewSummary: String

    var body: some View {
        AppSurfaceCard(title: "工具工作流", subtitle: "把选择、运行、结果分开看", padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(ToolWorkspaceStage.allCases) { stage in
                    toolStageRow(
                        stage: stage,
                        isActive: stage == activeStage,
                        detail: detail(for: stage)
                    )
                }
            }
        }
    }

    private func detail(for stage: ToolWorkspaceStage) -> String {
        switch stage {
        case .selection: return selectionSummary
        case .configuration: return configurationSummary
        case .review: return reviewSummary
        }
    }

    private func toolStageRow(stage: ToolWorkspaceStage, isActive: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(isActive ? stage.tint.opacity(0.16) : AppSurfaceTokens.cardBackground)
                Image(systemName: stage.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? stage.tint : AppSurfaceTokens.secondaryText)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(stage.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(isActive ? stage.tint.opacity(0.08) : AppSurfaceTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(isActive ? stage.tint.opacity(0.24) : AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
        )
    }
}

struct ToolStageHeader: View {
    let title: String
    let subtitle: String
    let stage: ToolWorkspaceStage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                    .fill(stage.tint.opacity(0.14))
                Image(systemName: stage.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(stage.tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer(minLength: 0)
            StatusBadge(text: stage.title, tone: .info, compact: true)
        }
    }
}
