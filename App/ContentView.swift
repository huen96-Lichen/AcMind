import SwiftUI
import AcMindKit

@MainActor
struct ClipboardPinActions {
    let showItem: (ClipboardItem) -> Void
    let showAll: () -> Void
    let hideAll: () -> Void
    let closeAll: () -> Void
    let copyDiagnostics: () -> Void
}

// MARK: - Content View
// AcMind 主应用框架

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    let clipboardPinActions: ClipboardPinActions
    @State private var showVoicePanel = false
    @State private var showCapturePanel = false
    @State private var showQuickNote = false

    private var selectedItemBinding: Binding<SidebarItem> {
        Binding(
            get: { appState.sidebarSelection },
            set: { appState.selectSidebarItem($0) }
        )
    }

    var body: some View {
        NavigationSplitView {
            MainSidebar(selectedItem: selectedItemBinding)
        } detail: {
            MainContent(
                selectedItem: appState.sidebarSelection,
                clipboardPinActions: clipboardPinActions
            )
        }
        .navigationSplitViewStyle(.balanced)
        .navigationSplitViewColumnWidth(min: 292, ideal: 320, max: 380)
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showVoicePanel) {
            CompanionVoicePanel()
        }
        .sheet(isPresented: $showCapturePanel) {
            CompanionCapturePanel()
        }
        .sheet(isPresented: $showQuickNote) {
            QuickNotePanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowAgent)) { _ in
            appState.selectSidebarItem(.agent)
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowInbox)) { _ in
            appState.selectSidebarItem(.inbox)
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowSchedule)) { _ in
            appState.selectSidebarItem(.schedule)
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowVoicePanel)) { _ in
            guard SettingsLocalPreferences.isVoiceInputEnabled() else {
                appState.showError(.serviceUnavailable("说入法输入已在设置中关闭"))
                return
            }
            showVoicePanel = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowCapturePanel)) { _ in
            showCapturePanel = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowQuickNote)) { _ in
            showQuickNote = true
        }
    }
}

// MARK: - Main Sidebar

struct MainSidebar: View {
    @Binding var selectedItem: SidebarItem
    @State private var hoveredItem: SidebarItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sidebarHeader
                sidebarSection(title: "核心工作流", items: SidebarItem.coreWorkflow)
                sidebarSection(title: "伴随能力", items: SidebarItem.companionCapabilities)
                sidebarSection(title: "系统", items: SidebarItem.systemItems)
            }
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360)
        .background(AppSurfaceTokens.sidebarBackground.ignoresSafeArea())
    }

    private func sidebarSection(title: String, items: [SidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sidebarSectionHeader(title)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        SidebarItemView(
                            item: item,
                            isSelected: selectedItem == item,
                            isHovered: hoveredItem == item
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredItem = isHovered ? item : nil
                    }
                }
            }
        }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AcMind")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Text("主导航")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppSurfaceTokens.secondaryText)
            .textCase(nil)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

// MARK: - Sidebar Item View

struct SidebarItemView: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
                    .frame(width: 26, height: 26)

                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : AppSurfaceTokens.secondaryText)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(1)
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                if item.group == .companionCapabilities {
                    Text("伴随能力")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 6)

            if let shortcut = item.shortcut {
                Text(shortcut.displayString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.accentColor : AppSurfaceTokens.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.08) : AppSurfaceTokens.cardBackgroundSoft.opacity(0.85))
                    )
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : (isHovered ? AppSurfaceTokens.cardBackgroundSoft.opacity(0.72) : Color.clear))
        )
        .foregroundStyle(AppSurfaceTokens.primaryText)
        .contentShape(Rectangle())
    }
}

// MARK: - Main Content

struct MainContent: View {
    let selectedItem: SidebarItem
    let clipboardPinActions: ClipboardPinActions

    var body: some View {
        Group {
            switch selectedItem {
            case .home, .systemStatus:
                WorkspaceHomeView()
                    .navigationTitle("首页")
            case .agent:
                AgentDashboardView()
                    .navigationTitle("Agent")
            case .inbox:
                InboxView()
                    .navigationTitle("收集箱")
            case .clipboard:
                ClipboardView(clipboardPinActions: clipboardPinActions)
                    .navigationTitle("剪贴板 & 手机同步")
            case .schedule:
                ScheduleDashboardView()
                    .navigationTitle("日程")
            case .workbench:
                ToolsView()
                    .navigationTitle("工具台")
            case .dynamicContinent:
                DynamicContinentConfigView()
                    .navigationTitle("灵动大陆 & 配置")
            case .voiceEntry:
                VoiceEntryView()
                    .navigationTitle("说入法设置")
            case .modelManagement:
                ModelManagementPanel()
                    .navigationTitle("模型管理")
            case .settings:
                SettingsView()
                    .navigationTitle("设置")
            }
        }
    }
}
