import SwiftUI
import AcMindKit

// MARK: - Content View

/// 主内容视图
/// 使用 NavigationSplitView 实现原生 macOS 三栏布局
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: ServiceContainer

    var body: some View {
        NavigationSplitView {
            // 侧边栏
            SidebarView()
                .frame(minWidth: 180, idealWidth: 200)
        } detail: {
            // 详情区域
            detailContent
                .frame(minWidth: 600, minHeight: 400)
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch appState.sidebarSelection {
        case .agent:
            AgentView()
                .environmentObject(AgentViewModel(
                    storage: container.storageService,
                    aiRuntime: container.aiRuntime
                ))

        case .inbox:
            InboxView()
                .environmentObject(InboxViewModel(
                    storage: container.storageService
                ))

        case .clipboard:
            ClipboardPlaceholderView()

        case .schedule:
            ScheduleNativeView()

        case .workbench:
            WorkbenchPlaceholderView()

        case .tools:
            ToolsPlaceholderView()

        case .settings:
            SettingsView()
                .environmentObject(SettingsViewModel(
                    settings: container.settingsService
                ))
        }
    }
}

// MARK: - Placeholder Views

struct WorkbenchPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("工作台")
                .font(.title)

            Text("知识沉淀与自动化工具")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ToolsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("自动工具")
                .font(.title)

            Text("批量处理与自动化")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("剪贴板")
                .font(.title)

            Text("剪贴板历史和快速收集")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
