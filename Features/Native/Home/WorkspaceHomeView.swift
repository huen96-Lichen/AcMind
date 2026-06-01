import SwiftUI

struct WorkspaceHomeView: View {
    @EnvironmentObject private var appState: AppState

    private let actions: [WorkspaceAction] = [
        WorkspaceAction(
            title: "说入法",
            subtitle: "长按 Fn 唤起，说话后自动清洗成文稿。",
            icon: "mic.fill",
            accent: AppSurfaceTokens.accentBlue,
            kind: .voice
        ),
        WorkspaceAction(
            title: "快速采集",
            subtitle: "把截图和收集动作直接送进工作流。",
            icon: "camera.viewfinder",
            accent: AppSurfaceTokens.accentOrange,
            kind: .capture
        ),
        WorkspaceAction(
            title: "收集箱",
            subtitle: "查看最近内容，继续整理与提炼。",
            icon: "tray.full",
            accent: AppSurfaceTokens.accentGreen,
            kind: .inbox
        ),
        WorkspaceAction(
            title: "设置",
            subtitle: "进入单层设置页，调整常用偏好。",
            icon: "gearshape.fill",
            accent: AppSurfaceTokens.accentPurple,
            kind: .settings
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroBanner
                summaryRow
                quickActions
            }
            .padding(28)
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .background(homeBackground)
    }

    private var homeBackground: some View {
        ZStack {
            AppSurfaceTokens.background

            LinearGradient(
                colors: [
                    AppSurfaceTokens.accentBlue.opacity(0.10),
                    Color.clear,
                    AppSurfaceTokens.accentPurple.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)

            Circle()
                .fill(AppSurfaceTokens.accentBlue.opacity(0.08))
                .frame(width: 420, height: 420)
                .blur(radius: 70)
                .offset(x: -260, y: -180)

            Circle()
                .fill(AppSurfaceTokens.accentPurple.opacity(0.08))
                .frame(width: 360, height: 360)
                .blur(radius: 72)
                .offset(x: 340, y: 180)
        }
        .ignoresSafeArea()
    }

    private var heroBanner: some View {
        AppSurfaceCard(padding: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppSurfaceTokens.accentBlue.opacity(0.22),
                                        AppSurfaceTokens.accentPurple.opacity(0.20)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)

                        Image(systemName: "house.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("启动页")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .textCase(.uppercase)
                            .tracking(1.2)

                        Text("从这里开始，优先处理说入法、采集和整理")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("把最常用的入口收拢到一屏，让第一眼看到的是“下一步能做什么”，不是空白内容。")
                            .font(.system(size: 14))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    homeChip(label: appState.isAppReady ? "已就绪" : "初始化中", accent: appState.isAppReady ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange)
                    homeChip(label: windowStateText(appState.mainWindowState), accent: AppSurfaceTokens.accentBlue)
                    homeChip(label: windowStateText(appState.capsuleWindowState), accent: AppSurfaceTokens.accentPurple)
                }
            }
        }
    }

    private var summaryRow: some View {
        HStack(alignment: .top, spacing: 16) {
            AppSurfaceCard(title: "当前状态", subtitle: "轻量概览，不打断主流程") {
                VStack(alignment: .leading, spacing: 10) {
                    SummaryLine(label: "启动阶段", value: appState.initializationPhase.rawValue)
                    SummaryLine(label: "主窗口", value: windowStateText(appState.mainWindowState))
                    SummaryLine(label: "随身胶囊", value: windowStateText(appState.capsuleWindowState))
                }
            }

            AppSurfaceCard(title: "快速提示", subtitle: "今天最常用的动作") {
                VStack(alignment: .leading, spacing: 10) {
                    hintRow(icon: "mic.fill", label: "说入法", value: "长按 Fn，直接开始说话")
                    hintRow(icon: "camera.viewfinder", label: "快速采集", value: "截图与动作送进工作流")
                    hintRow(icon: "tray.full", label: "收集箱", value: "继续整理和提炼")
                }
            }
        }
    }

    private var quickActions: some View {
        AppSurfaceCard(title: "快速入口", subtitle: "把高频动作放在同一层级") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                ForEach(actions) { action in
                    Button {
                        action.perform(using: appState)
                    } label: {
                        ActionTile(action: action)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func windowStateText(_ state: WindowState) -> String {
        switch state {
        case .closed: return "已关闭"
        case .minimized: return "已最小化"
        case .normal: return "已打开"
        case .fullscreen: return "全屏"
        }
    }

    private func homeChip(label: String, accent: Color) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppSurfaceTokens.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
    }

    private func hintRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct WorkspaceAction: Identifiable {
    enum Kind {
        case voice
        case capture
        case inbox
        case settings

        @MainActor
        func perform(using appState: AppState) {
            switch self {
            case .voice:
                NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
            case .capture:
                NotificationCenter.default.post(name: .companionShowCapturePanel, object: nil)
            case .inbox:
                appState.selectSidebarItem(.inbox)
            case .settings:
                appState.selectSidebarItem(.settings)
            }
        }
    }

    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let kind: Kind

    @MainActor
    func perform(using appState: AppState) {
        kind.perform(using: appState)
    }
}

private struct ActionTile: View {
    let action: WorkspaceAction

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(action.accent.opacity(0.10))
                    .frame(width: 44, height: 44)

                Image(systemName: action.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(action.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(action.subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft.opacity(0.66))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.68), lineWidth: 1)
        )
    }
}

private struct StatusPill: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            Text(detail)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .frame(width: 170, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct SummaryLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .padding(.vertical, 4)
    }
}
