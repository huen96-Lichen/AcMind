import SwiftUI

enum AcWorkRoute: String, CaseIterable, Identifiable {
    case workspace
    case agent
    case inbox
    case calendar
    case toolbench
    case dynamicIsland
    case voiceInput
    case status
    case models
    case settings

    var id: String { rawValue }
}

enum AcWorkLayout {
    static let designSize = CGSize(width: 1500, height: 920)
    static let minimumWindowSize = CGSize(width: 1180, height: 720)
    static let sidebarWidth: CGFloat = 216
    static let toolbarHeight: CGFloat = 60
    static let pagePadding: CGFloat = 20
    static let sectionGap: CGFloat = 16
    static let filterRailWidth: CGFloat = 220
    static let inspectorWidth: CGFloat = 304
    static let inspectorThreshold: CGFloat = 1320
}

struct AcWorkShell<Content: View>: View {
    @Binding var selection: AcWorkRoute
    let title: String
    let context: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            AcWorkSidebar(selection: $selection)
                .frame(width: AcWorkLayout.sidebarWidth)

            VStack(spacing: 0) {
                AcWorkToolbar(title: title, context: context)
                    .frame(height: AcWorkLayout.toolbarHeight)

                Divider()

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(AcWorkLayout.pagePadding)
            }
        }
        .frame(
            minWidth: AcWorkLayout.minimumWindowSize.width,
            minHeight: AcWorkLayout.minimumWindowSize.height
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct AcWorkSidebar: View {
    @Binding var selection: AcWorkRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Color.clear.frame(height: 44)

            Text("AcWork")
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    navGroup("工作", routes: [.workspace, .agent, .inbox, .calendar])
                    navGroup("处理", routes: [.toolbench])
                    navGroup("随身能力", routes: [.dynamicIsland, .voiceInput])
                    navGroup("系统", routes: [.status, .models, .settings])
                }
                .padding(.horizontal, 12)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text("本地服务正常")
                    Text("Qwen 9B · 本地")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 11))
            }
            .padding(16)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder
    private func navGroup(_ title: String, routes: [AcWorkRoute]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            ForEach(routes) { route in
                Button {
                    selection = route
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: icon(for: route))
                            .frame(width: 18)
                        Text(label(for: route))
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(selection == route ? Color.accentColor.opacity(0.10) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func label(for route: AcWorkRoute) -> String {
        switch route {
        case .workspace: "工作台"
        case .agent: "Agent"
        case .inbox: "收集箱"
        case .calendar: "日程"
        case .toolbench: "工具台"
        case .dynamicIsland: "灵动大陆"
        case .voiceInput: "说入法"
        case .status: "状态"
        case .models: "模型"
        case .settings: "设置"
        }
    }

    private func icon(for route: AcWorkRoute) -> String {
        switch route {
        case .workspace: "rectangle.grid.2x2"
        case .agent: "sparkles"
        case .inbox: "tray.full"
        case .calendar: "calendar"
        case .toolbench: "wrench.and.screwdriver"
        case .dynamicIsland: "capsule"
        case .voiceInput: "waveform"
        case .status: "gauge.with.dots.needle.67percent"
        case .models: "cpu"
        case .settings: "gearshape"
        }
    }
}

private struct AcWorkToolbar: View {
    let title: String
    let context: String?

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))

            if let context {
                Text(context)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("快速记录") {}
                .buttonStyle(.borderedProminent)

            Button {
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, AcWorkLayout.pagePadding)
    }
}
